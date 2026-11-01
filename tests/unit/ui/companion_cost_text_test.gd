extends GdUnitTestSuite
## Unit tests for the text of the companion buy button: a cost never leaves its unit alone on a line.
## The wrap is the engine's own, on a width too short for the whole text.
## Story: production/epics/idle-titans/story-011-management-tabs.md.

const COST: int = 960_300_000_000
const NARROW_WIDTH: float = 150.0
const FONT_SIZE: int = 16
const PANE_AT_320: float = 363.0
## Side margins of BuyButton in the theme.
const MARGINS: float = 4.0
const LEAST_ROOM_FOR_THE_NAME: float = 100.0

var _panel: CompanionPanel


func before_test() -> void:
	_panel = auto_free(CompanionPanel.new())
	_panel._mode = BuyQuote.Mode.TEN


func _quote(affordable: bool) -> BuyQuote:
	var quote: BuyQuote = BuyQuote.new()
	quote.count = 74
	quote.cost = BigNumber.from_int(COST)
	quote.missing = BigNumber.from_int(COST)
	quote.affordable = affordable
	return quote


func _lines(text: String) -> PackedStringArray:
	var paragraph: TextParagraph = TextParagraph.new()
	paragraph.add_string(text, ThemeDB.fallback_font, FONT_SIZE)
	paragraph.width = NARROW_WIDTH
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	var lines: PackedStringArray = PackedStringArray()
	for i in paragraph.get_line_count():
		var span: Vector2i = paragraph.get_line_range(i)
		lines.append(text.substr(span.x, span.y - span.x).strip_edges())
	return lines


func test_longest_cost_holds_on_one_line_of_a_compact_button() -> void:
	# Arrange: the real row, in the narrowest pane (320 CSS px wide)
	var panel: CompanionPanel = auto_free((load("res://src/ui/companion_panel.tscn") as PackedScene).instantiate())
	add_child(panel)
	panel.size = Vector2(PANE_AT_320, 200)
	panel._add_row("scout")
	var button: Button = panel._rows[0]["button"]
	var text: String = "Améliorer x10 : %s" % CompanionPanel.keep_together(CompanionPanel.LONGEST_COST)
	var font: Font = button.get_theme_font("font")

	# Act
	var needed: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x

	# Assert
	assert_float(button.custom_minimum_size.x - MARGINS).is_greater_equal(needed)
	assert_float(button.custom_minimum_size.x).is_less(PANE_AT_320 - LEAST_ROOM_FOR_THE_NAME)


func test_keep_together_leaves_no_plain_space() -> void:
	assert_str(CompanionPanel.keep_together("960,3 B")).is_equal("960,3 B")


func test_cost_stays_whole_on_its_line() -> void:
	# Arrange
	var text: String = _panel._button_text(5, _quote(true))
	var cost: String = BigNumber.from_int(COST).format().replace(" ", " ")

	# Act
	var lines: PackedStringArray = _lines(text)

	# Assert
	assert_int(lines.size()).is_greater(1)
	assert_str(lines[-1]).is_equal(cost)


func test_missing_amount_stays_whole_on_its_line() -> void:
	var text: String = _panel._button_text(5, _quote(false))
	var missing: String = BigNumber.from_int(COST).format().replace(" ", " ")
	assert_bool(text.ends_with(missing)).is_true()
