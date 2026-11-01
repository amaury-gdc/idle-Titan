extends GdUnitTestSuite
## Unit tests for the limit of the floating texts: from start to end of travel, a text stays inside
## the monster area and never covers the buttons around it.
## Story: production/epics/idle-titans/story-010-adaptive-layout.md.

const BOUNDS: Rect2 = Rect2(100.0, 100.0, 300.0, 170.0)
const HALF: Vector2 = Vector2(50.0, 20.0)
const STEP: float = 0.05
const STEPS: int = 30
## Steps that stop just before the end of the 1,3 s of a gold text.
const FREE_TRAVEL_STEPS: int = 24
const BIG_GOLD: int = 123_456_789

var _layer: FloatingTextLayer


func before_test() -> void:
	_layer = auto_free(FloatingTextLayer.new())
	add_child(_layer)


func _assert_inside(label: Label) -> void:
	var font: Font = label.get_theme_font("font")
	var text_size: Vector2 = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
	var center: Vector2 = label.position + label.size / 2.0
	var text: Rect2 = Rect2(center - text_size / 2.0, text_size)
	assert_bool(BOUNDS.encloses(text)).is_true()


func test_keep_inside_leaves_a_point_with_room_alone() -> void:
	assert_vector(FloatingTextLayer.keep_inside(BOUNDS.get_center(), HALF, BOUNDS)).is_equal(BOUNDS.get_center())


func test_keep_inside_pulls_a_text_back_in_at_each_corner() -> void:
	var low: Vector2 = BOUNDS.position + HALF
	var high: Vector2 = BOUNDS.end - HALF
	assert_vector(FloatingTextLayer.keep_inside(Vector2.ZERO, HALF, BOUNDS)).is_equal(low)
	assert_vector(FloatingTextLayer.keep_inside(Vector2.ONE * 5000.0, HALF, BOUNDS)).is_equal(high)


func test_keep_inside_centers_a_text_wider_than_the_bounds() -> void:
	var half: Vector2 = Vector2(BOUNDS.size.x, HALF.y)
	assert_float(FloatingTextLayer.keep_inside(Vector2.ZERO, half, BOUNDS).x).is_equal(BOUNDS.get_center().x)


func test_gold_stays_inside_from_start_to_end_of_travel() -> void:
	_layer.set_target_point(BOUNDS.get_center())
	_layer.set_box_scale(1.0)
	_layer.set_bounds(BOUNDS)
	_layer.show_gold(1, BigNumber.from_int(BIG_GOLD), true)
	var label: Label = _layer.get_child(0)
	_assert_inside(label)
	for i in STEPS:
		_layer._process(STEP)
		if label.visible:
			_assert_inside(label)


func test_hit_stays_inside_from_start_to_end_of_travel() -> void:
	_layer.set_target_point(BOUNDS.get_center())
	_layer.set_box_scale(1.5)
	_layer.set_bounds(BOUNDS)
	_layer.show_hit(BigNumber.from_int(BIG_GOLD), FloorManager.HitSource.BURST)
	var label: Label = _layer.get_child(0)
	_assert_inside(label)
	for i in STEPS:
		_layer._process(STEP)
		if label.visible:
			_assert_inside(label)


func test_no_bounds_keeps_the_free_travel() -> void:
	_layer.set_target_point(BOUNDS.get_center())
	_layer.show_gold(1, BigNumber.from_int(BIG_GOLD), false)
	var label: Label = _layer.get_child(0)
	var start: Vector2 = label.position
	# Small steps: the layer honors at most MAX_FRAME_SECONDS per frame.
	for i in FREE_TRAVEL_STEPS:
		_layer._process(STEP)
	assert_float(label.position.y).is_less(start.y - 100.0)
