extends GdUnitTestSuite
## Unit tests for the contrast of the shared theme and the talent colours, read from the real
## resource: WCAG 2.1 AA, 4.5:1 for text (spec, Accessibility).
## Stories: production/archive/idle-titans/story-010-adaptive-layout.md,
## production/epics/idle-titans/story-019b-mobile-ui-refonte.md (colour tokens, focus ring).

const THEME_PATH: String = "res://src/ui/main_theme.tres"
const MIN_CONTRAST: float = 4.5
## WCAG 2.1 AA for what is not text.
const MIN_NON_TEXT_CONTRAST: float = 3.0
## Tolerance of a colour written with 6 decimals in the theme file.
const COLOR_TOLERANCE: float = 0.002
## Buttons whose fill carries a white text.
const WHITE_TEXT_BUTTONS: Array[String] = ["AwakenButton", "EquipButton", "ChallengeButton", "DangerButton"]
## Every (style, type) a focused control can sit on, and the panels around them.
const FOCUS_BACKGROUNDS: Array[Array] = [
	["normal", "Button"], ["hover", "Button"], ["disabled", "Button"],
	["normal", "BuyButton"], ["hover", "BuyButton"], ["pressed", "BuyButton"],
	["normal", "AwakenButton"], ["normal", "EquipButton"], ["normal", "ChallengeButton"],
	["normal", "DangerButton"], ["pressed", "TabButton"], ["pressed", "SegmentButton"],
	["normal", "TalentOwned"],
	["normal", "TalentBuyable"], ["normal", "TalentLocked"], ["panel", "HeaderPanel"],
	["panel", "ManagementPanel"],
]

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
	var texts: Dictionary = {"normal": "font_color", "hover": "font_hover_color", "pressed": "font_pressed_color"}
	for style: String in texts:
		assert_float(_contrast(_text(texts[style], "BuyButton"), _background(style, "BuyButton"))).is_greater_equal(MIN_CONTRAST)


func test_white_text_buttons_read_in_every_state() -> void:
	var text: Color = _text("font_color", "Button")
	for type: String in WHITE_TEXT_BUTTONS:
		for style: String in ["normal", "hover", "pressed"]:
			assert_float(_contrast(text, _background(style, type))).is_greater_equal(MIN_CONTRAST)


func test_corner_buttons_read_in_every_state() -> void:
	var text: Color = _text("font_color", "Button")
	for type: String in ["CornerChallenge", "CornerButton", "CornerConfirm"]:
		for style: String in ["normal", "hover", "pressed"]:
			assert_float(_contrast(text, _background(style, type))).override_failure_message(type + "/" + style).is_greater_equal(MIN_CONTRAST)


func test_corner_is_drawn_44_units_in_a_touch_area_of_50() -> void:
	# The corner of GameZone is 50 u tall; its styles draw 3 u less above and below (story 019b).
	for type: String in ["CornerChallenge", "CornerButton", "CornerConfirm"]:
		for style: String in ["normal", "hover", "pressed"]:
			var box: StyleBoxFlat = _theme.get_stylebox(style, type)
			var drawn: float = GameZone.CORNER_HEIGHT + box.expand_margin_top + box.expand_margin_bottom
			assert_float(drawn).override_failure_message(type + "/" + style).is_equal(44.0)


func test_confirm_state_is_told_by_a_white_edge_too() -> void:
	var confirm: StyleBoxFlat = _theme.get_stylebox("normal", "CornerConfirm")
	var neutral: StyleBoxFlat = _theme.get_stylebox("normal", "CornerButton")
	assert_int(confirm.border_width_top).is_greater(neutral.border_width_top)
	assert_float(_contrast(confirm.border_color, UiPalette.PANEL)).is_greater_equal(MIN_NON_TEXT_CONTRAST)


func test_enabled_button_keeps_a_light_text() -> void:
	# The muted grey belongs to the disabled state only (story 019b): an enabled button stays light.
	assert_bool(_text("font_disabled_color", "Button").is_equal_approx(UiPalette.TEXT_DISABLED)).is_true()
	for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		var text: Color = _text(item, "Button")
		assert_float(_luminance(text)).is_greater(_luminance(UiPalette.TEXT_DISABLED))
		assert_float(_contrast(text, _background("normal", "Button"))).is_greater_equal(MIN_CONTRAST)


func test_focus_ring_shows_on_every_background() -> void:
	# The ring is white with a dark shadow: on a light fill (yellow) the shadow is what shows.
	var ring: StyleBoxFlat = _theme.get_stylebox("focus", "Button")
	assert_bool(ring.draw_center).is_false()
	assert_int(ring.border_width_top).is_greater_equal(2)
	assert_int(ring.shadow_size).is_greater(0)
	for pair: Array in FOCUS_BACKGROUNDS:
		var fill: Color = _background(pair[0], pair[1])
		var best: float = maxf(_contrast(ring.border_color, fill), _contrast(ring.shadow_color, fill))
		assert_float(best).override_failure_message("ring on %s/%s" % [pair[1], pair[0]]).is_greater_equal(MIN_NON_TEXT_CONTRAST)
	# The cards of the lists (story 019b) are drawn on the row colours, not on a theme style.
	for fill: Color in [UiPalette.ROW, UiPalette.ROW_HOVER]:
		var best: float = maxf(_contrast(ring.border_color, fill), _contrast(ring.shadow_color, fill))
		assert_float(best).override_failure_message("ring on %s" % fill).is_greater_equal(MIN_NON_TEXT_CONTRAST)


func test_hp_text_reads_on_the_gauge() -> void:
	assert_float(_contrast(Color.WHITE, UiPalette.HP_RED)).is_greater_equal(MIN_CONTRAST)
	assert_float(_contrast(UiPalette.HP_RED, UiPalette.HP_BACK)).is_greater_equal(MIN_NON_TEXT_CONTRAST)


func test_theme_matches_the_palette() -> void:
	var pairs: Array[Array] = [
		[_background("panel", "HeaderPanel"), UiPalette.BACKGROUND],
		[_background("panel", "ManagementPanel"), UiPalette.PANEL],
		[_background("normal", "Button"), UiPalette.BUTTON],
		[_background("normal", "BuyButton"), UiPalette.YELLOW],
		[_text("font_color", "BuyButton"), UiPalette.ON_YELLOW],
		[_background("normal", "AwakenButton"), UiPalette.VIOLET],
		[_background("normal", "EquipButton"), UiPalette.GREEN],
		[_background("normal", "ChallengeButton"), UiPalette.RED],
		[_background("panel", "DotPanel"), UiPalette.RED],
		[_background("normal", "TalentOwned"), UiPalette.OWNED_BG],
		[_text("font_color", "PaneText"), UiPalette.TEXT_MUTED],
	]
	for pair: Array in pairs:
		var got: Color = pair[0]
		var want: Color = pair[1]
		for channel: int in 3:
			assert_float(got[channel]).is_equal_approx(want[channel], COLOR_TOLERANCE)


func test_buy_hover_is_darker_than_normal() -> void:
	assert_float(_luminance(_background("hover", "BuyButton"))).is_less(_luminance(_background("normal", "BuyButton")))


func test_buy_state_is_told_by_a_border_too() -> void:
	var enabled: StyleBoxFlat = _theme.get_stylebox("normal", "BuyButton")
	var disabled: StyleBoxFlat = _theme.get_stylebox("disabled", "Button")
	assert_int(enabled.border_width_top).is_greater(0)
	assert_int(disabled.border_width_top).is_equal(0)


func test_tier_bar_fill_stands_out_of_its_background() -> void:
	var fill: Color = _background("fill", "TierBar")
	assert_float(_contrast(fill, _background("background", "TierBar"))).is_greater_equal(MIN_NON_TEXT_CONTRAST)


func test_disabled_text_carrying_a_cost_reads() -> void:
	assert_float(_contrast(_text("font_disabled_color", "Button"), _background("disabled", "Button"))).is_greater_equal(MIN_CONTRAST)


func test_active_skill_text_reads() -> void:
	assert_float(_contrast(_text("font_disabled_color", "SkillActive"), _background("disabled", "SkillActive"))).is_greater_equal(MIN_CONTRAST)


func test_skill_orb_rings_stand_out() -> void:
	# The ready ring on the game zone, the arcs on their track (story 019b, lot 4).
	assert_float(_contrast(UiPalette.YELLOW, UiPalette.PANEL)).is_greater_equal(MIN_NON_TEXT_CONTRAST)
	assert_float(_contrast(UiPalette.YELLOW, UiPalette.BUTTON)).is_greater_equal(MIN_NON_TEXT_CONTRAST)
	assert_float(_contrast(UiPalette.TEXT_MUTED, UiPalette.BUTTON)).is_greater_equal(MIN_NON_TEXT_CONTRAST)


func test_skill_orb_icons_stand_out_of_the_round() -> void:
	for icon: Color in [Color.WHITE, UiPalette.TEXT_MUTED, UiPalette.TEXT_DISABLED]:
		for round_fill: Color in [UiPalette.ROW, UiPalette.ROW_HOVER]:
			assert_float(_contrast(icon, round_fill)).is_greater_equal(MIN_NON_TEXT_CONTRAST)


func test_skill_orb_seconds_read() -> void:
	assert_float(_contrast(UiPalette.ON_YELLOW, UiPalette.YELLOW)).is_greater_equal(MIN_CONTRAST)
	assert_float(_contrast(Color.WHITE, UiPalette.BACKGROUND)).is_greater_equal(MIN_CONTRAST)


func test_tab_colours_stand_out_of_the_bar_and_of_the_open_tab() -> void:
	# Icons and stripes of the bottom tabs (story 019b, lot 5).
	for tab: int in ManagementTabs.Tab.values():
		var color: Color = ManagementTabs.tab_color(tab)
		# A closed tab is drawn with the style of Button: the theme resource does not follow base types.
		for fill: Color in [_background("normal", "Button"), _background("pressed", "TabButton"), UiPalette.PANEL]:
			assert_float(_contrast(color, fill)).is_greater_equal(MIN_NON_TEXT_CONTRAST)


func test_tab_labels_read_open_and_closed() -> void:
	assert_float(_contrast(UiPalette.TEXT_SOFT, _background("pressed", "TabButton"))).is_greater_equal(MIN_CONTRAST)
	assert_float(_contrast(UiPalette.TEXT_MUTED, _background("normal", "Button"))).is_greater_equal(MIN_CONTRAST)


func test_talent_count_reads_on_the_dot() -> void:
	# The number is white (main_screen.tscn, TalentsCount; checked in panel_shell_test.gd).
	assert_float(_contrast(Color.WHITE, _background("panel", "DotPanel"))).is_greater_equal(MIN_CONTRAST)


func test_pane_header_reads() -> void:
	# "DPS des souris" and its value on the panel, "Achat ×N" on its fill, its blue edge on the panel.
	assert_float(_contrast(UiPalette.TEXT_MUTED, UiPalette.PANEL)).is_greater_equal(MIN_CONTRAST)
	assert_float(_contrast(CompanionPanel.COLOR_DAMAGE, UiPalette.PANEL)).is_greater_equal(MIN_CONTRAST)
	assert_float(_contrast(CompanionPanel.COLOR_DAMAGE, UiPalette.ROW_HOVER)).is_greater_equal(MIN_CONTRAST)
	for fill: Color in [UiPalette.BUTTON, UiPalette.BUTTON_HOVER, UiPalette.ROW]:
		assert_float(_contrast(_text("font_color", "Button"), fill)).is_greater_equal(MIN_CONTRAST)
	assert_float(_contrast(UiPalette.BLUE, UiPalette.PANEL)).is_greater_equal(MIN_NON_TEXT_CONTRAST)


func test_companion_card_texts_read() -> void:
	# Story 019b, lot 6: on the card (ROW) the level in blue, the grey lines, the violet line of a
	# threshold and the rank; in the button its two lines in each state.
	for text: Color in [Color.WHITE, UiPalette.BLUE, UiPalette.TEXT_MUTED, UiPalette.VIOLET_EDGE, CompanionPanel.COLOR_RANK]:
		assert_float(_contrast(text, UiPalette.ROW)).is_greater_equal(MIN_CONTRAST)
	assert_float(_contrast(UiPalette.ON_YELLOW, _background("normal", "BuyButton"))).is_greater_equal(MIN_CONTRAST)
	assert_float(_contrast(UiPalette.TEXT_DISABLED, _background("disabled", "Button"))).is_greater_equal(MIN_CONTRAST)
	assert_float(_contrast(Color.WHITE, _background("normal", "AwakenButton"))).is_greater_equal(MIN_CONTRAST)
	# "Max": the grey text on the dark outlined button, its edge on the card.
	assert_float(_contrast(UiPalette.TEXT_DISABLED, UiPalette.PANEL)).is_greater_equal(MIN_CONTRAST)
	assert_float(_contrast(UiPalette.TEXT_DISABLED, UiPalette.ROW)).is_greater_equal(MIN_NON_TEXT_CONTRAST)


func test_awakening_edge_stands_out_of_the_card_and_the_list() -> void:
	assert_float(_contrast(UiPalette.VIOLET_EDGE, UiPalette.ROW)).is_greater_equal(MIN_NON_TEXT_CONTRAST)
	assert_float(_contrast(UiPalette.VIOLET_EDGE, UiPalette.PANEL)).is_greater_equal(MIN_NON_TEXT_CONTRAST)


func test_item_cards_and_slots_read() -> void:
	# Story 019b, lot 7: the rarity words on the card, the grey line, the bag count, "Équiper".
	for rarity: Color in InventoryScreen.RARITY_COLORS.values():
		assert_float(_contrast(rarity, UiPalette.ROW)).is_greater_equal(MIN_CONTRAST)
		# The band, the edge of a slot and its dots stand out of the card and the header.
		assert_float(_contrast(rarity, UiPalette.PANEL)).is_greater_equal(MIN_NON_TEXT_CONTRAST)
		assert_float(_contrast(rarity, UiPalette.BACKGROUND)).is_greater_equal(MIN_NON_TEXT_CONTRAST)
	assert_float(_contrast(UiPalette.TEXT_MUTED, UiPalette.ROW)).is_greater_equal(MIN_CONTRAST)
	assert_float(_contrast(UiPalette.YELLOW, UiPalette.PANEL)).is_greater_equal(MIN_CONTRAST)
	assert_float(_contrast(_text("font_color", "Button"), _background("normal", "EquipButton"))).is_greater_equal(MIN_CONTRAST)
	# An empty slot: its grey icon on the slot.
	assert_float(_contrast(UiPalette.TEXT_DISABLED, UiPalette.ROW)).is_greater_equal(MIN_NON_TEXT_CONTRAST)


func test_panel_handle_bar_stands_out() -> void:
	assert_float(_contrast(UiPalette.TEXT_MUTED, UiPalette.PANEL)).is_greater_equal(MIN_NON_TEXT_CONTRAST)


func test_selected_segment_is_inverted_and_reads() -> void:
	var fill: Color = _background("pressed", "SegmentButton")
	assert_float(_contrast(_text("font_pressed_color", "SegmentButton"), fill)).is_greater_equal(MIN_CONTRAST)
	assert_float(_luminance(fill)).is_greater(_luminance(_background("normal", "Button")))


func test_selected_tab_has_a_bar_and_reads() -> void:
	var selected: StyleBoxFlat = _theme.get_stylebox("pressed", "TabButton")
	assert_int(selected.border_width_top).is_greater(0)
	assert_float(_contrast(_text("font_pressed_color", "TabButton"), selected.bg_color)).is_greater_equal(MIN_CONTRAST)


func test_notification_dot_has_an_edge_that_reads() -> void:
	var dot: StyleBoxFlat = _theme.get_stylebox("panel", "DotPanel")
	assert_int(dot.border_width_top).is_greater(0)
	assert_float(_contrast(dot.bg_color, dot.border_color)).is_greater_equal(MIN_CONTRAST)


func test_notification_dot_edge_stands_out_of_the_tabs() -> void:
	# Red on the dark tab bar is under 3:1 (2.59): the light edge is what makes the dot visible.
	var dot: StyleBoxFlat = _theme.get_stylebox("panel", "DotPanel")
	for fill: Color in [_background("panel", "ManagementPanel"), _background("pressed", "TabButton")]:
		assert_float(_contrast(dot.border_color, fill)).is_greater_equal(MIN_NON_TEXT_CONTRAST)


func test_talent_header_and_tiers_read() -> void:
	# Story 019b, lot 8: the yellow number and the tier progress on the panel, "Réinitialiser" and its
	# grey edge, the lock of a closed tier, the check of a bought tile on its fill and when selected.
	for text: Color in [UiPalette.YELLOW, UiPalette.TEXT_MUTED, Color.WHITE]:
		assert_float(_contrast(text, UiPalette.PANEL)).is_greater_equal(MIN_CONTRAST)
	for fill: Color in [UiPalette.BUTTON, UiPalette.BUTTON_HOVER, UiPalette.ROW]:
		assert_float(_contrast(_text("font_color", "Button"), fill)).is_greater_equal(MIN_CONTRAST)
	assert_float(_contrast(UiPalette.TEXT_MUTED, UiPalette.PANEL)).is_greater_equal(MIN_NON_TEXT_CONTRAST)
	for style: String in ["normal", "hover", "pressed"]:
		assert_float(_contrast(TalentTile.CHECK_COLOR, _background(style, "TalentOwned"))).is_greater_equal(MIN_NON_TEXT_CONTRAST)


func test_talent_states_read() -> void:
	for type: String in ["TalentBuyable", "TalentOwned", "TalentUnaffordable", "TalentLocked"]:
		for style: String in ["normal", "hover", "pressed"]:
			assert_float(_contrast(_text("font_color", type), _background(style, type))).is_greater_equal(MIN_CONTRAST)

