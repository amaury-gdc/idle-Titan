extends GdUnitTestSuite
## Loads the real files of assets/data and pins today's formulas, so a change of balance shows up
## as a failed test and not as a silent shift. When a story retunes a value on purpose, its
## expected number here changes with it.
## Story: production/epics/idle-titans/story-014-simulator-measures.md.

const COMPANION_COUNT: int = 8
const SCOUT_LEVEL: int = 10
const SCOUT_DPS_AT_LEVEL: String = "20"
## Story 023: the click takes a share of each companion, 1 + floor(20 * 0.4) with the scout's "0.4".
const CLICK_WITH_SCOUT: String = "9"
## Story 023: the shares of companions_roster.json, in roster order.
const CLICK_SHARES: Array[String] = ["0.4", "0.34", "0.3", "0.26", "0.22", "0.18", "0.13", "0.08"]
const BOSS_STAGE: int = 10
const BOSS_HP: String = "8500"
## Story 023: base 36, then the segments of core_curves.json (1.3159 from stage 1, 1.3424 from 100,
## and, unchanged since story 020, 1.38 from 150, 1.40 from 190, 1.27 from 205, 1.6 from 211; a
## growth applies to the steps that leave its from_stage). Stages 1 to 100 are exact floors
## computed apart. From 120 on the numbers are the game's own: BigNumber rounds the segmented
## product and drifts from the exact floor around the 13th digit, so these pin what the game
## computes, one stage per segment. From 150 on they are within 0.1% of the story 020 values.
const HP_BY_STAGE: Dictionary = {
	1: "36", 10: "425", 50: "25016350", 100: "22875379421342", 120: "8260515984040074",
	150: "56684651436830325503", 205: "3471758213699041330274587003",
	211: "14567056255208872674704307264", 220: "1001040483441829404590128738707",
}
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


## Story 023: the rebalance message of the real file, version 2, for records above the first boss.
const BALANCE_VERSION: int = 2
const BALANCE_NOTICE_ABOVE: int = 10
const BALANCE_TEXT: String = "L'équilibrage a changé : taper compte plus au début et certains monstres sont plus résistants. Tu ne perds rien."


func test_real_roster_holds_the_click_shares() -> void:
	# Arrange
	var roster: Dictionary = DataLoader.load_json("res://assets/data/companions_roster.json")

	# Act
	var shares: Array[String] = []
	for entry: Dictionary in roster["companions"]:
		shares.append(entry.get("click_share", ""))

	# Assert: the shares, and no leftover of the former flat factor in the curves
	assert_array(shares).is_equal(CLICK_SHARES)
	assert_bool((_curves as Dictionary).has("click_companion_power_factor")).is_false()


## Story 023: "Frappe alliée" multiplies the share of the companions in a click by 1.7 (50 before).
const CLICK_ALLY_PERCENT: int = 70


func test_real_talents_hold_the_click_ally_percent() -> void:
	# Arrange
	var talents: Dictionary = DataLoader.load_json("res://assets/data/talents.json")

	# Act
	var percents: Array[int] = []
	for node: Dictionary in talents["nodes"]:
		if node["id"] == "click_ally":
			for effect: Dictionary in node["effects"]:
				percents.append(int(effect["percent"]))

	# Assert: one node, one effect, on the click share
	assert_array(percents).is_equal([CLICK_ALLY_PERCENT])


func test_real_curves_keep_the_entry_of_the_first_balance_version() -> void:
	# Arrange
	var notices: Array = (_curves as Dictionary)["balance_notices"]

	# Act
	var first: Dictionary = notices[0]

	# Assert: story 020, records above stage 150
	assert_int(notices.size()).is_equal(BALANCE_VERSION)
	assert_int(int(first["version"])).is_equal(1)
	assert_int(int(first["min_stage"])).is_equal(150)
	assert_str(first["text"]).contains("étages élevés")


func test_real_curves_announce_the_rebalance_above_the_first_boss_only() -> void:
	# Arrange
	var at_limit: PermanentState = PermanentState.new()
	var above: PermanentState = PermanentState.new()

	# Act
	var silent: BalanceNotice = BalanceNotice.from_data(_curves, at_limit)
	var shown: BalanceNotice = BalanceNotice.from_data(_curves, above)

	# Assert
	assert_str(shown.get_error()).is_empty()
	assert_int(shown.version()).is_equal(BALANCE_VERSION)
	assert_str(shown.title()).is_equal("Équilibrage mis à jour")
	assert_str(shown.text()).is_equal(BALANCE_TEXT)
	assert_bool(silent.apply(BALANCE_NOTICE_ABOVE)).is_false()
	assert_bool(shown.apply(BALANCE_NOTICE_ABOVE + 1)).is_true()


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
