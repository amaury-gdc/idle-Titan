class_name EnemyView
extends Control
## Draws the enemy as simple original shapes (no external art) and reports clicks
## that land on its body. Pure presentation: knows nothing about HP or gold.
##
## A boss (story 004) is drawn bigger, dark red with a gold outline, a gold crown
## and red pupils, so it can never be mistaken for a normal enemy.
##
## The node fills the slot the layout gives it. The drawing lives in a square box, the biggest one
## in that slot, capped by [constant MAX_BOX] and by [method set_box_limit]: all drawing and the hit
## radius follow [method box_scale] through [method CanvasItem.draw_set_transform]. The [member
## Control.scale] property stays reserved to [method play_hit].
##
## Stable contract, which the future cat art must keep: [signal clicked], [method set_stage],
## [method play_hit], [method anchor_global] (where effects aim) and [method hit_radius].
##
## Each finger on the body counts as one click (D6): a touch arrives as its own event, and the
## mouse press Godot emulates for the first finger is ignored, or that finger would count twice.
## There is no global attack key: the enemy takes the keyboard focus, and Space or Enter attacks
## while it has it, once per key press (no repeat when held).
##
## Usage: place in a scene, connect [signal clicked], call [method set_stage]
## when the stage changes (with [code]is_boss = true[/code] on a boss stage) and
## [method play_hit] on each hit.

## The body was clicked (left button / touch-emulated press).
signal clicked

## Size of the box the shapes below are drawn in (display setting, not a gameplay value).
const DRAW_UNITS: float = 300.0
## Biggest box, in logical units (display setting, not a gameplay value).
const MAX_BOX: float = 640.0
const BODY_RADIUS: float = 120.0
## Bigger body of a boss. Its horns and crown keep the same height as a normal
## enemy's, so the boss banner above the enemy is never covered.
const BOSS_BODY_RADIUS: float = 140.0
const COLOR_BOSS_BODY: Color = Color(0.36, 0.05, 0.1)
const COLOR_BOSS_OUTLINE: Color = Color(1.0, 0.8, 0.2)
const COLOR_BOSS_PUPIL: Color = Color(0.95, 0.1, 0.1)
## The keyboard focus ring, in drawing units: light with a dark edge, as on the buttons.
const FOCUS_RING_GAP: float = 4.0
const FOCUS_RING_WIDTH: float = 5.0
const FOCUS_RING_EDGE_WIDTH: float = 9.0
const FOCUS_RING_POINTS: int = 64
const COLOR_FOCUS_RING: Color = Color(1.0, 1.0, 1.0)
const COLOR_FOCUS_EDGE: Color = Color(0.04, 0.05, 0.09)

var _body_color: Color = Color(0.8, 0.4, 0.4)
var _is_boss: bool = false
var _tween: Tween
var _box_limit: float = MAX_BOX


func _ready() -> void:
	resized.connect(_on_resized)
	_on_resized()


## The body colour of [param stage] (visual variety only, not gameplay data).
static func stage_color(stage: int) -> Color:
	return Color.from_hsv(fposmod(float(stage) * 0.17, 1.0), 0.55, 0.85)


## Recolors the enemy for [param stage] (visual variety only, not gameplay data).
## With [param is_boss] it is drawn as the boss instead.
func set_stage(stage: int, is_boss: bool = false) -> void:
	_is_boss = is_boss
	_body_color = COLOR_BOSS_BODY if is_boss else stage_color(stage)
	queue_redraw()


## Short squash animation on a hit.
func play_hit() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	scale = Vector2(0.92, 0.92)
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.1)


## Caps the box at [param limit] units, on top of [constant MAX_BOX] and of the slot.
func set_box_limit(limit: float) -> void:
	_box_limit = limit
	queue_redraw()


## Side of the box the enemy is drawn in, in logical units.
func box_size() -> float:
	return minf(minf(size.x, size.y), minf(MAX_BOX, _box_limit))


## Factor from the drawing units to this node's units.
func box_scale() -> float:
	return box_size() / DRAW_UNITS


## The center of the enemy in global coordinates, from the unscaled rectangle: a squash in
## progress does not move it. Convert it to a layer's local space before using it there.
func anchor_global() -> Vector2:
	var center: Vector2 = position + size / 2.0
	var parent: Control = get_parent_control()
	return parent.get_global_transform() * center if parent != null else center


## Radius of the clickable body around the anchor, in this node's units.
func hit_radius() -> float:
	return _radius() * box_scale()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept", false, true):
		clicked.emit()
		accept_event()
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and touch.position.distance_to(_center()) <= hit_radius():
			clicked.emit()
			accept_event()
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	# Never device == 0: the emulation has its own id, a real mouse may have any other.
	if button.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if button.position.distance_to(_center()) <= hit_radius():
		clicked.emit()
		accept_event()


func _draw() -> void:
	var factor: float = box_scale()
	draw_set_transform(_center(), 0.0, Vector2(factor, factor))
	var c: Vector2 = Vector2.ZERO
	var radius: float = _radius()
	var dark: Color = _body_color.darkened(0.45)
	# Horns.
	draw_colored_polygon(PackedVector2Array([c + Vector2(-100, -60), c + Vector2(-70, -150), c + Vector2(-40, -100)]), dark)
	draw_colored_polygon(PackedVector2Array([c + Vector2(100, -60), c + Vector2(70, -150), c + Vector2(40, -100)]), dark)
	# Body, outline first.
	draw_circle(c, radius + (9.0 if _is_boss else 5.0), COLOR_BOSS_OUTLINE if _is_boss else dark)
	draw_circle(c, radius, _body_color)
	if _is_boss:
		draw_colored_polygon(PackedVector2Array([
				c + Vector2(-45, -128), c + Vector2(-45, -148), c + Vector2(-22, -136),
				c + Vector2(0, -150), c + Vector2(22, -136), c + Vector2(45, -148),
				c + Vector2(45, -128)]), COLOR_BOSS_OUTLINE)
	# Eyes.
	draw_circle(c + Vector2(-42, -20), 24.0, Color.WHITE)
	draw_circle(c + Vector2(42, -20), 24.0, Color.WHITE)
	var pupil: Color = COLOR_BOSS_PUPIL if _is_boss else Color.BLACK
	draw_circle(c + Vector2(-38, -16), 11.0, pupil)
	draw_circle(c + Vector2(38, -16), 11.0, pupil)
	# Mouth.
	draw_rect(Rect2(c + Vector2(-50, 42), Vector2(100, 14)), dark)
	# has_focus(true): the focus a click gives is hidden, only the keyboard draws the ring.
	if has_focus(true):
		var ring: float = BOSS_BODY_RADIUS + FOCUS_RING_GAP
		draw_arc(c, ring, 0.0, TAU, FOCUS_RING_POINTS, COLOR_FOCUS_EDGE, FOCUS_RING_EDGE_WIDTH)
		draw_arc(c, ring, 0.0, TAU, FOCUS_RING_POINTS, COLOR_FOCUS_RING, FOCUS_RING_WIDTH)


func _on_resized() -> void:
	pivot_offset = _center()
	queue_redraw()


func _radius() -> float:
	return BOSS_BODY_RADIUS if _is_boss else BODY_RADIUS


func _center() -> Vector2:
	return size / 2.0
