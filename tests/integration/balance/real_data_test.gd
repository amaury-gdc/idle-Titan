extends GdUnitTestSuite
## Loads the real files of assets/data and pins today's formulas, so a change of balance shows up
## as a failed test and not as a silent shift. When a story retunes a value on purpose, its
## expected number here changes with it.
## Story: production/epics/idle-titans/story-014-simulator-measures.md.

const COMPANION_COUNT: int = 8
const SCOUT_LEVEL: int = 10
const SCOUT_DPS_AT_LEVEL: String = "20"
## 1 + floor(20 * 0.1).
const CLICK_WITH_SCOUT: String = "3"
const BOSS_STAGE: int = 10
const BOSS_HP: String = "5520"
## Exact floors of 22 * 1.325^(stage - 1), computed apart.
const HP_BY_STAGE: Dictionary = {1: "22", 10: "276", 50: "21428941", 100: "27656335170372", 120: "7693291624962307"}
## Exact floors of 10 * 1.08^(level - 1), computed apart.
const SCOUT_COST_BY_LEVEL: Dictionary = {1: "10", 2: "10", 100: "20368"}

var _curves: Variant
var _combat: Combat


func before_test() -> void:
	_curves = DataLoader.load_json("res://assets/data/core_curves.json")
	_combat = Combat.from_data(_curves, DataLoader.load_json("res://assets/data/companions_roster.json"))


func _boss() -> BossFight:
	return BossFight.from_data(DataLoader.load_json("res://assets/data/boss_curves.json"))


func test_curves_and_roster_are_valid() -> void:
	assert_str(_combat.get_error()).is_empty()
	assert_int(_combat.companions().size()).is_equal(COMPANION_COUNT)


func test_bosses_are_valid() -> void:
	assert_str(_boss().get_error()).is_empty()


func test_offline_income_is_valid() -> void:
	assert_str(OfflineIncome.from_data(_curves, _combat).get_error()).is_empty()


func test_talents_are_valid() -> void:
	var tree: TalentTree = TalentTree.from_data(DataLoader.load_json("res://assets/data/talents.json"), PermanentState.new(), GameState.new())
	assert_str(tree.get_error()).is_empty()


func test_skills_are_valid() -> void:
	var state: GameState = GameState.new()
	var floors: FloorManager = FloorManager.new(state, _combat, _boss(), PermanentState.new())
	var skills: SkillManager = SkillManager.from_data(DataLoader.load_json("res://assets/data/skills.json"), state, _combat, floors)
	assert_str(skills.get_error()).is_empty()


func test_items_are_valid() -> void:
	var inventory: Inventory = Inventory.from_data(DataLoader.load_json("res://assets/data/items.json"), PermanentState.new(), GameState.new(), _combat, func() -> float: return 0.0)
	assert_str(inventory.get_error()).is_empty()


func test_enemy_hp_is_pinned() -> void:
	for stage: int in HP_BY_STAGE:
		assert_str(_combat.enemy_max_hp(stage).to_decimal_string()).is_equal(HP_BY_STAGE[stage])


func test_boss_hp_is_pinned() -> void:
	assert_str(_boss().boss_max_hp(_combat.enemy_max_hp(BOSS_STAGE)).to_decimal_string()).is_equal(BOSS_HP)


func test_scout_costs_are_pinned() -> void:
	var scout: Companion = _combat.companion("scout")
	for level: int in SCOUT_COST_BY_LEVEL:
		assert_str(scout.cost_of_level(level).to_decimal_string()).is_equal(SCOUT_COST_BY_LEVEL[level])


func test_scout_damage_includes_its_first_tier() -> void:
	assert_str(_combat.companion("scout").damage_per_second_at_level(SCOUT_LEVEL).to_decimal_string()).is_equal(SCOUT_DPS_AT_LEVEL)


func test_click_adds_its_share_of_the_companions_power() -> void:
	assert_str(_combat.click_damage({"scout": SCOUT_LEVEL}).to_decimal_string()).is_equal(CLICK_WITH_SCOUT)
