extends GdUnitTestSuite
## Unit tests for the pure decisions of the adaptive main screen: the shape thresholds and their
## dead zone, the scale and its two bounds, the portrait monster row, the modal rectangle and the
## room of the loot message.
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
const ORB_OUTLINE: float = CompanionOrbs.OUTLINE_WIDTH


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


func test_monster_row_tall_screen_keeps_its_full_height() -> void:
	assert_float(AdaptiveLayout.portrait_monster_row(844.0)).is_equal(AdaptiveLayout.MONSTER_ROW_MAX)


func test_monster_row_short_screen_stops_at_its_minimum() -> void:
	assert_float(AdaptiveLayout.portrait_monster_row(500.0)).is_equal(AdaptiveLayout.MONSTER_ROW_MIN)


func test_monster_row_gives_way_before_the_management_zone() -> void:
	var height: float = 640.0
	var row: float = AdaptiveLayout.portrait_monster_row(height)
	var left: float = height - AdaptiveLayout.HEADER_HEIGHT - AdaptiveLayout.portrait_game_height(row)
	assert_float(row).is_less(AdaptiveLayout.MONSTER_ROW_MAX)
	assert_float(row).is_greater(AdaptiveLayout.MONSTER_ROW_MIN)
	assert_float(left).is_equal_approx(AdaptiveLayout.MANAGEMENT_MIN_HEIGHT, TOLERANCE)


func test_short_phone_keeps_two_and_a_half_list_rows() -> void:
	var height: float = AdaptiveLayout.logical_size(Vector2(320.0, 568.0), PORTRAIT).y
	var row: float = AdaptiveLayout.portrait_monster_row(height)
	var management: float = height - AdaptiveLayout.HEADER_HEIGHT - AdaptiveLayout.portrait_game_height(row)
	var list: float = management - 120.0
	assert_float(list / 56.0).is_greater_equal(2.5)


func test_modal_rect_wide_view_is_capped_and_centered() -> void:
	var rect: Rect2 = AdaptiveLayout.modal_rect(Vector2(1280.0, 720.0), 600.0)
	assert_float(rect.size.x).is_equal(AdaptiveLayout.MODAL_MAX_WIDTH)
	assert_float(rect.size.y).is_equal(600.0)
	assert_vector(rect.position).is_equal(Vector2(280.0, 60.0))


func test_modal_rect_small_view_keeps_the_margins() -> void:
	var rect: Rect2 = AdaptiveLayout.modal_rect(Vector2(390.0, 446.0), 600.0)
	assert_float(rect.size.x).is_equal(390.0 - AdaptiveLayout.MODAL_MARGIN * 2.0)
	assert_float(rect.size.y).is_equal(446.0 - AdaptiveLayout.MODAL_MARGIN * 2.0)


func test_orb_radius_and_pitch_stay_within_their_bounds() -> void:
	assert_float(GameZone.orb_radius(100.0)).is_equal(GameZone.ORB_RADIUS_MIN)
	assert_float(GameZone.orb_pitch(100.0)).is_equal(GameZone.ORB_PITCH_MIN)
	assert_float(GameZone.orb_radius(640.0)).is_equal(GameZone.ORB_RADIUS_MAX)
	assert_float(GameZone.orb_pitch(640.0)).is_equal(GameZone.ORB_PITCH_MAX)


func test_orb_radius_follows_the_box_between_its_bounds() -> void:
	assert_float(GameZone.orb_radius(450.0)).is_equal_approx(GameZone.ORB_RADIUS_MIN * 1.5, TOLERANCE)
	assert_float(GameZone.orb_pitch(450.0)).is_equal_approx(GameZone.ORB_PITCH_MIN * 1.5, TOLERANCE)


# The spheres of a portrait zone: 2 by 2 on each side of a box of [param box], as GameZone puts them.
func _portrait_orbs(zone: Vector2, row: float, box: float) -> PackedVector2Array:
	var enemy: Rect2 = GameZone.blocks(PORTRAIT, zone, row)["enemy"]
	var pitch: float = GameZone.orb_pitch(box)
	var flank: float = (enemy.position.x + enemy.get_center().x - box / 2.0) / 2.0
	var orbs: PackedVector2Array = PackedVector2Array()
	for x: float in [flank, enemy.get_center().x * 2.0 - flank]:
		for column: float in [-0.5, 0.5]:
			for line: float in [-0.5, 0.5]:
				orbs.append(Vector2(x + column * pitch, enemy.get_center().y + line * pitch))
	return orbs


func _assert_clear_of_orbs(slot: Rect2, orbs: PackedVector2Array, box: float) -> void:
	var reach: float = GameZone.orb_radius(box) + ORB_OUTLINE
	for orb: Vector2 in orbs:
		assert_bool(slot.intersects(Rect2(orb - Vector2.ONE * reach, Vector2.ONE * reach * 2.0))).is_false()


func test_loot_slot_portrait_never_reaches_a_sphere() -> void:
	for row: float in [120.0, 170.0]:
		var zone: Vector2 = Vector2(363.0, AdaptiveLayout.portrait_game_height(row))
		var box: float = row
		for free: bool in [true, false]:
			var slot: Rect2 = GameZone.loot_slot_for(PORTRAIT, zone, row, box, free)
			_assert_clear_of_orbs(slot, _portrait_orbs(zone, row, box), box)


func test_loot_slot_portrait_free_band_starts_in_the_band() -> void:
	var zone: Vector2 = Vector2(390.0, AdaptiveLayout.portrait_game_height(170.0))
	var slot: Rect2 = GameZone.loot_slot_for(PORTRAIT, zone, 170.0, 170.0, true)
	assert_float(slot.position.y).is_equal(AdaptiveLayout.ROW_GAP)


func test_loot_slot_portrait_occupied_band_stays_under_it() -> void:
	var zone: Vector2 = Vector2(390.0, AdaptiveLayout.portrait_game_height(170.0))
	var rects: Dictionary = GameZone.blocks(PORTRAIT, zone, 170.0)
	var slot: Rect2 = GameZone.loot_slot_for(PORTRAIT, zone, 170.0, 170.0, false)
	assert_float(slot.position.y).is_greater_equal((rects["challenge"] as Rect2).end.y)
	assert_bool((rects["enemy"] as Rect2).encloses(slot)).is_true()


func test_loot_slot_landscape_stays_out_of_the_side_columns() -> void:
	var zone: Vector2 = Vector2(768.0, 664.0)
	var rects: Dictionary = GameZone.blocks(LANDSCAPE, zone, 170.0)
	for free: bool in [true, false]:
		var slot: Rect2 = GameZone.loot_slot_for(LANDSCAPE, zone, 170.0, 360.0, free)
		assert_bool(slot.intersects(rects["orbs"])).is_false()
		assert_bool(slot.intersects(rects["skills"])).is_false()


func test_loot_slot_landscape_occupied_band_stays_under_the_timer() -> void:
	var zone: Vector2 = Vector2(768.0, 664.0)
	var timer: Rect2 = GameZone.blocks(LANDSCAPE, zone, 170.0)["timer"]
	var slot: Rect2 = GameZone.loot_slot_for(LANDSCAPE, zone, 170.0, 360.0, false)
	assert_float(slot.position.y).is_greater_equal(timer.end.y)
