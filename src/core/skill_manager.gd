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
##         DataLoader.load_json("res://assets/data/skills.json"), game_state, combat, floors)
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
## Skills in file (display) order.
var _skills: Array[Skill] = []
## Skill id (String) -> [Skill].
var _by_id: Dictionary = {}
## Factor on every cooldown started from now on (1.0 = the data).
var _cooldown_modifier: float = 1.0


## Parses and validates skills.json (as returned by [method DataLoader.load_json], null
## allowed), restores the timers saved in [param state] and applies the buffs still
## running to [param floors]. Always returns an instance; check [method is_valid].
## [param floors] must be built from the same [param state] and [param combat].
static func from_data(data: Variant, state: GameState, combat: Combat, floors: FloorManager) -> SkillManager:
	var manager: SkillManager = SkillManager.new()
	manager._state = state
	manager._combat = combat
	manager._floors = floors
	manager._load(data)
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


## Cooldown [param skill] would get if activated now: the data value times the modifier,
## at least the effect duration.
func effective_cooldown(skill_to_check: Skill) -> float:
	return maxf(skill_to_check.cooldown_seconds * _cooldown_modifier, skill_to_check.duration_seconds)


## Damage the burst [param skill] deals now, before the damage buff:
## floor((companion_power + click_damage) * dps_seconds), both with their talents.
func burst_damage(burst: Skill) -> BigNumber:
	var per_second: BigNumber = _floors.companion_power().add(_floors.click_damage())
	return per_second.multiply_decimal(burst.amount)


## True when [param id] exists and is READY.
func can_activate(id: String) -> bool:
	var found: Skill = _by_id.get(id)
	return found != null and found.state() == Skill.State.READY


## Activates [param id]: starts its cooldown and applies its effect (a burst deals its
## damage now, a buff starts). Returns false and changes nothing when the id is unknown
## or the skill is not READY.
func activate(id: String) -> bool:
	if not can_activate(id):
		return false
	var found: Skill = _by_id[id]
	found.start(effective_cooldown(found))
	if found.effect == Skill.Effect.BURST:
		_floors.apply_damage(burst_damage(found))
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
			restored.restore(float(saved.get("cooldown_left", 0.0)), float(saved.get("active_left", 0.0)))
	_push_multipliers()


# Tells the FloorManager the factors of the buffs running now ("1" when none).
func _push_multipliers() -> void:
	var damage: String = "1"
	var gold: String = "1"
	for running: Skill in _skills:
		if running.state() != Skill.State.ACTIVE:
			continue
		if running.effect == Skill.Effect.DAMAGE_MULTIPLIER:
			damage = running.amount
		elif running.effect == Skill.Effect.GOLD_MULTIPLIER:
			gold = running.amount
	_floors.set_damage_multiplier(damage)
	_floors.set_gold_multiplier(gold)
