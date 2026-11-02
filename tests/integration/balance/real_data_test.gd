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
	assert_str(_combat.companion("scout").damage_per_second_at_level(SCOUT_LEVEL, 0, 0).to_decimal_string()).is_equal(SCOUT_DPS_AT_LEVEL)


## Stories 016 and 017: the awakening block of design/economy-rework.md "Éveil", which the real file
## has since story 017 and which this test pins, and the bounds of "Gardien 1000 / Dragon 100".
const AWAKENING_BLOCK: Dictionary = {
	"thresholds": [200, 300, 400, 500, 600, 700, 800, 900, 1000],
	"self_multiplier": "3.4",
	"squad_multiplier": "2.10",
	"squad_until_threshold": 600,
	"cost_level_multiplier": "10",
}
const GUARDIAN_LEVEL: int = 1000
const GUARDIAN_AWAKENINGS: int = 9
const DRAGON_LEVEL: int = 100
## The ratio must stay between 1.5 and 3, written as fractions: 3/2 and 3/1.
const RATIO_MIN_NUMERATOR: int = 3
const RATIO_MIN_DENOMINATOR: int = 2
const RATIO_MAX: int = 3


func test_real_roster_holds_the_awakening_block_of_the_design() -> void:
	# Arrange
	var roster: Dictionary = DataLoader.load_json("res://assets/data/companions_roster.json")

	# Act
	var block: Dictionary = roster.get("awakening", {})
	var rules: AwakeningRules = AwakeningRules.from_block(roster.get("awakening"))

	# Assert: the file and the design agree, key by key (JSON reads every number as a float), and the
	# rules read it
	assert_array(block.keys()).contains_exactly_in_any_order(AWAKENING_BLOCK.keys())
	assert_array(rules.thresholds()).is_equal(AWAKENING_BLOCK["thresholds"])
	for key: String in ["self_multiplier", "squad_multiplier", "cost_level_multiplier"]:
		assert_str(block[key]).is_equal(AWAKENING_BLOCK[key])
	assert_int(int(block["squad_until_threshold"])).is_equal(AWAKENING_BLOCK["squad_until_threshold"])
	assert_bool(rules.is_valid()).is_true()
	assert_bool(rules.is_enabled()).is_true()
	assert_int(rules.threshold_count()).is_equal(GUARDIAN_AWAKENINGS)
	assert_int(rules.squad_threshold_count()).is_equal(5)


func test_guardian_1000_awakened_stays_between_1_5_and_3_dragons_100() -> void:
	# Arrange: the real roster, awakening block included; the guardian's nine awakenings are the
	# squad's (5 counted), and both share them, the dragon having none of its own
	var combat: Combat = _combat
	assert_str(combat.get_error()).is_empty()
	var awakenings: Dictionary = {"guardian": GUARDIAN_AWAKENINGS}

	# Act
	var guardian: BigNumber = combat.companion_power({"guardian": GUARDIAN_LEVEL}, awakenings)
	var dragon: BigNumber = combat.companion_power({"dragon": DRAGON_LEVEL}, awakenings)

	# Assert: about x2.34 (3.4^9 * 60000 * 1000 * 216 / (140e9 * 100 * 24))
	assert_int(combat.squad_awakenings(awakenings)).is_equal(5)
	assert_int(guardian.multiply(BigNumber.from_int(RATIO_MIN_DENOMINATOR)).compare(dragon.multiply(BigNumber.from_int(RATIO_MIN_NUMERATOR)))).is_greater_equal(0)
	assert_int(guardian.compare(dragon.multiply(BigNumber.from_int(RATIO_MAX)))).is_less_equal(0)


func test_click_adds_its_share_of_the_companions_power() -> void:
	assert_str(_combat.click_damage({"scout": SCOUT_LEVEL}, {}).to_decimal_string()).is_equal(CLICK_WITH_SCOUT)
