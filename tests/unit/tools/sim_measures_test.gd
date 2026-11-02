extends GdUnitTestSuite
## Unit tests for the helpers of the simulator: milestones, click share and the ratio buyer.
## Story: production/epics/idle-titans/story-014-simulator-measures.md.

const FALLBACK: Array[int] = [50, 100]
const FIRST_STAGES: Array[int] = [10, 11]
const CHEAP_ROW: Dictionary = {"id": "cheap", "name": "A", "base_cost": "10", "base_damage": "1", "cost_growth": "1.08", "attack_interval_seconds": 1.0, "tiers": []}
const STRONG_ROW: Dictionary = {"id": "strong", "name": "B", "base_cost": "100", "base_damage": "50", "cost_growth": "1.08", "attack_interval_seconds": 1.0, "tiers": []}

var _state: GameState


func _manager() -> CompanionManager:
	_state = GameState.new()
	var curves: Dictionary = {
		"schema_version": Combat.SUPPORTED_CURVES_SCHEMA,
		"enemy_hp_base": "1000000", "enemy_hp_growth": "1", "gold_per_kill_base": "1", "gold_per_kill_growth": "1",
		"click_damage_base": "1", "click_companion_power_factor": "0",
		"autosave_interval_seconds": 5, "offline_efficiency": "0.1", "offline_max_hours": 12, "offline_min_seconds": 60,
	}
	var combat: Combat = Combat.from_data(curves, {"schema_version": Combat.SUPPORTED_ROSTER_SCHEMA, "companions": [CHEAP_ROW, STRONG_ROW]})
	assert_str(combat.get_error()).is_empty()
	var boss: BossFight = BossFight.from_data({"schema_version": BossFight.SUPPORTED_SCHEMA, "boss_every_stages": 10, "timer_seconds": 30, "boss_hp_multiplier": "2", "boss_gold_base": "1", "boss_gold_growth": "1", "auto_challenge_margin": "1"})
	assert_str(boss.get_error()).is_empty()
	return CompanionManager.new(_state, combat, FloorManager.new(_state, combat, boss, PermanentState.new()))


func test_milestones_empty_text_uses_the_fallback() -> void:
	assert_array(SimMeasures.merged_milestones("", FALLBACK, FIRST_STAGES)).is_equal([10, 11, 50, 100])


func test_milestones_text_replaces_the_fallback_and_keeps_the_first_stages() -> void:
	assert_array(SimMeasures.merged_milestones("200,60", FALLBACK, FIRST_STAGES)).is_equal([10, 11, 60, 200])


func test_milestones_are_sorted_without_duplicates() -> void:
	assert_array(SimMeasures.merged_milestones("11,5,5", FALLBACK, FIRST_STAGES)).is_equal([5, 10, 11])


func test_milestones_invalid_entry_gives_an_empty_list() -> void:
	for text: String in ["abc", "10,,20", "0", "-5", "1.5"]:
		assert_array(SimMeasures.merged_milestones(text, FALLBACK, FIRST_STAGES)).is_empty()


func test_click_share_is_the_part_of_the_clicks() -> void:
	assert_float(SimMeasures.click_share(1.0, 3.0)).is_equal(0.25)


func test_click_share_without_damage_is_zero() -> void:
	assert_float(SimMeasures.click_share(0.0, 0.0)).is_equal(0.0)


func test_known_buyers() -> void:
	assert_bool(SimMeasures.is_known_buyer("cheapest")).is_true()
	assert_bool(SimMeasures.is_known_buyer("ratio")).is_true()
	assert_bool(SimMeasures.is_known_buyer("richest")).is_false()


func test_best_ratio_is_empty_when_nothing_is_affordable() -> void:
	var manager: CompanionManager = _manager()
	assert_str(SimMeasures.best_ratio_id(manager)).is_empty()


func test_best_ratio_ignores_the_better_level_that_is_not_affordable() -> void:
	var manager: CompanionManager = _manager()
	_state.gold = BigNumber.from_int(10)
	assert_str(SimMeasures.best_ratio_id(manager)).is_equal("cheap")


func test_best_ratio_takes_the_most_damage_per_gold() -> void:
	var manager: CompanionManager = _manager()
	_state.gold = BigNumber.from_int(100)
	assert_str(SimMeasures.best_ratio_id(manager)).is_equal("strong")
