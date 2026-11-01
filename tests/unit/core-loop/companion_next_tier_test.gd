extends GdUnitTestSuite
## Unit tests for the read of the next tier, from the data and with no assumed rhythm, and for the
## sum of levels now kept between two calls: same exact value as one level at a time.
## Story: production/epics/idle-titans/story-013-companion-touch-ups.md.

const REAL_TIERS: Array[Dictionary] = [
	{"level": 10, "damage_multiplier": "2"},
	{"level": 25, "damage_multiplier": "2"},
	{"level": 50, "damage_multiplier": "2"},
	{"level": 100, "damage_multiplier": "3"},
	{"level": 150, "damage_multiplier": "3"},
	{"level": 200, "damage_multiplier": "3"},
]


func _companion(tiers: Array) -> Companion:
	var companion: Companion = Companion.from_entry({
		"id": "scout",
		"name": "Scout",
		"base_cost": "10",
		"base_damage": "1",
		"cost_growth": "1.08",
		"attack_interval_seconds": 1.0,
		"tiers": tiers,
	}, "")
	assert_bool(companion.is_valid()).is_true()
	return companion


func _assert_tier(tier: Dictionary, level: int, multiplier: String, previous: int) -> void:
	assert_int(tier["level"]).is_equal(level)
	assert_str(tier["multiplier"]).is_equal(multiplier)
	assert_int(tier["previous"]).is_equal(previous)


func test_next_tier_at_level_0_is_the_first_with_no_previous() -> void:
	_assert_tier(_companion(REAL_TIERS).next_tier_from(0), 10, "2", 0)


func test_next_tier_just_before_a_tier_is_that_tier() -> void:
	_assert_tier(_companion(REAL_TIERS).next_tier_from(9), 10, "2", 0)


func test_next_tier_on_a_tier_is_the_following_one() -> void:
	_assert_tier(_companion(REAL_TIERS).next_tier_from(10), 25, "2", 10)


func test_next_tier_between_two_tiers_reads_both_around() -> void:
	_assert_tier(_companion(REAL_TIERS).next_tier_from(24), 25, "2", 10)


func test_next_tier_before_the_last_reads_its_multiplier() -> void:
	_assert_tier(_companion(REAL_TIERS).next_tier_from(199), 200, "3", 150)


func test_next_tier_on_the_last_tier_is_none() -> void:
	_assert_tier(_companion(REAL_TIERS).next_tier_from(200), 0, "", 200)


func test_next_tier_past_the_last_tier_is_none() -> void:
	_assert_tier(_companion(REAL_TIERS).next_tier_from(250), 0, "", 200)


func test_next_tier_without_any_tier_is_none_and_no_previous() -> void:
	_assert_tier(_companion([]).next_tier_from(5), 0, "", 0)


func test_next_tier_follows_the_data_not_a_rhythm() -> void:
	var odd: Array = [{"level": 3, "damage_multiplier": "2"}, {"level": 7, "damage_multiplier": "4"}]
	_assert_tier(_companion(odd).next_tier_from(3), 7, "4", 3)


func test_multiplier_with_decimals_uses_the_french_comma() -> void:
	var tiers: Array = [{"level": 5, "damage_multiplier": "1.5"}]
	_assert_tier(_companion(tiers).next_tier_from(0), 5, "1,5", 0)


func test_multiplier_below_one_keeps_its_leading_zero() -> void:
	var tiers: Array = [{"level": 5, "damage_multiplier": "0.25"}]
	_assert_tier(_companion(tiers).next_tier_from(0), 5, "0,25", 0)


func test_multiplier_drops_its_trailing_zeros() -> void:
	var tiers: Array = [{"level": 5, "damage_multiplier": "2.50"}, {"level": 6, "damage_multiplier": "3.0"}]
	var companion: Companion = _companion(tiers)
	_assert_tier(companion.next_tier_from(0), 5, "2,5", 0)
	_assert_tier(companion.next_tier_from(5), 6, "3", 5)


func test_kept_sum_is_the_same_exact_value_on_a_second_call() -> void:
	# Arrange
	var companion: Companion = _companion(REAL_TIERS)
	var expected: BigNumber = BigNumber.new()
	for level in range(151, 201):
		expected = expected.add(companion.cost_of_level(level))

	# Act
	var first: BigNumber = companion.cost_of_levels_from(151, 50)
	var second: BigNumber = companion.cost_of_levels_from(151, 50)

	# Assert
	assert_int(first.compare(expected)).is_equal(0)
	assert_int(second.compare(expected)).is_equal(0)


func test_kept_sum_never_answers_for_another_level_or_count() -> void:
	# Arrange
	var companion: Companion = _companion(REAL_TIERS)
	companion.cost_of_levels_from(11, 15)

	# Act
	var other_count: BigNumber = companion.cost_of_levels_from(11, 14)
	var other_level: BigNumber = companion.cost_of_levels_from(12, 14)

	# Assert
	var fresh: Companion = _companion(REAL_TIERS)
	assert_int(other_count.compare(fresh.cost_of_levels_from(11, 14))).is_equal(0)
	assert_int(other_level.compare(_companion(REAL_TIERS).cost_of_levels_from(12, 14))).is_equal(0)
