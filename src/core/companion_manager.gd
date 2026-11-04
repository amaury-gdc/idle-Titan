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
## [param id] awakened through [method awaken] (story 016): the gold is spent and its awakenings, and
## the squad's, already count. Level and enemy are unchanged. The UI redraws on it.
signal awakened(id: String)

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
## What [method buyable_levels_cap] returns when no awakening threshold stands ahead: no limit.
## Larger than any level count a purchase can reach, small enough to add to a level without overflow.
const NO_CAP: int = 1 << 30

var _state: GameState
var _combat: Combat
var _floors: FloorManager
## Companion id -> Array of awakening costs indexed by rank (BigNumber, null until computed). A pure
## function of the data, kept because the interface asks for it on every redraw and a cost is a
## power on big numbers.
var _awakening_costs: Dictionary = {}
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


## Damage of one attack of [param id] at its current level, with its awakenings and the squad's
## and the companion talents (story 006, "Synergie" and "Champion" of story 019); 0 when not bought.
## [param id] must be in the roster.
func damage(id: String) -> BigNumber:
	return _floors.companion_attack_damage(id)


## Damage per second of [param id] at its current level, awakenings and companion talents included,
## attack speed of "Cadence" too; 0 when not bought. [param id] must be in the roster.
func damage_per_second(id: String) -> BigNumber:
	return _floors.companion_dps(id)


## What [method damage_per_second] of [param id] would be at [param level], all else as now (see
## [method FloorManager.companion_dps_at]): a reading for the "+X DPS" of a purchase, which changes
## nothing. [param id] must be in the roster.
## [codeblock]
## var gain: BigNumber = companions.damage_per_second_at("scout", 20).subtract(companions.damage_per_second("scout"))
## [/codeblock]
func damage_per_second_at(id: String, level: int) -> BigNumber:
	return _floors.companion_dps_at(id, level)


## Number of awakenings of [param id] (0 for none, an unknown id, or a roster without the
## "awakening" block), never above the number of thresholds of the data.
## [codeblock]
## print(companions.awakenings("archer"))   # 2 after awakening at 200 and 300
## [/codeblock]
func awakenings(id: String) -> int:
	return _combat.awakening_count(_state.companion_awakenings, id)


## The awakenings of the whole squad that count for the squad multiplier (thresholds up to the
## limit of the data, all companions): the A of the damage formula.
## [codeblock]
## print(companions.squad_awakenings())   # 3 when scout was awakened twice and archer once
## [/codeblock]
func squad_awakenings() -> int:
	return _combat.squad_awakenings(_state.companion_awakenings)


## The next awakening of [param id], in threshold order, whatever its level: {} when there is none
## (every threshold awakened, a roster without the "awakening" block, or an unknown id), else
## {"level": int, "cost": BigNumber}: the threshold level and the gold it costs (cost_level_multiplier
## times the cost of that level). The player can pay it once the level is reached, see [method can_awaken].
## [codeblock]
## var next: Dictionary = companions.next_awakening("scout")
## if not next.is_empty():
##     print("Awaken at level %d for %s" % [next["level"], (next["cost"] as BigNumber).format()])
## [/codeblock]
func next_awakening(id: String) -> Dictionary:
	var companion: Companion = _combat.companion(id)
	if companion == null:
		return {}
	var done: int = awakenings(id)
	var thresholds: Array[int] = _combat.awakening_thresholds()
	if done >= thresholds.size():
		return {}
	return {"level": thresholds[done], "cost": _awakening_cost(companion, done)}


## The awakening threshold levels of the data, in order; empty without the "awakening" block. The
## interface reads it to draw the rank. Read-only: do not modify.
## [codeblock]
## print(companions.awakening_thresholds().size())   # 9 with thresholds 200 to 1000
## [/codeblock]
func awakening_thresholds() -> Array[int]:
	return _combat.awakening_thresholds()


## True when the next awakening of [param id] counts for the squad multiplier (its threshold is
## within the limit of the data). False when there is no next awakening.
## [codeblock]
## print(companions.next_awakening_counts_for_squad("scout"))   # true for thresholds up to 600
## [/codeblock]
func next_awakening_counts_for_squad(id: String) -> bool:
	# The squad thresholds are the first ones of the list: below their count, a next one exists.
	return awakenings(id) < _combat.awakening_rules().squad_threshold_count()


## The damage factor of one awakening of the companion itself as text with a decimal comma, for
## display only ("3,4"); "1" without the "awakening" block.
func awakening_self_text() -> String:
	return _combat.awakening_rules().self_multiplier_text()


## The damage factor of one counted awakening on the whole squad as text with a decimal comma, for
## display only ("2,10"); "1" without the "awakening" block.
func awakening_squad_text() -> String:
	return _combat.awakening_rules().squad_multiplier_text()


## True when [param id] has a next awakening, its level has reached that threshold and the gold on
## hand covers the cost. Never true on its own: awakening is an action of the player. Cheap enough
## for every frame: no Dictionary, and no cost is read while the level is below the threshold.
func can_awaken(id: String) -> bool:
	var companion: Companion = _combat.companion(id)
	if companion == null:
		return false
	var done: int = awakenings(id)
	if not _threshold_reached(id, done):
		return false
	return _state.gold.compare(_awakening_cost(companion, done)) >= 0


## Awakens [param id]: spends the cost of [method next_awakening] and counts one more awakening, which
## multiplies its damage (and the squad's up to the limit of the data) at once. Returns true on
## success. Returns false and changes nothing when [method can_awaken] is false (a second call right
## after a success asks for the following threshold, which the level has usually not reached).
## Emits [signal awakened] on success. The level, the enemy and the boss countdown are not touched.
## [codeblock]
## if companions.can_awaken("scout"):
##     companions.awaken("scout")
## [/codeblock]
func awaken(id: String) -> bool:
	var companion: Companion = _combat.companion(id)
	if companion == null:
		return false
	var done: int = awakenings(id)
	if not _threshold_reached(id, done):
		return false
	var cost: BigNumber = _awakening_cost(companion, done)
	if _state.gold.compare(cost) < 0:
		return false
	_state.gold = _state.gold.subtract(cost)
	_state.companion_awakenings[id] = done + 1
	awakened.emit(id)
	return true


## How many levels [param id] can still buy before it must awaken: the next threshold not yet
## awakened minus the current level, 0 when the level has reached it (the companion is blocked until
## [method awaken]; a save whose levels already pass several thresholds stays blocked until they are
## all awakened, in order). [constant NO_CAP] when no threshold stands ahead (roster without the
## "awakening" block, or all thresholds awakened). [method can_buy], [method buy_levels],
## [method cost_of_levels], [method affordable_levels] and [method affordable_walk] all obey it.
## [codeblock]
## # scout at level 197, next threshold 200
## companions.buyable_levels_cap("scout")   # 3
## [/codeblock]
func buyable_levels_cap(id: String) -> int:
	var done: int = awakenings(id)
	var thresholds: Array[int] = _combat.awakening_thresholds()
	if done >= thresholds.size():
		return NO_CAP
	return maxi(thresholds[done] - level(id), 0)


## Gold cost of the next level of [param id] (level 1 when not bought).
## [param id] must be in the roster. It is the price of the level even when the companion is
## blocked at a threshold (see [method buyable_levels_cap]). "Négociation" (story 019) is included,
## here and in every level cost and purchase of this class (see [method FloorManager.discounted_cost]);
## awakening costs are NOT discounted (Amaury's ruling: no node touches the awakening cost).
func next_cost(id: String) -> BigNumber:
	return _floors.discounted_cost(_combat.companion(id).cost_of_level(level(id) + 1))


## True when [param id] is in the roster, is not blocked at an awakening threshold
## ([method buyable_levels_cap] above 0) and the gold on hand covers [method next_cost].
func can_buy(id: String) -> bool:
	if _combat.companion(id) == null or buyable_levels_cap(id) <= 0:
		return false
	return _state.gold.compare(next_cost(id)) >= 0


## Exact gold cost of the next [param count] levels of [param id], the sum of what
## [param count] calls of [method buy_or_upgrade] would spend. 0 when count <= 0. [param count] is
## cut to [method buyable_levels_cap]: asking for 10 with 5 levels left to the threshold gives the
## cost of 5, which is what [method buy_levels] spends. [param id] must be in the roster.
func cost_of_levels(id: String, count: int) -> BigNumber:
	return _combat.companion(id).cost_of_levels_from(level(id) + 1, mini(count, buyable_levels_cap(id)), _floors.cost_discount_percent())


## How many next levels of [param id] the gold on hand covers, at most [param max_count], never more
## than [constant MAX_SCAN_LEVELS] and never past the awakening threshold ([method buyable_levels_cap]).
## 0 for an unknown id or when max_count <= 0. The result can be passed to [method buy_levels] as is.
func affordable_levels(id: String, max_count: int = MAX_SCAN_LEVELS) -> int:
	var companion: Companion = _combat.companion(id)
	if companion == null:
		return 0
	return companion.affordable_levels_from(level(id) + 1, _state.gold, mini(mini(max_count, MAX_SCAN_LEVELS), buyable_levels_cap(id)), _floors.cost_discount_percent())


## What [method affordable_levels] counts, with the exact cost of those levels, from one walk:
## {"count": int, "total": BigNumber}. An unknown id gives a count of 0.
func affordable_walk(id: String, max_count: int = MAX_SCAN_LEVELS) -> Dictionary:
	var companion: Companion = _combat.companion(id)
	if companion == null:
		return {"count": 0, "total": BigNumber.new()}
	return companion.affordable_walk_from(level(id) + 1, _state.gold, mini(mini(max_count, MAX_SCAN_LEVELS), buyable_levels_cap(id)), _floors.cost_discount_percent())


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
## exactly [method cost_of_levels]. [param count] stops at the awakening threshold
## ([method buyable_levels_cap]): asking for 10 with 5 levels left buys 5. Returns true on success.
## Unknown id, count <= 0, blocked at a threshold or gold short of the whole sum: returns false and
## nothing changes. Emits [signal companions_bought] once on success, and no [signal companion_leveled_up].
## [codeblock]
## if companions.buy_levels("archer", companions.affordable_levels("archer")):
##     print(companions.level("archer"))
## [/codeblock]
func buy_levels(id: String, count: int) -> bool:
	if count <= 0 or _combat.companion(id) == null:
		return false
	var bought: int = mini(count, buyable_levels_cap(id))
	if bought <= 0:
		return false
	var total: BigNumber = cost_of_levels(id, bought)
	if _state.gold.compare(total) < 0:
		return false
	_state.gold = _state.gold.subtract(total)
	var new_level: int = level(id) + bought
	_state.companion_levels[id] = new_level
	companions_bought.emit(id, new_level)
	return true


## Buys [param id] (level 0 to 1) or raises it by one level, spending [method next_cost]
## from the state's gold. Returns true on success. Unknown id, blocked at an awakening threshold or
## not enough gold: returns false and nothing changes. Emits [signal companion_leveled_up] on success.
func buy_or_upgrade(id: String) -> bool:
	if not can_buy(id):
		return false
	_state.gold = _state.gold.subtract(next_cost(id))
	var new_level: int = level(id) + 1
	_state.companion_levels[id] = new_level
	companion_leveled_up.emit(id, new_level)
	return true


## Total damage per second of the companions, awakenings and companion talents included (story 006).
## The click formula and the offline gold use the bare sum of [method Combat.companion_power]
## instead (awakenings included, talents not).
func total_power() -> BigNumber:
	return _floors.companion_power()


# True when [param id], with [param done] awakenings, has a next threshold and its level reached it.
func _threshold_reached(id: String, done: int) -> bool:
	var thresholds: Array[int] = _combat.awakening_thresholds()
	return done < thresholds.size() and level(id) >= thresholds[done]


# Cost of the awakening number [param index] (0-based, below the number of thresholds) of
# [param companion]: cost_level_multiplier * cost_of_level(threshold), floored. Computed once, then
# kept in an Array per companion indexed by rank (null until computed).
func _awakening_cost(companion: Companion, index: int) -> BigNumber:
	if not _awakening_costs.has(companion.id):
		var fresh: Array = []
		fresh.resize(_combat.awakening_thresholds().size())
		_awakening_costs[companion.id] = fresh
	var costs: Array = _awakening_costs[companion.id]
	if costs[index] == null:
		var threshold: int = _combat.awakening_thresholds()[index]
		costs[index] = companion.cost_of_level(threshold).multiply_decimal(_combat.awakening_rules().cost_multiplier())
	return costs[index]


## Advances time by [param delta] seconds (clamped to 0..[constant MAX_TICK_SECONDS]).
## Every bought companion attacks once per elapsed interval, however many fit in
## [param delta]; the remainder carries over to the next call. Companions act in
## roster order within one call, and an attack that kills the enemy makes the
## following attacks hit the next stage's enemy.
func tick(delta: float) -> void:
	# "Cadence" (story 019): the attack timers run faster than game time.
	var step: float = clampf(delta, 0.0, MAX_TICK_SECONDS) * _floors.attack_speed_factor()
	if step <= 0.0:
		return
	for companion: Companion in _combat.companions():
		if level(companion.id) <= 0:
			continue
		var elapsed: float = float(_elapsed.get(companion.id, 0.0)) + step
		var attacks: int = int(elapsed / companion.attack_interval_seconds)
		_elapsed[companion.id] = elapsed - float(attacks) * companion.attack_interval_seconds
		if attacks == 0:
			continue
		var attack_damage: BigNumber = _floors.companion_attack_damage(companion.id)
		for i in attacks:
			_floors.apply_damage(attack_damage)
			companion_attacked.emit(companion.id, attack_damage)
