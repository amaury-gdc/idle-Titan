class_name CompanionManager
extends RefCounted
## Runtime logic of the companions: buying and upgrading them with gold, and their
## automatic attacks. Levels live in the injected [GameState]
## ([member GameState.companion_levels], saved by the existing save format); the
## formulas come from the [Companion] definitions held by the injected [Combat].
## Implements design/game-brief.md "Core loop" and MVP feature 3 (story 003).
## No Node, no timer and no UI reference: time is fed through [method tick], so a
## headless simulation drives it exactly like the game does. The UI listens to
## the signals.
##
## Each bought companion attacks alone, every attack_interval_seconds, through
## [method FloorManager.apply_damage]. Attack timers are not saved: after a load a
## companion needs one full interval before its first attack, and a companion just
## bought starts its first interval at the next tick. Single-thread only.
##
## Usage:
## [codeblock]
## var companions: CompanionManager = CompanionManager.new(game_state, combat, floors)
## companions.companion_leveled_up.connect(func(id: String, level: int) -> void: print(id, level))
## if companions.buy_or_upgrade("archer"):
##     print(companions.next_cost("archer").format())
## # every frame:
## companions.tick(delta)
## [/codeblock]

## Gold was spent on one level through [method buy_or_upgrade] and [param id] is now at
## [param new_level] (a first purchase gives 1). A batch does not emit it: see
## [signal companions_bought].
signal companion_leveled_up(id: String, new_level: int)
## One [method buy_levels] succeeded and [param id] is now at [param new_level]. Emitted
## once per batch, in place of [signal companion_leveled_up], so a listener connected
## to both redraws once whatever the batch size.
signal companions_bought(id: String, new_level: int)
## [param id] attacked on its own and dealt [param damage] (already applied to the enemy).
signal companion_attacked(id: String, damage: BigNumber)

## Largest [param delta] one [method tick] call honors, in seconds. A longer frame
## (tab in the background, debugger pause) is cut to this, so a stall can never
## trigger a flood of attacks. Offline progress is a separate feature (brief
## "Hors-ligne"), not handled here. Infrastructure safety bound, not balance.
const MAX_TICK_SECONDS: float = 5.0
## Most levels one [method affordable_levels] scan counts, so a huge gold value cannot
## make it run without end. 1000 levels of the cheapest companion, from level 0, cost
## about 3e35 gold (cost_growth 1.08, base_cost 10). The wall stands before stage 130,
## where one kill pays about 3e14; a kill only pays 3e35 near stage 330. So this
## cannot change a purchase in play, and past it a second purchase buys the rest.
## Infrastructure safety bound, not balance.
const MAX_SCAN_LEVELS: int = 1000

var _state: GameState
var _combat: Combat
var _floors: FloorManager
## Companion id (String) -> seconds accumulated toward the next attack (float).
var _elapsed: Dictionary = {}


## All three are required; [param combat] must be valid and [param floors] built
## from the same [param state] and [param combat].
func _init(state: GameState, combat: Combat, floors: FloorManager) -> void:
	_state = state
	_combat = combat
	_floors = floors


## The roster in display order. Read-only: do not modify.
func companions() -> Array[Companion]:
	return _combat.companions()


## Display name of [param id], which must be in the roster.
func display_name(id: String) -> String:
	return _combat.companion(id).display_name


## Current level of [param id]; 0 means not bought.
func level(id: String) -> int:
	return maxi(int(_state.companion_levels.get(id, 0)), 0)


## Damage of one attack of [param id] at its current level, with the companion talents
## (story 006); 0 when not bought. [param id] must be in the roster.
func damage(id: String) -> BigNumber:
	return _floors.companion_damage(_combat.companion(id).damage_at_level(level(id)))


## Damage per second of [param id] at its current level, with the companion talents;
## 0 when not bought. [param id] must be in the roster.
func damage_per_second(id: String) -> BigNumber:
	return _floors.companion_damage(_combat.companion(id).damage_per_second_at_level(level(id)))


## Gold cost of the next level of [param id] (level 1 when not bought).
## [param id] must be in the roster.
func next_cost(id: String) -> BigNumber:
	return _combat.companion(id).cost_of_level(level(id) + 1)


## True when [param id] is in the roster and the gold on hand covers [method next_cost].
func can_buy(id: String) -> bool:
	if _combat.companion(id) == null:
		return false
	return _state.gold.compare(next_cost(id)) >= 0


## Exact gold cost of the next [param count] levels of [param id], the sum of what
## [param count] calls of [method buy_or_upgrade] would spend. 0 when count <= 0.
## [param id] must be in the roster.
func cost_of_levels(id: String, count: int) -> BigNumber:
	return _combat.companion(id).cost_of_levels_from(level(id) + 1, count)


## How many next levels of [param id] the gold on hand covers, at most [param max_count]
## and never more than [constant MAX_SCAN_LEVELS]. 0 for an unknown id or when
## max_count <= 0. The result can be passed to [method buy_levels] as is.
func affordable_levels(id: String, max_count: int = MAX_SCAN_LEVELS) -> int:
	var companion: Companion = _combat.companion(id)
	if companion == null:
		return 0
	return companion.affordable_levels_from(level(id) + 1, _state.gold, mini(max_count, MAX_SCAN_LEVELS))


## What [method affordable_levels] counts, with the exact cost of those levels, from one walk:
## {"count": int, "total": BigNumber}. An unknown id gives a count of 0.
func affordable_walk(id: String, max_count: int = MAX_SCAN_LEVELS) -> Dictionary:
	var companion: Companion = _combat.companion(id)
	if companion == null:
		return {"count": 0, "total": BigNumber.new()}
	return companion.affordable_walk_from(level(id) + 1, _state.gold, mini(max_count, MAX_SCAN_LEVELS))


## The tier levels of [param id], which must be in the roster. Read-only: do not modify.
func tier_levels(id: String) -> Array[int]:
	return _combat.companion(id).tier_levels()


## The first tier above the current level of [param id], which must be in the roster:
## see [method Companion.next_tier_from]. Reading only, no rule depends on it.
## [codeblock]
## var tier: Dictionary = companions.next_tier("archer")
## if tier["level"] > 0:
##     print("level %d: x%s" % [tier["level"], tier["multiplier"]])
## [/codeblock]
func next_tier(id: String) -> Dictionary:
	return _combat.companion(id).next_tier_from(level(id))


## Buys the next [param count] levels of [param id] as one transaction, spending
## exactly [method cost_of_levels]. Returns true on success. Unknown id, count <= 0 or
## gold short of the whole sum: returns false and nothing changes. Emits
## [signal companions_bought] once on success, and no [signal companion_leveled_up].
## [codeblock]
## if companions.buy_levels("archer", companions.affordable_levels("archer")):
##     print(companions.level("archer"))
## [/codeblock]
func buy_levels(id: String, count: int) -> bool:
	if count <= 0 or _combat.companion(id) == null:
		return false
	var total: BigNumber = cost_of_levels(id, count)
	if _state.gold.compare(total) < 0:
		return false
	_state.gold = _state.gold.subtract(total)
	var new_level: int = level(id) + count
	_state.companion_levels[id] = new_level
	companions_bought.emit(id, new_level)
	return true


## Buys [param id] (level 0 to 1) or raises it by one level, spending [method next_cost]
## from the state's gold. Returns true on success. Unknown id or not enough gold:
## returns false and nothing changes. Emits [signal companion_leveled_up] on success.
func buy_or_upgrade(id: String) -> bool:
	if not can_buy(id):
		return false
	_state.gold = _state.gold.subtract(next_cost(id))
	var new_level: int = level(id) + 1
	_state.companion_levels[id] = new_level
	companion_leveled_up.emit(id, new_level)
	return true


## Total damage per second of the companions, with the companion talents (story 006).
## The click formula and the offline gold use the bare sum of [method Combat.companion_power]
## instead.
func total_power() -> BigNumber:
	return _floors.companion_power()


## Advances time by [param delta] seconds (clamped to 0..[constant MAX_TICK_SECONDS]).
## Every bought companion attacks once per elapsed interval, however many fit in
## [param delta]; the remainder carries over to the next call. Companions act in
## roster order within one call, and an attack that kills the enemy makes the
## following attacks hit the next stage's enemy.
func tick(delta: float) -> void:
	var step: float = clampf(delta, 0.0, MAX_TICK_SECONDS)
	if step <= 0.0:
		return
	for companion: Companion in _combat.companions():
		var current_level: int = level(companion.id)
		if current_level <= 0:
			continue
		var elapsed: float = float(_elapsed.get(companion.id, 0.0)) + step
		var attacks: int = int(elapsed / companion.attack_interval_seconds)
		_elapsed[companion.id] = elapsed - float(attacks) * companion.attack_interval_seconds
		if attacks == 0:
			continue
		var attack_damage: BigNumber = _floors.companion_damage(companion.damage_at_level(current_level))
		for i in attacks:
			_floors.apply_damage(attack_damage)
			companion_attacked.emit(companion.id, attack_damage)
