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


# --skills=3 (story 023): the player who challenges the boss with the skills ready.

const SKILLS_DATA: Dictionary = {"schema_version": 1, "skills": [
	{"id": "big_hit", "name": "Gros coup", "effect": "burst", "dps_seconds": "6", "cooldown_seconds": 60},
	{"id": "damage_buff", "name": "Frénésie", "effect": "damage_multiplier", "multiplier": "1.5", "duration_seconds": 15, "cooldown_seconds": 90},
	{"id": "gold_bonus", "name": "Bonus d'or", "effect": "gold_multiplier", "multiplier": "1.5", "duration_seconds": 20, "cooldown_seconds": 120},
]}
const RETRY_PERCENT: int = 10


## Skills on the fixture of [method _manager]; with [param locked_by_talents] the real talent tree
## is there and nothing is bought, so the skills behind a node are locked as in the game.
func _skills(data: Dictionary, locked_by_talents: bool = false) -> SkillManager:
	var manager: CompanionManager = _manager()
	var curves: Variant = DataLoader.load_json("res://assets/data/core_curves.json")
	var combat: Combat = Combat.from_data(curves, DataLoader.load_json("res://assets/data/companions_roster.json"))
	var floors: FloorManager = FloorManager.new(_state, combat)
	var hub: ModifierHub = null
	if locked_by_talents:
		var tree: TalentTree = SimMeasures.simulated_tree(DataLoader.load_json("res://assets/data/talents.json"), PermanentState.new(), _state)
		assert_str(tree.get_error()).is_empty()
		hub = ModifierHub.new(floors, OfflineIncome.from_data(curves, combat), tree, null)
	var skills: SkillManager = SkillManager.from_data(data, _state, combat, floors, hub)
	assert_str(skills.get_error()).is_empty()
	assert_object(manager).is_not_null()
	return skills


func test_boss_skills_ready_when_burst_and_buff_are_ready() -> void:
	assert_bool(SimMeasures.boss_skills_ready(_skills(SKILLS_DATA))).is_true()


func test_boss_skills_not_ready_while_one_of_them_recharges() -> void:
	# Arrange
	var skills: SkillManager = _skills(SKILLS_DATA)

	# Act
	assert_bool(skills.activate("big_hit")).is_true()

	# Assert
	assert_bool(SimMeasures.boss_skills_ready(skills)).is_false()


func test_boss_skills_ready_ignores_the_gold_bonus() -> void:
	# Arrange
	var skills: SkillManager = _skills(SKILLS_DATA)

	# Act: the gold bonus is used as soon as it is ready, never kept for a boss
	assert_bool(skills.activate("gold_bonus")).is_true()

	# Assert
	assert_bool(SimMeasures.boss_skills_ready(skills)).is_true()


func test_boss_skills_ready_ignores_a_skill_the_talents_lock() -> void:
	# Arrange: no node bought, so the damage buff is locked and only the burst counts
	var skills: SkillManager = _skills(SKILLS_DATA, true)
	assert_bool(skills.is_unlocked("damage_buff")).is_false()
	assert_bool(skills.is_unlocked("big_hit")).is_true()

	# Act and assert
	assert_bool(SimMeasures.boss_skills_ready(skills)).is_true()
	assert_bool(skills.activate("big_hit")).is_true()
	assert_bool(SimMeasures.boss_skills_ready(skills)).is_false()


func test_grown_enough_without_a_failed_attempt() -> void:
	assert_bool(SimMeasures.grown_enough(BigNumber.from_int(1), null, RETRY_PERCENT)).is_true()


func test_grown_enough_only_from_the_growth_asked() -> void:
	# Arrange
	var at_failure: BigNumber = BigNumber.from_int(100)

	# Act and assert: +9% is not enough, +10% is
	assert_bool(SimMeasures.grown_enough(BigNumber.from_int(109), at_failure, RETRY_PERCENT)).is_false()
	assert_bool(SimMeasures.grown_enough(BigNumber.from_int(110), at_failure, RETRY_PERCENT)).is_true()
