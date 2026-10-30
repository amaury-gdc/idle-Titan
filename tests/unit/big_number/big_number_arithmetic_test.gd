extends GdUnitTestSuite
## Unit tests for BigNumber add, subtract and multiply, including values above int64.
## Story: production/epics/idle-titans/story-001-data-state-save.md

const INT64_MAX: String = "9223372036854775807"
const INT64_MAX_PLUS_ONE: String = "9223372036854775808"


func _big(text: String) -> BigNumber:
	return BigNumber.from_string(text)


# --- add -------------------------------------------------------------------

func test_add_small_values_returns_sum() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_int(2)
	var b: BigNumber = BigNumber.from_int(3)

	# Act
	var result: BigNumber = a.add(b)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("5")


func test_add_carries_across_limb_boundary() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_int(999_999_999)
	var b: BigNumber = BigNumber.from_int(1)

	# Act
	var result: BigNumber = a.add(b)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("1000000000")


func test_add_zero_returns_same_value() -> void:
	# Arrange
	var a: BigNumber = _big("123456789012345678901")

	# Act
	var result: BigNumber = a.add(BigNumber.new())

	# Assert
	assert_str(result.to_decimal_string()).is_equal("123456789012345678901")


func test_add_one_to_int64_max_is_exact() -> void:
	# Arrange
	var a: BigNumber = _big(INT64_MAX)

	# Act
	var result: BigNumber = a.add(BigNumber.from_int(1))

	# Assert
	assert_str(result.to_decimal_string()).is_equal(INT64_MAX_PLUS_ONE)


func test_add_two_values_above_int64_is_exact() -> void:
	# Arrange
	var a: BigNumber = _big("99999999999999999999999999999")
	var b: BigNumber = _big("1")

	# Act
	var result: BigNumber = a.add(b)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("100000000000000000000000000000")


# --- subtract --------------------------------------------------------------

func test_subtract_small_values_returns_difference() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_int(10)
	var b: BigNumber = BigNumber.from_int(3)

	# Act
	var result: BigNumber = a.subtract(b)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("7")


func test_subtract_borrows_across_limb_boundary() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_int(1_000_000_000)
	var b: BigNumber = BigNumber.from_int(1)

	# Act
	var result: BigNumber = a.subtract(b)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("999999999")


func test_subtract_larger_from_smaller_clamps_to_zero() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_int(3)
	var b: BigNumber = BigNumber.from_int(10)

	# Act
	var result: BigNumber = a.subtract(b)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("0")
	assert_bool(result.is_zero()).is_true()


func test_subtract_equal_values_returns_zero() -> void:
	# Arrange
	var a: BigNumber = _big("123456789012345678901")
	var b: BigNumber = _big("123456789012345678901")

	# Act
	var result: BigNumber = a.subtract(b)

	# Assert
	assert_bool(result.is_zero()).is_true()


func test_subtract_one_from_int64_max_plus_one_is_exact() -> void:
	# Arrange
	var a: BigNumber = _big(INT64_MAX_PLUS_ONE)

	# Act
	var result: BigNumber = a.subtract(BigNumber.from_int(1))

	# Assert
	assert_str(result.to_decimal_string()).is_equal(INT64_MAX)


func test_subtract_then_add_returns_original_value() -> void:
	# Arrange
	var a: BigNumber = _big("340282366920938463463374607431768211456")
	var b: BigNumber = _big("18446744073709551616")

	# Act
	var result: BigNumber = a.subtract(b).add(b)

	# Assert
	assert_int(result.compare(a)).is_equal(0)


# --- multiply --------------------------------------------------------------

func test_multiply_small_values_returns_product() -> void:
	# Arrange
	var a: BigNumber = BigNumber.from_int(12345)
	var b: BigNumber = BigNumber.from_int(6789)

	# Act
	var result: BigNumber = a.multiply(b)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("83810205")


func test_multiply_by_zero_returns_zero() -> void:
	# Arrange
	var a: BigNumber = _big("123456789012345678901")

	# Act
	var result: BigNumber = a.multiply(BigNumber.new())

	# Assert
	assert_bool(result.is_zero()).is_true()


func test_multiply_by_one_returns_same_value() -> void:
	# Arrange
	var a: BigNumber = _big("123456789012345678901")

	# Act
	var result: BigNumber = a.multiply(BigNumber.from_int(1))

	# Assert
	assert_str(result.to_decimal_string()).is_equal("123456789012345678901")


func test_multiply_value_above_int64_squared_is_exact() -> void:
	# Arrange: (2^63 + 1)^2 = 2^126 + 2^64 + 1
	var a: BigNumber = _big("9223372036854775809")

	# Act
	var result: BigNumber = a.multiply(a)

	# Assert
	assert_str(result.to_decimal_string()).is_equal("85070591730234615884290395931651604481")


func test_multiply_powers_of_ten_adds_zeros() -> void:
	# Arrange
	var a: BigNumber = _big("100000000000000000000")  # 10^20

	# Act
	var result: BigNumber = a.multiply(a)

	# Assert: 10^40
	assert_str(result.to_decimal_string()).is_equal("10000000000000000000000000000000000000000")


func test_multiply_is_commutative() -> void:
	# Arrange
	var a: BigNumber = _big("987654321098765432109876543210")
	var b: BigNumber = _big("123456789")

	# Act
	var ab: BigNumber = a.multiply(b)
	var ba: BigNumber = b.multiply(a)

	# Assert
	assert_int(ab.compare(ba)).is_equal(0)
