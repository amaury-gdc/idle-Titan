class_name GrowthCurve
extends RefCounted
## Exact exponential growth curves on [BigNumber]: base * growth^steps.
##
## The growth factor is a decimal String ("1.3"), never a float. The result is
## computed as floor(base * numerator^steps / 10^(scale * steps)), where
## numerator/10^scale is the growth written as a fraction, so the value is exact
## and independent of any per-step rounding (applying multiply_decimal step by
## step would truncate at every step and drift).
##
## Cost: one power + one division on numbers of about steps * 0.12 limbs; meant
## to be called once per stage or purchase, not per frame. Single-thread only.
##
## Usage:
## [codeblock]
## var hp: BigNumber = GrowthCurve.value_at(BigNumber.from_int(15), "1.3", 1)
## # hp is 19 (15 * 1.3 = 19.5, floored)
## [/codeblock]


## True if [param growth] is "123" or "1.25": ASCII digits, at most one dot,
## digits on both sides of the dot (same grammar as [method BigNumber.multiply_decimal]).
static func is_valid_factor(growth: String) -> bool:
	return _parse_factor(growth).size() == 2


## Returns floor(base * growth^steps), exact. Returns null (and pushes an error)
## when [param growth] is not a valid decimal factor or [param steps] is negative.
## steps 0 returns [param base] unchanged.
static func value_at(base: BigNumber, growth: String, steps: int) -> BigNumber:
	if steps < 0:
		push_error("GrowthCurve.value_at: negative steps")
		return null
	var parsed: Array = _parse_factor(growth)
	if parsed.size() != 2:
		push_error("GrowthCurve.value_at: invalid growth factor '%s'" % growth)
		return null
	var numerator: BigNumber = parsed[0]
	var scale: int = parsed[1]
	var scaled: BigNumber = base.multiply(numerator.power(steps))
	return scaled.divide(BigNumber.from_int(10).power(scale * steps))


# Returns [numerator: BigNumber, scale: int] or [] when invalid.
static func _parse_factor(growth: String) -> Array:
	var parts: PackedStringArray = growth.split(".")
	if parts.size() > 2:
		return []
	var digits: String = parts[0]
	var scale: int = 0
	if parts.size() == 2:
		scale = parts[1].length()
		digits += parts[1]
	if parts[0].is_empty() or (parts.size() == 2 and parts[1].is_empty()):
		return []
	var numerator: BigNumber = BigNumber.from_string(digits)
	if numerator == null:
		return []
	return [numerator, scale]
