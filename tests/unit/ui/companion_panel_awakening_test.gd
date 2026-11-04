extends GdUnitTestSuite
## Unit tests for the companion rows around the awakening (story 017), on the real scene and the real
## theme: the progress line in each state, the rank badge, the "Éveil" button and its signal, the
## real count of x10, and the widths of the longest numbers at 320x568. Story 019b (lot 6): the line
## is short beside its bar ("Éveil 300") and keeps its whole sentence in its tooltip; at a threshold
## it says "Niveau bloqué : éveil requis", the button reads "Éveil I" over its cost in violet, the card
## is edged in violet, and the gain of the awakening is in the accessible name of the button.
## Story: production/epics/idle-titans/story-017-awakening-ui.md, design/economy-rework.md "Éveil".

const PANEL_SCENE: String = "res://src/ui/companion_panel.tscn"
const THEME_PATH: String = "res://src/ui/main_theme.tres"
const ID: String = "scout"
const OTHER_ID: String = "knight"
const TIERS: Array[Dictionary] = [
	{"level": 10, "damage_multiplier": "2"},
	{"level": 25, "damage_multiplier": "2"},
	{"level": 200, "damage_multiplier": "3"},
]
const AWAKENING: Dictionary = {
	"thresholds": [200, 300, 400, 500, 600, 700, 800, 900, 1000],
	"self_multiplier": "3.4",
	"squad_multiplier": "2.10",
	"squad_until_threshold": 600,
	"cost_level_multiplier": "10",
}
const FIRST_THRESHOLD: int = 200
const LAST_THRESHOLD: int = 1000
const ALL_AWAKENINGS: int = 9
## Highest companion level measured at stage 200 (3 digits), and its awakenings (200 to 600).
const LEVEL_AT_STAGE_200: int = 640
const AWAKENINGS_AT_640: int = 5
## Panel of the management zone at 320x568, in logical units (as companion_panel_tier_test.gd).
const PANE_AT_320: Vector2 = Vector2(363, 204)
const VISIBLE_ROWS_AT_320: float = 2.0
const FONT_SIZE: int = 16
const MIN_TARGET: float = 50.0
## Most groups of 3 digits a number reaches up to stage 300 and the awakening of level 1000: the
## exponent of the widest scientific notation stays at two digits (e46 for the dragon at 1000).
const LONGEST_EXPONENT_GROUPS: int = 33

var _state: GameState
var _companions: CompanionManager
var _panel: CompanionPanel
var _buys: Array = []
var _awakens: Array = []


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
		"awakening": AWAKENING.duplicate(true),
		"companions": [_entry(ID, "Éclaireur"), _entry(OTHER_ID, "Chevalier")],
	}
	var combat: Combat = Combat.from_data(curves, roster)
	_state = GameState.new()
	_companions = CompanionManager.new(_state, combat, FloorManager.new(_state, combat))
	_panel = auto_free((load(PANEL_SCENE) as PackedScene).instantiate())
	_panel.theme = load(THEME_PATH)
	add_child(_panel)
	_buys = []
	_awakens = []
	_panel.buy_requested.connect(func(id: String, count: int) -> void: _buys.append([id, count]))
	_panel.awaken_requested.connect(func(id: String) -> void: _awakens.append(id))
	_panel.setup(_companions, func() -> BigNumber: return _state.gold)


func _entry(id: String, display_name: String) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"base_cost": "10",
		"base_damage": "1",
		"cost_growth": "1.08",
		"attack_interval_seconds": 1.0,
		"tiers": TIERS,
	}


func _row(index: int = 0) -> Dictionary:
	return (_panel.get("_rows") as Array)[index]


func _button(index: int = 0) -> Button:
	return _row(index)["button"]


func _lines(index: int = 0) -> PackedStringArray:
	return _panel.row_lines(index)


func _tier_text() -> String:
	return (_row()["tier"] as Label).text


func _tier_sentence() -> String:
	return (_row()["tier"] as Label).tooltip_text


func _bar() -> ProgressBar:
	return _row()["bar"]


func _rank() -> Label:
	return _row()["rank"]


func _plenty() -> BigNumber:
	return BigNumber.from_string("1" + "0".repeat(80))


func _at(level: int, awakenings: int = 0, gold: BigNumber = BigNumber.new()) -> void:
	_state.companion_levels = {ID: level}
	_state.companion_awakenings = {ID: awakenings} if awakenings > 0 else {}
	_state.gold = gold
	_panel.refresh()


func _awakening_cost() -> BigNumber:
	return _companions.next_awakening(ID)["cost"]


func _cost(cost: BigNumber) -> String:
	return CompanionPanel.keep_together(cost.format())


# "×N · +X DPS" for a press that takes the companion from its level now to [param to_level].
func _counted_gain(count: int, to_level: int) -> String:
	var gain: BigNumber = _companions.damage_per_second_at(ID, to_level).subtract(_companions.damage_per_second(ID))
	return CompanionPanel.keep_together("×%d ·" % count) + " " + CompanionPanel.gain_text(gain)


func _width(control: Control, text: String, font_size: int = FONT_SIZE) -> float:
	return control.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


# --- progress line ---------------------------------------------------------------------------

func test_line_before_the_last_tier_names_the_tier() -> void:
	_at(150)
	assert_str(_tier_text()).is_equal(CompanionPanel.keep_together("Palier 200"))
	assert_str(_tier_sentence()).is_equal(CompanionPanel.keep_together("Palier niv. 200 : ×3"))


func test_line_at_the_threshold_says_the_level_is_blocked_on_a_full_bar() -> void:
	_at(FIRST_THRESHOLD)
	assert_str(_tier_text()).is_equal("Niveau bloqué : éveil requis")
	assert_str(_tier_sentence()).is_equal("Niveau bloqué : éveil requis")
	assert_float(_bar().value).is_equal(1.0)


func test_line_past_the_last_tier_names_the_next_awakening_not_the_last_tier() -> void:
	# Arrange: awakened once, halfway from 200 to 300
	_at(250, 1)

	# Assert
	assert_str(_tier_text()).is_equal(CompanionPanel.keep_together("Éveil 300"))
	assert_str(_tier_sentence()).is_equal(CompanionPanel.keep_together("Éveil niv. 300 : ×3,4"))
	assert_str(_tier_text()).not_contains("Tous les paliers")
	assert_float(_bar().value).is_equal_approx(0.5, 0.0001)


func test_line_after_every_awakening_says_so_on_a_full_bar() -> void:
	_at(LAST_THRESHOLD, ALL_AWAKENINGS)
	assert_str(_tier_text()).is_equal("Tous les éveils faits")
	assert_float(_bar().value).is_equal(1.0)


func test_line_at_level_1000_before_its_last_awakening_says_blocked() -> void:
	_at(LAST_THRESHOLD, ALL_AWAKENINGS - 1)
	assert_str(_tier_text()).is_equal("Niveau bloqué : éveil requis")


# --- rank ------------------------------------------------------------------------------------

func test_rank_badge_is_hidden_before_the_first_awakening() -> void:
	_at(FIRST_THRESHOLD)
	assert_bool(_rank().visible).is_false()


func test_rank_badge_gives_way_to_the_blocked_line_at_a_threshold() -> void:
	# Story 019b: at 300 with one awakening, the button says "Éveil II"; the line needs the room.
	_at(300, 1, _plenty())
	assert_bool(_rank().visible).is_false()
	assert_str(_lines()[0]).is_equal(CompanionPanel.keep_together("Éveil II"))
	_at(350, 2)
	assert_bool(_rank().visible).is_true()


func test_rank_reads_as_a_framed_roman_numeral() -> void:
	# Arrange
	_at(350, 2)

	# Act
	var frame: StyleBoxFlat = _rank().get_theme_stylebox("normal") as StyleBoxFlat

	# Assert: the words and a drawn frame, not a colour alone
	assert_bool(_rank().visible).is_true()
	assert_str(_rank().text).is_equal(CompanionPanel.keep_together("Éveil II"))
	assert_object(frame).is_not_null()
	assert_int(frame.border_width_top).is_greater(0)
	assert_bool(frame.draw_center).is_false()


# --- button ----------------------------------------------------------------------------------

func test_button_at_the_threshold_awakens_with_its_cost_and_the_squad_gain() -> void:
	_at(FIRST_THRESHOLD, 0, _plenty())
	assert_array(_lines()).is_equal(PackedStringArray([CompanionPanel.keep_together("Éveil I"), _cost(_awakening_cost())]))
	assert_str(_button().accessibility_name).is_equal("Éveiller Éclaireur : %s. %s" % [_cost(_awakening_cost()), CompanionPanel.keep_together("Escouade ×2,10")])
	assert_str(_button().theme_type_variation).is_equal("AwakenButton")
	assert_bool(_button().disabled).is_false()


func test_card_at_the_threshold_is_edged_in_violet() -> void:
	# The state reads by a shape too (an edge), not by the violet of the button alone.
	_at(FIRST_THRESHOLD, 0, _plenty())
	var card: StyleBoxFlat = (_row()["card"] as PanelContainer).get_theme_stylebox("panel")
	assert_int(card.border_width_left).is_greater(0)
	assert_bool(card.border_color.is_equal_approx(UiPalette.VIOLET_EDGE)).is_true()
	_at(FIRST_THRESHOLD - 1, 0, _plenty())
	assert_int(((_row()["card"] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat).border_width_left).is_equal(0)


func test_button_past_the_squad_limit_announces_the_companion_gain() -> void:
	_at(700, 5, _plenty())
	assert_str(_lines()[0]).is_equal(CompanionPanel.keep_together("Éveil VI"))
	assert_str(_button().accessibility_name).ends_with(CompanionPanel.keep_together("Ce compagnon ×3,4"))


func test_awaken_button_with_exact_gold_is_enabled() -> void:
	_at(FIRST_THRESHOLD)
	_at(FIRST_THRESHOLD, 0, _awakening_cost())
	assert_bool(_button().disabled).is_false()


func test_awaken_button_one_gold_short_is_disabled_without_a_shortfall() -> void:
	_at(FIRST_THRESHOLD)
	_at(FIRST_THRESHOLD, 0, _awakening_cost().subtract(BigNumber.from_int(1)))
	assert_bool(_button().disabled).is_true()
	assert_array(_lines()).is_equal(PackedStringArray([CompanionPanel.keep_together("Éveil I"), _cost(_awakening_cost())]))
	for line: String in _lines():
		assert_str(line).not_contains("manque")
	assert_str(_button().accessibility_name).not_contains("manque")


func test_awaken_press_asks_for_the_awakening_and_no_level() -> void:
	_at(FIRST_THRESHOLD, 0, _plenty())
	_button().pressed.emit()
	assert_array(_awakens).contains_exactly([ID])
	assert_array(_buys).is_empty()


func test_buy_press_below_the_threshold_asks_for_no_awakening() -> void:
	_at(FIRST_THRESHOLD - 1, 0, _plenty())
	_button().pressed.emit()
	assert_array(_awakens).is_empty()
	assert_array(_buys).contains_exactly([[ID, 1]])


func test_x10_three_levels_before_the_threshold_shows_x3() -> void:
	_panel.set_mode(BuyQuote.Mode.TEN)
	_at(FIRST_THRESHOLD - 3, 0, _plenty())
	assert_array(_lines()).is_equal(PackedStringArray([_cost(_companions.cost_of_levels(ID, 3)), _counted_gain(3, FIRST_THRESHOLD)]))
	_button().pressed.emit()
	assert_array(_buys).contains_exactly([[ID, 3]])


func test_max_across_the_threshold_shows_the_levels_up_to_it() -> void:
	_panel.set_mode(BuyQuote.Mode.MAX)
	_at(150, 0, _plenty())
	assert_array(_lines()).is_equal(PackedStringArray([_cost(_companions.cost_of_levels(ID, 50)), _counted_gain(50, FIRST_THRESHOLD)]))


func test_tier_mode_aims_at_the_next_threshold() -> void:
	_panel.set_mode(BuyQuote.Mode.TIER)
	_at(250, 1, _plenty())
	assert_array(_lines()).is_equal(PackedStringArray([_cost(_companions.cost_of_levels(ID, 50)), _counted_gain(50, 300)]))


func test_tier_mode_after_every_awakening_has_nothing_left() -> void:
	_panel.set_mode(BuyQuote.Mode.TIER)
	_at(LAST_THRESHOLD, ALL_AWAKENINGS, _plenty())
	assert_array(_lines()).is_equal(PackedStringArray(["Max", ""]))
	assert_bool(_button().disabled).is_true()


# --- sizes -----------------------------------------------------------------------------------

func test_awaken_button_stays_at_least_50_high_and_its_two_lines_fit_in_it() -> void:
	# Arrange
	_panel.size = PANE_AT_320
	_at(FIRST_THRESHOLD, 0, _plenty())
	await await_idle_frame()

	# Act: what the two lines need inside the button
	var needed: float = (_row()["cost"] as Control).get_parent().get_combined_minimum_size().y

	# Assert: the target keeps its 50 u, and the lines fit its 56 u
	assert_float(_button().size.y).is_greater_equal(MIN_TARGET)
	assert_float(needed).is_less_equal(CompanionPanel.BUTTON_SIZE.y)


func test_max_of_1000_levels_past_the_last_awakening_fits_the_56_high_button() -> void:
	# Arrange: x1000 is the one count of 4 digits: its line may wrap once, never out of the button
	_panel.size = PANE_AT_320
	_panel.set_mode(BuyQuote.Mode.MAX)
	_at(LAST_THRESHOLD, ALL_AWAKENINGS, _plenty())
	await await_idle_frame()

	# Act
	var needed: float = (_row()["cost"] as Control).get_parent().get_combined_minimum_size().y

	# Assert
	assert_str(_lines()[1]).starts_with(CompanionPanel.keep_together("×%d ·" % CompanionManager.MAX_SCAN_LEVELS) + " ")
	assert_float(needed).is_less_equal(CompanionPanel.BUTTON_SIZE.y)


func test_rank_badge_keeps_the_height_of_the_line() -> void:
	_at(LAST_THRESHOLD, ALL_AWAKENINGS)
	assert_float(_rank().get_combined_minimum_size().y).is_less_equal(CompanionPanel.TIER_LINE_HEIGHT)


func test_longest_line_with_the_longest_rank_holds_at_320_wide() -> void:
	# Arrange: "Éveil 1000" beside the bar and "Éveil VIII", the longest numeral
	_panel.size = PANE_AT_320
	_at(950, 8)
	await await_idle_frame()

	# Act
	var line: Control = _bar().get_parent()
	var tier: Label = _row()["tier"]
	var used: float = tier.size.x + _bar().size.x + _rank().size.x

	# Assert
	assert_str(tier.text).is_equal(CompanionPanel.keep_together("Éveil 1000"))
	assert_str(_tier_sentence()).is_equal(CompanionPanel.keep_together("Éveil niv. 1000 : ×3,4"))
	assert_str(_rank().text).is_equal(CompanionPanel.keep_together("Éveil VIII"))
	assert_float(used).is_less_equal(line.size.x)
	assert_float(_bar().size.x).is_greater(0.0)


func test_two_rows_at_a_3_digit_level_stay_visible_at_320x568() -> void:
	# Arrange: the highest level measured at stage 200, awakened 5 times, with a name that holds on
	# one line at 3 digits today; its badge and its next awakening on the line
	_panel.size = PANE_AT_320
	_state.companion_levels = {ID: LEVEL_AT_STAGE_200, OTHER_ID: LEVEL_AT_STAGE_200}
	_state.companion_awakenings = {ID: AWAKENINGS_AT_640, OTHER_ID: AWAKENINGS_AT_640}
	_state.gold = _plenty()
	_panel.refresh()
	await await_idle_frame()
	var scroll: ScrollContainer = _panel.get("_scroll")
	var row: Control = _row()["card"]
	var gap: float = float((_panel.get("_rows_box") as Control).get_theme_constant("separation"))
	var title: Label = _row()["title"]

	# Act
	var visible_rows: float = (scroll.size.y + gap) / (row.size.y + gap)

	# Assert
	assert_str(title.text).is_equal("Éclaireur")
	assert_str((_row()["level"] as Label).text).is_equal("Niv. %d" % LEVEL_AT_STAGE_200)
	assert_int(title.get_line_count()).is_equal(1)
	assert_bool(_rank().visible).is_true()
	assert_float(row.size.y).is_equal(CompanionPanel.ROW_HEIGHT)
	assert_float(visible_rows).is_greater_equal(VISIBLE_ROWS_AT_320)


func test_long_name_at_level_1000_stays_inside_its_row_at_320_wide() -> void:
	# Arrange: late in the game, the longest name of this roster at 4 digits (story 017, option B:
	# the name may wrap; the row grows, nothing goes out of it and nothing overlaps)
	_panel.size = PANE_AT_320
	_state.companion_levels = {ID: LAST_THRESHOLD, OTHER_ID: LAST_THRESHOLD}
	_state.companion_awakenings = {ID: ALL_AWAKENINGS, OTHER_ID: ALL_AWAKENINGS}
	_state.gold = _plenty()
	_panel.refresh()
	await await_idle_frame()
	var row: Dictionary = _row(1)
	var title: Label = row["title"]
	var level: Label = row["level"]
	var button: Button = row["button"]
	var card: Control = row["card"]
	var texts: Control = title.get_parent().get_parent()

	# Act
	var texts_end: float = texts.position.x + texts.size.x
	var title_line_width: float = title.size.x + level.size.x

	# Assert: the name on one line, never cut; "Niv. 1000" beside it or under it, whole, inside the
	# text column; all of it beside the button and not under it
	var level_rect: Rect2 = Rect2(level.global_position, level.size)
	var texts_rect: Rect2 = Rect2(texts.global_position, texts.size)
	assert_str(title.text).is_equal("Chevalier")
	assert_str(level.text).is_equal("Niv. %d" % LAST_THRESHOLD)
	assert_int(title.get_line_count()).is_equal(1)
	assert_int(level.get_line_count()).is_equal(1)
	assert_float(title.size.x).is_greater_equal(title.get_combined_minimum_size().x)
	assert_bool(texts_rect.encloses(level_rect)).override_failure_message("%s outside %s" % [level_rect, texts_rect]).is_true()
	assert_float(minf(title_line_width, maxf(title.size.x, level.size.x))).is_less_equal(texts.size.x)
	assert_float(texts_end).is_less_equal(button.position.x)
	assert_float(button.position.x + button.size.x).is_less_equal(button.get_parent().size.x)
	assert_float(texts.size.y).is_less_equal(button.get_parent().size.y)
	assert_float(card.size.x).is_less_equal((_panel.get("_scroll") as Control).size.x)
	assert_float(button.size.y).is_greater_equal(MIN_TARGET)


func test_longest_cost_is_at_least_as_wide_as_every_format_up_to_stage_300() -> void:
	# Arrange: 999,9 followed by every suffix from K to Dc, then the scientific notation, as the
	# real BigNumber.format writes them
	var button: Button = _button()
	var reserved: float = _width(button, CompanionPanel.LONGEST_COST)
	var widest: String = ""
	var widest_width: float = 0.0

	# Act
	for groups in range(1, LONGEST_EXPONENT_GROUPS + 1):
		var text: String = BigNumber.from_string("9999" + "0".repeat(groups * 3 - 1)).format()
		var width: float = _width(button, CompanionPanel.keep_together(text))
		if width > widest_width:
			widest_width = width
			widest = text

	# Assert
	assert_str(BigNumber.from_string("9999" + "0".repeat(32)).format()).is_equal("999,9 Dc")
	assert_str(BigNumber.from_string("9999" + "0".repeat(98)).format()).is_equal(CompanionPanel.LONGEST_COST)
	assert_float(reserved).override_failure_message("widest: " + widest).is_greater_equal(widest_width)


func test_each_line_of_the_awakening_button_holds_on_one_line_at_320_wide() -> void:
	# Arrange: the longest rank to reach and the longest cost, in the bold 16 u of the button
	_panel.size = PANE_AT_320
	await await_idle_frame()
	var button: Button = _button()
	var cost: Label = _row()["cost"]
	var box: StyleBox = button.get_theme_stylebox("disabled")
	var lines: Array[String] = [
		CompanionPanel.keep_together("Éveil VIII"),
		CompanionPanel.keep_together(CompanionPanel.LONGEST_COST),
	]

	# Act
	var room: float = button.size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT)

	# Assert
	for line: String in lines:
		assert_float(room).override_failure_message(line).is_greater_equal(_width(cost, line, CompanionPanel.FONT_SIZE_MAIN))


func test_longest_buy_lines_hold_in_the_button_at_320_wide() -> void:
	# Arrange: the longest cost on its bold line, the longest count and gain on at most two lines
	_panel.size = PANE_AT_320
	await await_idle_frame()
	var button: Button = _button()
	var cost: Label = _row()["cost"]
	var gain: Label = _row()["gain"]
	var box: StyleBox = button.get_theme_stylebox("disabled")
	var longest_gain: String = CompanionPanel.keep_together("×%d ·" % CompanionPanel.LONGEST_COUNT) + " " \
			+ CompanionPanel.gain_text(BigNumber.from_string("9999" + "0".repeat(98)))

	# Act: the longest texts in the real labels, then what the inside of the button needs
	var room: float = button.size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT)
	cost.text = CompanionPanel.keep_together(CompanionPanel.LONGEST_COST)
	gain.text = longest_gain
	gain.custom_minimum_size.x = room
	await await_idle_frame()
	var needed: float = cost.get_parent().get_combined_minimum_size().y

	# Assert
	assert_float(room).is_greater_equal(_width(cost, cost.text, CompanionPanel.FONT_SIZE_MAIN))
	assert_int(gain.get_line_count()).is_less_equal(2)
	assert_float(needed).is_less_equal(CompanionPanel.BUTTON_SIZE.y)
