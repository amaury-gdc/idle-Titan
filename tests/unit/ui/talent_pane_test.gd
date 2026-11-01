extends GdUnitTestSuite
## Unit tests for the Talents tab: detail and confirmation of D5, what a locked node prints, one
## branch or the full tree by the width of the pane, the focus, and no width past the pane.
## Story: production/epics/idle-titans/story-011-management-tabs.md.

const SCENE: String = "res://src/ui/talent_screen.tscn"
const COMPACT: Vector2 = Vector2(348, 300)
const WIDE: Vector2 = Vector2(700, 500)
const STAGES_PER_POINT: int = 5
const STAGE_WITH_ONE_POINT: int = 5
const MIN_TARGET: float = 50.0

var _permanent: PermanentState
var _state: GameState
var _tree: TalentTree
var _screen: TalentScreen
var _bought: Array = []
var _resets: Array = []


func before_test() -> void:
	_permanent = PermanentState.new()
	_state = GameState.new()
	_state.stage = STAGE_WITH_ONE_POINT
	_state.max_stage_reached = STAGE_WITH_ONE_POINT
	_tree = TalentTree.from_data({
		"schema_version": TalentTree.SUPPORTED_SCHEMA,
		"stages_per_point": STAGES_PER_POINT,
		"branches": [{"id": "one", "name": "Compagnons"}, {"id": "two", "name": "Économie"}],
		"nodes": [
			_node("a", "one", 1, []),
			_node("b", "one", 1, ["a"]),
			_node("c", "two", 3, []),
		],
	}, _permanent, _state)
	assert_str(_tree.get_error()).is_empty()
	_tree.sync_best_stage()
	_screen = auto_free((load(SCENE) as PackedScene).instantiate())
	_screen.visible = true
	add_child(_screen)
	_bought = []
	_resets = []
	_screen.buy_requested.connect(func(id: String) -> void: _bought.append(id))
	_screen.reset_requested.connect(func() -> void: _resets.append(true))


func _node(id: String, branch: String, cost: int, requires: Array) -> Dictionary:
	return {"id": id, "branch": branch, "name": "Nom %s" % id, "cost": cost, "requires": requires,
			"effect": {"stat": TalentTree.STAT_CLICK_DAMAGE, "percent": 10}}


func _start(pane: Vector2) -> void:
	_screen.size = pane
	_screen.setup(_tree)


func _button(id: String) -> Button:
	return _screen._button_of(id)


func _focused() -> Control:
	return _screen.get_viewport().gui_get_focus_owner()


func _tree_of(branches: int, nodes_per_branch: int) -> TalentTree:
	var branch_list: Array = []
	var nodes: Array = []
	for b in branches:
		branch_list.append({"id": "b%d" % b, "name": "Branche %d" % b})
		for n in nodes_per_branch:
			nodes.append(_node("n%d_%d" % [b, n], "b%d" % b, 1, []))
	return TalentTree.from_data({"schema_version": TalentTree.SUPPORTED_SCHEMA, "stages_per_point": STAGES_PER_POINT,
			"branches": branch_list, "nodes": nodes}, _permanent, _state)


func test_compact_keeps_the_general_text_after_the_nodes() -> void:
	_start(COMPACT)
	assert_int(_screen._info_label.get_index()).is_greater(_screen._branches_box.get_index())


func test_wide_keeps_the_general_text_before_the_nodes() -> void:
	_start(WIDE)
	assert_int(_screen._info_label.get_index()).is_less(_screen._branches_box.get_index())


func test_text_order_follows_a_width_change() -> void:
	_start(COMPACT)
	_screen.size = WIDE
	assert_int(_screen._info_label.get_index()).is_less(_screen._branches_box.get_index())
	_screen.size = COMPACT
	assert_int(_screen._info_label.get_index()).is_greater(_screen._branches_box.get_index())


func test_column_title_is_only_for_the_full_tree() -> void:
	_start(COMPACT)
	assert_bool(_screen._column_titles[0].visible).is_false()
	_screen.size = WIDE
	assert_bool(_screen._column_titles[0].visible).is_true()


func test_wide_touched_node_stays_above_the_detail_band() -> void:
	# Arrange: a tree taller than the pane, and its last node
	_tree = _tree_of(1, 12)
	_screen.size = Vector2(WIDE.x, TalentScreen.WIDE_MIN_HEIGHT)
	_screen.setup(_tree)
	await await_idle_frame()
	await await_idle_frame()
	_button("n0_11").grab_focus(true)
	_screen._scroll.scroll_vertical = 0
	await await_idle_frame()

	# Act
	_button("n0_11").pressed.emit()
	await await_idle_frame()
	await await_idle_frame()
	await await_idle_frame()

	# Assert
	assert_float(_button("n0_11").get_global_rect().end.y).is_less_equal(_screen._scroll.get_global_rect().end.y + 1.0)


func test_confirmation_button_says_yes() -> void:
	_tree.buy("a")
	_start(COMPACT)
	_screen._reset_button.pressed.emit()
	assert_str(_screen._action_button.text).is_equal("Oui, réinitialiser")


func test_close_confirmation_leaves_a_node_detail_open() -> void:
	_start(COMPACT)
	_button("a").pressed.emit()
	_screen.close_confirmation()
	assert_int(_screen.detail()).is_equal(TalentScreen.Detail.NODE)


func test_close_confirmation_closes_the_question() -> void:
	_tree.buy("a")
	_start(COMPACT)
	_screen._reset_button.pressed.emit()
	_screen.close_confirmation()
	assert_bool(_screen.is_detail_open()).is_false()
	assert_array(_resets).is_empty()


func test_missing_points_are_singular_and_plural_exactly() -> void:
	_start(COMPACT)
	assert_str(_screen._missing_text(_tree.node("c"))).is_equal("Coût : 3 pts, manque 2 pts")
	_state.max_stage_reached = STAGE_WITH_ONE_POINT * 2
	_tree.sync_best_stage()
	assert_str(_screen._missing_text(_tree.node("c"))).is_equal("Coût : 3 pts, manque 1 pt")


func test_requirements_read_as_all_of_them() -> void:
	# Arrange: the tree asks for every prerequisite (TalentTree.prerequisites_met)
	_tree = TalentTree.from_data({"schema_version": TalentTree.SUPPORTED_SCHEMA, "stages_per_point": STAGES_PER_POINT,
			"branches": [{"id": "one", "name": "Branche"}],
			"nodes": [_node("a", "one", 1, []), _node("b", "one", 1, []), _node("c", "one", 1, []),
					_node("two", "one", 1, ["a", "b"]), _node("three", "one", 1, ["a", "b", "c"])]}, _permanent, _state)
	_start(COMPACT)

	# Act, Assert
	assert_str(_button("two").text).contains("Requiert : Nom a et Nom b")
	assert_str(_button("three").text).contains("Requiert : Nom a, Nom b et Nom c")


func test_refresh_if_stale_skips_a_redraw_when_nothing_moved() -> void:
	_start(COMPACT)
	_screen._points_label.text = "untouched"
	_screen.refresh_if_stale()
	assert_str(_screen._points_label.text).is_equal("untouched")


func test_refresh_if_stale_redraws_on_a_new_best_stage() -> void:
	_start(COMPACT)
	_state.max_stage_reached = STAGE_WITH_ONE_POINT * 2
	_tree.sync_best_stage()
	_screen.refresh_if_stale()
	assert_str(_screen._points_label.text).contains("2")


func test_more_branches_than_columns_can_hold_fall_back_on_one_branch() -> void:
	assert_bool(TalentScreen.fits_full_tree(WIDE, 3)).is_true()
	assert_bool(TalentScreen.fits_full_tree(WIDE, 6)).is_false()
	assert_bool(TalentScreen.fits_full_tree(Vector2(TalentScreen.full_tree_min_width(6), WIDE.y), 6)).is_true()


func test_six_branches_never_widen_the_tab() -> void:
	# Arrange
	_tree = _tree_of(6, 1)
	_screen.size = WIDE
	_screen.setup(_tree)

	# Act
	await await_idle_frame()
	await await_idle_frame()

	# Assert
	assert_bool(_screen.is_wide()).is_false()
	assert_float(_screen.get_combined_minimum_size().x).is_less_equal(WIDE.x)
	_screen.size = COMPACT
	await await_idle_frame()
	await await_idle_frame()
	assert_float(_screen.get_combined_minimum_size().x).is_less_equal(COMPACT.x)


func test_locked_node_prints_what_it_requires() -> void:
	_start(COMPACT)
	assert_str(_button("b").text).contains("Requiert : Nom a")


func test_touching_a_node_opens_its_detail_and_buys_nothing() -> void:
	_start(COMPACT)
	_button("a").pressed.emit()
	assert_int(_screen.detail()).is_equal(TalentScreen.Detail.NODE)
	assert_array(_bought).is_empty()


func test_action_buys_the_node_of_the_detail() -> void:
	_start(COMPACT)
	_button("a").pressed.emit()
	_screen._action_button.pressed.emit()
	assert_array(_bought).contains_exactly(["a"])


func test_locked_node_opens_a_detail_whose_action_is_disabled() -> void:
	_start(COMPACT)
	_button("b").pressed.emit()
	assert_bool(_screen.is_detail_open()).is_true()
	assert_bool(_screen._action_button.disabled).is_true()
	assert_str(_screen._detail_status.text).contains("Requiert : Nom a")


func test_compact_detail_replaces_the_tree() -> void:
	_start(COMPACT)
	_button("a").pressed.emit()
	assert_bool(_screen._scroll.visible).is_false()
	assert_bool(_screen._detail_panel.visible).is_true()
	assert_bool(_screen._back_button.visible).is_true()


func test_wide_detail_leaves_the_full_tree_visible() -> void:
	_start(WIDE)
	_button("a").pressed.emit()
	assert_bool(_screen._scroll.visible).is_true()
	assert_bool(_screen._detail_panel.visible).is_true()


func test_reset_asks_first_and_retour_cancels() -> void:
	_tree.buy("a")
	_start(COMPACT)
	_screen._reset_button.pressed.emit()
	assert_int(_screen.detail()).is_equal(TalentScreen.Detail.RESET)
	assert_array(_resets).is_empty()
	_screen.close_detail()
	assert_array(_resets).is_empty()
	assert_bool(_screen.is_detail_open()).is_false()


func test_confirmed_reset_is_reported_once_and_closes_the_detail() -> void:
	_tree.buy("a")
	_start(COMPACT)
	_screen._reset_button.pressed.emit()
	_screen._action_button.pressed.emit()
	assert_int(_resets.size()).is_equal(1)
	assert_bool(_screen.is_detail_open()).is_false()


func test_close_detail_without_a_detail_does_nothing() -> void:
	_start(COMPACT)
	assert_bool(_screen.close_detail()).is_false()


func test_under_640_one_branch_at_a_time_through_the_selector() -> void:
	_start(Vector2(ManagementTabs.DETAIL_WIDE_WIDTH - 1.0, 500))
	assert_bool(_screen._selector.visible).is_true()
	assert_bool(_button("a").is_visible_in_tree()).is_true()
	assert_bool(_button("c").is_visible_in_tree()).is_false()
	_screen._segments[1].pressed.emit()
	assert_bool(_button("a").is_visible_in_tree()).is_false()
	assert_bool(_button("c").is_visible_in_tree()).is_true()


func test_from_640_the_full_tree_without_a_selector() -> void:
	_start(Vector2(ManagementTabs.DETAIL_WIDE_WIDTH, 500))
	assert_bool(_screen._selector.visible).is_false()
	assert_bool(_button("a").is_visible_in_tree()).is_true()
	assert_bool(_button("c").is_visible_in_tree()).is_true()


func test_full_tree_needs_both_the_width_and_the_height() -> void:
	# 704x340 is the pane of a 900x900 browser window.
	var wide: float = ManagementTabs.DETAIL_WIDE_WIDTH
	var tall: float = TalentScreen.WIDE_MIN_HEIGHT
	assert_bool(TalentScreen.fits_full_tree(Vector2(704.0, 340.0))).is_false()
	assert_bool(TalentScreen.fits_full_tree(Vector2(wide, tall - 1.0))).is_false()
	assert_bool(TalentScreen.fits_full_tree(Vector2(wide - 1.0, tall))).is_false()
	assert_bool(TalentScreen.fits_full_tree(Vector2(wide, tall))).is_true()


func test_width_change_keeps_branch_and_detail() -> void:
	_start(COMPACT)
	_screen._segments[1].pressed.emit()
	_button("c").pressed.emit()
	_screen.size = WIDE
	_screen.size = COMPACT
	assert_int(_screen.open_branch()).is_equal(1)
	assert_int(_screen.detail()).is_equal(TalentScreen.Detail.NODE)


func test_detail_of_a_node_shows_its_branch_when_narrowing() -> void:
	_start(WIDE)
	_button("c").pressed.emit()
	_screen.size = COMPACT
	_screen.close_detail()
	assert_bool(_button("c").is_visible_in_tree()).is_true()


func test_buying_moves_the_focus_from_the_disabled_action_to_retour() -> void:
	_start(COMPACT)
	_button("a").pressed.emit()
	_screen._action_button.grab_focus()
	_tree.buy("a")
	_screen.refresh()
	assert_object(_focused()).is_same(_screen._back_button)


func test_close_detail_gives_the_focus_back_to_the_node() -> void:
	_start(COMPACT)
	_button("a").grab_focus()
	_button("a").pressed.emit()
	_screen.close_detail()
	assert_object(_focused()).is_same(_button("a"))


func test_reset_button_disabling_keeps_a_focus() -> void:
	_tree.buy("a")
	_start(COMPACT)
	_screen._reset_button.grab_focus()
	_tree.reset()
	_screen.refresh()
	assert_bool(_focused() != null and not _screen._reset_button.has_focus()).is_true()


func test_no_buyable_node_says_so() -> void:
	_tree.buy("a")  # the only point: "b" and "c" cannot be paid for
	_start(COMPACT)
	assert_str(_screen._empty_label.text).contains("Aucun talent achetable")
	assert_bool(_screen._empty_label.visible).is_true()


func test_buyable_node_hides_the_empty_text() -> void:
	_start(COMPACT)
	assert_bool(_screen._empty_label.visible).is_false()


func test_ends_of_the_tab_order_follow_the_detail() -> void:
	_start(COMPACT)
	assert_object(_screen.first_focus()).is_same(_screen._segments[0])
	_button("a").pressed.emit()
	assert_object(_screen.first_focus()).is_same(_screen._back_button)
	assert_object(_screen.last_focus()).is_same(_screen._action_button)


func test_does_not_stay_enabled_past_the_settings_modal() -> void:
	assert_int(_screen.focus_behavior_recursive).is_equal(Control.FOCUS_BEHAVIOR_INHERITED)


func test_nodes_pass_the_mouse_on_so_that_a_drag_scrolls() -> void:
	_start(COMPACT)
	assert_int(_button("a").mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)


func test_compact_branch_stays_inside_the_pane_and_scrolls_vertically() -> void:
	_start(COMPACT)
	await await_idle_frame()
	await await_idle_frame()
	assert_float(_screen.get_combined_minimum_size().x).is_less_equal(COMPACT.x)
	assert_float(_button("a").size.x).is_less_equal(COMPACT.x)
	assert_float(_button("a").size.y).is_greater_equal(MIN_TARGET)
	assert_float(_button("a").size.y).is_greater_equal(_button("a").get_combined_minimum_size().y)
	assert_int(_screen._scroll.horizontal_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_DISABLED)


func test_columns_of_the_full_tree_share_the_width_of_the_pane() -> void:
	_start(WIDE)
	await await_idle_frame()
	await await_idle_frame()
	var column_width: float = _screen._columns[0].size.x
	assert_float(column_width).is_equal_approx(_screen._columns[1].size.x, 1.0)
	_screen.size = Vector2(WIDE.x * 1.5, WIDE.y)
	await await_idle_frame()
	await await_idle_frame()
	assert_float(_screen._columns[0].size.x).is_greater(column_width)
