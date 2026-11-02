extends GdUnitTestSuite
## Unit tests for the enemy HP segments of Combat ("enemy_hp_segments" in core_curves.json).
## Pinned numbers are exact floors computed apart with rational arithmetic (not with Combat).
## Story: production/epics/idle-titans/story-015-hp-segments-click-share.md
## Design: design/economy-rework.md "PV par paliers".

const BASE: String = "10"
## Test segments, not the game's: flat 10 HP up to stage 100, then 1.5, 1.2 from 150, 2 from 190, 1.1 from 205.
## Anchors A_k: 10, 10, 6376215002, 9371579521197, 307087917750583296.
const HP_BY_STAGE: Dictionary = {
	1: "10", 2: "10", 99: "10", 100: "10",
	101: "15", 102: "22",
	149: "4250810001", 150: "6376215002", 151: "7651458002",
	189: "7809649600997", 190: "9371579521197", 191: "18743159042394",
	200: "9596497429705728", 204: "153543958875291648", 205: "307087917750583296", 206: "337796709525641625",
	210: "494568162416491904", 300: "2627651830019071307830",
}
## Exact floors of 22 * 1.325^(stage - 1), the former scalar curve of the game files.
const SCALAR_HP_BY_STAGE: Dictionary = {1: "22", 10: "276", 50: "21428941", 100: "27656335170372", 120: "7693291624962307"}


func _segments() -> Array:
	return [
		{"from_stage": 1, "growth": "1"},
		{"from_stage": 100, "growth": "1.5"},
		{"from_stage": 150, "growth": "1.2"},
		{"from_stage": 190, "growth": "2"},
		{"from_stage": 205, "growth": "1.1"},
	]


func _curves(hp_keys: Dictionary, hp_base: String = BASE) -> Dictionary:
	var curves: Dictionary = {
		"schema_version": Combat.SUPPORTED_CURVES_SCHEMA,
		"enemy_hp_base": hp_base,
		"gold_per_kill_base": "1",
		"gold_per_kill_growth": "1",
		"click_damage_base": "1",
		"click_companion_power_factor": "0",
	}
	curves.merge(hp_keys)
	return curves


func _combat(hp_keys: Dictionary, hp_base: String = BASE) -> Combat:
	return Combat.from_data(_curves(hp_keys, hp_base), {"schema_version": 2, "companions": []})


func _segmented() -> Combat:
	return _combat({"enemy_hp_segments": _segments()})


func _hp(combat: Combat, stage: int) -> String:
	return combat.enemy_max_hp(stage).to_decimal_string()


func _boss() -> BossFight:
	return BossFight.from_data({
		"schema_version": BossFight.SUPPORTED_SCHEMA,
		"boss_every_stages": 10,
		"timer_seconds": 30,
		"boss_hp_multiplier": "20",
		"boss_gold_base": "15",
		"boss_gold_growth": "1.30",
		"auto_challenge_margin": "1.2",
	})


# --- Former behavior ---

func test_scalar_growth_still_gives_the_former_curve() -> void:
	# Arrange
	var combat: Combat = _combat({"enemy_hp_growth": "1.325"}, "22")

	# Act / Assert
	assert_str(combat.get_error()).is_empty()
	for stage: int in SCALAR_HP_BY_STAGE:
		assert_str(_hp(combat, stage)).is_equal(SCALAR_HP_BY_STAGE[stage])


func test_single_segment_gives_the_same_hp_as_the_scalar() -> void:
	# Arrange
	var combat: Combat = _combat({"enemy_hp_segments": [{"from_stage": 1, "growth": "1.325"}]}, "22")

	# Act / Assert
	assert_str(combat.get_error()).is_empty()
	for stage: int in SCALAR_HP_BY_STAGE:
		assert_str(_hp(combat, stage)).is_equal(SCALAR_HP_BY_STAGE[stage])


func test_from_stage_read_as_a_json_float_is_accepted() -> void:
	# Arrange: DataLoader returns every JSON number as a float
	var combat: Combat = _combat({"enemy_hp_segments": [
		{"from_stage": 1.0, "growth": "1"},
		{"from_stage": 100.0, "growth": "1.5"},
	]})

	# Act / Assert
	assert_str(combat.get_error()).is_empty()
	assert_str(_hp(combat, 101)).is_equal("15")


# --- Junctions ---

func test_junction_100_101_changes_rate_one_step_after_from_stage() -> void:
	# Arrange
	var combat: Combat = _segmented()

	# Act / Assert: stage 100 still reached at the flat rate, stage 101 is the first step at 1.5
	assert_str(_hp(combat, 99)).is_equal("10")
	assert_str(_hp(combat, 100)).is_equal("10")
	assert_str(_hp(combat, 101)).is_equal("15")
	assert_str(_hp(combat, 102)).is_equal("22")


func test_junction_150_151_changes_rate_one_step_after_from_stage() -> void:
	# Arrange
	var combat: Combat = _segmented()

	# Act / Assert
	assert_str(_hp(combat, 149)).is_equal("4250810001")
	assert_str(_hp(combat, 150)).is_equal("6376215002")
	assert_str(_hp(combat, 151)).is_equal("7651458002")


func test_junction_190_191_changes_rate_one_step_after_from_stage() -> void:
	# Arrange
	var combat: Combat = _segmented()

	# Act / Assert
	assert_str(_hp(combat, 189)).is_equal("7809649600997")
	assert_str(_hp(combat, 190)).is_equal("9371579521197")
	assert_str(_hp(combat, 191)).is_equal("18743159042394")


func test_hp_does_not_drop_at_any_junction() -> void:
	# Arrange
	var combat: Combat = _segmented()

	# Act / Assert: HP(from_stage) is what the previous segment gives at that stage
	for junction: int in [100, 150, 190, 205]:
		assert_str(_hp(combat, junction)).is_equal(HP_BY_STAGE[junction])
		assert_bool(combat.enemy_max_hp(junction).compare(combat.enemy_max_hp(junction - 1)) >= 0).is_true()


func test_anchors_are_floored_once_not_carried_unrounded() -> void:
	# Arrange: 10 * 1.5^50 * 1.2^40 = 9371579521404.x without flooring A_3, 9371579521197 with it.
	var combat: Combat = _segmented()

	# Act
	var hp: String = _hp(combat, 190)

	# Assert
	assert_str(hp).is_equal("9371579521197")
	assert_str(hp).is_not_equal("9371579521404")


func test_hp_matches_every_pinned_stage() -> void:
	# Arrange
	var combat: Combat = _segmented()

	# Act / Assert
	for stage: int in HP_BY_STAGE:
		assert_str(_hp(combat, stage)).is_equal(HP_BY_STAGE[stage])


func test_repeated_queries_give_the_same_hp_in_any_order() -> void:
	# Arrange: the anchors are computed at load, so a query must not depend on the previous one
	var combat: Combat = _segmented()
	var first: String = _hp(combat, 300)

	# Act
	_hp(combat, 1)
	_hp(combat, 150)

	# Assert
	assert_str(_hp(combat, 300)).is_equal(first)
	assert_str(_hp(combat, 151)).is_equal("7651458002")


# --- Bosses ---

func test_boss_hp_is_twenty_times_enemy_hp_at_stages_200_210_300() -> void:
	# Arrange: 200 is in the 190 segment, 210 and 300 in the 205 segment
	var combat: Combat = _segmented()
	var boss: BossFight = _boss()
	assert_str(boss.get_error()).is_empty()

	# Act / Assert
	for stage: int in [200, 210, 300]:
		assert_bool(boss.is_boss_stage(stage)).is_true()
		var enemy_hp: BigNumber = combat.enemy_max_hp(stage)
		assert_str(enemy_hp.to_decimal_string()).is_equal(HP_BY_STAGE[stage])
		assert_str(boss.boss_max_hp(enemy_hp).to_decimal_string()).is_equal(enemy_hp.multiply(BigNumber.from_int(20)).to_decimal_string())


func test_boss_hp_at_stage_300_is_pinned() -> void:
	# Arrange
	var combat: Combat = _segmented()

	# Act
	var hp: BigNumber = _boss().boss_max_hp(combat.enemy_max_hp(300))

	# Assert: 20 * 2627651830019071307830
	assert_str(hp.to_decimal_string()).is_equal("52553036600381426156600")


# --- Never zero ---

func test_hp_is_at_least_one_when_a_segment_shrinks_it_to_zero() -> void:
	# Arrange: 5 * 0.1 floors to 0 at stage 2
	var combat: Combat = _combat({"enemy_hp_segments": [{"from_stage": 1, "growth": "0.1"}]}, "5")

	# Act / Assert
	assert_str(_hp(combat, 1)).is_equal("5")
	assert_str(_hp(combat, 2)).is_equal("1")
	assert_str(_hp(combat, 50)).is_equal("1")


func test_hp_is_at_least_one_when_an_anchor_is_zero() -> void:
	# Arrange: the anchor of the second segment is floor(5 * 0.1^2) = 0
	var combat: Combat = _combat({"enemy_hp_segments": [
		{"from_stage": 1, "growth": "0.1"},
		{"from_stage": 3, "growth": "10"},
	]}, "5")

	# Act / Assert
	assert_str(combat.get_error()).is_empty()
	assert_str(_hp(combat, 3)).is_equal("1")
	assert_str(_hp(combat, 10)).is_equal("1")


func test_hp_is_at_least_one_with_a_zero_base() -> void:
	# Arrange
	var combat: Combat = _combat({"enemy_hp_segments": _segments()}, "0")

	# Act / Assert
	assert_str(_hp(combat, 1)).is_equal("1")
	assert_str(_hp(combat, 300)).is_equal("1")


func test_stage_below_one_reads_as_stage_one() -> void:
	# Arrange
	var combat: Combat = _segmented()

	# Act / Assert
	assert_str(_hp(combat, 0)).is_equal("10")
	assert_str(_hp(combat, -5)).is_equal("10")


# --- Refused data ---

func test_empty_segments_are_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat({"enemy_hp_segments": []})

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).is_equal("core_curves.json: 'enemy_hp_segments' must be a non-empty array of {from_stage, growth}")


func test_segments_that_are_not_an_array_are_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat({"enemy_hp_segments": "1.3"})

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).contains("'enemy_hp_segments' must be a non-empty array")


func test_first_segment_not_at_stage_one_is_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat({"enemy_hp_segments": [{"from_stage": 2, "growth": "1.3"}]})

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).is_equal("core_curves.json: the first 'enemy_hp_segments' entry must start at from_stage 1")


func test_segments_in_decreasing_order_are_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat({"enemy_hp_segments": [
		{"from_stage": 1, "growth": "1.1"},
		{"from_stage": 50, "growth": "1.2"},
		{"from_stage": 40, "growth": "1.3"},
	]})

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).is_equal("core_curves.json: 'enemy_hp_segments' from_stage values must be strictly increasing")


func test_segments_with_a_repeated_from_stage_are_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat({"enemy_hp_segments": [
		{"from_stage": 1, "growth": "1.1"},
		{"from_stage": 50, "growth": "1.2"},
		{"from_stage": 50, "growth": "1.3"},
	]})

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).contains("strictly increasing")


func test_two_segments_from_stage_one_are_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat({"enemy_hp_segments": [
		{"from_stage": 1, "growth": "1.1"},
		{"from_stage": 1, "growth": "1.2"},
	]})

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).contains("strictly increasing")


func test_invalid_growth_text_is_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat({"enemy_hp_segments": [
		{"from_stage": 1, "growth": "1.3"},
		{"from_stage": 50, "growth": "1,4"},
	]})

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).is_equal("core_curves.json: 'enemy_hp_segments' growth must be a decimal string such as \"1.3\"")


func test_growth_given_as_a_number_is_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat({"enemy_hp_segments": [{"from_stage": 1, "growth": 1.3}]})

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).contains("growth must be a decimal string")


func test_missing_growth_is_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat({"enemy_hp_segments": [{"from_stage": 1}]})

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).contains("growth must be a decimal string")


func test_non_integer_from_stage_is_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat({"enemy_hp_segments": [
		{"from_stage": 1, "growth": "1.3"},
		{"from_stage": 50.5, "growth": "1.4"},
	]})

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).is_equal("core_curves.json: 'enemy_hp_segments' from_stage must be an integer")


func test_from_stage_above_the_limit_is_refused() -> void:
	# Arrange / Act: a huge from_stage would freeze the load while its anchor is computed
	var combat: Combat = _combat({"enemy_hp_segments": [
		{"from_stage": 1, "growth": "1.3"},
		{"from_stage": Combat.MAX_SEGMENT_FROM_STAGE + 1, "growth": "1.4"},
	]})

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).is_equal("core_curves.json: 'enemy_hp_segments' from_stage must not exceed %d" % Combat.MAX_SEGMENT_FROM_STAGE)


func test_from_stage_at_the_limit_is_accepted() -> void:
	# Arrange / Act: growth "1" keeps the anchor small
	var combat: Combat = _combat({"enemy_hp_segments": [
		{"from_stage": 1, "growth": "1"},
		{"from_stage": Combat.MAX_SEGMENT_FROM_STAGE, "growth": "2"},
	]})

	# Assert
	assert_str(combat.get_error()).is_empty()
	assert_str(_hp(combat, Combat.MAX_SEGMENT_FROM_STAGE + 1)).is_equal("20")


func test_segment_that_is_not_an_object_is_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat({"enemy_hp_segments": ["1.3"]})

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).contains("each 'enemy_hp_segments' entry must be an object")


func test_scalar_and_segments_together_are_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat({"enemy_hp_growth": "1.3", "enemy_hp_segments": _segments()})

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).is_equal("core_curves.json: 'enemy_hp_growth' and 'enemy_hp_segments' cannot both be set, keep one")


func test_neither_scalar_nor_segments_is_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat({})

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).is_equal("core_curves.json: 'enemy_hp_growth' or 'enemy_hp_segments' is required")


func test_refused_segments_leave_a_usable_one_hp_curve() -> void:
	# Arrange: the main screen shows the error, but nothing must crash before it does
	var combat: Combat = _combat({"enemy_hp_segments": []})

	# Act / Assert
	assert_str(_hp(combat, 7)).is_equal("1")
