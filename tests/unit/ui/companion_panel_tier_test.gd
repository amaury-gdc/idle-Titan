extends GdUnitTestSuite
## Unit tests for the companion rows of story 013, on the real scene and the real theme: the tier
## line and its bar, the Palier segment, the button text and the border telling its state.
## Story: production/epics/idle-titans/story-013-companion-touch-ups.md, D3 of
## design/ux/main-screen-adaptive.md.

const PANEL_SCENE: String = "res://src/ui/companion_panel.tscn"
const THEME_PATH: String = "res://src/ui/main_theme.tres"
const ID: String = "scout"
const BARE_ID: String = "bare"
const TIERS: Array[Dictionary] = [
	{"level": 10, "damage_multiplier": "2"},
	{"level": 25, "damage_multiplier": "1.5"},
	{"level": 200, "damage_multiplier": "3"},
]
## Panel of the management zone at 320x568, in logical units.
const PANE_AT_320: Vector2 = Vector2(363, 204)
const VISIBLE_ROWS_AT_320: float = 2.0
const FONT_SIZE: int = 16

var _state: GameState
var _companions: CompanionManager
var _panel: CompanionPanel
var _requests: Array = []
var _modes: Array = []


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
	var roster: Dictionary = {
		"schema_version": 2,
		"companions": [_entry(ID, TIERS), _entry(BARE_ID, [])],
	}
	var combat: Combat = Combat.from_data(curves, roster)
	_state = GameState.new()
	_companions = CompanionManager.new(_state, combat, FloorManager.new(_state, combat))
	_panel = auto_free((load(PANEL_SCENE) as PackedScene).instantiate())
	_panel.theme = load(THEME_PATH)
	add_child(_panel)
	_requests = []
	_modes = []
	_panel.buy_requested.connect(func(id: String, count: int) -> void: _requests.append([id, count]))
	_panel.mode_changed.connect(func(mode: int) -> void: _modes.append(mode))
	_panel.setup(_companions, func() -> BigNumber: return _state.gold)


func _entry(id: String, tiers: Array) -> Dictionary:
	return {
		"id": id,
		"name": id,
		"base_cost": "10",
		"base_damage": "1",
		"cost_growth": "1.08",
		"attack_interval_seconds": 1.0,
		"tiers": tiers,
	}


func _row(index: int = 0) -> Dictionary:
	return (_panel.get("_rows") as Array)[index]


func _button(index: int = 0) -> Button:
	return _row(index)["button"]


func _tier_text(index: int = 0) -> String:
	return (_row(index)["tier"] as Label).text


# The whole sentence, multiplier included, kept in the tooltip of the line (story 019b).
func _tier_sentence(index: int = 0) -> String:
	return (_row(index)["tier"] as Label).tooltip_text


func _bar(index: int = 0) -> ProgressBar:
	return _row(index)["bar"]


func _at_level(level: int, gold: BigNumber = BigNumber.new()) -> void:
	_state.companion_levels = {ID: level}
	_state.gold = gold
	_panel.refresh()


func _lines() -> PackedStringArray:
	return _panel.row_lines(0)


func _cost(cost: BigNumber) -> String:
	return CompanionPanel.keep_together(cost.format())


# "×N · " before the rest of the line (story 019b: the count shows when the mode does not say it).
func _counted(count: int, rest: String) -> String:
	return CompanionPanel.keep_together("×%d ·" % count) + " " + rest


func _gain(from_level: int, to_level: int) -> String:
	_state.companion_levels = {ID: from_level}
	var gain: BigNumber = _companions.damage_per_second_at(ID, to_level).subtract(_companions.damage_per_second(ID))
	return CompanionPanel.gain_text(gain)


func test_row_at_level_0_names_the_first_tier_on_an_empty_bar() -> void:
	_at_level(0)
	assert_str(_tier_text()).is_equal(CompanionPanel.keep_together("Palier 10"))
	assert_str(_tier_sentence()).is_equal(CompanionPanel.keep_together("Palier niv. 10 : ×2"))
	assert_float(_bar().value).is_equal(0.0)
	assert_bool(_bar().visible).is_true()


func test_row_between_two_tiers_fills_from_the_previous_tier() -> void:
	_at_level(19)
	assert_str(_tier_text()).is_equal(CompanionPanel.keep_together("Palier 25"))
	assert_str(_tier_sentence()).is_equal(CompanionPanel.keep_together("Palier niv. 25 : ×1,5"))
	assert_float(_bar().value).is_equal_approx(9.0 / 15.0, 0.0001)


func test_row_on_a_tier_starts_the_next_bar_empty() -> void:
	_at_level(10)
	assert_str(_tier_text()).is_equal(CompanionPanel.keep_together("Palier 25"))
	assert_str(_tier_sentence()).is_equal(CompanionPanel.keep_together("Palier niv. 25 : ×1,5"))
	assert_float(_bar().value).is_equal(0.0)


func test_row_after_the_last_tier_says_so_on_a_full_bar() -> void:
	_at_level(250)
	assert_str(_tier_text()).is_equal("Tous les paliers atteints")
	assert_str(_tier_sentence()).is_equal("Tous les paliers atteints")
	assert_float(_bar().value).is_equal(1.0)
	# No goal ahead: the words say it all, the bar goes (story 019b).
	assert_bool(_bar().visible).is_false()


func test_row_on_the_last_tier_says_so_on_a_full_bar() -> void:
	_at_level(200)
	assert_str(_tier_text()).is_equal("Tous les paliers atteints")
	assert_float(_bar().value).is_equal(1.0)


func test_row_without_any_tier_says_so_on_an_empty_bar() -> void:
	_at_level(5)
	assert_str(_tier_text(1)).is_equal("Tous les paliers atteints")
	assert_float(_bar(1).value).is_equal(0.0)
	assert_bool(_bar(1).visible).is_false()


func test_bar_takes_no_input_and_no_focus() -> void:
	assert_int(_bar().mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(_bar().focus_mode).is_equal(Control.FOCUS_NONE)


func test_refresh_builds_no_node() -> void:
	# Arrange
	var nodes_before: int = _panel.get_child_count(true)
	var rows_box: Node = _panel.get("_rows_box")
	var first_bar: ProgressBar = _bar()
	var rows_before: int = rows_box.get_child_count()

	# Act
	_at_level(15)
	_panel.set_mode(BuyQuote.Mode.TIER)

	# Assert
	assert_int(_panel.get_child_count(true)).is_equal(nodes_before)
	assert_int(rows_box.get_child_count()).is_equal(rows_before)
	assert_object(_bar()).is_same(first_bar)


func _mode_button() -> Button:
	return _panel.get("_mode_button")


func test_one_button_walks_the_five_modes_and_comes_back() -> void:
	# Arrange: the order of story 019b
	var expected: Array = [BuyQuote.Mode.TEN, BuyQuote.Mode.HUNDRED, BuyQuote.Mode.MAX, BuyQuote.Mode.TIER, BuyQuote.Mode.ONE]

	# Act
	for i in expected.size():
		_mode_button().pressed.emit()

	# Assert
	assert_array(_modes).is_equal(expected)
	assert_int(_panel.buy_mode()).is_equal(BuyQuote.Mode.ONE)


func test_pressing_from_max_reports_palier() -> void:
	_panel.set_mode(BuyQuote.Mode.MAX)
	_mode_button().pressed.emit()
	assert_array(_modes).contains_exactly([BuyQuote.Mode.TIER])
	assert_str(_mode_button().text).is_equal("Achat Palier")


func test_stored_tier_mode_is_shown_on_the_button() -> void:
	_panel.set_mode(BuyQuote.Mode.TIER)
	assert_str(_mode_button().text).is_equal("Achat Palier")
	assert_str(_mode_button().accessibility_name).contains("Achat Palier")


func test_button_text_names_each_mode() -> void:
	var texts: Dictionary = {BuyQuote.Mode.ONE: "Achat ×1", BuyQuote.Mode.TEN: "Achat ×10",
			BuyQuote.Mode.HUNDRED: "Achat ×100", BuyQuote.Mode.MAX: "Achat Max", BuyQuote.Mode.TIER: "Achat Palier"}
	for mode: int in texts:
		_panel.set_mode(mode)
		assert_str(_mode_button().text).is_equal(texts[mode])


func test_set_mode_does_not_report_back() -> void:
	_panel.set_mode(BuyQuote.Mode.HUNDRED)
	assert_array(_modes).is_empty()


func test_tier_button_shows_the_real_count_and_the_verb_of_a_first_purchase() -> void:
	_at_level(0)
	_panel.set_mode(BuyQuote.Mode.TIER)
	assert_array(_lines()).is_equal(PackedStringArray(["Acheter", _counted(10, _cost(_companions.cost_of_levels(ID, 10)))]))
	assert_str(_button().accessibility_name).starts_with("Acheter %s ×10 : %s" % [ID, _companions.cost_of_levels(ID, 10).format()])


func test_tier_button_shows_the_real_count_of_an_upgrade() -> void:
	_at_level(10)
	_panel.set_mode(BuyQuote.Mode.TIER)
	var expected: PackedStringArray = PackedStringArray([_cost(_companions.cost_of_levels(ID, 15)), _counted(15, _gain(10, 25))])
	assert_array(_lines()).is_equal(expected)
	assert_str(_button().accessibility_name).starts_with("Améliorer %s ×15 : %s" % [ID, _companions.cost_of_levels(ID, 15).format()])


func test_tier_press_buys_the_count_the_row_shows() -> void:
	_at_level(10, _companions.cost_of_levels(ID, 15))
	_state.gold = _state.gold.add(_companions.cost_of_levels(ID, 15))
	_panel.set_mode(BuyQuote.Mode.TIER)
	_button().pressed.emit()
	assert_array(_requests).contains_exactly([[ID, 15]])


func test_tier_button_with_exact_gold_is_enabled() -> void:
	_panel.set_mode(BuyQuote.Mode.TIER)
	_at_level(0, _companions.cost_of_levels(ID, 10))
	assert_bool(_button().disabled).is_false()


func test_tier_button_one_gold_short_is_disabled_with_the_cost_alone() -> void:
	var total: BigNumber = _companions.cost_of_levels(ID, 10)
	_panel.set_mode(BuyQuote.Mode.TIER)
	_at_level(0, total.subtract(BigNumber.from_int(1)))
	assert_bool(_button().disabled).is_true()
	assert_array(_lines()).is_equal(PackedStringArray(["Acheter", _counted(10, _cost(total))]))


func test_tier_button_after_the_last_tier_reads_max_outlined_and_disabled() -> void:
	# Story 019b: "Max" only in the Palier mode once the last tier is passed, and never a price.
	_panel.set_mode(BuyQuote.Mode.TIER)
	_at_level(250, BigNumber.from_string("1" + "0".repeat(60)))
	assert_bool(_button().disabled).is_true()
	assert_array(_lines()).is_equal(PackedStringArray(["Max", ""]))
	assert_int((_button().get_theme_stylebox("disabled") as StyleBoxFlat).border_width_top).is_greater(0)
	assert_str(_button().accessibility_name).is_equal("%s : Max, dernier palier atteint" % ID)


func test_max_never_shows_outside_the_tier_mode() -> void:
	# Past the last tier the other modes still buy levels: no "Max" on the button.
	for mode: int in [BuyQuote.Mode.ONE, BuyQuote.Mode.TEN, BuyQuote.Mode.HUNDRED, BuyQuote.Mode.MAX]:
		_panel.set_mode(mode)
		_at_level(250, BigNumber.from_string("1" + "0".repeat(60)))
		assert_str(_lines()[0]).override_failure_message("mode %d" % mode).is_not_equal("Max")
		assert_bool(_button().disabled).is_false()


func test_tier_press_after_the_last_tier_asks_for_nothing() -> void:
	_panel.set_mode(BuyQuote.Mode.TIER)
	_at_level(250, BigNumber.from_string("1" + "0".repeat(60)))
	_button().pressed.emit()
	assert_array(_requests).is_empty()


func test_button_short_of_gold_never_says_what_is_missing_in_any_mode() -> void:
	for mode: int in BuyQuote.Mode.values():
		_panel.set_mode(mode)
		_at_level(0)
		assert_bool(_button().disabled).is_true()
		for line: String in _lines():
			assert_str(line).not_contains("manque")
			assert_str(line).not_contains("\n")
		assert_str(_button().accessibility_name).not_contains("manque")


func test_only_the_affordable_button_has_a_border() -> void:
	# Arrange: the styles the engine draws for the real button, through BuyButton and its base
	var button: Button = _button()

	# Act
	var enabled_widths: Array[int] = []
	for style: String in ["normal", "hover", "pressed"]:
		enabled_widths.append((button.get_theme_stylebox(style) as StyleBoxFlat).border_width_top)
	var disabled: StyleBoxFlat = button.get_theme_stylebox("disabled")

	# Assert
	for width: int in enabled_widths:
		assert_int(width).is_greater(0)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		assert_int(disabled.get_border_width(side)).is_equal(0)


func test_longest_cost_holds_on_one_line_and_the_longest_gain_on_two_at_320_wide() -> void:
	# Arrange: the button of 112 u; its cost line is bold 16 u, its gain line 14 u and may wrap once
	_panel.size = PANE_AT_320
	await await_idle_frame()
	var button: Button = _button()
	var cost: Label = _row()["cost"]
	var gain: Label = _row()["gain"]
	var box: StyleBox = button.get_theme_stylebox("disabled")
	var longest_gain: String = _counted(CompanionPanel.LONGEST_COUNT, CompanionPanel.gain_text(BigNumber.from_string("9999" + "0".repeat(98))))

	# Act
	var room: float = button.size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT)
	var cost_width: float = cost.get_theme_font("font").get_string_size(CompanionPanel.keep_together(CompanionPanel.LONGEST_COST),
			HORIZONTAL_ALIGNMENT_LEFT, -1, CompanionPanel.FONT_SIZE_MAIN).x
	var lines: int = gain.get_theme_font("font").get_multiline_string_size(longest_gain, HORIZONTAL_ALIGNMENT_CENTER, room, CompanionPanel.FONT_SIZE_SECONDARY,
			-1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y / gain.get_line_height()

	# Assert
	assert_float(button.size.x).is_equal(CompanionPanel.BUTTON_SIZE.x)
	assert_float(room).is_greater_equal(cost_width)
	assert_int(lines).is_less_equal(2)


func test_longest_tier_line_holds_beside_its_bar_at_320_wide() -> void:
	# Arrange: the longest tier of this roster beside its bar ("Palier 200")
	_panel.size = PANE_AT_320
	_at_level(150)
	await await_idle_frame()

	# Act
	var tier: Label = _row()["tier"]
	var line: Control = tier.get_parent()

	# Assert
	assert_float(tier.size.x + _bar().size.x).is_less_equal(line.size.x)
	assert_float(_bar().size.x).is_greater(0.0)


func test_two_rows_stay_visible_at_320x568() -> void:
	# Arrange
	_panel.size = PANE_AT_320
	await await_idle_frame()
	var scroll: ScrollContainer = _panel.get("_scroll")
	var row: Control = _button().get_parent().get_parent()
	var gap: float = float((_panel.get("_rows_box") as Control).get_theme_constant("separation"))

	# Act
	var visible_rows: float = (scroll.size.y + gap) / (row.size.y + gap)

	# Assert
	assert_float(visible_rows).is_greater_equal(VISIBLE_ROWS_AT_320)


func test_buy_target_stays_50_high_in_the_shortest_row() -> void:
	_panel.size = PANE_AT_320
	await await_idle_frame()
	assert_float(_button().size.y).is_greater_equal(50.0)
	assert_float(_button().size.y).is_equal(CompanionPanel.BUTTON_SIZE.y)
