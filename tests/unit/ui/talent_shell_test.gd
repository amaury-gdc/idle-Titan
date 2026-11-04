extends GdUnitTestSuite
## Unit tests for the Talents tab in the panel of story 019b, lot 8: the 46 u header ("N points à
## dépenser", the words on two lines only when one does not fit, "Réinitialiser" touched over 50 u,
## the free part that covers neither), the tier headers (progress and lock), and the tiles (64 u at
## least, the check of a bought node, the real cost of a closed one).
## Story: production/epics/idle-titans/story-019b-mobile-ui-refonte.md

const SCENE: String = "res://src/ui/talent_screen.tscn"
## The pane at 390 u wide (portrait reference) and at 320 u, less the panel's own margins.
const PANE_390: Vector2 = Vector2(374, 420)
const PANE_320: Vector2 = Vector2(304, 380)
const TREE_VERSION: int = 1
## 20 points at stage 100; 1 point at stage 5.
const STAGE_WITH_POINTS: int = 100
const STAGE_WITH_ONE_POINT: int = 5
const NOW: int = 1_000_000
const TEN_DAYS: int = 864_000
const MIN_TOUCH: float = 50.0

var _state: GameState
var _permanent: PermanentState
var _tree: TalentTree
var _screen: TalentScreen


func before_test() -> void:
	_state = GameState.new()
	_state.max_stage_reached = STAGE_WITH_POINTS
	_permanent = PermanentState.new()
	_permanent.talent_tree_seen = TREE_VERSION
	_tree = TalentTree.from_data(DataLoader.load_json("res://assets/data/talents.json"), _permanent, _state)
	assert_str(_tree.get_error()).is_empty()
	_screen = auto_free((load(SCENE) as PackedScene).instantiate())
	_screen.visible = true
	add_child(_screen)


func _start(pane: Vector2) -> void:
	_screen.set_context(null, 12.0, func() -> int: return NOW, func() -> bool: return false)
	_screen.size = pane
	_screen.setup(_tree)
	await get_tree().process_frame
	await get_tree().process_frame


func _tile(id: String) -> TalentTile:
	return _screen._button_of(id) as TalentTile


func _header_of(tier: int) -> Dictionary:
	for header: Dictionary in _screen._headers:
		if header["branch"] == "click" and header["tier"] == tier:
			return header
	return {}


# Header

func test_header_is_46_units_and_fits_the_pane_at_320() -> void:
	# Arrange: a wait after a reset, so that "Réinitialiser" has its two lines
	_permanent.talents = {"click_grip": 1}
	_permanent.talent_reset_unix = NOW + TEN_DAYS
	await _start(PANE_320)

	# Act
	var header: Vector2 = _screen._top.get_combined_minimum_size()

	# Assert
	assert_str(_screen._reset_button.text).contains("\n")
	assert_float(header.y).is_equal(AdaptiveLayout.PANE_HEADER_HEIGHT)
	assert_float(header.x).is_less_equal(PANE_320.x - TalentScreen.PANE_SIDE_MARGINS)
	assert_float(_screen._top.size.y).is_equal(AdaptiveLayout.PANE_HEADER_HEIGHT)


func test_points_are_a_yellow_number_of_32_and_their_words() -> void:
	await _start(PANE_390)
	assert_str(_screen._points_label.text).is_equal("20")
	assert_int(_screen._points_label.get_theme_font_size(&"font_size")).is_equal(32)
	assert_bool(_screen._points_label.get_theme_color(&"font_color").is_equal_approx(UiPalette.YELLOW)).is_true()
	assert_str(_screen._points_word.text).is_equal("points à dépenser")
	assert_int(_screen._points_word.get_theme_font_size(&"font_size")).is_greater_equal(16)


func test_words_go_on_two_lines_only_when_one_does_not_fit() -> void:
	# Arrange, Act: at 390 u one line fits, at 320 u it does not
	await _start(PANE_390)
	var wide: String = _screen._points_word.text
	_screen.size = PANE_320
	await get_tree().process_frame
	await get_tree().process_frame
	var narrow: String = _screen._points_word.text

	# Assert
	assert_str(wide).is_equal("points à dépenser")
	assert_str(narrow).is_equal("points\nà dépenser")


func test_one_point_is_singular() -> void:
	_state.max_stage_reached = STAGE_WITH_ONE_POINT
	await _start(PANE_390)
	assert_str(_screen._points_label.text).is_equal("1")
	assert_str(_screen._points_word.text).is_equal("point à dépenser")


func test_reset_is_drawn_in_the_header_and_touched_over_50_units() -> void:
	await _start(PANE_390)
	var reset: HeaderButton = _screen._reset_button as HeaderButton
	assert_object(reset).is_not_null()
	assert_float(reset.touch_rect().size.y).is_greater_equal(MIN_TOUCH)
	assert_float(reset.size.x).is_greater_equal(MIN_TOUCH)
	assert_int(reset.get_theme_font_size(&"font_size")).is_greater_equal(16)


func test_free_part_covers_neither_the_points_nor_reset() -> void:
	# Arrange
	await _start(PANE_390)
	var free: Rect2 = _screen.pane_header().free_part().get_global_rect()
	var reset: HeaderButton = _screen._reset_button as HeaderButton
	var reset_touch: Rect2 = Rect2(reset.global_position + reset.touch_rect().position, reset.touch_rect().size)

	# Assert: a free part exists, beside both
	assert_float(free.size.x).is_greater_equal(30.0)
	assert_bool(free.intersects(_screen._points_box.get_global_rect())).is_false()
	assert_bool(free.intersects(reset_touch)).is_false()


# Tier headers

func test_closed_tier_shows_a_lock_and_its_progress_in_14_units() -> void:
	await _start(PANE_390)
	var open: Dictionary = _header_of(1)
	var closed: Dictionary = _header_of(2)
	assert_str((open["progress"] as Label).text).is_equal("Ouvert")
	assert_bool((open["lock"] as Control).visible).is_false()
	assert_str((closed["progress"] as Label).text).is_equal("0 / 2 points")
	assert_bool((closed["lock"] as Control).visible).is_true()
	assert_int((closed["progress"] as Label).get_theme_font_size(&"font_size")).is_equal(TalentScreen.TIER_PROGRESS_FONT_SIZE)
	assert_bool((closed["progress"] as Label).get_theme_color(&"font_color").is_equal_approx(UiPalette.TEXT_MUTED)).is_true()
	assert_bool((open["progress"] as Label).get_theme_color(&"font_color").is_equal_approx(UiPalette.YELLOW)).is_true()


func test_tier_lock_goes_once_the_tier_opens() -> void:
	# Arrange: tier 2 of the click branch opens at 2 points spent
	await _start(PANE_390)
	assert_bool((_header_of(2)["lock"] as Control).visible).is_true()

	# Act
	_tree.buy("click_grip")
	_tree.buy("click_crit")
	_screen.refresh()

	# Assert
	assert_str((_header_of(2)["progress"] as Label).text).is_equal("Ouvert")
	assert_bool((_header_of(2)["lock"] as Control).visible).is_false()


# Tiles

func test_tiles_are_64_units_at_least_and_grow_with_their_text() -> void:
	await _start(PANE_390)
	for row: Dictionary in _screen._rows:
		var tile: Button = row["button"]
		if tile.is_visible_in_tree():
			assert_float(tile.size.y).is_greater_equal(TalentTile.MIN_HEIGHT)
			assert_float(tile.size.y + 0.5).is_greater_equal(tile.get_minimum_size().y)
	assert_float(TalentScreen.NODE_MIN_SIZE.y).is_equal(TalentTile.MIN_HEIGHT)
	assert_int(_tile("click_grip").alignment).is_equal(HORIZONTAL_ALIGNMENT_LEFT)


func test_only_a_bought_tile_has_the_check_and_its_room() -> void:
	# Arrange
	_permanent.talents = {"click_grip": 1}
	await _start(PANE_390)
	var bought: TalentTile = _tile("click_grip")
	var other: TalentTile = _tile("click_crit")

	# Assert: the check in the room before the text, the word kept
	assert_bool(bought.is_owned()).is_true()
	assert_bool(other.is_owned()).is_false()
	assert_str(bought.text).ends_with("Acheté")
	var base: float = other.get_theme_stylebox(&"normal").get_margin(SIDE_LEFT)
	var room: float = bought.get_theme_stylebox(&"normal").get_margin(SIDE_LEFT)
	assert_float(room).is_greater_equal(TalentTile.CHECK_ROOM)
	var check: Vector2 = bought.check_center()
	assert_float(check.x + TalentTile.CHECK_RADIUS).is_less_equal(room)
	assert_float(check.x - TalentTile.CHECK_RADIUS).is_greater_equal(0.0)
	assert_float(check.y).is_between(0.0, bought.size.y)
	assert_float(base).is_less(room)


func test_reset_removes_the_check_and_its_room() -> void:
	# Arrange
	_permanent.talents = {"click_grip": 1}
	await _start(PANE_390)
	var tile: TalentTile = _tile("click_grip")
	var base: float = _tile("click_crit").get_theme_stylebox(&"normal").get_margin(SIDE_LEFT)

	# Act: the node is no longer owned
	_permanent.talents = {}
	_screen.refresh()

	# Assert
	assert_bool(tile.is_owned()).is_false()
	assert_float(tile.get_theme_stylebox(&"normal").get_margin(SIDE_LEFT)).is_equal(base)


func test_check_follows_a_selected_bought_tile() -> void:
	# Arrange: a bought node whose card is open uses the "pressed" box
	_permanent.talents = {"click_grip": 1}
	await _start(PANE_390)

	# Act
	_screen.open_node("click_grip")
	_screen.close_detail()

	# Assert: the room is still there on every state
	var tile: TalentTile = _tile("click_grip")
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		assert_float(tile.get_theme_stylebox(state).get_margin(SIDE_LEFT)).is_greater_equal(TalentTile.CHECK_ROOM)


func test_closed_tiles_show_their_real_cost_and_an_excluded_one_none() -> void:
	# Arrange: Rentier bought, so Moisson is excluded
	_state.max_stage_reached = 75
	_permanent.talents = {"eco_purse": 1, "gold_unlock": 1, "economy_offline": 1, "eco_flair": 1, "eco_haggle": 1, "gold_cd": 1, "eco_top_rentier": 1}
	await _start(PANE_390)
	var text: TalentCardText = _screen._text

	# Assert
	assert_str(_tile("boss_hunter").text).ends_with(" · " + text.points_text(3))
	assert_str(_tile("eco_top_harvest").text).ends_with("Exclu")
	assert_str(_tile("eco_top_harvest").text).not_contains("·")
