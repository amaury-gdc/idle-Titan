class_name SkillManager
extends RefCounted
## Runtime logic of the three active skills (story 005, design/game-brief.md MVP feature
## 5): activation, cooldowns, effect durations and the effects themselves. Definitions
## come from skills.json (see [Skill] and assets/data/data_schema.md). No Node, no timer
## and no UI reference: time is fed through [method tick], so a headless simulation
## drives it exactly like the game does. The UI polls the [Skill] states.
##
## Effects:
## [codeblock]
## burst (Gros coup)         burst_damage = floor((companion_power + click_damage) * dps_seconds)
##                           dealt at once through FloorManager.apply_damage
## damage_multiplier         FloorManager multiplies every damage it applies (clicks,
##                           companion attacks and the burst) by "multiplier" while active
## gold_multiplier           FloorManager multiplies the gold of every kill (normal enemies
##                           and bosses) by "multiplier" while active
## [/codeblock]
## "companion_power + click_damage" reads as one second of damage with one click per second:
## the click term keeps the burst useful before any companion is bought. Both come from
## [FloorManager], so the burst gets the click and companion talents (story 006). The data
## holds exactly one skill per effect, so buffs never stack.
##
## The multipliers are pushed to the [FloorManager] when a buff starts or ends, so the
## FloorManager never depends on this class. Offline gold ([OfflineIncome]) does not use them.
##
## Cooldown modifiers: [method set_cooldown_modifier] scales every cooldown started
## afterwards (story 006 talents). A cooldown never goes below the effect duration.
##
## Talents (story 018, design/talent-tree-v2.md), read through the optional [ModifierHub]:
## a skill some node unlocks is LOCKED until such a node is bought. The lock is derived from the
## bought nodes, never stored, and checked here: [method can_activate] and [method activate]
## refuse a locked skill, whatever asks (button, key, simulator). A saved timer of a locked skill
## is ignored, and a skill that becomes locked (reset, new tree version) stops at once: its buff
## ends, its cooldown is dropped, nothing is left over. [method effective_amount],
## [method effective_duration] and [method effective_cooldown] are the per-skill values with the
## [code]skill_mod[/code] of the talents; activations, restored timers and running timers (cut
## when a value shrinks) all use them.
##
## Time: skills run on game time fed to [method tick], clamped to [constant MAX_TICK_SECONDS]
## like the companions and the boss countdown. A tab in the background therefore pauses
## cooldowns and running buffs (at most one clamped step is credited on return), and so
## does the "Bon retour !" panel, behind which the main screen stops ticking. Timers are
## saved in [member GameState.skill_timers] by [method save_to] and restored at construction.
## Single-thread only. Build with [method from_data] and check [method is_valid].
##
## Usage:
## [codeblock]
## var skills: SkillManager = SkillManager.from_data(
##         DataLoader.load_json("res://assets/data/skills.json"), game_state, combat, floors, hub)
## if skills.is_valid():
##     if skills.activate("big_hit"):
##         print("boom")
##     skills.tick(delta)              # every frame, after the damage of the frame
##     skills.save_to(game_state)      # before SaveManager.save()
## else:
##     push_error(skills.get_error())
## [/codeblock]

## Version of skills.json this code understands.
const SUPPORTED_SCHEMA: int = 1
## Largest [param delta] one [method tick] call honors, in seconds. A longer frame (tab in
## the background, debugger pause) is cut to this, so a stall neither floods nor
## fast-forwards the timers. Same bound as [constant CompanionManager.MAX_TICK_SECONDS];
## infrastructure safety bound, not balance.
const MAX_TICK_SECONDS: float = 5.0

var _error: String = ""
var _state: GameState
var _combat: Combat
var _floors: FloorManager
## Source of the locks and per-skill values of the talents; null means none.
var _modifiers: ModifierHub
## Skills in file (display) order.
var _skills: Array[Skill] = []
## Skill id (String) -> [Skill].
var _by_id: Dictionary = {}
## Ids (String -> true) of the skills the talents lock, cached by _refresh_flags.
var _locked: Dictionary = {}
## Id (String) -> multiplier (decimal String) of the unlocked skills a talent makes passive, cached
## by _refresh_flags.
var _passive: Dictionary = {}
var _talent_version: int = 0
## Factor on every cooldown started from now on (1.0 = the data).
var _cooldown_modifier: float = 1.0


## Parses and validates skills.json (as returned by [method DataLoader.load_json], null
## allowed), restores the timers saved in [param state] and applies the buffs still
## running to [param floors]. Always returns an instance; check [method is_valid].
## [param floors] must be built from the same [param state] and [param combat]. [param modifiers]
## brings the talents (locks and per-skill values); build it first, so that the restored timers
## already follow them. Without it no skill is locked and the data values apply.
static func from_data(data: Variant, state: GameState, combat: Combat, floors: FloorManager, modifiers: ModifierHub = null) -> SkillManager:
	var manager: SkillManager = SkillManager.new()
	manager._state = state
	manager._combat = combat
	manager._floors = floors
	manager._modifiers = modifiers
	manager._load(data)
	if modifiers != null and manager.is_valid():
		modifiers.changed.connect(manager._follow_talents)
	return manager


## True when the data parsed cleanly.
func is_valid() -> bool:
	return _error.is_empty()


## First validation problem found, or "" when valid.
func get_error() -> String:
	return _error


## The skills in file order (empty when the data is invalid). Read-only: do not modify.
func skills() -> Array[Skill]:
	return _skills


## The skill with [param id], or null.
func skill(id: String) -> Skill:
	return _by_id.get(id)


## Scales the cooldown of every skill activated from now on by [param factor] (0.8 = 20%
## shorter; negative values count as 0). Running cooldowns are not changed. Meant for
## talents (story 006); the result never goes below the effect duration.
func set_cooldown_modifier(factor: float) -> void:
	_cooldown_modifier = maxf(factor, 0.0)


## Current cooldown factor (1.0 = the data).
func cooldown_modifier() -> float:
	return _cooldown_modifier


## Cooldown [param skill] would get if activated now: the value of the talents (else of the
## data) times the modifier, at least [method effective_duration].
func effective_cooldown(skill_to_check: Skill) -> float:
	return maxf(_talent_cooldown(skill_to_check) * _cooldown_modifier, effective_duration(skill_to_check))


## Seconds the effect of [param skill] lasts now: the value of the talents, else of the data.
## Always 0 for a burst.
func effective_duration(skill_to_check: Skill) -> float:
	if skill_to_check.effect == Skill.Effect.BURST:
		return 0.0
	var value: Variant = _override(skill_to_check, TalentTree.SKILL_DURATION)
	return skill_to_check.duration_seconds if value == null else float(value)


## Strength of [param skill] now, as a decimal string (seconds of damage of a burst, factor of a
## buff): the value of the talents, else of the data.
## A passive skill ([method is_passive]) gives the multiplier of its passive node instead, whatever its
## [code]skill_mod[/code] say (story 019 "Instinct de meute" cancels "Frénésie durable" and "ardente").
func effective_amount(skill_to_check: Skill) -> String:
	var passive: String = _passive.get(skill_to_check.id, "")
	if not passive.is_empty():
		return passive
	var value: Variant = _override(skill_to_check, TalentTree.SKILL_AMOUNT)
	return skill_to_check.amount if value == null else String(value)


## Damage the burst [param skill] deals now, before the damage buff:
## floor((companion_power + click_damage) * dps_seconds), both with their talents, dps_seconds
## from [method effective_amount] (see [method FloorManager.damage_over]).
func burst_damage(burst: Skill) -> BigNumber:
	return _floors.damage_over(effective_amount(burst))


## False when [param id] is unknown or the talents lock it (derived from the bought nodes).
## Read from flags cached on every change of the hub (see [method _refresh_flags]): the skill bar asks
## every frame.
func is_unlocked(id: String) -> bool:
	return _by_id.has(id) and not _locked.has(id)


## True when a bought node makes [param id] passive (story 019 "Instinct de meute", a
## [code]skill_passive[/code] effect): its effect runs all the time at [method effective_amount], it
## cannot be activated and has no timer. The button stays in its place, marked "Passif" by the UI.
## Derived from the bought nodes, never saved. False for an unknown id or a locked skill.
func is_passive(id: String) -> bool:
	return _passive.has(id)


## A number that changes each time the talents may have changed the skills (locks, passives, values):
## a display compares it with the one it drew to rebuild its texts only then.
func talent_version() -> int:
	return _talent_version


## True when [param id] exists, is unlocked, is not passive and is READY.
func can_activate(id: String) -> bool:
	var found: Skill = _by_id.get(id)
	return found != null and is_unlocked(id) and not is_passive(id) and found.state() == Skill.State.READY


## Activates [param id]: starts its cooldown and applies its effect (a burst deals its
## damage now, a buff starts). Returns false and changes nothing when the id is unknown,
## the skill is locked or not READY.
func activate(id: String) -> bool:
	if not can_activate(id):
		return false
	var found: Skill = _by_id[id]
	found.start(effective_cooldown(found), effective_duration(found))
	if found.effect == Skill.Effect.BURST:
		_floors.apply_damage(burst_damage(found), FloorManager.HitSource.BURST)
	else:
		_push_multipliers()
	return true


## Advances every timer by [param delta] seconds (clamped to 0..[constant MAX_TICK_SECONDS]).
## A buff that ends here stops affecting the [FloorManager]. Call it once per frame, after
## the damage of that frame (a buff counts for the whole frame it ends in).
func tick(delta: float) -> void:
	var step: float = clampf(delta, 0.0, MAX_TICK_SECONDS)
	if step <= 0.0:
		return
	var ended: bool = false
	for running: Skill in _skills:
		if running.tick(step):
			ended = true
	if ended:
		_push_multipliers()


## Writes the timers of the skills that are not READY into [member GameState.skill_timers]
## (id -> {"cooldown_left", "active_left"}), replacing what was there. Call it before
## [method SaveManager.save].
func save_to(state: GameState) -> void:
	state.skill_timers = {}
	for saved: Skill in _skills:
		if saved.cooldown_left() > 0.0:
			state.skill_timers[saved.id] = {"cooldown_left": saved.cooldown_left(), "active_left": saved.active_left()}


func _load(data: Variant) -> void:
	if not data is Dictionary:
		_error = "skills.json is missing or not an object"
		return
	var d: Dictionary = data
	var version: Variant = d.get("schema_version")
	if not (version is int or version is float) or int(version) != SUPPORTED_SCHEMA:
		_error = "skills.json: unsupported schema_version (expected %d)" % SUPPORTED_SCHEMA
		return
	var entries: Variant = d.get("skills")
	if not entries is Array:
		_error = "skills.json: 'skills' must be an array"
		return
	var effects_seen: Dictionary = {}
	for entry: Variant in entries:
		if not entry is Dictionary:
			_error = "skills.json: each skill must be an object"
			return
		var parsed: Skill = Skill.from_entry(entry)
		if not parsed.is_valid():
			_error = parsed.get_error()
			return
		if _by_id.has(parsed.id):
			_error = "skills.json: duplicate id '%s'" % parsed.id
			return
		if effects_seen.has(parsed.effect):
			_error = "skills.json: only one skill per effect is supported ('%s' repeats an effect)" % parsed.id
			return
		effects_seen[parsed.effect] = true
		_by_id[parsed.id] = parsed
		_skills.append(parsed)
	if _skills.size() != Skill.EFFECT_BY_NAME.size():
		_error = "skills.json: expected exactly one skill for each of %s" % str(Skill.EFFECT_BY_NAME.keys())
		return
	for restored: Skill in _skills:
		var saved: Variant = _state.skill_timers.get(restored.id)
		if saved is Dictionary:
			restored.restore(float(saved.get("cooldown_left", 0.0)), float(saved.get("active_left", 0.0)), _cooldown_cap(restored), effective_duration(restored))
	_follow_talents()


# Stops the locked skills and cuts the timers of the others to their current values, then pushes
# the buffs. Called after the load and on every change of the hub. The cooldown cap leaves the
# cooldown modifier out: it only applies to cooldowns started afterwards.
func _follow_talents() -> void:
	_refresh_flags()
	for followed: Skill in _skills:
		if is_unlocked(followed.id) and not is_passive(followed.id):
			followed.restore(followed.cooldown_left(), followed.active_left(), _cooldown_cap(followed), effective_duration(followed))
		else:
			followed.restore(0.0, 0.0, 0.0, 0.0)
	_push_multipliers()


# Asks the hub once per skill which are locked and which are passive (an unlocked skill only), so
# that is_unlocked, is_passive and effective_amount scan no talent. Called by _follow_talents, on
# the load and on every change of the hub.
func _refresh_flags() -> void:
	_talent_version += 1
	_locked.clear()
	_passive.clear()
	if _modifiers == null:
		return
	for flagged: Skill in _skills:
		if not _modifiers.skill_unlocked(flagged.id):
			_locked[flagged.id] = true
			continue
		var multiplier: String = _modifiers.skill_passive(flagged.id)
		if not multiplier.is_empty():
			_passive[flagged.id] = multiplier


# The cooldown of the talents, else of the data, without the modifier.
func _talent_cooldown(skill_to_check: Skill) -> float:
	var value: Variant = _override(skill_to_check, TalentTree.SKILL_COOLDOWN)
	return skill_to_check.cooldown_seconds if value == null else float(value)


# Longest a saved or running cooldown may be: [method _talent_cooldown], at least the duration.
func _cooldown_cap(skill_to_check: Skill) -> float:
	return maxf(_talent_cooldown(skill_to_check), effective_duration(skill_to_check))


# The value the talents give to [param field] of [param skill], or null.
func _override(skill_to_check: Skill, field: String) -> Variant:
	return null if _modifiers == null else _modifiers.skill_override(skill_to_check.id, field)


# Tells the FloorManager the factors of the buffs running now, passive ones included ("1" when none).
func _push_multipliers() -> void:
	var damage: String = "1"
	var gold: String = "1"
	for running: Skill in _skills:
		if running.state() != Skill.State.ACTIVE and not is_passive(running.id):
			continue
		if running.effect == Skill.Effect.DAMAGE_MULTIPLIER:
			damage = effective_amount(running)
		elif running.effect == Skill.Effect.GOLD_MULTIPLIER:
			gold = effective_amount(running)
	_floors.set_damage_multiplier(damage)
	_floors.set_gold_multiplier(gold)
