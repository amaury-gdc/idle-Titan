class_name Combat
extends RefCounted
## Pure combat formulas, fed entirely by data (core_curves.json and
## companions_roster.json). Holds no run state: callers pass companion levels in.
## Implements design/game-brief.md "Core loop" (story 002).
##
## Formulas (stage >= 1, all BigNumber-exact, see [GrowthCurve]):
## [codeblock]
## enemy_max_hp(stage)  = max(1, floor(A_k * g_k^(stage - f_k)))   k = last segment with f_k <= stage
## gold_per_kill(stage) = gold_per_kill_base * gold_per_kill_growth^(stage - 1)
## companion_power      = sum over bought companions of their damage PER SECOND at their level
##                        and awakenings (0 if none bought), see [method Companion.damage_per_second_at_level]
## click_damage         = click_damage_base + floor(companion_power * click_companion_power_factor)
##                        (roster without "click_share"), or
##                        click_damage_base + floor(sum of click_share_i * dps_i)
##                        (every companion has "click_share"; ONE floor, no talents in dps_i)
## [/codeblock]
## Enemy HP comes from segments of growth (design/economy-rework.md "PV par paliers"): each
## segment {f_k = from_stage, g_k = growth} applies from its from_stage on, the first one from
## stage 1. A_1 = enemy_hp_base and A_(k+1) = floor(A_k * g_k^(f_(k+1) - f_k)) are computed once at
## load. Junction convention: HP(f_(k+1)) is still reached with g_k (it equals A_(k+1)) and
## HP(f_(k+1) + 1) is the first value reached with g_(k+1). The scalar "enemy_hp_growth" is
## one segment from stage 1, so it gives exactly the former HP(stage) = floor(base * growth^(stage - 1)).
## Companion power is damage per second, not per attack: companions attack at
## different intervals, and per-second is what they really add to the fight, so
## the click share stays fair when an interval is retuned. The factor is data.
## The companion formulas (cost, damage, tiers, awakening multipliers) live in [Companion]; this
## class only sums them, so there is one definition of companion damage. The awakening block of the
## roster (story 016, see [AwakeningRules]) is read here and bound to every companion; the counts of
## awakenings are passed in (required arguments), like the levels.
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
##     var dmg: BigNumber = combat.click_damage(game_state.companion_levels, game_state.companion_awakenings)
## else:
##     push_error(combat.get_error())
## [/codeblock]

## Current version of core_curves.json.
const SUPPORTED_CURVES_SCHEMA: int = 3
## Oldest version of core_curves.json this class can read: version 3 only added the
## offline keys, read by [OfflineIncome], so a version 2 file still gives valid combat.
## "enemy_hp_segments" (story 015) is an optional alternative to "enemy_hp_growth" inside these
## versions: no bump, so the former files stay valid.
const OLDEST_CURVES_SCHEMA: int = 2
## Version of companions_roster.json this code understands ("click_share", story 015, is optional
## inside it: no bump).
const SUPPORTED_ROSTER_SCHEMA: int = 2
## Largest accepted "from_stage" in "enemy_hp_segments": the anchor of a segment costs a power of
## that many steps at load, so a typo such as 1e12 would freeze the game. Load-time safety bound,
## not balance (the game designs about 300 stages).
const MAX_SEGMENT_FROM_STAGE: int = 100000

var _error: String = ""
## HP segments, same index in the three arrays: first stage, growth factor, HP anchor A_k at that
## stage. Never empty (the default is a flat 0 that [method enemy_max_hp] reads as 1 HP).
var _hp_from: Array[int] = [1]
var _hp_growths: Array[String] = ["1"]
var _hp_anchors: Array[BigNumber] = [BigNumber.new()]
var _gold_base: BigNumber
var _gold_growth: String = ""
var _click_base: BigNumber = BigNumber.new()
## "1" until the file is read, the same fallback as [method _read_factor]: click_damage on an invalid
## Combat must still return a number (the factor is only read once the roster is valid).
var _click_power_factor: String = "1"
## Companion id -> click_share numerator brought to the common scale [member _click_scale]
## (empty when the roster uses [member _click_power_factor]).
var _click_weights: Dictionary = {}
## Largest scale of the click shares: every weight is a share times 10^_click_scale.
var _click_scale: int = 0
## core_curves.json "cost_growth" when valid, "" otherwise (only needed by
## companions that define no cost_growth of their own).
var _default_cost_growth: String = ""
## Companion id (String) -> [Companion].
var _companion_by_id: Dictionary = {}
## Companions in roster order.
var _companions: Array[Companion] = []
## The optional "awakening" block of the roster (story 016); disabled without it.
var _awakening: AwakeningRules = AwakeningRules.new()


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
## Example with segments {1, "2"} and {4, "3"} and base 10: stage 4 is 80, stage 5 is 240.
func enemy_max_hp(stage: int) -> BigNumber:
	var s: int = maxi(stage, 1)
	var k: int = _hp_from.size() - 1
	while _hp_from[k] > s:
		k -= 1
	var hp: BigNumber = GrowthCurve.value_at(_hp_anchors[k], _hp_growths[k], s - _hp_from[k])
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


## The awakening rules of the roster (disabled, with no threshold, when the roster has no
## "awakening" block). Read-only: do not modify.
func awakening_rules() -> AwakeningRules:
	return _awakening


## The awakening thresholds, strictly increasing (empty without a block). Read-only: do not modify.
func awakening_thresholds() -> Array[int]:
	return _awakening.thresholds()


## Awakenings of companion [param id] in [param awakenings] ([member GameState.companion_awakenings],
## id -> count), kept between 0 and the number of thresholds: a corrupt or foreign count can neither
## be negative nor exceed what the data allows. Example: 12 with nine thresholds reads 9.
func awakening_count(awakenings: Dictionary, id: String) -> int:
	return clampi(int(awakenings.get(id, 0)), 0, _awakening.threshold_count())


## The awakenings of the whole squad that count for the squad multiplier: for each companion of the
## roster, its awakenings at thresholds up to "squad_until_threshold" (a companion awakened at 200 to
## 800 with a limit of 600 counts 5). Example: two companions awakened twice, limit above both: 4.
func squad_awakenings(awakenings: Dictionary) -> int:
	var total: int = 0
	var counted: int = _awakening.squad_threshold_count()
	for def: Companion in _companions:
		total += mini(awakening_count(awakenings, def.id), counted)
	return total


## Sum of the damage per second of every bought companion, awakenings included.
## [param companion_levels] is [member GameState.companion_levels] (id -> level) and
## [param awakenings] is [member GameState.companion_awakenings] (id -> count); the second is
## required so that a caller that forgets it does not compile. Pass {} for none. Ids missing from
## the roster and levels <= 0 contribute nothing.
## Example: [code]combat.companion_power({"scout": 200}, {"scout": 1})[/code].
func companion_power(companion_levels: Dictionary, awakenings: Dictionary) -> BigNumber:
	var total: BigNumber = BigNumber.new()
	var squad: int = squad_awakenings(awakenings)
	for id: Variant in companion_levels:
		var def: Companion = _companion_by_id.get(id)
		if def == null:
			continue
		total = total.add(def.damage_per_second_at_level(int(companion_levels[id]), awakening_count(awakenings, def.id), squad))
	return total


## Damage of one click. Without "click_share" in the roster: base + floor(companion_power * factor).
## With a share on every companion: base + floor(sum of share_i * dps_i), a single floor over the
## whole sum, dps_i being [method Companion.damage_per_second_at_level] with its awakenings (no
## talents). [param awakenings] is required, see [method companion_power].
## Example: two companions of 1 damage per second with shares "0.5" and "0.5", base 1: the click
## is 2 (floor of 1.0), not 1 (two floors of 0.5).
## [param share_factor] (decimal string, "1" for none, story 019 "Frappe alliée") multiplies the share of
## the companions only, never the base; the shares are scaled first and floored once at the end.
func click_damage(companion_levels: Dictionary, awakenings: Dictionary, share_factor: String = "1") -> BigNumber:
	if _click_weights.is_empty():
		var power: BigNumber = companion_power(companion_levels, awakenings)
		if share_factor != "1":
			power = power.multiply_decimal(share_factor)
		return _click_base.add(power.multiply_decimal(_click_power_factor))
	var scaled: BigNumber = BigNumber.new()
	var squad: int = squad_awakenings(awakenings)
	for id: Variant in companion_levels:
		var weight: BigNumber = _click_weights.get(id)
		if weight == null:
			continue
		var def: Companion = _companion_by_id.get(id)
		var dps: BigNumber = def.damage_per_second_at_level(int(companion_levels[id]), awakening_count(awakenings, def.id), squad)
		scaled = scaled.add(dps.multiply(weight))
	if share_factor != "1":
		scaled = scaled.multiply_decimal(share_factor)
	return _click_base.add(scaled.divide_by_power_of_ten(_click_scale))


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
	_read_hp_curve(c)
	_gold_base = _read_big(c, "gold_per_kill_base")
	_gold_growth = _read_factor(c, "gold_per_kill_growth")
	_click_base = _read_big(c, "click_damage_base")
	var growth: Variant = c.get("cost_growth")
	if growth is String and GrowthCurve.is_valid_factor(growth):
		_default_cost_growth = growth
	if not _error.is_empty():
		return
	if r.has("awakening"):
		_awakening = AwakeningRules.from_block(r["awakening"])
		if not _awakening.is_valid():
			_fail(_awakening.get_error())
			return
	_read_roster(r)
	if not _error.is_empty():
		return
	_read_click_formula(c)


# Enemy HP: either the scalar "enemy_hp_growth" (one segment from stage 1) or the list
# "enemy_hp_segments", never both. Fills _hp_from / _hp_growths / _hp_anchors; the anchors
# A_(k+1) = floor(A_k * g_k^(f_(k+1) - f_k)) are computed here, once.
func _read_hp_curve(data: Dictionary) -> void:
	var base: BigNumber = _read_big(data, "enemy_hp_base")
	var has_scalar: bool = data.has("enemy_hp_growth")
	var has_segments: bool = data.has("enemy_hp_segments")
	if has_scalar and has_segments:
		_fail("core_curves.json: 'enemy_hp_growth' and 'enemy_hp_segments' cannot both be set, keep one")
		return
	if not has_scalar and not has_segments:
		_fail("core_curves.json: 'enemy_hp_growth' or 'enemy_hp_segments' is required")
		return
	if has_scalar:
		_hp_growths = [_read_factor(data, "enemy_hp_growth")]
		_hp_anchors = [base]
		return
	var segments: Variant = data["enemy_hp_segments"]
	if not segments is Array or (segments as Array).is_empty():
		_fail("core_curves.json: 'enemy_hp_segments' must be a non-empty array of {from_stage, growth}")
		return
	var from: Array[int] = []
	var growths: Array[String] = []
	var anchors: Array[BigNumber] = []
	for entry: Variant in segments:
		if not entry is Dictionary:
			_fail("core_curves.json: each 'enemy_hp_segments' entry must be an object")
			return
		var raw_from: Variant = entry.get("from_stage")
		if not (raw_from is int or raw_from is float) or float(raw_from) != floorf(float(raw_from)):
			_fail("core_curves.json: 'enemy_hp_segments' from_stage must be an integer")
			return
		if float(raw_from) > MAX_SEGMENT_FROM_STAGE:
			_fail("core_curves.json: 'enemy_hp_segments' from_stage must not exceed %d" % MAX_SEGMENT_FROM_STAGE)
			return
		var stage_from: int = int(raw_from)
		if from.is_empty() and stage_from != 1:
			_fail("core_curves.json: the first 'enemy_hp_segments' entry must start at from_stage 1")
			return
		if not from.is_empty() and stage_from <= from[-1]:
			_fail("core_curves.json: 'enemy_hp_segments' from_stage values must be strictly increasing")
			return
		var growth_value: Variant = entry.get("growth")
		if not growth_value is String or not GrowthCurve.is_valid_factor(growth_value):
			_fail("core_curves.json: 'enemy_hp_segments' growth must be a decimal string such as \"1.3\"")
			return
		var raw_growth: String = growth_value
		if from.is_empty():
			anchors.append(base)
		else:
			anchors.append(GrowthCurve.value_at(anchors[-1], growths[-1], stage_from - from[-1]))
		from.append(stage_from)
		growths.append(raw_growth)
	_hp_from = from
	_hp_growths = growths
	_hp_anchors = anchors


# Click formula, once the roster is read: "click_share" on every companion, or on none (then
# "click_companion_power_factor" is required). A roster with no companion has no share.
func _read_click_formula(data: Dictionary) -> void:
	var shared: int = 0
	for def: Companion in _companions:
		if not def.click_share().is_empty():
			shared += 1
	if shared == 0:
		_click_power_factor = _read_factor(data, "click_companion_power_factor")
		return
	if shared < _companions.size():
		_fail("companions_roster.json: 'click_share' must be set on every companion or on none (%d of %d have it)" % [shared, _companions.size()])
		return
	for def: Companion in _companions:
		_click_scale = maxi(_click_scale, int(def.click_share()[1]))
	for def: Companion in _companions:
		var share: Array = def.click_share()
		_click_weights[def.id] = (share[0] as BigNumber).multiply(BigNumber.from_int(10).power(_click_scale - int(share[1])))


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
		def.bind_awakening(_awakening)
		_companion_by_id[def.id] = def
		_companions.append(def)


# Keeps the first error only.
func _fail(message: String) -> void:
	if _error.is_empty():
		_error = message
