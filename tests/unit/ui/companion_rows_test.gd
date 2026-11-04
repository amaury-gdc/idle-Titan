extends GdUnitTestSuite
## Unit tests for the companion cards of story 019b (lot 6): the portrait in the colour of the roster,
## the name and "Niv. N" in blue, "DPS · part %", the sizes of the card and of the button, the colour
## of the button text in each state, and when the button names its count ("×N · ").
## The gain itself: companion_gain_test.gd. Story: production/epics/idle-titans/story-019b-mobile-ui-refonte.md

const PANEL_SCENE: String = "res://src/ui/companion_panel.tscn"
const THEME_PATH: String = "res://src/ui/main_theme.tres"
const IDS: Array[String] = ["scout", "archer", "mage"]
const SCOUT_COLOR: String = "#8bc34a"
const PANE: Vector2 = Vector2(390, 400)

var _state: GameState
var _companions: CompanionManager
var _panel: CompanionPanel


func before_test() -> void:
	var curves: Dictionary = {
		"schema_version": Combat.SUPPORTED_CURVES_SCHEMA,
		"enemy_hp_base": "1000",
		"enemy_hp_growth": "1",
		"gold_per_kill_base": "1",
		"gold_per_kill_growth": "1",
		"click_damage_base": "1",
		"click_companion_power_factor": "0",
		"cost_growth": "1.08",
		"offline_efficiency": "0.5",
		"offline_max_hours": 12,
		"offline_min_seconds": 60,
	}
	var companions: Array = []
	for i in IDS.size():
		companions.append({"id": IDS[i], "name": IDS[i].capitalize(), "base_cost": "10", "base_damage": str(3 * (i + 1)),
				"cost_growth": "1.08", "attack_interval_seconds": 1.0, "tiers": [{"level": 10, "damage_multiplier": "2"}]})
	var roster: Dictionary = {"schema_version": 2, "companions": companions}
	var combat: Combat = Combat.from_data(curves, roster)
	_state = GameState.new()
	_companions = CompanionManager.new(_state, combat, FloorManager.new(_state, combat))
	_panel = auto_free((load(PANEL_SCENE) as PackedScene).instantiate())
	_panel.theme = load(THEME_PATH)
	add_child(_panel)
	_panel.size = PANE
	_panel.set_colors({"companions": [{"id": "scout", "color": SCOUT_COLOR}, {"id": "archer", "color": "not a colour"}]})
	_panel.setup(_companions, func() -> BigNumber: return _state.gold)


func _row(index: int = 0) -> Dictionary:
	return (_panel.get("_rows") as Array)[index]


func _at(levels: Dictionary, gold: BigNumber = BigNumber.new(), mode: BuyQuote.Mode = BuyQuote.Mode.ONE) -> void:
	_state.companion_levels = levels
	_state.gold = gold
	_panel.set_mode(mode)
	_panel.refresh()


func _plenty() -> BigNumber:
	return BigNumber.from_string("1" + "0".repeat(40))


# --- texts -----------------------------------------------------------------------------------

func test_card_names_the_companion_and_its_level_in_blue() -> void:
	_at({"scout": 12})
	assert_str((_row()["title"] as Label).text).is_equal("Scout")
	assert_str((_row()["level"] as Label).text).is_equal("Niv. 12")
	assert_bool((_row()["level"] as Label).get_theme_color("font_color").is_equal_approx(UiPalette.BLUE)).is_true()
	assert_int((_row()["title"] as Label).get_theme_font_size("font_size")).is_equal(CompanionPanel.FONT_SIZE_MAIN)


func test_damage_line_gives_the_dps_and_its_share_of_the_squad() -> void:
	# Arrange
	_at({"scout": 5, "archer": 5, "mage": 5})
	var squad: BigNumber = _companions.total_power()

	# Act
	var text: String = (_row(1)["damage"] as Label).text

	# Assert: archer deals 2 / 6 of the squad (3 + 6 + 9 per level)
	assert_str(text).is_equal(CompanionPanel.damage_text(_companions.damage_per_second("archer"), squad))
	assert_str(text).ends_with(CompanionPanel.keep_together("DPS · 33 %"))
	assert_int((_row(1)["damage"] as Label).get_theme_font_size("font_size")).is_equal(CompanionPanel.FONT_SIZE_SECONDARY)


func test_shares_add_up_to_100_within_rounding() -> void:
	_at({"scout": 7, "archer": 3, "mage": 11})
	var total: int = 0
	for i in IDS.size():
		var words: PackedStringArray = (_row(i)["damage"] as Label).text.split(CompanionPanel.NO_BREAK_SPACE)
		total += int(words[-2])
	assert_int(total).is_between(99, 101)


func test_companion_not_bought_reads_0_dps_and_0_percent() -> void:
	_at({"archer": 3})
	assert_str((_row()["damage"] as Label).text).is_equal(CompanionPanel.keep_together("0 DPS · 0 %"))


func test_level_0_button_reads_acheter_over_the_cost() -> void:
	_at({}, _plenty())
	assert_array(_panel.row_lines(0)).is_equal(PackedStringArray(["Acheter", CompanionPanel.keep_together(_companions.next_cost("scout").format())]))


# --- count ------------------------------------------------------------------------------------

func test_count_shows_only_when_the_mode_does_not_say_it() -> void:
	# x1 and x10 buy their own count: nothing; Max and Palier always name it
	_at({"scout": 1}, _plenty(), BuyQuote.Mode.ONE)
	assert_str(_panel.row_lines(0)[1]).starts_with("+")
	_at({"scout": 1}, _plenty(), BuyQuote.Mode.TEN)
	assert_str(_panel.row_lines(0)[1]).starts_with("+")
	_at({"scout": 1}, _plenty(), BuyQuote.Mode.TIER)
	assert_str(_panel.row_lines(0)[1]).starts_with(CompanionPanel.keep_together("×9 ·") + " ")
	_at({"scout": 1}, _plenty(), BuyQuote.Mode.MAX)
	assert_str(_panel.row_lines(0)[1]).starts_with(CompanionPanel.keep_together("×%d ·" % (_row()["count"] as int)) + " ")


func test_count_prefix_follows_the_mode() -> void:
	# The count and its dot stay together; a plain space after them is where a long line may break.
	_panel.set_mode(BuyQuote.Mode.HUNDRED)
	assert_str(_panel.count_prefix(100)).is_empty()
	assert_str(_panel.count_prefix(37)).is_equal(CompanionPanel.keep_together("×37 ·") + " ")
	assert_str(_panel.count_prefix(0)).is_empty()


# --- colours and sizes -----------------------------------------------------------------------

func test_portrait_takes_the_colour_of_the_roster_or_a_default() -> void:
	assert_bool((_row(0)["portrait"] as MousePortrait).color.is_equal_approx(Color(SCOUT_COLOR))).is_true()
	assert_bool((_row(1)["portrait"] as MousePortrait).color.is_equal_approx(CompanionPanel.DEFAULT_PORTRAIT_COLOR)).is_true()
	assert_bool((_row(2)["portrait"] as MousePortrait).color.is_equal_approx(CompanionPanel.DEFAULT_PORTRAIT_COLOR)).is_true()


func test_button_text_is_dark_on_yellow_and_grey_when_short_of_gold() -> void:
	_at({"scout": 1}, _plenty())
	assert_bool((_row()["cost"] as Label).get_theme_color("font_color").is_equal_approx(UiPalette.ON_YELLOW)).is_true()
	_at({"scout": 1})
	assert_bool((_row()["cost"] as Label).get_theme_color("font_color").is_equal_approx(UiPalette.TEXT_DISABLED)).is_true()
	assert_bool((_row()["gain"] as Label).get_theme_color("font_color").is_equal_approx(UiPalette.TEXT_DISABLED)).is_true()


func test_card_is_70_high_with_a_button_of_112_by_56_and_a_portrait_of_52() -> void:
	_at({"scout": 12})
	await await_idle_frame()
	assert_float((_row()["card"] as Control).size.y).is_equal(CompanionPanel.ROW_HEIGHT)
	assert_vector((_row()["button"] as Control).size).is_equal(CompanionPanel.BUTTON_SIZE)
	assert_vector((_row()["portrait"] as Control).size).is_equal(Vector2.ONE * CompanionPanel.PORTRAIT_SIZE)


func test_card_and_its_texts_pass_the_mouse_on_so_that_a_drag_scrolls() -> void:
	assert_int((_row()["card"] as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_int((_row()["button"] as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_int((_row()["portrait"] as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_gold_alone_only_changes_whether_the_button_can_be_paid() -> void:
	# Arrange: x1 at level 1, short of gold
	_at({"scout": 1})
	var lines: PackedStringArray = _panel.row_lines(0)
	var said: String = (_row()["button"] as Button).accessibility_name

	# Act
	_state.gold = _plenty()
	_panel.refresh()

	# Assert: same words, now payable
	assert_bool((_row()["button"] as Button).disabled).is_false()
	assert_array(_panel.row_lines(0)).is_equal(lines)
	assert_str((_row()["button"] as Button).accessibility_name).is_equal(said)
	assert_bool((_row()["cost"] as Label).get_theme_color("font_color").is_equal_approx(UiPalette.ON_YELLOW)).is_true()


func test_refresh_with_the_same_gold_sets_no_style_again() -> void:
	# A style set again reapplies the theme of the card: a redraw at the pace of the gold must not.
	_at({"scout": 1}, _plenty())
	var card: PanelContainer = _row()["card"]
	var style: StyleBox = card.get_theme_stylebox("panel")
	var changes: Array = []
	card.theme_changed.connect(func() -> void: changes.append(true))
	_panel.refresh()
	_panel.refresh()
	assert_object(card.get_theme_stylebox("panel")).is_same(style)
	assert_array(changes).is_empty()
