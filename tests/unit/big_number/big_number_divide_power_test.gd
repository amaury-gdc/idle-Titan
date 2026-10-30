extends GdUnitTestSuite
## Unit tests for BigNumber divide (floor quotient) and power (exact).
## Error paths (division by zero, negative exponent) push an engine error and
## return null; they are not asserted here, see tests/README.md.
## Story: production/epics/idle-titans/story-001-data-state-save.md


func _big(text: String) -> BigNumber:
	return BigNumber.from_string(text)


# --- divide ----------------------------------------------------------------

func test_divide_exact_values_returns_quotient() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_int(100)
	var b: BigNumber = BigNumber.from_int(10)

	# Act
	var result: BigNumber = a.divide(b)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("10")


func test_divide_with_remainder_returns_floor_quotient() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_int(10)
	var b: BigNumber = BigNumber.from_int(3)

	# Act
	var result: BigNumber = a.divide(b)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("3")


func test_divide_smaller_by_larger_returns_zero() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_int(7)
	var b: BigNumber = BigNumber.from_int(10)

	# Act
	var result: BigNumber = a.divide(b)

	# Assert
	assert_bool(result.is_zero()).is_true()


func test_divide_zero_by_value_returns_zero() -> void:
	# Arrange
	var a: BigNumber = BigNumber.new()
	var b: BigNumber = BigNumber.from_int(5)

	# Act
	var result: BigNumber = a.divide(b)

	# Assert
	assert_bool(result.is_zero()).is_true()


func test_divide_by_itself_returns_one() -> void:
	# Arrange
	var a: BigNumber = _big("123456789012345678901234567890")

	# Act
	var result: BigNumber = a.divide(a)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("1")


func test_divide_value_above_int64_by_three_is_exact_floor() -> void:
	# Arrange
	var a: BigNumber = _big("10000000000000000000000000000000000000000")  # 10^40

	# Act
	var result: BigNumber = a.divide(BigNumber.from_int(3))

	# Assert: 10^40 / 3 = 3.33e39, which is forty digits, all 3
	assert_str(result.to_decimal_string()).is_equal("3333333333333333333333333333333333333333")


func test_divide_two_to_the_128_by_two_to_the_64_is_exact() -> void:
	# Arrange
	var a: BigNumber = _big("340282366920938463463374607431768211456")  # 2^128
	var b: BigNumber = _big("18446744073709551616")  # 2^64

	# Act
	var result: BigNumber = a.divide(b)

	# Assert: 2^64
	assert_str(result.to_decimal_string()).is_equal("18446744073709551616")


func test_divide_then_multiply_never_exceeds_original() -> void:
	# Arrange
	var a: BigNumber = _big("98765432109876543210987654321")
	var b: BigNumber = _big("1234567891")

	# Act
	var floored: BigNumber = a.divide(b).multiply(b)

	# Assert: q * b <= a < (q + 1) * b
	assert_int(floored.compare(a)).is_less_equal(0)
	assert_int(a.compare(floored.add(b))).is_equal(-1)


# --- power -----------------------------------------------------------------

func test_power_two_to_the_ten_returns_1024() -> void:
	# Arrange
	var base: BigNumber = BigNumber.from_int(2)

	# Act
	var result: BigNumber = base.power(10)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("1024")


func test_power_two_to_the_hundred_is_exact() -> void:
	# Arrange
	var base: BigNumber = BigNumber.from_int(2)

	# Act
	var result: BigNumber = base.power(100)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("1267650600228229401496703205376")


func test_power_two_to_the_sixty_four_exceeds_int64_and_is_exact() -> void:
	# Arrange
	var base: BigNumber = BigNumber.from_int(2)

	# Act
	var result: BigNumber = base.power(64)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("18446744073709551616")


func test_power_exponent_zero_returns_one() -> void:
	# Arrange
	var base: BigNumber = _big("123456789012345678901234567890")

	# Act
	var result: BigNumber = base.power(0)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("1")


func test_power_zero_to_the_zero_returns_one_by_convention() -> void:
	# Arrange
	var base: BigNumber = BigNumber.new()

	# Act
	var result: BigNumber = base.power(0)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("1")


func test_power_zero_to_a_positive_exponent_returns_zero() -> void:
	# Arrange
	var base: BigNumber = BigNumber.new()

	# Act
	var result: BigNumber = base.power(5)

	# Assert
	assert_bool(result.is_zero()).is_true()


func test_power_one_to_a_large_exponent_returns_one() -> void:
	# Arrange
	var base: BigNumber = BigNumber.from_int(1)

	# Act
	var result: BigNumber = base.power(1000)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("1")


func test_power_ten_to_the_forty_is_one_followed_by_forty_zeros() -> void:
	# Arrange
	var base: BigNumber = BigNumber.from_int(10)

	# Act
	var result: BigNumber = base.power(40)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("10000000000000000000000000000000000000000")


func test_power_matches_repeated_multiplication() -> void:
	# Arrange
	var base: BigNumber = BigNumber.from_int(7)
	var expected: BigNumber = BigNumber.from_int(1)
	for i: int in 25:
		expected = expected.multiply(base)

	# Act
	var result: BigNumber = base.power(25)

	# Assert
	assert_int(result.compare(expected)).is_equal(0)
