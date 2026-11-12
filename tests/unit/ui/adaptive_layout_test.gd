extends GdUnitTestSuite
## Unit tests for the pure decisions of the adaptive main screen: the shape thresholds and their
## dead zone, the scale and its two bounds, the portrait scene and panel (story 019b), the modal
## rectangle and the room of the loot message.
##
## Why the thresholds stand above 1 (independent review of story 010): a square window, or one a
## little wider than tall, has no room for a 60/40 split with 3 columns, so it reads better in rows.
## A 4:3 tablet (1,33) stays landscape. The dead zone keeps its width of 0,10 around the cold start.
## Story: production/epics/idle-titans/story-010-adaptive-layout.md


const PORTRAIT: AdaptiveLayout.Shape = AdaptiveLayout.Shape.PORTRAIT
const LANDSCAPE: AdaptiveLayout.Shape = AdaptiveLayout.Shape.LANDSCAPE
const UNDECIDED: AdaptiveLayout.Shape = AdaptiveLayout.Shape.UNDECIDED
## Test height: a width of 1000 reads as a ratio of 1,0, and so on.
const HEIGHT: float = 1000.0
const TOLERANCE: float = 0.001
const CAP: float = AdaptiveLayout.MAX_PORTRAIT_CSS_PER_UNIT
const FLOOR: float = AdaptiveLayout.MIN_CSS_PER_UNIT


func _css(ratio: float) -> Vector2:
	return Vector2(ratio * HEIGHT, HEIGHT)


func test_shape_cold_start_under_threshold_is_portrait() -> void:
	assert_int(AdaptiveLayout.decide_shape(_css(1.14), UNDECIDED)).is_equal(PORTRAIT)


func test_shape_cold_start_at_threshold_is_landscape() -> void:
	assert_int(AdaptiveLayout.decide_shape(_css(1.15), UNDECIDED)).is_equal(LANDSCAPE)


func test_shape_cold_start_has_no_previous_argument_needed() -> void:
	assert_int(AdaptiveLayout.decide_shape(Vector2(390.0, 844.0))).is_equal(PORTRAIT)
	assert_int(AdaptiveLayout.decide_shape(Vector2(844.0, 390.0))).is_equal(LANDSCAPE)


func test_shape_square_window_is_portrait_whatever_came_before() -> void:
	var square: Vector2 = Vector2(HEIGHT, HEIGHT)
	assert_int(AdaptiveLayout.decide_shape(square)).is_equal(PORTRAIT)
	assert_int(AdaptiveLayout.decide_shape(square, LANDSCAPE)).is_equal(PORTRAIT)


func test_shape_four_by_three_tablet_follows_its_orientation() -> void:
	assert_int(AdaptiveLayout.decide_shape(Vector2(1024.0, 768.0), PORTRAIT)).is_equal(LANDSCAPE)
	assert_int(AdaptiveLayout.decide_shape(Vector2(768.0, 1024.0), LANDSCAPE)).is_equal(PORTRAIT)


func test_shape_landscape_stays_landscape_at_portrait_threshold() -> void:
	assert_int(AdaptiveLayout.decide_shape(_css(1.10), LANDSCAPE)).is_equal(LANDSCAPE)


func test_shape_landscape_turns_portrait_just_under_threshold() -> void:
	assert_int(AdaptiveLayout.decide_shape(_css(1.099), LANDSCAPE)).is_equal(PORTRAIT)


func test_shape_portrait_stays_portrait_at_landscape_threshold() -> void:
	assert_int(AdaptiveLayout.decide_shape(_css(1.20), PORTRAIT)).is_equal(PORTRAIT)


func test_shape_portrait_turns_landscape_just_over_threshold() -> void:
	assert_int(AdaptiveLayout.decide_shape(_css(1.201), PORTRAIT)).is_equal(LANDSCAPE)


func test_shape_dead_zone_keeps_previous_shape_both_ways() -> void:
	for ratio: float in [1.11, 1.15, 1.19]:
		assert_int(AdaptiveLayout.decide_shape(_css(ratio), PORTRAIT)).is_equal(PORTRAIT)
		assert_int(AdaptiveLayout.decide_shape(_css(ratio), LANDSCAPE)).is_equal(LANDSCAPE)


func test_shape_empty_window_keeps_previous_shape() -> void:
	assert_int(AdaptiveLayout.decide_shape(Vector2.ZERO, PORTRAIT)).is_equal(PORTRAIT)
	assert_int(AdaptiveLayout.decide_shape(Vector2.ZERO, LANDSCAPE)).is_equal(LANDSCAPE)


func test_content_size_between_the_bounds_is_the_base() -> void:
	assert_vector(AdaptiveLayout.content_size(Vector2(390.0, 844.0), PORTRAIT)).is_equal(Vector2i(390, 640))
	assert_vector(AdaptiveLayout.content_size(Vector2(2560.0, 1080.0), LANDSCAPE)).is_equal(Vector2i(1280, 720))


func test_content_size_exactly_at_the_floor_is_the_base() -> void:
	var css: Vector2 = Vector2(AdaptiveLayout.BASE_LANDSCAPE) * FLOOR
	assert_vector(AdaptiveLayout.content_size(css, LANDSCAPE)).is_equal(AdaptiveLayout.BASE_LANDSCAPE)


func test_content_size_exactly_at_the_ceiling_is_the_base() -> void:
	var css: Vector2 = Vector2(AdaptiveLayout.BASE_PORTRAIT) * CAP
	assert_vector(AdaptiveLayout.content_size(css, PORTRAIT)).is_equal(AdaptiveLayout.BASE_PORTRAIT)


func test_content_size_under_the_floor_is_the_window_at_the_floor() -> void:
	assert_vector(AdaptiveLayout.content_size(Vector2(844.0, 390.0), LANDSCAPE)).is_equal(Vector2i(959, 443))
	assert_vector(AdaptiveLayout.content_size(Vector2(320.0, 568.0), PORTRAIT)).is_equal(Vector2i(363, 645))


func test_content_size_under_the_floor_never_scales_under_the_floor() -> void:
	var css: Vector2 = Vector2(844.0, 390.0)
	var content: Vector2 = Vector2(AdaptiveLayout.content_size(css, LANDSCAPE))
	assert_bool(minf(css.x / content.x, css.y / content.y) >= FLOOR).is_true()


func test_content_size_over_the_ceiling_is_the_window_at_the_ceiling() -> void:
	assert_vector(AdaptiveLayout.content_size(Vector2(768.0, 1024.0), PORTRAIT)).is_equal(Vector2i(600, 800))


func test_content_size_over_the_ceiling_never_scales_over_it() -> void:
	for css: Vector2 in [Vector2(768.0, 1024.0), Vector2(1000.0, 1000.0), Vector2(811.0, 1367.0)]:
		var content: Vector2 = Vector2(AdaptiveLayout.content_size(css, PORTRAIT))
		assert_bool(minf(css.x / content.x, css.y / content.y) <= CAP + TOLERANCE).is_true()


func test_ceiling_is_portrait_only() -> void:
	var css: Vector2 = Vector2(2560.0, 1440.0)
	assert_float(AdaptiveLayout.css_per_unit(css, LANDSCAPE)).is_equal_approx(2.0, TOLERANCE)
	assert_vector(AdaptiveLayout.content_size(css, LANDSCAPE)).is_equal(AdaptiveLayout.BASE_LANDSCAPE)


func test_floor_wins_in_a_tall_narrow_window_and_the_ceiling_stays_out() -> void:
	var css: Vector2 = Vector2(300.0, 1200.0)
	assert_float(AdaptiveLayout.css_per_unit(css, PORTRAIT)).is_equal(FLOOR)
	assert_vector(AdaptiveLayout.content_size(css, PORTRAIT)).is_equal(Vector2i(340, 1363))


func test_ceiling_wins_in_a_big_window_and_the_floor_stays_out() -> void:
	assert_float(AdaptiveLayout.css_per_unit(Vector2(1000.0, 1000.0), PORTRAIT)).is_equal(CAP)


func test_logical_size_matches_the_table_of_the_spec() -> void:
	assert_vector(AdaptiveLayout.logical_size(Vector2(390.0, 844.0), PORTRAIT)).is_equal_approx(Vector2(390.0, 844.0), Vector2.ONE * TOLERANCE)
	assert_vector(AdaptiveLayout.logical_size(Vector2(768.0, 1024.0), PORTRAIT)).is_equal_approx(Vector2(600.0, 800.0), Vector2.ONE * TOLERANCE)
	assert_vector(AdaptiveLayout.logical_size(Vector2(2560.0, 1080.0), LANDSCAPE)).is_equal_approx(Vector2(1706.667, 720.0), Vector2.ONE * TOLERANCE)


func test_css_per_unit_floor_holds_on_a_small_window() -> void:
	assert_float(AdaptiveLayout.css_per_unit(Vector2(320.0, 480.0), PORTRAIT)).is_equal(FLOOR)


func test_scene_spec_phone_gets_the_heights_of_the_spec() -> void:
	# 390x742: header 52, scene 208, skills 68, panel 358, tabs 56 (story 019b).
	assert_float(AdaptiveLayout.portrait_scene(742.0)).is_equal(208.0)
	assert_float(AdaptiveLayout.portrait_panel(742.0)).is_equal(358.0)


func test_scene_tall_phone_gives_the_surplus_to_the_panel() -> void:
	assert_float(AdaptiveLayout.portrait_scene(866.0)).is_equal(AdaptiveLayout.SCENE_MAX)
	assert_float(AdaptiveLayout.portrait_panel(866.0)).is_equal(482.0)


func test_scene_gives_way_before_the_panel() -> void:
	var height: float = AdaptiveLayout.logical_size(Vector2(360.0, 640.0), PORTRAIT).y
	var scene: float = AdaptiveLayout.portrait_scene(height)
	assert_float(scene).is_less(AdaptiveLayout.SCENE_MAX)
	assert_float(scene).is_greater(AdaptiveLayout.SCENE_MIN)
	assert_float(AdaptiveLayout.portrait_panel(height)).is_greater_equal(height * AdaptiveLayout.PANEL_MIN_SHARE)


func test_short_phone_keeps_its_panel_share_and_two_and_a_half_rows() -> void:
	# 320x568 at the floor: 645 u tall.
	var height: float = AdaptiveLayout.logical_size(Vector2(320.0, 568.0), PORTRAIT).y
	var panel: float = AdaptiveLayout.portrait_panel(height)
	assert_float(AdaptiveLayout.portrait_scene(height)).is_equal(178.0)
	assert_float(panel).is_greater_equal(height * AdaptiveLayout.PANEL_MIN_SHARE)
	assert_float(panel).is_greater_equal(AdaptiveLayout.PANEL_MIN_HEIGHT)


func test_scene_very_short_screen_stops_at_its_minimum() -> void:
	# Under the minimum of the scene the panel is what gives way: 500 u leave it 164 u.
	assert_float(AdaptiveLayout.portrait_scene(500.0)).is_equal(AdaptiveLayout.SCENE_MIN)
	assert_float(AdaptiveLayout.portrait_panel(500.0)).is_equal(164.0)


func test_portrait_rows_add_up_to_the_screen() -> void:
	for height: float in [500.0, 645.0, 693.0, 742.0, 866.0]:
		var rows: float = AdaptiveLayout.HEADER_HEIGHT + AdaptiveLayout.portrait_game_height(AdaptiveLayout.portrait_scene(height)) \
				+ AdaptiveLayout.portrait_panel(height) + AdaptiveLayout.TAB_ROW_HEIGHT
		assert_float(rows).is_equal_approx(height, TOLERANCE)


func test_collapsed_rows_add_up_to_the_screen() -> void:
	# Story 019b, lot 5: header, scene, skills, the collapsed handle and the tabs.
	for height: float in [645.0, 693.0, 742.0, 866.0]:
		var rows: float = AdaptiveLayout.HEADER_HEIGHT + AdaptiveLayout.portrait_game_height(AdaptiveLayout.portrait_scene_collapsed(height)) \
				+ AdaptiveLayout.HANDLE_COLLAPSED_HEIGHT + AdaptiveLayout.TAB_ROW_HEIGHT
		assert_float(rows).is_equal_approx(height, TOLERANCE)


func test_collapsed_scene_takes_what_the_panel_gave_and_never_falls_under_its_minimum() -> void:
	assert_float(AdaptiveLayout.portrait_scene_collapsed(742.0)).is_equal(516.0)
	assert_float(AdaptiveLayout.portrait_scene_collapsed(742.0)).is_greater(AdaptiveLayout.portrait_scene(742.0))
	assert_float(AdaptiveLayout.portrait_scene_collapsed(300.0)).is_equal(AdaptiveLayout.SCENE_MIN)


func test_open_panel_holds_its_handle_header_and_two_and_a_half_rows() -> void:
	assert_float(AdaptiveLayout.PANEL_MIN_HEIGHT).is_equal(
			AdaptiveLayout.HANDLE_HEIGHT + AdaptiveLayout.PANE_HEADER_HEIGHT + 2.5 * 70.0)


func test_modal_rect_wide_view_is_capped_and_centered() -> void:
	var rect: Rect2 = AdaptiveLayout.modal_rect(Vector2(1280.0, 720.0), 600.0)
	assert_float(rect.size.x).is_equal(AdaptiveLayout.MODAL_MAX_WIDTH)
	assert_float(rect.size.y).is_equal(600.0)
	assert_vector(rect.position).is_equal(Vector2(280.0, 60.0))


func test_modal_rect_small_view_keeps_the_margins() -> void:
	var rect: Rect2 = AdaptiveLayout.modal_rect(Vector2(390.0, 446.0), 600.0)
	assert_float(rect.size.x).is_equal(390.0 - AdaptiveLayout.MODAL_MARGIN * 2.0)
	assert_float(rect.size.y).is_equal(446.0 - AdaptiveLayout.MODAL_MARGIN * 2.0)


# The monster box of a portrait zone: the height of its room, at most BOX_ZONE_RATIO of the width.
func _portrait_box(zone: Vector2, scene: float) -> float:
	var enemy: Rect2 = GameZone.blocks(PORTRAIT, zone, scene)["enemy"]
	return minf(enemy.size.y, zone.x * GameZone.BOX_ZONE_RATIO)


# The portrait companions are mice (story 019b): their silhouettes, outline included.
func _assert_clear_of_mice(slot: Rect2, zone: Vector2, scene: float, box: float) -> void:
	var half: Vector2 = MouseFace.half_extent(GameZone.portrait_mouse_size(zone, scene))
	for mouse: Vector2 in GameZone.portrait_mouse_centers(zone, scene, box):
		var where: String = "slot %s, mouse %s, zone %s, scene %s" % [slot, Rect2(mouse - half, half * 2.0), zone, scene]
		assert_bool(slot.intersects(Rect2(mouse - half, half * 2.0))).override_failure_message(where).is_false()


func test_loot_slot_portrait_never_reaches_a_mouse() -> void:
	for width: float in [363.0, 390.0]:
		for scene: float in [AdaptiveLayout.SCENE_MIN, AdaptiveLayout.SCENE_MAX]:
			var zone: Vector2 = Vector2(width, AdaptiveLayout.portrait_game_height(scene))
			var box: float = _portrait_box(zone, scene)
			for free: bool in [true, false]:
				var slot: Rect2 = GameZone.loot_slot_for(PORTRAIT, zone, scene, box, free)
				_assert_clear_of_mice(slot, zone, scene, box)


func test_loot_slot_portrait_free_band_starts_at_the_top_of_the_scene() -> void:
	var zone: Vector2 = Vector2(390.0, AdaptiveLayout.portrait_game_height(AdaptiveLayout.SCENE_MAX))
	var slot: Rect2 = GameZone.loot_slot_for(PORTRAIT, zone, AdaptiveLayout.SCENE_MAX, _portrait_box(zone, AdaptiveLayout.SCENE_MAX), true)
	assert_float(slot.position.y).is_equal(GameZone.PADDING)


func test_loot_slot_portrait_occupied_band_stays_under_the_corner() -> void:
	var scene: float = AdaptiveLayout.SCENE_MAX
	var zone: Vector2 = Vector2(390.0, AdaptiveLayout.portrait_game_height(scene))
	var rects: Dictionary = GameZone.blocks(PORTRAIT, zone, scene)
	var slot: Rect2 = GameZone.loot_slot_for(PORTRAIT, zone, scene, _portrait_box(zone, scene), false)
	assert_float(slot.position.y).is_greater_equal((rects["challenge"] as Rect2).end.y)
	assert_bool((rects["enemy"] as Rect2).encloses(slot)).is_true()


## Left columns of the landscape screen (story 019b, lot 9): 1280x720 and an 844x390 phone (959x443 u),
## each 3/7 of the width and the height under the 52 u header.
const LANDSCAPE_ZONES: Array[Vector2] = [Vector2(548.0, 668.0), Vector2(411.0, 391.0)]


func test_loot_slot_landscape_never_reaches_a_mouse_or_the_skills() -> void:
	for zone: Vector2 in LANDSCAPE_ZONES:
		var scene: float = GameZone.scene_height(LANDSCAPE, zone, 0.0)
		var box: float = GameZone.portrait_box(zone, scene)
		var skills: Rect2 = GameZone.blocks(LANDSCAPE, zone, 0.0)["skills"]
		for free: bool in [true, false]:
			var slot: Rect2 = GameZone.loot_slot_for(LANDSCAPE, zone, 0.0, box, free)
			_assert_clear_of_mice(slot, zone, scene, box)
			assert_bool(slot.intersects(skills)).override_failure_message("zone %s" % zone).is_false()


func test_loot_slot_landscape_occupied_band_stays_under_the_corner() -> void:
	for zone: Vector2 in LANDSCAPE_ZONES:
		var scene: float = GameZone.scene_height(LANDSCAPE, zone, 0.0)
		var corner: Rect2 = GameZone.blocks(LANDSCAPE, zone, 0.0)["challenge"]
		var slot: Rect2 = GameZone.loot_slot_for(LANDSCAPE, zone, 0.0, GameZone.portrait_box(zone, scene), false)
		assert_float(slot.position.y).is_greater_equal(corner.end.y)
