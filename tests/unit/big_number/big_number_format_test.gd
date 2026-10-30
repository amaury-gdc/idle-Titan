extends GdUnitTestSuite
## Unit tests for BigNumber.format (abbreviated display, French comma) and for
## decimal-string parsing and serialization, including values above int64.
## Story: production/epics/idle-titans/story-001-data-state-save.md


func _big(text: String) -> BigNumber:
	return BigNumber.from_string(text)


# --- format ----------------------------------------------------------------

func test_format_zero_returns_zero() -> void:
	# Arrange
	var n: BigNumber = BigNumber.new()

	# Act / Assert
	assert_str(n.format()).is_equal("0")


func test_format_below_one_thousand_returns_plain_digits() -> void:
	# Arrange
	var n: BigNumber = BigNumber.from_int(999)

	# Act / Assert
	assert_str(n.format()).is_equal("999")


func test_format_exactly_one_thousand_returns_one_k() -> void:
	# Arrange
	var n: BigNumber = BigNumber.from_int(1000)

	# Act / Assert
	assert_str(n.format()).is_equal("1 K")


func test_format_one_million_five_hundred_thousand_returns_comma_decimal() -> void:
	# Arrange
	var n: BigNumber = BigNumber.from_int(1_500_000)

	# Act / Assert
	assert_str(n.format()).is_equal("1,5 M")


func test_format_three_point_two_billion_returns_b_suffix() -> void:
	# Arrange
	var n: BigNumber = BigNumber.from_int(3_200_000_000)

	# Act / Assert
	assert_str(n.format()).is_equal("3,2 B")


func test_format_truncates_instead_of_rounding_up() -> void:
	# Arrange
	var n: BigNumber = BigNumber.from_int(1999)

	# Act / Assert: 1,999 K shows 1,9 K, never 2 K
	assert_str(n.format()).is_equal("1,9 K")


func test_format_drops_trailing_zero_decimal() -> void:
	# Arrange
	var n: BigNumber = BigNumber.from_int(2_050)

	# Act / Assert: 2,05 K truncates to 2,0 and the ",0" is dropped
	assert_str(n.format()).is_equal("2 K")


func test_format_two_digit_lead_keeps_one_decimal() -> void:
	# Arrange
	var n: BigNumber = BigNumber.from_int(12_345)

	# Act / Assert
	assert_str(n.format()).is_equal("12,3 K")


func test_format_three_digit_lead_keeps_one_decimal() -> void:
	# Arrange
	var n: BigNumber = BigNumber.from_int(123_456)

	# Act / Assert
	assert_str(n.format()).is_equal("123,4 K")


func test_format_value_above_int64_uses_qi_suffix() -> void:
	# Arrange: 2^63 + 1
	var n: BigNumber = _big("9223372036854775809")

	# Act / Assert
	assert_str(n.format()).is_equal("9,2 Qi")


func test_format_last_suffix_in_table_is_dc() -> void:
	# Arrange: 10^33
	var n: BigNumber = BigNumber.from_int(10).power(33)

	# Act / Assert
	assert_str(n.format()).is_equal("1 Dc")


func test_format_beyond_suffix_table_falls_back_to_exponent_notation() -> void:
	# Arrange: 10^36 and 1.5 * 10^36
	var one: BigNumber = BigNumber.from_int(10).power(36)
	var one_and_a_half: BigNumber = _big("1500000000000000000000000000000000000")

	# Act / Assert
	assert_str(one.format()).is_equal("1e36")
	assert_str(one_and_a_half.format()).is_equal("1,5e36")


# --- parsing and serialization ----------------------------------------------

func test_from_string_above_int64_round_trips_exactly() -> void:
	# Arrange
	var text: String = "123456789012345678901234567890"

	# Act
	var n: BigNumber = _big(text)

	# Assert
	assert_str(n.to_decimal_string()).is_equal(text)


func test_from_string_int64_max_plus_one_is_greater_than_int64_max() -> void:
	# Arrange
	var above: BigNumber = _big("9223372036854775808")
	var max_int: BigNumber = BigNumber.from_int(9223372036854775807)

	# Act / Assert
	assert_int(above.compare(max_int)).is_equal(1)
	assert_int(max_int.compare(above)).is_equal(-1)


func test_from_string_with_leading_zeros_is_accepted() -> void:
	# Arrange / Act
	var n: BigNumber = _big("007")

	# Assert
	assert_str(n.to_decimal_string()).is_equal("7")


func test_from_string_with_limb_boundary_zero_padding_keeps_inner_zeros() -> void:
	# Arrange: inner limb is all zeros
	var text: String = "1000000000000000000"  # 10^18, three limbs

	# Act
	var n: BigNumber = _big(text)

	# Assert
	assert_str(n.to_decimal_string()).is_equal(text)


func test_from_string_with_invalid_text_returns_null() -> void:
	# Arrange
	var invalid_texts: PackedStringArray = ["", " 5", "5 ", "1_0", "-1", "+5", "1.5", "1e3", "abc", "٣"]

	for text: String in invalid_texts:
		# Act
		var n: BigNumber = _big(text)

		# Assert
		assert_object(n).override_failure_message("'%s' should be rejected" % text).is_null()


func test_from_int_negative_value_clamps_to_zero() -> void:
	# Arrange / Act
	var n: BigNumber = BigNumber.from_int(-5)

	# Assert
	assert_bool(n.is_zero()).is_true()


func test_compare_orders_values_by_magnitude() -> void:
	# Arrange
	var small: BigNumber = BigNumber.from_int(5)
	var big: BigNumber = _big("100000000000000000000")

	# Act / Assert
	assert_int(small.compare(big)).is_equal(-1)
	assert_int(big.compare(small)).is_equal(1)
	assert_int(big.compare(big)).is_equal(0)
