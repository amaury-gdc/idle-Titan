class_name Companion
extends RefCounted
## One companion's definition and its formulas, built from one entry of
## companions_roster.json (schema 2, see assets/data/data_schema.md). The optional
## "click_share" key (economy rework story 015) is only parsed here, see [method click_share].
## Implements design/game-brief.md "Core loop" and MVP feature 3 (story 003).
## Holds no run state: the level is always passed in.
##
## Formulas (level L >= 1, BigNumber-exact; level 0 means "not bought"):
## [codeblock]
## cost_of_level(L)          = floor(base_cost * cost_growth^(L - 1))
## damage_at_level(L, a, A)  = floor(base_damage * L * product of damage_multiplier
##                                   of every tier with tier.level <= L
##                                   * self_multiplier^a * squad_multiplier^A)
## damage_per_second_at_level(L, a, A) = floor(damage_at_level(L, a, A) / attack_interval_seconds)
## [/codeblock]
## a is this companion's awakenings and A the counted awakenings of the squad (story 016, see
## [AwakeningRules]). The tier and awakening product is applied before a single floor, so decimal
## multipliers such as "1.5" or "3.4" do not drift. Costs and damages of the last queried level
## are memoized (pure functions of the level, and of a and A for damages), so repeated reads
## each frame allocate nothing.
##
## Each level's cost is floored on its own, so the sum of N levels has no closed
## form: a geometric sum would differ. Sums therefore walk the unfloored numerator
## base_cost * numerator^(L - 1) over 10^(scale * (L - 1)) one level at a time (one
## multiplication, one floor per level). The numerator of the last queried level is
## kept, so a purchase or a scan from the same level never recomputes the power.
##
## Single-thread only. Build with [method from_entry] and check [method is_valid].
##
## Usage:
## [codeblock]
## var companion: Companion = Companion.from_entry(entry, "1.1")
## if companion.is_valid():
##     var cost: BigNumber = companion.cost_of_level(3)
##     var damage: BigNumber = companion.damage_at_level(10, 0, 0)   # level-10 tier, no awakening
## else:
##     push_error(companion.get_error())
## [/codeblock]

## Largest forward jump the kept numerator walks instead of recomputing the power:
## past it, the power is the cheaper of the two. Performance bound, not balance.
const NUMERATOR_WALK_LIMIT: int = 64

## Stable id, the key used in [member GameState.companion_levels].
var id: String = ""
## Display name (French, passed to the UI as is).
var display_name: String = ""
## Seconds between two automatic attacks (> 0, resolution 1 ms).
var attack_interval_seconds: float = 1.0

var _error: String = ""
var _base_cost: BigNumber = BigNumber.new()
var _base_damage: BigNumber = BigNumber.new()
var _cost_growth: String = "1"
var _interval_ms: int = 1000
## _cost_growth as the exact fraction _growth_numerator / 10^_growth_scale.
var _growth_numerator: BigNumber = BigNumber.from_int(1)
var _growth_scale: int = 0
## Tier unlock levels, strictly increasing.
var _tier_levels: Array[int] = []
## Tier multipliers as exact fractions numerator / 10^scale (same index as _tier_levels).
var _tier_numerators: Array[BigNumber] = []
var _tier_scales: Array[int] = []
## Tier multipliers as shown to the player, French comma and no trailing zero (same index).
var _tier_labels: Array[String] = []
## "click_share" as the exact fraction [numerator: BigNumber, scale: int], or [] when the entry has none.
var _click_share: Array = []
var _cost_memo_level: int = -1
var _cost_memo: BigNumber = null
## base_cost * numerator^(level - 1) for level _numerator_level, unfloored.
var _numerator_level: int = -1
var _numerator: BigNumber = null
## The last sum of levels: the list quotes the same one on every change of gold (story 013, up to
## 50 levels per companion).
var _sum_memo_level: int = -1
var _sum_memo_count: int = -1
var _sum_memo_discount: int = 0
var _sum_memo: BigNumber = null
## Awakening rules bound by [Combat] (story 016); a disabled instance until then.
var _awakening: AwakeningRules = AwakeningRules.new()
## The last damage and dps, keyed by (level, own awakenings, squad awakenings).
var _damage_memo_level: int = -1
var _damage_memo_own: int = 0
var _damage_memo_squad: int = 0
var _damage_memo: BigNumber = null
var _dps_memo_level: int = -1
var _dps_memo_own: int = 0
var _dps_memo_squad: int = 0
var _dps_memo: BigNumber = null


## Parses and validates one roster entry. [param default_cost_growth] is the
## core_curves.json "cost_growth" ("" when absent or invalid), used when the entry
## has no own "cost_growth". Always returns an instance; check [method is_valid].
static func from_entry(entry: Dictionary, default_cost_growth: String) -> Companion:
	var companion: Companion = Companion.new()
	companion._load(entry, default_cost_growth)
	return companion


## True when the entry parsed cleanly.
func is_valid() -> bool:
	return _error.is_empty()


## First validation problem found, or "" when valid.
func get_error() -> String:
	return _error


## Gold cost to buy level [param level] (>= 1; level 1 is the first purchase, level
## L+1 the upgrade from L). Example: base_cost "10", growth "1.15": level 1 costs 10, level 2 costs 11.
func cost_of_level(level: int) -> BigNumber:
	if _cost_memo_level != level:
		var target: int = maxi(level, 1)
		_cost_memo = _numerator_at(target).divide_by_power_of_ten(_growth_scale * (target - 1))
		_cost_memo_level = level
	return _cost_memo


## Exact total gold cost of the [param count] levels starting at [param level] (>= 1,
## lower is read as 1), each floored on its own: the same value as adding
## [method cost_of_level] for level, level + 1, and so on. 0 when count <= 0.
## Example: base_cost "10", growth "1.15": from level 1, count 2 costs 21.
## [param discount_percent] (story 019 "Négociation") takes that percent off each level on its own, see
## [method discounted_cost], so the sum is still what [param count] single purchases would spend.
func cost_of_levels_from(level: int, count: int, discount_percent: int = 0) -> BigNumber:
	var total: BigNumber = BigNumber.new()
	if count <= 0:
		return total
	var first: int = maxi(level, 1)
	if _sum_memo_level == first and _sum_memo_count == count and _sum_memo_discount == discount_percent:
		return _sum_memo
	var numerator: BigNumber = _numerator_at(first)
	var exponent: int = _growth_scale * (first - 1)
	for i in count:
		if i > 0:
			numerator = numerator.multiply(_growth_numerator)
			exponent += _growth_scale
		total = total.add(discounted_cost(numerator.divide_by_power_of_ten(exponent), discount_percent))
	_sum_memo_level = first
	_sum_memo_count = count
	_sum_memo_discount = discount_percent
	_sum_memo = total
	return total


## [param cost] with [param discount_percent] taken off: floor(cost * (100 - percent) / 100), but at
## least 1 for a cost that was not 0 (a level never becomes free). Unchanged for a percent <= 0.
## Example: 10 with 5 gives 9; 1 with 5 gives 1.
static func discounted_cost(cost: BigNumber, discount_percent: int) -> BigNumber:
	if discount_percent <= 0 or cost.is_zero():
		return cost
	var reduced: BigNumber = cost.multiply_decimal("0.%02d" % (100 - mini(discount_percent, 99)))
	return reduced if not reduced.is_zero() else BigNumber.from_int(1)


## How many consecutive levels starting at [param level] (>= 1, lower is read as 1)
## [param gold] covers, from 0 to [param max_count]. The scan stops at the first level
## the gold cannot cover. Example: base_cost "10", growth "1.15", gold 21, from level
## 1: returns 2 (10 + 11).
func affordable_levels_from(level: int, gold: BigNumber, max_count: int, discount_percent: int = 0) -> int:
	return affordable_walk_from(level, gold, max_count, discount_percent)["count"]


## The same scan as [method affordable_levels_from], which also keeps the sum it walked:
## {"count": int, "total": BigNumber}, where total is the exact cost of those count levels (0 when
## count is 0). One walk, so a caller needing both never pays for a second one.
func affordable_walk_from(level: int, gold: BigNumber, max_count: int, discount_percent: int = 0) -> Dictionary:
	var kept: BigNumber = BigNumber.new()
	if max_count <= 0:
		return {"count": 0, "total": kept}
	var first: int = maxi(level, 1)
	var numerator: BigNumber = _numerator_at(first)
	var exponent: int = _growth_scale * (first - 1)
	for i in max_count:
		if i > 0:
			numerator = numerator.multiply(_growth_numerator)
			exponent += _growth_scale
		var total: BigNumber = kept.add(discounted_cost(numerator.divide_by_power_of_ten(exponent), discount_percent))
		if total.compare(gold) > 0:
			return {"count": i, "total": kept}
		kept = total
	return {"count": max_count, "total": kept}


## This companion's share of its damage per second that feeds the click (the optional roster
## key "click_share", economy rework story 015), as the exact fraction
## [numerator: BigNumber, scale: int] meaning numerator / 10^scale, between 0 and 1.
## [] when the entry has no click_share. Example: "0.45" gives [45, 2]; "1" gives [1, 0].
## [method Combat.click_damage] sums these shares; it is the only reader.
func click_share() -> Array:
	return _click_share


## The levels that unlock a tier, strictly increasing. Read-only: do not modify.
func tier_levels() -> Array[int]:
	return _tier_levels


## The first tier above [param level], read from the data, which assumes no rhythm:
## {"level": int, "multiplier": String, "previous": int}. "multiplier" is displayable as is ("2",
## "1,5"); "previous" is the last tier reached, 0 when none. Past the last tier, or without any
## tier, "level" is 0 and "multiplier" is empty; "previous" then tells the two apart.
## Example: tiers at 10 and 25, from level 10: {"level": 25, "multiplier": "2", "previous": 10}.
func next_tier_from(level: int) -> Dictionary:
	var previous: int = 0
	for i in _tier_levels.size():
		if _tier_levels[i] > level:
			return {"level": _tier_levels[i], "multiplier": _tier_labels[i], "previous": previous}
		previous = _tier_levels[i]
	return {"level": 0, "multiplier": "", "previous": previous}


## Binds the awakening rules of the roster (story 016), called by [Combat] when it reads the
## roster. Without it, awakenings have no effect. Clears the damage memos.
func bind_awakening(rules: AwakeningRules) -> void:
	_awakening = rules
	_damage_memo_level = -1
	_dps_memo_level = -1


## Damage of one attack at [param level], tiers included, times the awakenings. 0 for level <= 0.
## [param own_awakenings] is this companion's awakenings and [param squad_awakenings] the counted
## awakenings of the whole squad ([method Combat.squad_awakenings]); both required, 0 meaning none,
## so a caller that forgets them does not compile. One floor over the whole product.
## Example: base_damage "2", tier {level 10, x "2"}: level 9 deals 18, level 10 deals 40 with (0, 0).
## With "3.4" per awakening of its own and "2.10" for the squad, level 10 deals 40 * 3.4 = 136 with
## (1, 0) and floor(40 * 3.4 * 2.10) = 285 with (1, 1).
func damage_at_level(level: int, own_awakenings: int, squad_awakenings: int) -> BigNumber:
	if level <= 0:
		return BigNumber.new()
	var own: int = maxi(own_awakenings, 0)
	var squad: int = maxi(squad_awakenings, 0)
	# The memo is keyed by the level AND the awakenings: an awakening at the same level changes
	# the damage and must never read a stale value.
	if _damage_memo_level != level or _damage_memo_own != own or _damage_memo_squad != squad:
		_damage_memo = _compute_damage(level, own, squad)
		_damage_memo_level = level
		_damage_memo_own = own
		_damage_memo_squad = squad
	return _damage_memo


## Damage per second at [param level]: damage_at_level / attack_interval_seconds,
## floored (a 1-damage companion attacking every 2 s counts 0). This is what feeds
## [method Combat.companion_power], so a fast weak companion and a slow strong one
## with the same real output weigh the same in the click formula. The awakening arguments are
## those of [method damage_at_level] and are required too. 0 for level <= 0.
func damage_per_second_at_level(level: int, own_awakenings: int, squad_awakenings: int) -> BigNumber:
	# Before the memo: its empty key (level -1) would otherwise answer a negative level with null.
	if level <= 0:
		return BigNumber.new()
	var own: int = maxi(own_awakenings, 0)
	var squad: int = maxi(squad_awakenings, 0)
	if _dps_memo_level != level or _dps_memo_own != own or _dps_memo_squad != squad:
		_dps_memo = damage_at_level(level, own, squad).multiply(BigNumber.from_int(1000)).divide(BigNumber.from_int(_interval_ms))
		_dps_memo_level = level
		_dps_memo_own = own
		_dps_memo_squad = squad
	return _dps_memo


# Unfloored cost numerator of [param level] (>= 1), kept for the next call: a small
# step forward walks from the kept value, anything else recomputes the power.
func _numerator_at(level: int) -> BigNumber:
	var steps: int = level - _numerator_level
	if _numerator == null or steps < 0 or steps > NUMERATOR_WALK_LIMIT:
		_numerator = _base_cost.multiply(_growth_numerator.power(level - 1))
	else:
		for i in steps:
			_numerator = _numerator.multiply(_growth_numerator)
	_numerator_level = level
	return _numerator


func _compute_damage(level: int, own_awakenings: int, squad_awakenings: int) -> BigNumber:
	var scaled: BigNumber = _base_damage.multiply(BigNumber.from_int(level))
	var scale_sum: int = 0
	for i in _tier_levels.size():
		if _tier_levels[i] > level:
			break
		scaled = scaled.multiply(_tier_numerators[i])
		scale_sum += _tier_scales[i]
	if own_awakenings > 0 or squad_awakenings > 0:
		var awakening: Array = _awakening.multiplier_fraction(own_awakenings, squad_awakenings)
		scaled = scaled.multiply(awakening[0])
		scale_sum += awakening[1]
	if scale_sum == 0:
		return scaled
	return scaled.divide(BigNumber.from_int(10).power(scale_sum))


func _load(entry: Dictionary, default_cost_growth: String) -> void:
	var raw_id: Variant = entry.get("id")
	if not raw_id is String or (raw_id as String).is_empty():
		_fail("companion without a string 'id'")
		return
	id = raw_id
	var raw_name: Variant = entry.get("name")
	if not raw_name is String or (raw_name as String).is_empty():
		_fail("'%s' needs a string 'name'" % id)
		return
	display_name = raw_name
	_base_cost = _read_big(entry, "base_cost")
	_base_damage = _read_big(entry, "base_damage")
	_read_cost_growth(entry, default_cost_growth)
	var fraction: Array = GrowthCurve.parse_factor(_cost_growth)
	if fraction.size() == 2:
		_growth_numerator = fraction[0]
		_growth_scale = fraction[1]
	_read_interval(entry)
	_read_tiers(entry)
	_read_click_share(entry)


func _read_big(entry: Dictionary, key: String) -> BigNumber:
	var v: Variant = entry.get(key)
	if v is String:
		var parsed: BigNumber = BigNumber.from_string(v)
		if parsed != null:
			return parsed
	_fail("'%s' %s must be a digit string" % [id, key])
	return BigNumber.new()


func _read_cost_growth(entry: Dictionary, default_cost_growth: String) -> void:
	if not entry.has("cost_growth"):
		if default_cost_growth.is_empty():
			_fail("'%s' has no cost_growth and core_curves.json has no valid 'cost_growth' fallback" % id)
			return
		_cost_growth = default_cost_growth
		return
	var v: Variant = entry["cost_growth"]
	if not v is String or not GrowthCurve.is_valid_factor(v):
		_fail("'%s' cost_growth must be a decimal string such as \"1.15\"" % id)
		return
	_cost_growth = v


func _read_interval(entry: Dictionary) -> void:
	var v: Variant = entry.get("attack_interval_seconds")
	if (v is int or v is float) and roundi(float(v) * 1000.0) >= 1:
		attack_interval_seconds = float(v)
		_interval_ms = roundi(attack_interval_seconds * 1000.0)
		return
	_fail("'%s' attack_interval_seconds must be a number >= 0.001" % id)


func _read_tiers(entry: Dictionary) -> void:
	var tiers: Variant = entry.get("tiers")
	if not tiers is Array:
		_fail("'%s' tiers must be an array (empty if none)" % id)
		return
	var previous_level: int = 1
	for tier: Variant in tiers:
		if not tier is Dictionary:
			_fail("'%s' each tier must be an object" % id)
			return
		var level: Variant = tier.get("level")
		if not (level is int or level is float) or float(level) != floorf(float(level)) or int(level) <= previous_level:
			_fail("'%s' tier levels must be integers >= 2, strictly increasing" % id)
			return
		var multiplier: Variant = tier.get("damage_multiplier")
		if not multiplier is String or not GrowthCurve.is_valid_factor(multiplier):
			_fail("'%s' tier damage_multiplier must be a decimal string such as \"2\"" % id)
			return
		var parts: PackedStringArray = (multiplier as String).split(".")
		var numerator: BigNumber = BigNumber.from_string("".join(parts))
		if numerator.is_zero():
			_fail("'%s' tier damage_multiplier must be above 0" % id)
			return
		previous_level = int(level)
		_tier_levels.append(previous_level)
		_tier_numerators.append(numerator)
		_tier_scales.append(parts[1].length() if parts.size() == 2 else 0)
		_tier_labels.append(_multiplier_label(numerator, _tier_scales[-1]))


# Optional "click_share": a decimal string from 0 to 1 included ("0.45", "1", "0").
func _read_click_share(entry: Dictionary) -> void:
	if not entry.has("click_share"):
		return
	var v: Variant = entry["click_share"]
	var fraction: Array = GrowthCurve.parse_factor(v) if v is String else []
	if fraction.size() != 2 or (fraction[0] as BigNumber).compare(BigNumber.from_int(10).power(fraction[1])) > 0:
		_fail("'%s' click_share must be a decimal string from 0 to 1, such as \"0.45\"" % id)
		return
	_click_share = fraction


# numerator / 10^scale as the player reads it: 15 at scale 1 gives "1,5", 200 at scale 2 gives "2".
func _multiplier_label(numerator: BigNumber, scale: int) -> String:
	var digits: String = numerator.to_decimal_string().pad_zeros(scale + 1)
	var whole: String = digits.substr(0, digits.length() - scale)
	var decimals: String = digits.substr(digits.length() - scale).rstrip("0")
	return whole if decimals.is_empty() else "%s,%s" % [whole, decimals]


# Keeps the first error only, prefixed with the file name.
func _fail(message: String) -> void:
	if _error.is_empty():
		_error = "companions_roster.json: " + message
