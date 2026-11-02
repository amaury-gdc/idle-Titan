class_name AwakeningRules
extends RefCounted
## The rules of the companion awakening, read from the optional "awakening" block at the root
## of companions_roster.json (economy rework story 016, design/economy-rework.md "Éveil"). Pure
## data and exact fractions: no run state, no gold. The runtime lives in [CompanionManager], the
## damage in [Companion] and [Combat].
##
## The block, every key required inside it:
## [codeblock]
## "awakening": {
##     "thresholds": [200, 300, 400],      // levels at which a companion must awaken, strictly increasing
##     "self_multiplier": "3.4",           // x on the awakened companion, once per awakening
##     "squad_multiplier": "2.10",         // x on EVERY companion, once per counted awakening
##     "squad_until_threshold": 300,       // only awakenings at a threshold <= this one count for the squad
##     "cost_level_multiplier": "10"       // awakening cost = this x cost_of_level(threshold)
## }
## [/codeblock]
## Without the block the roster is valid and nothing awakens ([method is_enabled] is false). All
## multipliers are decimal strings turned into exact fractions, like [GrowthCurve]: no float.
##
## Single-thread only. Build with [method from_block] and check [method is_valid].
##
## Usage:
## [codeblock]
## var rules: AwakeningRules = AwakeningRules.from_block(roster.get("awakening"))
## if rules.is_valid() and rules.is_enabled():
##     var first: int = rules.thresholds()[0]                    # 200
##     var fraction: Array = rules.multiplier_fraction(1, 1)     # 3.4 x 2.10 as [7140, 3]
## [/codeblock]

## Most thresholds one block may list. Load-time safety bound (and the upper limit of a saved
## awakening count in [GameState]), not balance: the design lists nine.
const MAX_THRESHOLDS: int = 100
## Largest accepted threshold level. Load-time safety bound: the cost of a threshold is a power of
## that many levels, so a typo such as 1e12 would freeze the game. Not balance.
const MAX_THRESHOLD_LEVEL: int = 100000

var _error: String = ""
var _enabled: bool = false
var _thresholds: Array[int] = []
## Multipliers as exact fractions numerator / 10^scale; 1 / 10^0 until read.
var _self_numerator: BigNumber = BigNumber.from_int(1)
var _self_scale: int = 0
var _squad_numerator: BigNumber = BigNumber.from_int(1)
var _squad_scale: int = 0
var _squad_threshold_count: int = 0
var _cost_multiplier: String = "1"
## The multipliers as display text, computed once from the data ("3,4", "2,10").
var _self_text: String = "1"
var _squad_text: String = "1"


## Parses [param block], the value of the "awakening" key of the roster. Pass null when the key is
## absent: the result is valid and disabled. Always returns an instance; check [method is_valid].
static func from_block(block: Variant) -> AwakeningRules:
	var rules: AwakeningRules = AwakeningRules.new()
	if block != null:
		rules._load(block)
	return rules


## True when the block parsed cleanly (or was absent).
func is_valid() -> bool:
	return _error.is_empty()


## First validation problem found, or "" when valid.
func get_error() -> String:
	return _error


## True when the roster has a valid "awakening" block.
func is_enabled() -> bool:
	return _enabled


## The threshold levels, strictly increasing; empty without a block. Read-only: do not modify.
func thresholds() -> Array[int]:
	return _thresholds


## How many awakenings one companion can have (the number of thresholds).
func threshold_count() -> int:
	return _thresholds.size()


## How many of the first thresholds count for the squad: those at or below
## "squad_until_threshold". Example: thresholds 200..1000 and squad_until 600 give 5.
func squad_threshold_count() -> int:
	return _squad_threshold_count


## The factor on the cost of the threshold level, as the decimal string of the data ("10").
func cost_multiplier() -> String:
	return _cost_multiplier


## The damage factor of [param own] awakenings of the companion and [param squad] counted awakenings
## of the whole squad, as the exact fraction [numerator: BigNumber, scale: int] meaning
## numerator / 10^scale: self_multiplier^own * squad_multiplier^squad. Negative counts read as 0.
## Example with "3.4" and "2.10": (1, 1) gives [7140, 3], that is 7,14.
func multiplier_fraction(own: int, squad: int) -> Array:
	var own_count: int = maxi(own, 0)
	var squad_count: int = maxi(squad, 0)
	var numerator: BigNumber = _self_numerator.power(own_count).multiply(_squad_numerator.power(squad_count))
	return [numerator, _self_scale * own_count + _squad_scale * squad_count]


## The factor on the awakened companion as text with the French decimal comma, written as the data
## gives it: "3,4" for "3.4". "1" without a block. For display only.
func self_multiplier_text() -> String:
	return _self_text


## The factor on every companion as text with the French decimal comma, written as the data gives
## it: "2,10" for "2.10". "1" without a block. For display only.
func squad_multiplier_text() -> String:
	return _squad_text


## [param numerator] / 10^[param scale] as text with a French decimal comma, keeping the zeros the
## data wrote: (210, 2) gives "2,10", (3, 0) gives "3". Display only.
## [codeblock]
## print(AwakeningRules.fraction_text(BigNumber.from_int(34), 1))   # "3,4"
## [/codeblock]
static func fraction_text(numerator: BigNumber, scale: int) -> String:
	var digits: String = numerator.to_decimal_string()
	if scale <= 0:
		return digits
	digits = digits.lpad(scale + 1, "0")
	return digits.substr(0, digits.length() - scale) + "," + digits.substr(digits.length() - scale)


func _load(block: Variant) -> void:
	if not block is Dictionary:
		_fail("'awakening' must be an object")
		return
	var data: Dictionary = block
	# Every field is assigned only once the whole block is valid: a refused block leaves no threshold.
	var thresholds: Array[int] = _read_thresholds(data)
	if thresholds.is_empty():
		return
	var own: Array = _read_multiplier(data, "self_multiplier")
	if own.is_empty():
		return
	var squad: Array = _read_multiplier(data, "squad_multiplier")
	if squad.is_empty():
		return
	var until: Variant = data.get("squad_until_threshold")
	if not _is_whole_number(until) or float(until) < 0.0 or float(until) > float(MAX_THRESHOLD_LEVEL):
		_fail("'awakening' squad_until_threshold must be an integer from 0 to %d" % MAX_THRESHOLD_LEVEL)
		return
	var cost: Variant = data.get("cost_level_multiplier")
	var cost_fraction: Array = GrowthCurve.parse_factor(cost as String) if cost is String else []
	if cost_fraction.size() != 2 or (cost_fraction[0] as BigNumber).is_zero():
		_fail("'awakening' cost_level_multiplier must be a decimal string above 0, such as \"10\"")
		return
	_thresholds = thresholds
	_self_numerator = own[0]
	_self_scale = own[1]
	_squad_numerator = squad[0]
	_squad_scale = squad[1]
	_cost_multiplier = cost as String
	_self_text = fraction_text(_self_numerator, _self_scale)
	_squad_text = fraction_text(_squad_numerator, _squad_scale)
	for threshold: int in _thresholds:
		if threshold <= int(until):
			_squad_threshold_count += 1
	_enabled = true


# The thresholds, or [] (with the error set) when the list is not a non-empty, strictly
# increasing array of integers from 1 to MAX_THRESHOLD_LEVEL, at most MAX_THRESHOLDS long.
func _read_thresholds(data: Dictionary) -> Array[int]:
	var parsed: Array[int] = []
	var raw: Variant = data.get("thresholds")
	if not raw is Array or (raw as Array).is_empty() or (raw as Array).size() > MAX_THRESHOLDS:
		_fail("'awakening' thresholds must be a non-empty array of at most %d integers" % MAX_THRESHOLDS)
		return parsed
	for entry: Variant in raw:
		if not _is_whole_number(entry) or float(entry) < 1.0 or float(entry) > float(MAX_THRESHOLD_LEVEL):
			_fail("'awakening' thresholds must be integers from 1 to %d" % MAX_THRESHOLD_LEVEL)
			return [] as Array[int]
		if not parsed.is_empty() and int(entry) <= parsed[-1]:
			_fail("'awakening' thresholds must be strictly increasing")
			return [] as Array[int]
		parsed.append(int(entry))
	return parsed


# The fraction [numerator, scale] of a decimal string above 0, or [] with the error set.
func _read_multiplier(data: Dictionary, key: String) -> Array:
	var raw: Variant = data.get(key)
	var fraction: Array = GrowthCurve.parse_factor(raw as String) if raw is String else []
	if fraction.size() != 2 or (fraction[0] as BigNumber).is_zero():
		_fail("'awakening' %s must be a decimal string above 0, such as \"3.4\"" % key)
		return []
	return fraction


func _is_whole_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))


# Keeps the first error only, prefixed with the file name.
func _fail(message: String) -> void:
	if _error.is_empty():
		_error = "companions_roster.json: " + message
