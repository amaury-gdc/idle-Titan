class_name Combat
extends RefCounted
## Pure combat formulas, fed entirely by data (core_curves.json and
## companions_roster.json). Holds no run state: callers pass companion levels in.
## Implements design/game-brief.md "Core loop" (story 002).
##
## Formulas (stage >= 1, all BigNumber-exact, see [GrowthCurve]):
## [codeblock]
## enemy_max_hp(stage)  = enemy_hp_base * enemy_hp_growth^(stage - 1)            (at least 1)
## gold_per_kill(stage) = gold_per_kill_base * gold_per_kill_growth^(stage - 1)
## companion_power      = sum over bought companions of their damage PER SECOND at their level
##                        (0 if none bought), see [method Companion.damage_per_second_at_level]
## click_damage         = click_damage_base + floor(companion_power * click_companion_power_factor)
## [/codeblock]
## Companion power is damage per second, not per attack: companions attack at
## different intervals, and per-second is what they really add to the fight, so
## the click share stays fair when an interval is retuned. The factor is data.
## The companion formulas (cost, damage, tiers) live in [Companion]; this class
## only sums them, so there is one definition of companion damage.
##
## Single-thread only. Build with [method from_data] and check [method is_valid].
##
## Usage:
## [codeblock]
## var combat: Combat = Combat.from_data(
##         DataLoader.load_json("res://assets/data/core_curves.json"),
##         DataLoader.load_json("res://assets/data/companions_roster.json"))
## if combat.is_valid():
##     var hp: BigNumber = combat.enemy_max_hp(10)
##     var dmg: BigNumber = combat.click_damage(game_state.companion_levels)
## else:
##     push_error(combat.get_error())
## [/codeblock]

## Current version of core_curves.json.
const SUPPORTED_CURVES_SCHEMA: int = 3
## Oldest version of core_curves.json this class can read: version 3 only added the
## offline keys, read by [OfflineIncome], so a version 2 file still gives valid combat.
const OLDEST_CURVES_SCHEMA: int = 2
## Version of companions_roster.json this code understands.
const SUPPORTED_ROSTER_SCHEMA: int = 2

var _error: String = ""
var _hp_base: BigNumber
var _hp_growth: String = ""
var _gold_base: BigNumber
var _gold_growth: String = ""
var _click_base: BigNumber
var _click_power_factor: String = ""
## core_curves.json "cost_growth" when valid, "" otherwise (only needed by
## companions that define no cost_growth of their own).
var _default_cost_growth: String = ""
## Companion id (String) -> [Companion].
var _companion_by_id: Dictionary = {}
## Companions in roster order.
var _companions: Array[Companion] = []


## Parses and validates the two data files (as returned by [method DataLoader.load_json],
## null allowed). Always returns an instance; check [method is_valid].
static func from_data(curves: Variant, roster: Variant) -> Combat:
	var combat: Combat = Combat.new()
	combat._load(curves, roster)
	return combat


## True when the data parsed cleanly and the formulas can be used.
func is_valid() -> bool:
	return _error.is_empty()


## First validation problem found, or "" when valid.
func get_error() -> String:
	return _error


## Enemy HP for [param stage] (values below 1 are treated as 1). Never zero.
func enemy_max_hp(stage: int) -> BigNumber:
	var hp: BigNumber = GrowthCurve.value_at(_hp_base, _hp_growth, maxi(stage, 1) - 1)
	return hp if not hp.is_zero() else BigNumber.from_int(1)


## Gold granted for killing the enemy of [param stage] (values below 1 are treated as 1).
func gold_per_kill(stage: int) -> BigNumber:
	return GrowthCurve.value_at(_gold_base, _gold_growth, maxi(stage, 1) - 1)


## Companions in roster order (empty when the data is invalid). Read-only: do not modify.
func companions() -> Array[Companion]:
	return _companions


## The companion with [param id], or null when the roster has none.
func companion(id: String) -> Companion:
	return _companion_by_id.get(id)


## Sum of the damage per second of every bought companion. [param companion_levels]
## is [member GameState.companion_levels] (id -> level). Ids missing from the roster
## and levels <= 0 contribute nothing.
func companion_power(companion_levels: Dictionary) -> BigNumber:
	var total: BigNumber = BigNumber.new()
	for id: Variant in companion_levels:
		var def: Companion = _companion_by_id.get(id)
		if def == null:
			continue
		total = total.add(def.damage_per_second_at_level(int(companion_levels[id])))
	return total


## Damage of one click: base + companion_power * factor (floored).
func click_damage(companion_levels: Dictionary) -> BigNumber:
	var bonus: BigNumber = companion_power(companion_levels).multiply_decimal(_click_power_factor)
	return _click_base.add(bonus)


func _load(curves: Variant, roster: Variant) -> void:
	if not curves is Dictionary:
		_error = "core_curves.json is missing or not an object"
		return
	if not roster is Dictionary:
		_error = "companions_roster.json is missing or not an object"
		return
	var c: Dictionary = curves
	var r: Dictionary = roster
	if not _schema_ok(c, OLDEST_CURVES_SCHEMA, SUPPORTED_CURVES_SCHEMA, "core_curves.json"):
		return
	if not _schema_ok(r, SUPPORTED_ROSTER_SCHEMA, SUPPORTED_ROSTER_SCHEMA, "companions_roster.json"):
		return
	_hp_base = _read_big(c, "enemy_hp_base")
	_hp_growth = _read_factor(c, "enemy_hp_growth")
	_gold_base = _read_big(c, "gold_per_kill_base")
	_gold_growth = _read_factor(c, "gold_per_kill_growth")
	_click_base = _read_big(c, "click_damage_base")
	_click_power_factor = _read_factor(c, "click_companion_power_factor")
	var growth: Variant = c.get("cost_growth")
	if growth is String and GrowthCurve.is_valid_factor(growth):
		_default_cost_growth = growth
	if not _error.is_empty():
		return
	_read_roster(r)


func _schema_ok(data: Dictionary, oldest: int, newest: int, file_name: String) -> bool:
	var v: Variant = data.get("schema_version")
	if not (v is int or v is float) or int(v) < oldest or int(v) > newest:
		_error = "%s: unsupported schema_version (expected %d)" % [file_name, newest]
		return false
	return true


func _read_big(data: Dictionary, key: String) -> BigNumber:
	var v: Variant = data.get(key)
	if v is String:
		var parsed: BigNumber = BigNumber.from_string(v)
		if parsed != null:
			return parsed
	_fail("core_curves.json: '%s' must be a digit string" % key)
	return BigNumber.new()


func _read_factor(data: Dictionary, key: String) -> String:
	var v: Variant = data.get(key)
	if v is String and GrowthCurve.is_valid_factor(v):
		return v
	_fail("core_curves.json: '%s' must be a decimal string such as \"1.3\"" % key)
	return "1"


func _read_roster(roster: Dictionary) -> void:
	var entries: Variant = roster.get("companions")
	if not entries is Array:
		_fail("companions_roster.json: 'companions' must be an array")
		return
	for entry: Variant in entries:
		if not entry is Dictionary:
			_fail("companions_roster.json: each companion must be an object")
			return
		var def: Companion = Companion.from_entry(entry, _default_cost_growth)
		if not def.is_valid():
			_fail(def.get_error())
			return
		if _companion_by_id.has(def.id):
			_fail("companions_roster.json: duplicate id '%s'" % def.id)
			return
		_companion_by_id[def.id] = def
		_companions.append(def)


# Keeps the first error only.
func _fail(message: String) -> void:
	if _error.is_empty():
		_error = message
