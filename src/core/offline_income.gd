class_name OfflineIncome
extends RefCounted
## Offline progress (story 004b, design/game-brief.md MVP feature 8 "Hors-ligne"): gold
## earned from the real time elapsed since the last save, from the companions' power.
## Pure logic: no disk, no clock (the current time is passed in), no UI.
##
## Formula (BigNumber-exact, all values from core_curves.json):
## [codeblock]
## counted_seconds = min(now - last_saved, offline_max_hours * 3600)
##                   (0 when last_saved is unknown, when now <= last_saved, or when the
##                   elapsed time is below offline_min_seconds)
## gold = floor(companion_power * counted_seconds * gold_per_kill(stage) / enemy_hp(stage)
##              * offline_efficiency * talent_factor)
## [/codeblock]
## talent_factor is the "offline_gold" talent bonus (story 006), see [method set_talent_factor].
## The companion power stays the bare sum: only this factor makes a talent count here.
## gold_per_kill / enemy_hp is the gold earned per point of damage on the current stage,
## so offline_efficiency is the share of what the companions would earn by farming that
## stage. A flat gold-per-damage rate would not work: that ratio falls by a factor of
## about 30 between stages 1 and 100. A boss stage uses the normal enemy of that stage.
## Clicks, purchases and stage advances are not simulated: only gold changes.
##
## Usage:
## [codeblock]
## var offline: OfflineIncome = OfflineIncome.from_data(curves, combat)
## if offline.is_valid():
##     var gain: Dictionary = offline.grant(game_state, int(Time.get_unix_time_from_system()))
##     if not gain.is_empty():
##         print(gain["seconds"], " s: ", (gain["gold"] as BigNumber).format())
## [/codeblock]

const SECONDS_PER_HOUR: float = 3600.0

var _error: String = ""
var _combat: Combat
var _efficiency: String = "0"
var _max_seconds: int = 0
var _min_seconds: int = 0
var _talent_factor: String = "1"
## Cap of the talents in seconds (story 019), 0 for none.
var _talent_cap_seconds: int = 0


## Reads the offline keys of [param curves] (core_curves.json as returned by
## [method DataLoader.load_json], null allowed) and uses [param combat] for the
## per-stage numbers. Always returns an instance; check [method is_valid].
static func from_data(curves: Variant, combat: Combat) -> OfflineIncome:
	var income: OfflineIncome = OfflineIncome.new()
	income._combat = combat
	income._load(curves)
	return income


## True when the data parsed cleanly.
func is_valid() -> bool:
	return _error.is_empty()


## First validation problem found, or "" when valid.
func get_error() -> String:
	return _error


## Sets the permanent factor of the talents on offline gold (story 006): a valid decimal
## string ("1.25"), "1" meaning none. It stays until the next call. With items in play, pass
## the SUM of talents and items for "offline_gold" (story 007, see [ModifierHub]).
func set_talent_factor(factor: String) -> void:
	_talent_factor = factor


## Sets the offline cap the talents give (story 019 "Longue veille"), in hours: the cap is the higher of
## this and offline_max_hours of the data, so it never lowers it. 0 means none.
func set_talent_cap_hours(hours: float) -> void:
	_talent_cap_seconds = int(maxf(hours, 0.0) * SECONDS_PER_HOUR)


## Longest absence that counts, in seconds: offline_max_hours, or the talent cap when it is higher.
func max_seconds() -> int:
	return maxi(_max_seconds, _talent_cap_seconds)


## Seconds of absence that count: 0 when [param last_saved_unix] is unknown (<= 0), when
## no time passed or the clock went backwards, or when the elapsed time is below the
## minimum; otherwise the elapsed time, capped at [method max_seconds].
func counted_seconds(last_saved_unix: int, now_unix: int) -> int:
	if last_saved_unix <= 0 or now_unix <= last_saved_unix:
		return 0
	var elapsed: int = now_unix - last_saved_unix
	if elapsed < _min_seconds:
		return 0
	return mini(elapsed, max_seconds())


## Gold for [param seconds] of absence at [param stage] with [param companion_levels]
## ([member GameState.companion_levels]) and [param awakenings]
## ([member GameState.companion_awakenings], required: pass {} for none; the power of an awakened
## squad is what earns offline, story 016). Zero when no companion is bought.
func gold_for(seconds: int, stage: int, companion_levels: Dictionary, awakenings: Dictionary) -> BigNumber:
	var power: BigNumber = _combat.companion_power(companion_levels, awakenings)
	var gross: BigNumber = power.multiply(BigNumber.from_int(seconds)).multiply(_combat.gold_per_kill(stage))
	return gross.multiply_decimal(_efficiency).multiply_decimal(_talent_factor).divide(_combat.enemy_max_hp(stage))


## Adds the offline gold to [param state] for the time elapsed since
## [member GameState.last_saved_unix], then moves that time to [param now_unix], so a
## second call grants nothing. Returns {} when nothing is granted (no saved time, no
## time elapsed, clock moved back, below the minimum, no companion), else
## {"seconds": int counted, "gold": BigNumber granted, "capped": bool, true when the
## maximum cut the elapsed time}. The stage is never touched.
func grant(state: GameState, now_unix: int) -> Dictionary:
	var seconds: int = counted_seconds(state.last_saved_unix, now_unix)
	var capped: bool = seconds > 0 and now_unix - state.last_saved_unix > max_seconds()
	state.last_saved_unix = now_unix
	if seconds <= 0:
		return {}
	var gold: BigNumber = gold_for(seconds, state.stage, state.companion_levels, state.companion_awakenings)
	if gold.is_zero():
		return {}
	state.gold = state.gold.add(gold)
	return {"seconds": seconds, "gold": gold, "capped": capped}


func _load(curves: Variant) -> void:
	if not curves is Dictionary:
		_error = "core_curves.json is missing or not an object"
		return
	var c: Dictionary = curves
	var version: Variant = c.get("schema_version")
	if not (version is int or version is float) or int(version) != Combat.SUPPORTED_CURVES_SCHEMA:
		_error = "core_curves.json: offline income needs schema_version %d" % Combat.SUPPORTED_CURVES_SCHEMA
		return
	var efficiency: Variant = c.get("offline_efficiency")
	if not (efficiency is String and GrowthCurve.is_valid_factor(efficiency)):
		_error = "core_curves.json: 'offline_efficiency' must be a decimal string such as \"0.1\""
		return
	_efficiency = efficiency
	var hours: Variant = c.get("offline_max_hours")
	if not (hours is int or hours is float) or float(hours) <= 0.0:
		_error = "core_curves.json: 'offline_max_hours' must be a number > 0"
		return
	_max_seconds = int(float(hours) * SECONDS_PER_HOUR)
	var minimum: Variant = c.get("offline_min_seconds")
	if not (minimum is int or minimum is float) or float(minimum) < 0.0:
		_error = "core_curves.json: 'offline_min_seconds' must be a number >= 0"
		return
	_min_seconds = int(minimum)
