extends GdUnitTestSuite
## Unit tests for BigNumber.multiply_decimal (exact, floored, String factor).
## Story: production/epics/idle-titans/story-001-data-state-save.md


func test_multiply_decimal_by_one_and_a_half_returns_exact_product() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_int(1000)

	# Act
	var result: BigNumber = a.multiply_decimal("1.5")

	# Assert
	assert_str(result.to_decimal_string()).is_equal("1500")


func test_multiply_decimal_rounds_down() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_int(7)

	# Act
	var result: BigNumber = a.multiply_decimal("0.5")

	# Assert: 3.5 floors to 3
	assert_str(result.to_decimal_string()).is_equal("3")


func test_multiply_decimal_just_below_next_integer_rounds_down() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_int(10)

	# Act
	var result: BigNumber = a.multiply_decimal("0.99")

	# Assert: 9.9 floors to 9
	assert_str(result.to_decimal_string()).is_equal("9")


func test_multiply_decimal_by_whole_number_string_acts_as_integer_multiply() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_int(5)

	# Act
	var result: BigNumber = a.multiply_decimal("12")

	# Assert
	assert_str(result.to_decimal_string()).is_equal("60")


func test_multiply_decimal_by_zero_point_zero_returns_zero() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_int(12345)

	# Act
	var result: BigNumber = a.multiply_decimal("0.0")

	# Assert
	assert_bool(result.is_zero()).is_true()


func test_multiply_decimal_of_zero_returns_zero() -> void:
	# Arrange
	var a: BigNumber = BigNumber.new()

	# Act
	var result: BigNumber = a.multiply_decimal("1.5")

	# Assert
	assert_bool(result.is_zero()).is_true()


func test_multiply_decimal_value_above_int64_is_exact_and_floored() -> void:
	# Arrange: x * 1.25 = x * 5 / 4, with a .75 fraction dropped
	var a: BigNumber = BigNumber.from_string("123456789012345678901234567891")

	# Act
	var result: BigNumber = a.multiply_decimal("1.25")

	# Assert
	assert_str(result.to_decimal_string()).is_equal("154320986265432098626543209863")


func test_multiply_decimal_with_many_fraction_digits_is_exact() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_string("1000000000000")  # 10^12

	# Act
	var result: BigNumber = a.multiply_decimal("1.000000000001")

	# Assert: 10^12 * (1 + 10^-12) = 10^12 + 1
	assert_str(result.to_decimal_string()).is_equal("1000000000001")


func test_multiply_decimal_with_invalid_factor_returns_null() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_int(100)
	var invalid_factors: PackedStringArray = ["-1", "1.2.3", ".5", "5.", "", "1e3", " 1", "1,5", "abc"]

	for factor: String in invalid_factors:
		# Act
		var result: BigNumber = a.multiply_decimal(factor)

		# Assert
		assert_object(result).override_failure_message("factor '%s' should be rejected" % factor).is_null()
