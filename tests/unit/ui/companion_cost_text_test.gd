extends GdUnitTestSuite
## Unit tests for the texts of the companion buy button: a cost never leaves its unit alone on a line.
## The wrap is the engine's own, on a width too short for the whole text. Story 019b (lot 6): the
## button has two lines, the cost then the gain; a long gain line may break only after its count.
## Stories: production/epics/idle-titans/story-011-management-tabs.md, story-019b-mobile-ui-refonte.md.

const COST: int = 960_300_000_000
const GAIN: int = 339_900_000
const COUNT: int = 74
## Room of the text of the 112 u button, its margins taken off (display setting of the theme).
const NARROW_WIDTH: float = 100.0
const FONT_SIZE: int = 14
const PANE_AT_320: float = 363.0
## Side margins of BuyButton in the theme.
const MARGINS: float = 4.0
const LEAST_ROOM_FOR_THE_NAME: float = 100.0

var _panel: CompanionPanel


func before_test() -> void:
	_panel = auto_free(CompanionPanel.new())
	_panel._mode = BuyQuote.Mode.MAX


func _quote(affordable: bool) -> BuyQuote:
	var quote: BuyQuote = BuyQuote.new()
	quote.count = COUNT
	quote.cost = BigNumber.from_int(COST)
	quote.affordable = affordable
	return quote


func _lines(text: String, font: Font = ThemeDB.fallback_font, width: float = NARROW_WIDTH) -> PackedStringArray:
	var paragraph: TextParagraph = TextParagraph.new()
	paragraph.add_string(text, font, FONT_SIZE)
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	var lines: PackedStringArray = PackedStringArray()
	for i in paragraph.get_line_count():
		var span: Vector2i = paragraph.get_line_range(i)
		lines.append(text.substr(span.x, span.y - span.x).strip_edges())
	return lines


func test_longest_cost_holds_on_one_line_of_the_button() -> void:
	# Arrange: the real row, in the narrowest pane (320 CSS px wide)
	var panel: CompanionPanel = auto_free((load("res://src/ui/companion_panel.tscn") as PackedScene).instantiate())
	add_child(panel)
	panel.size = Vector2(PANE_AT_320, 200)
	panel._add_row("scout")
	var button: Button = panel._rows[0]["button"]
	var cost: Label = panel._rows[0]["cost"]
	var font: Font = cost.get_theme_font("font")

	# Act
	var needed: float = font.get_string_size(CompanionPanel.keep_together(CompanionPanel.LONGEST_COST), HORIZONTAL_ALIGNMENT_LEFT, -1, CompanionPanel.FONT_SIZE_MAIN).x

	# Assert
	assert_float(button.custom_minimum_size.x - MARGINS).is_greater_equal(needed)
	assert_float(button.custom_minimum_size.x).is_less(PANE_AT_320 - LEAST_ROOM_FOR_THE_NAME)


func test_keep_together_leaves_no_plain_space() -> void:
	# Checked by its code: a copy of a file can turn U+00A0 into a plain space that looks the same.
	assert_str(CompanionPanel.NO_BREAK_SPACE).is_equal(char(0x00A0))
	assert_str(CompanionPanel.keep_together("960,3 B")).is_equal("960,3" + char(0x00A0) + "B")
	assert_bool(CompanionPanel.keep_together("960,3 B").contains(" ")).is_false()


func test_cost_stays_whole_on_its_line_and_the_gain_after_its_count() -> void:
	# Arrange: the real gain label of a row, and the room of its button
	var panel: CompanionPanel = auto_free((load("res://src/ui/companion_panel.tscn") as PackedScene).instantiate())
	add_child(panel)
	panel._add_row("scout")
	var button: Button = panel._rows[0]["button"]
	var gain: Label = panel._rows[0]["gain"]
	var box: StyleBox = button.get_theme_stylebox("disabled")
	var room: float = CompanionPanel.BUTTON_SIZE.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT)
	var lines: PackedStringArray = _panel.button_lines(5, _quote(true), BigNumber.from_int(GAIN))
	var cost: String = BigNumber.from_int(COST).format().replace(" ", CompanionPanel.NO_BREAK_SPACE)

	# Act: the bottom line in the room of the button
	var wrapped: PackedStringArray = _lines(lines[1], gain.get_theme_font("font"), room)

	# Assert: the cost alone on the top line; the gain whole on the last line, after the count
	assert_str(lines[0]).is_equal(cost)
	assert_int(wrapped.size()).is_less_equal(2)
	assert_str(wrapped[-1]).ends_with(CompanionPanel.gain_text(BigNumber.from_int(GAIN)))
	assert_str(lines[1]).starts_with(CompanionPanel.keep_together("×%d ·" % COUNT) + " ")
	assert_str(wrapped[0]).starts_with(CompanionPanel.keep_together("×%d ·" % COUNT))


func test_unaffordable_text_is_the_same_as_the_affordable_one() -> void:
	var gain: BigNumber = BigNumber.from_int(GAIN)
	assert_array(_panel.button_lines(5, _quote(false), gain)).is_equal(_panel.button_lines(5, _quote(true), gain))
