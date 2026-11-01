extends GdUnitTestSuite
## Unit tests for the long press state machine and the placement of its bubble.
## Story: production/epics/idle-titans/story-010-adaptive-layout.md, Interaction Map of
## design/ux/main-screen-adaptive.md.

const JUST_UNDER: float = LongPress.HOLD_SECONDS - 0.01
const STEP: float = 0.02
const VIEW: Vector2 = Vector2(390.0, 844.0)
const BUBBLE: Vector2 = Vector2(280.0, 100.0)
const TARGET_SIZE: Vector2 = Vector2(100.0, 50.0)
const FIRST_FINGER: int = 0
const SECOND_FINGER: int = 1

var _press: LongPress


func before_test() -> void:
	_press = LongPress.new()


func test_hold_under_the_time_does_not_fire() -> void:
	_press.begin(Vector2.ZERO)
	assert_bool(_press.tick(JUST_UNDER)).is_false()
	assert_int(_press.state()).is_equal(LongPress.State.HELD)


func test_hold_of_the_full_time_fires() -> void:
	_press.begin(Vector2.ZERO)
	_press.tick(JUST_UNDER)
	assert_bool(_press.tick(STEP)).is_true()
	assert_int(_press.state()).is_equal(LongPress.State.FIRED)


func test_hold_fires_only_once() -> void:
	_press.begin(Vector2.ZERO)
	_press.tick(LongPress.HOLD_SECONDS)
	assert_bool(_press.tick(STEP)).is_false()


func test_no_press_never_fires() -> void:
	assert_bool(_press.tick(LongPress.HOLD_SECONDS)).is_false()


func test_release_after_firing_must_be_swallowed() -> void:
	_press.begin(Vector2.ZERO)
	_press.tick(LongPress.HOLD_SECONDS)
	assert_bool(_press.release()).is_true()
	assert_int(_press.state()).is_equal(LongPress.State.IDLE)


func test_release_before_firing_is_a_normal_press() -> void:
	_press.begin(Vector2.ZERO)
	_press.tick(JUST_UNDER)
	assert_bool(_press.release()).is_false()


func test_move_of_exactly_ten_css_px_keeps_the_press() -> void:
	_press.begin(Vector2.ZERO)
	_press.move(Vector2(LongPress.MAX_MOVE_CSS, 0.0), 1.0)
	assert_int(_press.state()).is_equal(LongPress.State.HELD)


func test_move_past_ten_css_px_cancels() -> void:
	_press.begin(Vector2.ZERO)
	_press.move(Vector2(LongPress.MAX_MOVE_CSS + 0.5, 0.0), 1.0)
	assert_int(_press.state()).is_equal(LongPress.State.IDLE)
	assert_bool(_press.tick(LongPress.HOLD_SECONDS)).is_false()


func test_move_is_measured_in_css_px_not_units() -> void:
	_press.begin(Vector2.ZERO)
	_press.move(Vector2(8.0, 0.0), 1.5)
	assert_int(_press.state()).is_equal(LongPress.State.IDLE)


func test_move_after_firing_changes_nothing() -> void:
	_press.begin(Vector2.ZERO)
	_press.tick(LongPress.HOLD_SECONDS)
	_press.move(Vector2(500.0, 0.0), 1.0)
	assert_int(_press.state()).is_equal(LongPress.State.FIRED)


func test_first_finger_alone_keeps_the_press() -> void:
	_press.begin(Vector2.ZERO)
	_press.touch(FIRST_FINGER, true)
	assert_int(_press.state()).is_equal(LongPress.State.HELD)


func test_second_finger_cancels() -> void:
	_press.begin(Vector2.ZERO)
	_press.touch(FIRST_FINGER, true)
	_press.touch(SECOND_FINGER, true)
	assert_int(_press.state()).is_equal(LongPress.State.IDLE)


func test_finger_lifted_is_not_a_second_finger_later() -> void:
	_press.touch(FIRST_FINGER, true)
	_press.touch(FIRST_FINGER, false)
	_press.touch(SECOND_FINGER, true)
	_press.begin(Vector2.ZERO)
	_press.touch(SECOND_FINGER, true)
	assert_int(_press.state()).is_equal(LongPress.State.HELD)


func test_cancel_gives_up_the_hold() -> void:
	_press.begin(Vector2.ZERO)
	_press.cancel()
	assert_bool(_press.tick(LongPress.HOLD_SECONDS)).is_false()


func test_reset_forgets_the_fingers() -> void:
	_press.touch(FIRST_FINGER, true)
	_press.reset()
	_press.begin(Vector2.ZERO)
	_press.touch(SECOND_FINGER, true)
	assert_int(_press.state()).is_equal(LongPress.State.HELD)


func test_bubble_goes_above_a_target_with_room() -> void:
	var target: Rect2 = Rect2(Vector2(145.0, 400.0), TARGET_SIZE)
	var at: Vector2 = LongPress.bubble_position(BUBBLE, target, VIEW)
	assert_float(at.y + BUBBLE.y).is_less_equal(target.position.y)
	assert_float(at.x + BUBBLE.x / 2.0).is_equal_approx(target.get_center().x, 0.01)


func test_bubble_goes_below_a_target_at_the_top() -> void:
	var target: Rect2 = Rect2(Vector2(145.0, 10.0), TARGET_SIZE)
	var at: Vector2 = LongPress.bubble_position(BUBBLE, target, VIEW)
	assert_float(at.y).is_greater_equal(target.end.y)


func test_bubble_stays_whole_on_screen_at_each_corner() -> void:
	for target_at: Vector2 in [Vector2.ZERO, Vector2(VIEW.x - TARGET_SIZE.x, 0.0), VIEW - TARGET_SIZE, Vector2(0.0, VIEW.y - TARGET_SIZE.y)]:
		var at: Vector2 = LongPress.bubble_position(BUBBLE, Rect2(target_at, TARGET_SIZE), VIEW)
		assert_bool(Rect2(Vector2.ZERO, VIEW).encloses(Rect2(at, BUBBLE))).is_true()
