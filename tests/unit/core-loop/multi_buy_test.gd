extends GdUnitTestSuite
## Unit tests for the fast price path and the batch purchase: floor by a power of ten, exact costs
## at every useful level, sums of levels, x10 and Max. Oracles that must not share code with what
## they check work on plain decimal digits.
## Story: production/epics/idle-titans/story-010-adaptive-layout.md, "Calcul des prix"; D3 of
## design/ux/main-screen-adaptive.md.

const REAL_ROSTER_PATH: String = "res://assets/data/companions_roster.json"
const REAL_CURVES_PATH: String = "res://assets/data/core_curves.json"
const ID: String = "scout"
const BASE_COST: String = "10"
const GROWTH: String = "1.08"
## Largest real base_cost, two limbs.
const LARGE_BASE_COST: String = "220000000000"
const LAST_LEVEL: int = 1200
## The general division runs every this many levels: it is what the fast path replaced.
const DIVIDE_STRIDE: int = 50
const BATCH: int = 10
const HUGE_GOLD_DIGITS: int = 400
const RANDOM_VALUES: int = 300
## Multiplier and increment of a linear congruential generator: fixed, so every run is identical.
const LCG_MULTIPLIER: int = 1_103_515_245
const LCG_INCREMENT: int = 12_345
const LCG_MODULUS: int = 2_147_483_648
## A stage far behind the wall (before 130, assets/data/balance_notes.md).
const FAR_PAST_THE_WALL_STAGE: int = 300

var _state: GameState
var _companions: CompanionManager
var _leveled: Array = []
var _bought: Array = []
var _seed: int = 1


func before_test() -> void:
	_seed = 1
	_build(BigNumber.new(), 0)


# Builds a one-companion game holding [param gold], with the companion at [param start_level].
func _build(gold: BigNumber, start_level: int) -> void:
	var curves: Dictionary = {
		"schema_version": Combat.SUPPORTED_CURVES_SCHEMA,
		"enemy_hp_base": "1000",
		"enemy_hp_growth": "1",
		"gold_per_kill_base": "1",
		"gold_per_kill_growth": "1",
		"click_damage_base": "1",
		"click_companion_power_factor": "0",
		"cost_growth": GROWTH,
		"offline_efficiency": "0.5",
		"offline_max_hours": 12,
		"offline_min_seconds": 60,
	}
	var roster: Dictionary = {
		"schema_version": 2,
		"companions": [{
			"id": ID,
			"name": "Scout",
			"base_cost": BASE_COST,
			"base_damage": "1",
			"cost_growth": GROWTH,
			"attack_interval_seconds": 1.0,
			"tiers": [],
		}],
	}
	var combat: Combat = Combat.from_data(curves, roster)
	assert_str(combat.get_error()).is_empty()
	_state = GameState.new()
	_state.gold = gold
	if start_level > 0:
		_state.companion_levels = {ID: start_level}
	_companions = CompanionManager.new(_state, combat, FloorManager.new(_state, combat))
	_leveled = []
	_bought = []
	_companions.companion_leveled_up.connect(func(id: String, level: int) -> void: _leveled.append([id, level]))
	_companions.companions_bought.connect(func(id: String, level: int) -> void: _bought.append([id, level]))


func _huge_gold() -> BigNumber:
	return BigNumber.from_string("1" + "0".repeat(HUGE_GOLD_DIGITS))


# Next value of the fixed generator, in 0..LCG_MODULUS - 1.
func _next_random() -> int:
	_seed = (_seed * LCG_MULTIPLIER + LCG_INCREMENT) % LCG_MODULUS
	return _seed


# A decimal string of [param length] digits, the first one not zero.
func _random_digits(length: int) -> String:
	var text: String = str(_next_random() % 9 + 1)
	while text.length() < length:
		text += str(_next_random() % 10)
	return text


func _ten_to(exponent: int) -> BigNumber:
	return BigNumber.from_string("1" + "0".repeat(exponent))


# Little-endian decimal digits of [param text].
func _digits_of(text: String) -> PackedInt64Array:
	var digits: PackedInt64Array = PackedInt64Array()
	for i in range(text.length() - 1, -1, -1):
		digits.append(text.unicode_at(i) - 48)
	return digits


# Schoolbook multiplication on decimal digits: shares no code with BigNumber.
func _digits_times(digits: PackedInt64Array, factor: int) -> PackedInt64Array:
	var out: PackedInt64Array = PackedInt64Array()
	var carry: int = 0
	for digit: int in digits:
		var cur: int = digit * factor + carry
		out.append(cur % 10)
		@warning_ignore("integer_division")
		carry = cur / 10
	while carry > 0:
		out.append(carry % 10)
		@warning_ignore("integer_division")
		carry /= 10
	return out


# Decimal text of the number floored by 10^[param exponent], by dropping digits.
func _digits_floor(digits: PackedInt64Array, exponent: int) -> String:
	var text: String = ""
	for i in range(digits.size() - 1, exponent - 1, -1):
		text += str(digits[i])
	text = text.lstrip("0")
	return "0" if text.is_empty() else text


# The formula as it stood before the story: general division.
func _old_value_at(base: BigNumber, growth: String, steps: int) -> BigNumber:
	var parts: PackedStringArray = growth.split(".")
	var scale: int = parts[1].length() if parts.size() == 2 else 0
	var scaled: BigNumber = base.multiply(BigNumber.from_string("".join(parts)).power(steps))
	return scaled.divide(_ten_to(scale * steps))


# Every distinct cost_growth of the shipped data.
func _real_growth_factors() -> PackedStringArray:
	var curves: Dictionary = DataLoader.load_json(REAL_CURVES_PATH)
	var roster: Dictionary = DataLoader.load_json(REAL_ROSTER_PATH)
	var factors: PackedStringArray = PackedStringArray([curves["cost_growth"]])
	for entry: Dictionary in roster["companions"]:
		var growth: String = entry.get("cost_growth", curves["cost_growth"])
		if not factors.has(growth):
			factors.append(growth)
	return factors


func test_power_of_ten_division_many_values_matches_divide() -> void:
	# Arrange
	var mismatches: PackedStringArray = PackedStringArray()

	for i in RANDOM_VALUES:
		var value: BigNumber = BigNumber.from_string(_random_digits(_next_random() % 120 + 1))
		var exponent: int = _next_random() % 130
		# Act
		var fast: String = value.divide_by_power_of_ten(exponent).to_decimal_string()
		var slow: String = value.divide(_ten_to(exponent)).to_decimal_string()
		# Assert
		if fast != slow:
			mismatches.append("%s / 10^%d" % [value.to_decimal_string(), exponent])
	assert_array(Array(mismatches)).is_empty()


func test_power_of_ten_division_across_limb_boundaries_matches_divide() -> void:
	# Arrange
	var value: BigNumber = BigNumber.from_string(_random_digits(100))
	var mismatches: Array[int] = []

	for exponent in range(0, 120):
		# Act
		var fast: String = value.divide_by_power_of_ten(exponent).to_decimal_string()
		# Assert
		if fast != value.divide(_ten_to(exponent)).to_decimal_string():
			mismatches.append(exponent)
	assert_array(mismatches).is_empty()


func test_power_of_ten_division_exact_multiples_of_the_base_matches_divide() -> void:
	# Arrange: 1, 999999999 and 5 followed by whole limbs of zeros, so low limbs are empty.
	var mismatches: PackedStringArray = PackedStringArray()

	for lead: String in ["1", "999999999", "5", "100000000"]:
		for limbs in range(1, 6):
			var value: BigNumber = BigNumber.from_string(lead + "0".repeat(limbs * BigNumber.BASE_DIGITS))
			for exponent in range(0, (limbs + 2) * BigNumber.BASE_DIGITS, 3):
				# Act
				var fast: String = value.divide_by_power_of_ten(exponent).to_decimal_string()
				# Assert
				if fast != value.divide(_ten_to(exponent)).to_decimal_string():
					mismatches.append("%s / 10^%d" % [value.to_decimal_string(), exponent])
	assert_array(Array(mismatches)).is_empty()


func test_power_of_ten_division_exponent_past_the_value_gives_zero() -> void:
	# Arrange
	var value: BigNumber = BigNumber.from_string("123456789012")

	# Act and assert
	assert_bool(value.divide_by_power_of_ten(12).is_zero()).is_true()
	assert_bool(value.divide_by_power_of_ten(90).is_zero()).is_true()
	assert_bool(BigNumber.new().divide_by_power_of_ten(9).is_zero()).is_true()
	assert_str(value.divide_by_power_of_ten(11).to_decimal_string()).is_equal("1")


func test_power_of_ten_division_negative_exponent_gives_null() -> void:
	# Act and assert
	assert_object(BigNumber.from_int(5).divide_by_power_of_ten(-1)).is_null()


func test_power_matches_digit_schoolbook_for_every_limb_width() -> void:
	# Arrange
	var mismatches: PackedStringArray = PackedStringArray()

	for base_value: int in [0, 1, 2, 10, 108, 999_999_999, 1_000_000_000, 123_456_789_012]:
		var digits: PackedInt64Array = _digits_of("1")
		var base: BigNumber = BigNumber.from_int(base_value)
		for exponent in range(0, 41):
			# Act
			var result: String = base.power(exponent).to_decimal_string()
			# Assert
			if result != _digits_floor(digits, 0):
				mismatches.append("%d^%d" % [base_value, exponent])
			digits = _digits_times(digits, base_value)
	assert_array(Array(mismatches)).is_empty()


func test_multiply_one_limb_factor_matches_digit_schoolbook() -> void:
	# Arrange
	var mismatches: PackedStringArray = PackedStringArray()

	for factor: int in [1, 2, 108, 999_999_999]:
		for length: int in [1, 9, 10, 18, 19, 90]:
			var text: String = "9".repeat(length) if length % 9 == 0 else _random_digits(length)
			# Act
			var result: String = BigNumber.from_string(text).multiply(BigNumber.from_int(factor)).to_decimal_string()
			# Assert
			if result != _digits_floor(_digits_times(_digits_of(text), factor), 0):
				mismatches.append("%s * %d" % [text, factor])
	assert_array(Array(mismatches)).is_empty()


func test_value_at_real_growth_levels_1_to_1200_matches_old_formula() -> void:
	# Arrange
	var factors: PackedStringArray = _real_growth_factors()
	assert_bool(factors.is_empty()).is_false()
	var mismatches: PackedStringArray = PackedStringArray()

	for growth: String in factors:
		var parts: PackedStringArray = growth.split(".")
		var numerator: int = "".join(parts).to_int()
		var scale: int = parts[1].length() if parts.size() == 2 else 0
		for base_text: String in [BASE_COST, LARGE_BASE_COST]:
			var base: BigNumber = BigNumber.from_string(base_text)
			var digits: PackedInt64Array = _digits_of(base_text)
			for steps in range(0, LAST_LEVEL + 1):
				# Act
				var value: String = GrowthCurve.value_at(base, growth, steps).to_decimal_string()
				# Assert
				var expected: String = _digits_floor(digits, scale * steps)
				if value != expected:
					mismatches.append("%s x %s^%d" % [base_text, growth, steps])
				if steps % DIVIDE_STRIDE == 0 and value != _old_value_at(base, growth, steps).to_decimal_string():
					mismatches.append("divide: %s x %s^%d" % [base_text, growth, steps])
				digits = _digits_times(digits, numerator)
	assert_array(Array(mismatches)).is_empty()


func test_cost_of_level_in_any_query_order_matches_old_formula() -> void:
	# Arrange: forward steps, a walk at the limit, a jump past it, back down, and level 0.
	var base: BigNumber = BigNumber.from_string(BASE_COST)
	var companion: Companion = _companions.companions()[0]
	var limit: int = Companion.NUMERATOR_WALK_LIMIT
	var levels: Array[int] = [1, 2, 3, 3 + limit, 4 + 2 * limit, 700, 701, 700, 1000, 2, 0, 1]

	for level: int in levels:
		# Act
		var cost: String = companion.cost_of_level(level).to_decimal_string()
		# Assert
		var expected: String = _old_value_at(base, GROWTH, maxi(level, 1) - 1).to_decimal_string()
		assert_str(cost).is_equal(expected)


func test_cost_of_levels_equals_sum_of_next_cost_over_single_buys() -> void:
	for start_level: int in [0, 1, 37, 400]:
		for count: int in [1, 2, 10, 100]:
			# Arrange
			_build(_huge_gold(), start_level)
			var batch_cost: String = _companions.cost_of_levels(ID, count).to_decimal_string()
			var expected: BigNumber = BigNumber.new()

			# Act
			for i in count:
				expected = expected.add(_companions.next_cost(ID))
				assert_bool(_companions.buy_or_upgrade(ID)).is_true()

			# Assert
			assert_str(batch_cost).is_equal(expected.to_decimal_string())


func test_cost_of_levels_no_level_costs_nothing() -> void:
	# Act and assert
	assert_bool(_companions.cost_of_levels(ID, 0).is_zero()).is_true()
	assert_bool(_companions.cost_of_levels(ID, -3).is_zero()).is_true()


func test_buy_levels_leaves_gold_and_level_of_n_single_buys() -> void:
	for start_level: int in [0, 5, 390]:
		# Arrange
		var gold: BigNumber = _huge_gold()
		_build(gold, start_level)
		var batch_state: GameState = _state
		var batch: CompanionManager = _companions
		_build(gold, start_level)

		# Act
		var bought: bool = batch.buy_levels(ID, BATCH)
		for i in BATCH:
			_companions.buy_or_upgrade(ID)

		# Assert
		assert_bool(bought).is_true()
		assert_int(batch.level(ID)).is_equal(start_level + BATCH)
		assert_int(batch.level(ID)).is_equal(_companions.level(ID))
		assert_str(batch_state.gold.to_decimal_string()).is_equal(_state.gold.to_decimal_string())
		assert_str(batch.next_cost(ID).to_decimal_string()).is_equal(_companions.next_cost(ID).to_decimal_string())


func test_buy_levels_success_emits_one_batch_signal_and_no_level_up() -> void:
	# Arrange
	_build(_huge_gold(), 3)

	# Act
	_companions.buy_levels(ID, BATCH)

	# Assert
	assert_array(_bought).is_equal([[ID, 3 + BATCH]])
	assert_array(_leveled).is_empty()


func test_buy_or_upgrade_still_emits_level_up_only_and_returns_true() -> void:
	# Arrange
	_build(_huge_gold(), 3)

	# Act
	var bought: bool = _companions.buy_or_upgrade(ID)

	# Assert
	assert_bool(bought).is_true()
	assert_array(_leveled).is_equal([[ID, 4]])
	assert_array(_bought).is_empty()


func test_buy_levels_gold_one_short_of_x10_refuses_and_changes_nothing() -> void:
	# Arrange: enough for 9 levels, not for 10.
	_build(_huge_gold(), 2)
	var cost: BigNumber = _companions.cost_of_levels(ID, BATCH)
	var gold: BigNumber = cost.subtract(BigNumber.from_int(1))
	_build(gold, 2)
	assert_int(_companions.affordable_levels(ID)).is_equal(BATCH - 1)

	# Act
	var bought: bool = _companions.buy_levels(ID, BATCH)

	# Assert
	assert_bool(bought).is_false()
	assert_int(_companions.level(ID)).is_equal(2)
	assert_str(_state.gold.to_decimal_string()).is_equal(gold.to_decimal_string())
	assert_array(_bought).is_empty()
	assert_array(_leveled).is_empty()


func test_buy_levels_gold_exactly_x10_spends_all_of_it() -> void:
	# Arrange
	_build(_huge_gold(), 2)
	var cost: BigNumber = _companions.cost_of_levels(ID, BATCH)
	_build(cost, 2)

	# Act
	var bought: bool = _companions.buy_levels(ID, BATCH)

	# Assert
	assert_bool(bought).is_true()
	assert_int(_companions.level(ID)).is_equal(2 + BATCH)
	assert_bool(_state.gold.is_zero()).is_true()


func test_buy_levels_unknown_id_or_no_level_refuses() -> void:
	# Arrange
	_build(_huge_gold(), 1)
	var gold: String = _state.gold.to_decimal_string()

	# Act and assert
	assert_bool(_companions.buy_levels("nobody", 1)).is_false()
	assert_bool(_companions.buy_levels(ID, 0)).is_false()
	assert_bool(_companions.buy_levels(ID, -2)).is_false()
	assert_int(_companions.level(ID)).is_equal(1)
	assert_str(_state.gold.to_decimal_string()).is_equal(gold)
	assert_array(_bought).is_empty()


func test_affordable_levels_no_gold_is_zero() -> void:
	# Act and assert
	assert_int(_companions.affordable_levels(ID)).is_equal(0)


func test_affordable_levels_exact_sum_counts_those_levels_and_one_less_does_not() -> void:
	for count: int in [1, 7, 60]:
		# Arrange
		_build(_huge_gold(), 11)
		var cost: BigNumber = _companions.cost_of_levels(ID, count)

		# Act
		_build(cost, 11)
		var exact: int = _companions.affordable_levels(ID)
		_build(cost.subtract(BigNumber.from_int(1)), 11)
		var one_short: int = _companions.affordable_levels(ID)

		# Assert
		assert_int(exact).is_equal(count)
		assert_int(one_short).is_equal(count - 1)


func test_affordable_levels_unknown_id_or_no_room_is_zero() -> void:
	# Arrange
	_build(_huge_gold(), 0)

	# Act and assert
	assert_int(_companions.affordable_levels("nobody")).is_equal(0)
	assert_int(_companions.affordable_levels(ID, 0)).is_equal(0)


func test_affordable_levels_stops_at_the_asked_count() -> void:
	# Arrange
	_build(_huge_gold(), 0)

	# Act and assert
	assert_int(_companions.affordable_levels(ID, BATCH)).is_equal(BATCH)


func test_affordable_levels_huge_gold_stops_at_the_cap_and_can_be_bought() -> void:
	# Arrange
	_build(_huge_gold(), 0)

	# Act
	var count: int = _companions.affordable_levels(ID)
	var above_the_cap: int = _companions.affordable_levels(ID, CompanionManager.MAX_SCAN_LEVELS + 1)
	var bought: bool = _companions.buy_levels(ID, count)

	# Assert
	assert_int(count).is_equal(CompanionManager.MAX_SCAN_LEVELS)
	assert_int(above_the_cap).is_equal(CompanionManager.MAX_SCAN_LEVELS)
	assert_bool(bought).is_true()
	assert_int(_companions.level(ID)).is_equal(CompanionManager.MAX_SCAN_LEVELS)


func test_scan_cap_levels_of_the_cheapest_companion_cost_more_than_gold_in_play() -> void:
	# Arrange: the real data, and one kill far behind the wall as the richest gold in play.
	var curves: Dictionary = DataLoader.load_json(REAL_CURVES_PATH)
	var roster: Dictionary = DataLoader.load_json(REAL_ROSTER_PATH)
	var cheapest: Companion = Companion.from_entry(roster["companions"][0], curves["cost_growth"])
	var kill_gold: BigNumber = GrowthCurve.value_at(
		BigNumber.from_string(curves["gold_per_kill_base"]),
		curves["gold_per_kill_growth"],
		FAR_PAST_THE_WALL_STAGE
	)

	# Act
	var cap_cost: BigNumber = cheapest.cost_of_levels_from(1, CompanionManager.MAX_SCAN_LEVELS)

	# Assert
	assert_int(cap_cost.compare(kill_gold)).is_equal(1)


func test_scan_then_price_reads_keep_the_exact_price() -> void:
	# Arrange
	_build(_huge_gold(), 20)
	var expected: String = _old_value_at(BigNumber.from_string(BASE_COST), GROWTH, 20).to_decimal_string()
	var after_batch: String = _old_value_at(BigNumber.from_string(BASE_COST), GROWTH, 20 + BATCH).to_decimal_string()

	# Act
	_companions.affordable_levels(ID)
	_companions.cost_of_levels(ID, BATCH)
	var price: String = _companions.next_cost(ID).to_decimal_string()
	_companions.buy_levels(ID, BATCH)
	var price_after: String = _companions.next_cost(ID).to_decimal_string()

	# Assert
	assert_str(price).is_equal(expected)
	assert_str(price_after).is_equal(after_batch)
