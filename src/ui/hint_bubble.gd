class_name HintBubble
extends PanelContainer
## The bubble that replaces every hover-only text (story 010): a long press or the keyboard focus on
## a watched control shows its text, read-only. It takes no mouse and no focus. The next tap only
## dismisses it: that tap reaches nothing behind. A hold never activates the control under it,
## even an enabled one, and works on a disabled one. [LongPress] holds the rules; this node feeds
## it the real input.
##
## Touch: Godot sends the emulated mouse press of the first finger BEFORE its touch event, so one
## tap arrives as up to four events. [method _input] handles the whole sequence of the dismissing
## tap, and releases are never consumed outside it, or the GUI would keep a stale mouse focus.
##
## Usage:
## [codeblock]
## bubble.watch(skill_button, func() -> String: return skill_description)
## bubble.show_for(dps_button, breakdown_text)
## bubble.cancel()     # tab or shape change, hidden page
## [/codeblock]

## Widest bubble, in logical units (display setting, not a gameplay value).
const MAX_WIDTH: float = 280.0

var _press: LongPress = LongPress.new()
var _texts: Dictionary = {}
var _held: Control
var _target: Control
var _css_per_unit: float = 1.0
var _swallowing_tap: bool = false

@onready var _label: Label = $Label


func _ready() -> void:
	resized.connect(_place)
	# A wrapped label finds its height after the layout, and a Control never shrinks by itself.
	_label.minimum_size_changed.connect(_fit)
	set_process(false)


func _process(delta: float) -> void:
	if not _press.tick(delta):
		if _press.state() == LongPress.State.IDLE:
			set_process(false)
		return
	set_process(false)
	show_for(_held, _texts[_held].call())
	_forget_button_press(_held)


func _input(event: InputEvent) -> void:
	if _swallowing_tap:
		_swallow(event)
		return
	if visible and _is_press(event):
		dismiss()
		_swallowing_tap = true
		_swallow(event)
		return
	if visible and event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()
		return
	_observe(event)


## Shows the text of [param source] (a Callable returning a String) for [param target] on a long
## press or on keyboard focus. Call once per target.
func watch(target: Control, source: Callable) -> void:
	_texts[target] = source
	target.gui_input.connect(_on_target_input.bind(target))
	target.focus_entered.connect(_on_target_focused.bind(target))
	target.focus_exited.connect(_on_target_unfocused.bind(target))


## Shows [param text] next to [param target], whole on screen.
func show_for(target: Control, text: String) -> void:
	_target = target
	var width: float = minf(MAX_WIDTH, get_parent_control().size.x - LongPress.BUBBLE_MARGIN * 2.0)
	_label.custom_minimum_size.x = width
	# Before the text: a wrapped label measured at no width is one letter per line.
	_label.size.x = width
	_label.text = text
	visible = true
	_fit()


## True while the bubble shows the text of [param target].
func is_showing_for(target: Control) -> bool:
	return visible and _target == target


## Hides the bubble.
func dismiss() -> void:
	visible = false
	_target = null


## Gives up the hold in progress and hides the bubble: tab or shape change.
func cancel() -> void:
	_press.cancel()
	set_process(false)
	dismiss()


## Like [method cancel] for a hidden page: the releases of the fingers down will never arrive.
func reset() -> void:
	_press.reset()
	_swallowing_tap = false
	cancel()


## How many CSS pixels one logical unit makes now, for the 10 CSS px of the movement limit.
func set_css_per_unit(value: float) -> void:
	_css_per_unit = value


func _on_target_input(event: InputEvent, target: Control) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	_held = target
	_press.begin(target.get_global_transform() * button.position)
	set_process(true)


# has_focus(true): a click also gives the focus, but hidden; only the keyboard shows the bubble.
func _on_target_focused(target: Control) -> void:
	if target.has_focus(true):
		show_for(target, _texts[target].call())


func _on_target_unfocused(target: Control) -> void:
	if _target == target:
		dismiss()


# Watches the fingers and the pointer wherever they are: a hold is cancelled by what happens off
# its target too. Nothing is consumed here.
func _observe(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		_press.touch(touch.index, touch.pressed)
		if not touch.pressed:
			_press.release()
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if not button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			_press.release()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_press.move(motion.position, _css_per_unit)
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null:
		_press.move(drag.position, _css_per_unit)


# Consumes the dismissing tap. An emulated release is followed by the release of the finger itself.
func _swallow(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	var button: InputEventMouseButton = event as InputEventMouseButton
	if touch == null and button == null:
		return
	get_viewport().set_input_as_handled()
	# Consumed for the GUI, not for the count of fingers: a release missed here would stay as a
	# finger down for good, and cancel every later long press.
	if touch != null:
		_press.touch(touch.index, touch.pressed)
	if touch != null and not touch.pressed:
		_swallowing_tap = false
	elif button != null and not button.pressed and button.device != InputEvent.DEVICE_ID_EMULATION:
		_swallowing_tap = false


func _is_press(event: InputEvent) -> bool:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		return touch.pressed
	var button: InputEventMouseButton = event as InputEventMouseButton
	return button != null and button.pressed


# The button saw the press and would act on the release: disabling it clears that. A disabled
# target stays as it is, and the toggle draws nothing as both happen in the same frame.
func _forget_button_press(target: Control) -> void:
	var button: BaseButton = target as BaseButton
	if button == null or button.disabled:
		return
	button.disabled = true
	button.disabled = false


func _fit() -> void:
	if not visible:
		return
	reset_size()
	_place()


func _place() -> void:
	if _target == null:
		return
	var view: Vector2 = get_parent_control().size
	position = LongPress.bubble_position(size, _target.get_global_rect(), view)
