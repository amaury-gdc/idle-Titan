extends GdUnitTestSuite
## Unit tests for the shell of the management panel (story 019b, lot 5): the handle that collapses
## and unfolds it (touch, keyboard, the free part of a header, a tab), the hidden contents and the
## Tab order while collapsed, the landscape without a handle, the touch zones of the header (the
## free part never covers "DPS des souris" nor "Achat ×N"), and a list that keeps its scroll.
## The real scene without its script, as in management_tabs_test.gd.
## Story: production/epics/idle-titans/story-019b-mobile-ui-refonte.md

const SCENE: String = "res://src/ui/main_screen.tscn"
const STAGES_PER_POINT: int = 5
## A portrait screen of 390 x 742 units, and the same with a browser bar that came back.
const PORTRAIT: Vector2 = Vector2(390.0, 742.0)
const PORTRAIT_WITH_BAR: Vector2 = Vector2(390.0, 693.0)
const SCROLLED: int = 40

var _root: Control
var _tabs: ManagementTabs
var _handle: PanelHandle
var _panel: CompanionPanel
var _before: Button
var _after: Button
var _reports: Array = []


func before_test() -> void:
	_root = auto_free((load(SCENE) as PackedScene).instantiate())
	_root.set_script(null)
	add_child(_root)
	# Sized by hand: the full-rect anchors of the scene would override the size.
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.size = PORTRAIT
	(_root.find_child("Split", true, false) as BoxContainer).vertical = true
	_tabs = _root.find_child("ManagementTabs", true, false)
	_handle = _root.find_child("PanelHandle", true, false)
	_panel = _root.find_child("CompanionPanel", true, false)
	var state: GameState = GameState.new()
	state.max_stage_reached = STAGES_PER_POINT
	var tree: TalentTree = TalentTree.from_data({
		"schema_version": TalentTree.SUPPORTED_SCHEMA,
		"stages_per_point": STAGES_PER_POINT,
		"branches": [{"id": "one", "name": "Branche"}],
		"nodes": [{"id": "a", "branch": "one", "name": "Nom", "cost": 1, "requires": [],
				"effect": {"stat": TalentTree.STAT_CLICK_DAMAGE, "percent": 10}}],
	}, PermanentState.new(), state)
	(_root.find_child("TalentScreen", true, false) as TalentScreen).setup(tree)
	var curves: Variant = DataLoader.load_json("res://assets/data/core_curves.json")
	var combat: Combat = Combat.from_data(curves, DataLoader.load_json("res://assets/data/companions_roster.json"))
	var companions: CompanionManager = CompanionManager.new(state, combat, FloorManager.new(state, combat))
	_panel.setup(companions, func() -> BigNumber: return state.gold)
	_before = Button.new()
	_after = Button.new()
	_root.add_child(_before)
	_root.add_child(_after)
	_tabs.link_focus(_before, _after)
	_tabs.set_handle_enabled(true)
	_reports = []
	_tabs.collapsed_changed.connect(func(collapsed: bool) -> void: _reports.append(collapsed))


func _contents() -> Array[Control]:
	return [_panel, _root.find_child("InventoryScreen", true, false), _root.find_child("TalentScreen", true, false)]


func _laid_out() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


# The handle and the other ways in

func test_handle_collapses_the_panel_and_reports_it() -> void:
	# Act
	_handle.pressed.emit()

	# Assert
	assert_bool(_tabs.is_collapsed()).is_true()
	assert_array(_reports).contains_exactly([true])
	for content: Control in _contents():
		assert_bool(content.visible).is_false()
	assert_bool(_handle.is_collapsed()).is_true()
	assert_str(_handle.accessibility_name).is_equal("Déployer le panneau")


func test_second_press_unfolds_the_open_tab() -> void:
	_handle.pressed.emit()
	_handle.pressed.emit()
	assert_bool(_tabs.is_collapsed()).is_false()
	assert_array(_reports).contains_exactly([true, false])
	assert_bool(_panel.visible).is_true()
	assert_str(_handle.accessibility_name).is_equal("Replier le panneau")


func test_enter_on_the_focused_handle_collapses_the_panel() -> void:
	# Arrange
	await _laid_out()
	_handle.grab_focus()

	# Act
	for pressed: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		get_viewport().push_input(key)

	# Assert
	assert_bool(_tabs.is_collapsed()).is_true()


func test_free_part_of_a_header_collapses_the_panel() -> void:
	_panel.pane_header().free_part().pressed.emit()
	assert_bool(_tabs.is_collapsed()).is_true()


func test_touching_a_tab_of_a_collapsed_panel_unfolds_it_on_that_tab() -> void:
	# Arrange
	_handle.pressed.emit()

	# Act
	(_root.find_child("InventoryButton", true, false) as Button).pressed.emit()

	# Assert
	assert_bool(_tabs.is_collapsed()).is_false()
	assert_int(_tabs.selected()).is_equal(ManagementTabs.Tab.INVENTORY)
	assert_bool((_root.find_child("InventoryScreen", true, false) as Control).visible).is_true()
	assert_array(_reports).contains_exactly([true, false])


func test_collapsed_handle_grows_to_a_touch_target() -> void:
	assert_float(_handle.custom_minimum_size.y).is_equal(AdaptiveLayout.HANDLE_HEIGHT)
	_handle.pressed.emit()
	assert_float(_handle.custom_minimum_size.y).is_equal(AdaptiveLayout.HANDLE_COLLAPSED_HEIGHT)
	assert_float(_handle.custom_minimum_size.y).is_greater_equal(GameZone.BUTTON_HEIGHT)


func test_stored_choice_is_shown_without_being_reported() -> void:
	_tabs.set_collapsed(true)
	assert_bool(_tabs.is_collapsed()).is_true()
	assert_array(_reports).is_empty()


# Focus

func test_collapsed_panel_leaves_no_hidden_control_in_the_tab_order() -> void:
	# Arrange
	_handle.pressed.emit()

	# Act: walk the Tab order from the game zone to the header
	var walked: Array[Control] = []
	var at: Control = _before
	for i in 4:
		at = at.get_node(at.focus_next)
		walked.append(at)
		if at == _after:
			break

	# Assert: the handle, the open tab, then out of the panel
	assert_array(walked).contains_exactly([_handle, _root.find_child("CompanionsTabButton", true, false), _after])
	for content: Control in _contents():
		assert_bool(content.is_visible_in_tree()).is_false()


func test_unfolded_panel_goes_from_the_tab_to_the_header() -> void:
	var tab: Button = _root.find_child("CompanionsTabButton", true, false)
	assert_object(_before.get_node(_before.focus_next)).is_same(_handle)
	assert_object(_handle.get_node(_handle.focus_next)).is_same(tab)
	assert_object(tab.get_node(tab.focus_next)).is_same(_panel.squad_dps_button())


# Landscape

func test_landscape_hides_the_handle_and_shows_the_panel_open() -> void:
	# Arrange: collapsed in portrait
	_handle.pressed.emit()

	# Act
	_tabs.set_handle_enabled(false)

	# Assert: open, and the choice kept for the next portrait
	assert_bool(_handle.visible).is_false()
	assert_bool(_tabs.is_collapsed()).is_false()
	assert_bool(_panel.visible).is_true()
	_tabs.set_handle_enabled(true)
	assert_bool(_tabs.is_collapsed()).is_true()


func test_landscape_ignores_the_free_part_of_a_header() -> void:
	_tabs.set_handle_enabled(false)
	_panel.pane_header().free_part().pressed.emit()
	assert_bool(_tabs.is_collapsed()).is_false()
	assert_array(_reports).is_empty()


# Touch zones of the header

func test_free_part_never_covers_the_dps_nor_the_buy_mode_button() -> void:
	# Arrange
	await _laid_out()
	var free: Rect2 = _panel.pane_header().free_part().get_global_rect()
	var squad: HeaderButton = _panel.squad_dps_button() as HeaderButton
	var mode: HeaderButton = _panel.get("_mode_button")

	# Assert: the touch zones, grown upwards, apart from the free part
	for button: HeaderButton in [squad, mode]:
		var zone: Rect2 = Rect2(button.global_position + button.touch_rect().position, button.touch_rect().size)
		assert_bool(zone.intersects(free)).override_failure_message(button.name).is_false()
	assert_float(free.size.x).is_greater(0.0)


func test_header_buttons_are_touched_over_50_units() -> void:
	await _laid_out()
	for button: HeaderButton in [_panel.squad_dps_button() as HeaderButton, _panel.get("_mode_button") as HeaderButton]:
		assert_float(button.size.y).is_equal(AdaptiveLayout.PANE_HEADER_HEIGHT)
		assert_float(button.touch_rect().size.y).is_greater_equal(GameZone.BUTTON_HEIGHT)
		assert_bool(button._has_point(Vector2(1.0, -HeaderButton.TOUCH_GROW_UP + 0.5))).is_true()


func test_dps_of_the_mice_reports_a_press() -> void:
	var pressed: Array = []
	_panel.squad_dps_pressed.connect(func() -> void: pressed.append(true))
	_panel.squad_dps_button().pressed.emit()
	assert_array(pressed).has_size(1)


func test_dps_of_the_mice_shows_its_value_and_says_it_opens_the_detail() -> void:
	_panel.set_squad_dps("19,4 Qa")
	assert_str((_panel.find_child("SquadDpsValue", true, false) as Label).text).is_equal("19,4 Qa")
	assert_str(_panel.squad_dps_button().accessibility_name).contains("Détail du DPS")


# Scroll

func test_list_keeps_its_scroll_through_a_collapse() -> void:
	# Arrange
	await _laid_out()
	var scroll: ScrollContainer = _panel.get("_scroll")
	scroll.scroll_vertical = SCROLLED
	await _laid_out()
	var before: int = scroll.scroll_vertical

	# Act
	_handle.pressed.emit()
	await _laid_out()
	_handle.pressed.emit()
	await _laid_out()

	# Assert
	assert_int(before).is_equal(SCROLLED)
	assert_int(scroll.scroll_vertical).is_equal(SCROLLED)


func test_list_keeps_its_scroll_when_the_browser_bar_comes_back() -> void:
	# Arrange
	await _laid_out()
	var scroll: ScrollContainer = _panel.get("_scroll")
	scroll.scroll_vertical = SCROLLED
	await _laid_out()

	# Act: the screen loses the height of the bar
	_root.size = PORTRAIT_WITH_BAR
	await _laid_out()

	# Assert
	assert_int(scroll.scroll_vertical).is_equal(SCROLLED)
	assert_bool(_tabs.is_collapsed()).is_false()


# Bottom tabs

func test_tabs_read_souris_objets_talents_with_their_icons() -> void:
	var labels: Array = ["CompanionsLabel", "InventoryLabel", "TalentsLabel"].map(
			func(n: String) -> String: return (_root.find_child(n, true, false) as Label).text)
	assert_array(labels).contains_exactly(["Souris", "Objets", "Talents"])
	assert_int((_root.find_child("CompanionsIcon", true, false) as UiIcon).kind).is_equal(UiIcon.Kind.MOUSE)
	assert_int((_root.find_child("InventoryIcon", true, false) as UiIcon).kind).is_equal(UiIcon.Kind.SHIELD)
	assert_int((_root.find_child("TalentsIcon", true, false) as UiIcon).kind).is_equal(UiIcon.Kind.STAR)


func test_talents_dot_carries_the_number_of_points() -> void:
	_tabs.set_talent_points(21)
	var count: Label = _root.find_child("TalentsCount", true, false)
	assert_str(count.text).is_equal("21")
	assert_bool(count.get_theme_color(&"font_color").is_equal_approx(Color.WHITE)).is_true()
	assert_str((_root.find_child("TalentsButton", true, false) as Button).accessibility_name).is_equal("Talents, 21 points")


func test_talents_dot_stays_while_points_are_left_and_goes_with_them() -> void:
	# Arrange: the news dot is off, as after a visit of the tab
	var dot: Control = _root.find_child("TalentsDot", true, false)
	_tabs.set_dot(ManagementTabs.Tab.TALENTS, false)

	# Act / Assert
	_tabs.set_talent_points(3)
	assert_bool(dot.visible).is_true()
	_tabs.set_talent_points(0)
	assert_bool(dot.visible).is_false()
	_tabs.set_dot(ManagementTabs.Tab.TALENTS, true)
	assert_bool(dot.visible).is_true()


func test_open_tab_has_a_stripe_of_its_colour() -> void:
	for tab: int in ManagementTabs.Tab.values():
		var button: Button = _tabs._button_of(tab)
		var stripe: StyleBoxFlat = button.get_theme_stylebox(&"pressed")
		assert_int(stripe.border_width_top).is_greater(0)
		assert_bool(stripe.border_color.is_equal_approx(ManagementTabs.tab_color(tab))).is_true()
