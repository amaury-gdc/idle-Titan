extends GdUnitTestSuite
## Unit tests for the contrast of the shared theme and the talent colours, read from the real
## resource: WCAG 2.1 AA, 4.5:1 for text (spec, Accessibility).
## Story: production/epics/idle-titans/story-010-adaptive-layout.md.

const THEME_PATH: String = "res://src/ui/main_theme.tres"
const MIN_CONTRAST: float = 4.5

var _theme: Theme


func before_test() -> void:
	_theme = load(THEME_PATH)


func _luminance(color: Color) -> float:
	var linear: Color = color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b


func _contrast(a: Color, b: Color) -> float:
	var light: float = maxf(_luminance(a), _luminance(b))
	var dark: float = minf(_luminance(a), _luminance(b))
	return (light + 0.05) / (dark + 0.05)


func _background(style: String, type: String) -> Color:
	return (_theme.get_stylebox(style, type) as StyleBoxFlat).bg_color


func _text(item: String, type: String) -> Color:
	return _theme.get_color(item, type)


func test_contrast_formula_black_on_white_is_21() -> void:
	assert_float(_contrast(Color.BLACK, Color.WHITE)).is_equal_approx(21.0, 0.01)


func test_buy_button_text_reads_in_every_state() -> void:
	var text: Color = _text("font_color", "Button")
	for style: String in ["normal", "hover", "pressed"]:
		assert_float(_contrast(text, _background(style, "BuyButton"))).is_greater_equal(MIN_CONTRAST)


func test_buy_hover_is_darker_than_normal() -> void:
	assert_float(_luminance(_background("hover", "BuyButton"))).is_less(_luminance(_background("normal", "BuyButton")))


func test_buy_state_is_told_by_a_border_too() -> void:
	var enabled: StyleBoxFlat = _theme.get_stylebox("normal", "BuyButton")
	var disabled: StyleBoxFlat = _theme.get_stylebox("disabled", "Button")
	assert_int(enabled.border_width_top).is_greater(0)
	assert_int(disabled.border_width_top).is_equal(0)


func test_disabled_text_carrying_a_cost_reads() -> void:
	assert_float(_contrast(_text("font_disabled_color", "Button"), _background("disabled", "Button"))).is_greater_equal(MIN_CONTRAST)


func test_active_skill_text_reads() -> void:
	assert_float(_contrast(_text("font_disabled_color", "SkillActive"), _background("disabled", "SkillActive"))).is_greater_equal(MIN_CONTRAST)


func test_selected_segment_is_inverted_and_reads() -> void:
	var fill: Color = _background("pressed", "SegmentButton")
	assert_float(_contrast(_text("font_pressed_color", "SegmentButton"), fill)).is_greater_equal(MIN_CONTRAST)
	assert_float(_luminance(fill)).is_greater(_luminance(_background("normal", "Button")))


func test_selected_tab_has_a_bar_and_reads() -> void:
	var selected: StyleBoxFlat = _theme.get_stylebox("pressed", "TabButton")
	assert_int(selected.border_width_top).is_greater(0)
	assert_float(_contrast(_text("font_pressed_color", "TabButton"), selected.bg_color)).is_greater_equal(MIN_CONTRAST)


func test_notification_dot_has_a_dark_edge() -> void:
	var dot: StyleBoxFlat = _theme.get_stylebox("panel", "DotPanel")
	assert_int(dot.border_width_top).is_greater(0)
	assert_float(_contrast(dot.bg_color, dot.border_color)).is_greater_equal(MIN_CONTRAST)


func test_talent_states_read() -> void:
	for type: String in ["TalentBuyable", "TalentOwned", "TalentUnaffordable", "TalentLocked"]:
		for style: String in ["normal", "hover", "pressed"]:
			assert_float(_contrast(_text("font_color", type), _background(style, type))).is_greater_equal(MIN_CONTRAST)


func test_item_rows_read_in_every_state() -> void:
	for type: String in ["ItemRow", "ItemRowCommon", "ItemRowRare", "ItemRowLegendary"]:
		for style: String in ["normal", "hover", "pressed"]:
			assert_float(_contrast(_text("font_color", type), _background(style, type))).is_greater_equal(MIN_CONTRAST)
	assert_float(_contrast(_text("font_disabled_color", "ItemRow"), _background("disabled", "ItemRow"))).is_greater_equal(MIN_CONTRAST)
