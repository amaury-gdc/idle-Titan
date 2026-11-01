extends GdUnitTestSuite
## Unit tests for the tap that dismisses a [HintBubble]: on a touch screen it arrives as an emulated
## mouse press, the touch, an emulated release and the touch release, and the whole sequence must be
## swallowed without leaving a finger counted as down.
## Story: production/epics/idle-titans/story-010-adaptive-layout.md, Interaction Map of
## design/ux/main-screen-adaptive.md.

const HOLD: float = LongPress.HOLD_SECONDS + 0.01
const VIEW: Vector2 = Vector2(390.0, 844.0)
const FIRST_FINGER: int = 0
const SECOND_FINGER: int = 1

var _root: Control
var _bubble: HintBubble
var _target: Button


func before_test() -> void:
	_root = auto_free(Control.new())
	_root.size = VIEW
	add_child(_root)
	_bubble = HintBubble.new()
	var label: Label = Label.new()
	label.name = "Label"
	_bubble.add_child(label)
	_root.add_child(_bubble)
	_target = Button.new()
	_root.add_child(_target)
	_bubble.watch(_target, func() -> String: return "texte")


func _mouse(pressed: bool, device: int) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.device = device
	return event


func _touch(index: int, pressed: bool) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	return event


# One tap of the first finger, in the order Godot sends it: emulated mouse first.
func _tap() -> void:
	_bubble._input(_mouse(true, InputEvent.DEVICE_ID_EMULATION))
	_bubble._input(_touch(FIRST_FINGER, true))
	_bubble._input(_mouse(false, InputEvent.DEVICE_ID_EMULATION))
	_bubble._input(_touch(FIRST_FINGER, false))


# A long press of the first finger on the target, up to the end of the hold.
func _long_press() -> void:
	_target.gui_input.emit(_mouse(true, InputEvent.DEVICE_ID_EMULATION))
	_bubble._input(_touch(FIRST_FINGER, true))
	_bubble._process(HOLD)


func test_tap_dismisses_the_bubble() -> void:
	_bubble.show_for(_target, "texte")
	_bubble._input(_mouse(true, InputEvent.DEVICE_ID_EMULATION))
	assert_bool(_bubble.visible).is_false()


func test_emulated_release_keeps_swallowing_until_the_finger_is_up() -> void:
	_bubble.show_for(_target, "texte")
	_bubble._input(_mouse(true, InputEvent.DEVICE_ID_EMULATION))
	_bubble._input(_touch(FIRST_FINGER, true))
	_bubble._input(_mouse(false, InputEvent.DEVICE_ID_EMULATION))
	assert_bool(_bubble.get("_swallowing_tap")).is_true()
	_bubble._input(_touch(FIRST_FINGER, false))
	assert_bool(_bubble.get("_swallowing_tap")).is_false()


func test_real_mouse_release_ends_the_swallow() -> void:
	_bubble.show_for(_target, "texte")
	_bubble._input(_mouse(true, 0))
	_bubble._input(_mouse(false, 0))
	assert_bool(_bubble.get("_swallowing_tap")).is_false()


func test_long_press_works_after_a_dismissing_tap() -> void:
	_bubble.show_for(_target, "texte")
	_tap()
	_long_press()
	assert_bool(_bubble.visible).is_true()


func test_canceled_touch_ends_the_swallow_and_leaves_no_finger_down() -> void:
	# Arrange
	_bubble.show_for(_target, "texte")
	_bubble._input(_mouse(true, InputEvent.DEVICE_ID_EMULATION))
	_bubble._input(_touch(FIRST_FINGER, true))
	var canceled: InputEventScreenTouch = _touch(FIRST_FINGER, false)
	canceled.canceled = true
	# Act
	_bubble._input(canceled)
	_long_press()
	# Assert
	assert_bool(_bubble.get("_swallowing_tap")).is_false()
	assert_bool(_bubble.visible).is_true()


func test_finger_lifted_during_the_swallow_does_not_cancel_later_long_presses() -> void:
	# The second finger is down when the bubble comes, and lifts inside the dismissing tap.
	_bubble._input(_touch(SECOND_FINGER, true))
	_bubble.show_for(_target, "texte")
	_bubble._input(_mouse(true, InputEvent.DEVICE_ID_EMULATION))
	_bubble._input(_touch(FIRST_FINGER, true))
	_bubble._input(_touch(SECOND_FINGER, false))
	_bubble._input(_touch(FIRST_FINGER, false))
	_long_press()
	assert_bool(_bubble.visible).is_true()
