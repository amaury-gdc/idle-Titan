class_name BigNumber
extends RefCounted
## Exact non-negative integer of arbitrary size.
##
## Representation: little-endian array of base-1e9 limbs (each 0..999_999_999),
## no leading zero limbs (zero is an empty array). All arithmetic is exact.
## Serialized as a plain decimal string (see [method to_decimal_string]), which
## is lossless and JSON-safe (JSON numbers are doubles and would lose precision).
##
## Not thread-safe. Instances are mutable only through the constructor helpers;
## arithmetic methods return new instances.
##
## Usage:
## [codeblock]
## var gold := BigNumber.from_int(1_500_000)
## gold = gold.add(BigNumber.from_string("9223372036854775808")) # beyond int64
## print(BigNumber.from_int(1_500_000).format())      # "1,5 M"
## print(BigNumber.from_int(3_200_000_000).format())  # "3,2 B"
## [/codeblock]

const BASE: int = 1_000_000_000
const BASE_DIGITS: int = 9

## Display suffix per power of 1000 (index = group count). French decimal comma.
## 10^3 K, 10^6 M, 10^9 B, 10^12 T, 10^15 Qa, 10^18 Qi, 10^21 Sx, 10^24 Sp,
## 10^27 Oc, 10^30 No, 10^33 Dc. Beyond that, format() falls back to "1,5e36".
const SUFFIXES: PackedStringArray = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

var _limbs: PackedInt64Array = PackedInt64Array()


## Builds from a non-negative int. Negative values are clamped to zero.
static func from_int(value: int) -> BigNumber:
	var result := BigNumber.new()
	var v: int = maxi(value, 0)
	while v > 0:
		result._limbs.append(v % BASE)
		@warning_ignore("integer_division")
		v /= BASE
	return result


## Builds from a decimal digit string. Returns null unless the string is
## non-empty and every character is an ASCII digit 0-9 (sign, whitespace,
## underscore, non-ASCII digits all invalid). Leading zeros are accepted.
static func from_string(text: String) -> BigNumber:
	if not _is_ascii_digits(text):
		return null
	var result := BigNumber.new()
	var end: int = text.length()
	while end > 0:
		var start: int = maxi(end - BASE_DIGITS, 0)
		result._limbs.append(text.substr(start, end - start).to_int())
		end = start
	result._trim()
	return result


## Returns this + other.
func add(other: BigNumber) -> BigNumber:
	var result := BigNumber.new()
	var carry: int = 0
	var n: int = maxi(_limbs.size(), other._limbs.size())
	for i in n:
		var s: int = carry
		if i < _limbs.size():
			s += _limbs[i]
		if i < other._limbs.size():
			s += other._limbs[i]
		result._limbs.append(s % BASE)
		@warning_ignore("integer_division")
		carry = s / BASE
	if carry > 0:
		result._limbs.append(carry)
	return result


## Returns this - other, clamped to zero when other > this (gold never goes negative).
func subtract(other: BigNumber) -> BigNumber:
	if compare(other) <= 0:
		return BigNumber.new()
	var result := BigNumber.new()
	var borrow: int = 0
	for i in _limbs.size():
		var d: int = _limbs[i] - borrow
		if i < other._limbs.size():
			d -= other._limbs[i]
		if d < 0:
			d += BASE
			borrow = 1
		else:
			borrow = 0
		result._limbs.append(d)
	result._trim()
	return result


## Returns this * other (schoolbook; limb products stay below 2^63).
func multiply(other: BigNumber) -> BigNumber:
	if is_zero() or other.is_zero():
		return BigNumber.new()
	var result := BigNumber.new()
	result._limbs.resize(_limbs.size() + other._limbs.size())
	for i in _limbs.size():
		var carry: int = 0
		for j in other._limbs.size():
			var cur: int = result._limbs[i + j] + _limbs[i] * other._limbs[j] + carry
			result._limbs[i + j] = cur % BASE
			@warning_ignore("integer_division")
			carry = cur / BASE
		var k: int = i + other._limbs.size()
		while carry > 0:
			var cur2: int = result._limbs[k] + carry
			result._limbs[k] = cur2 % BASE
			@warning_ignore("integer_division")
			carry = cur2 / BASE
			k += 1
	result._trim()
	return result


## Returns the floor of this * factor, exact. [param factor] is a decimal String
## of the form "123" or "1.25" (ASCII digits, at most one dot, digits on both
## sides of the dot; no sign, exponent, whitespace or ".5"/"5."). Returns null
## for any other input. Example: BigNumber.from_int(7).multiply_decimal("0.5")
## is 3; 1000 with "1.5" is 1500. No float overload on purpose (floats are inexact).
func multiply_decimal(factor: String) -> BigNumber:
	var parts: PackedStringArray = factor.split(".")
	if parts.size() > 2 or not _is_ascii_digits(parts[0]):
		return null
	var scale: int = 0
	var digits: String = parts[0]
	if parts.size() == 2:
		if not _is_ascii_digits(parts[1]):
			return null
		scale = parts[1].length()
		digits += parts[1]
	var scaled: BigNumber = multiply(BigNumber.from_string(digits))
	return scaled.divide(BigNumber.from_int(10).power(scale))


## Returns the floor integer quotient this / other. Division by zero pushes an
## error and returns null. Example: 10^40 / 3 = 3333...3 (40 digits of "3" minus
## one digit, exact).
func divide(other: BigNumber) -> BigNumber:
	if other.is_zero():
		push_error("BigNumber.divide: division by zero")
		return null
	var quotient: BigNumber = BigNumber.new()
	quotient._limbs.resize(_limbs.size())
	var remainder: BigNumber = BigNumber.new()
	for i in range(_limbs.size() - 1, -1, -1):
		remainder._limbs.insert(0, _limbs[i])
		remainder._trim()
		# Largest q in [0, BASE) with other * q <= remainder (binary search).
		var lo: int = 0
		var hi: int = BASE - 1
		while lo < hi:
			var mid: int = (lo + hi + 1) >> 1
			if other._multiply_small(mid).compare(remainder) <= 0:
				lo = mid
			else:
				hi = mid - 1
		quotient._limbs[i] = lo
		if lo > 0:
			remainder = remainder.subtract(other._multiply_small(lo))
	quotient._trim()
	return quotient


## Returns this ^ exponent, exact (square-and-multiply). exponent 0 gives 1,
## including 0^0 = 1 (usual convention). A negative exponent pushes an error and
## returns null. Example: BigNumber.from_int(2).power(100) is 1267650600228229401496703205376.
func power(exponent: int) -> BigNumber:
	if exponent < 0:
		push_error("BigNumber.power: negative exponent")
		return null
	var result: BigNumber = BigNumber.from_int(1)
	var base: BigNumber = self
	var e: int = exponent
	while e > 0:
		if e & 1 == 1:
			result = result.multiply(base)
		e >>= 1
		if e > 0:
			base = base.multiply(base)
	return result


## Returns -1, 0 or 1 as this is less than, equal to or greater than other.
func compare(other: BigNumber) -> int:
	if _limbs.size() != other._limbs.size():
		return -1 if _limbs.size() < other._limbs.size() else 1
	for i in range(_limbs.size() - 1, -1, -1):
		if _limbs[i] != other._limbs[i]:
			return -1 if _limbs[i] < other._limbs[i] else 1
	return 0


## True if the value is zero.
func is_zero() -> bool:
	return _limbs.is_empty()


## Exact decimal representation, e.g. "9223372036854775808". Used for saving.
func to_decimal_string() -> String:
	if _limbs.is_empty():
		return "0"
	var s: String = str(_limbs[_limbs.size() - 1])
	for i in range(_limbs.size() - 2, -1, -1):
		s += str(_limbs[i]).pad_zeros(BASE_DIGITS)
	return s


## Abbreviated display with French decimal comma, truncated (never rounded up)
## to one decimal, trailing ",0" dropped: 999 -> "999", 1_500_000 -> "1,5 M",
## 3_200_000_000 -> "3,2 B", 2_000 -> "2 K". See [constant SUFFIXES].
func format() -> String:
	var digits: String = to_decimal_string()
	if digits.length() <= 3:
		return digits
	@warning_ignore("integer_division")
	var groups: int = (digits.length() - 1) / 3
	var lead_len: int = digits.length() - groups * 3
	var lead: String = digits.substr(0, lead_len)
	var tenth: String = digits.substr(lead_len, 1)
	var number: String = lead if tenth == "0" else lead + "," + tenth
	if groups < SUFFIXES.size():
		return number + " " + SUFFIXES[groups]
	# Beyond the suffix table: scientific notation with the same comma style.
	var sci: String = lead if lead_len == 1 and tenth == "0" else number
	return sci + "e" + str(groups * 3)


func _trim() -> void:
	while not _limbs.is_empty() and _limbs[_limbs.size() - 1] == 0:
		_limbs.remove_at(_limbs.size() - 1)


# Multiplies by 0 <= m < BASE (limb * m stays below 2^63).
func _multiply_small(m: int) -> BigNumber:
	var result: BigNumber = BigNumber.new()
	if m == 0:
		return result
	var carry: int = 0
	for i in _limbs.size():
		var cur: int = _limbs[i] * m + carry
		result._limbs.append(cur % BASE)
		@warning_ignore("integer_division")
		carry = cur / BASE
	if carry > 0:
		result._limbs.append(carry)
	return result


static func _is_ascii_digits(text: String) -> bool:
	if text.is_empty():
		return false
	for i in text.length():
		var c: int = text.unicode_at(i)
		if c < 48 or c > 57:
			return false
	return true
