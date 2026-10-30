class_name EnemyView
extends Control
## Draws the enemy as simple original shapes (no external art) and reports clicks
## that land on its body. Pure presentation: knows nothing about HP or gold.
##
## Usage: place in a scene, connect [signal clicked], call [method set_stage]
## when the stage changes and [method play_hit] on each hit.

## The body was clicked (left button / touch-emulated press).
signal clicked

const BODY_RADIUS: float = 120.0

var _body_color: Color = Color(0.8, 0.4, 0.4)
var _tween: Tween


func _ready() -> void:
	pivot_offset = size / 2.0


## Recolors the enemy for [param stage] (visual variety only, not gameplay data).
func set_stage(stage: int) -> void:
	_body_color = Color.from_hsv(fposmod(float(stage) * 0.17, 1.0), 0.55, 0.85)
	queue_redraw()


## Short squash animation on a hit.
func play_hit() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	scale = Vector2(0.92, 0.92)
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.1)


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.position.distance_to(_center()) <= BODY_RADIUS:
		clicked.emit()
		accept_event()


func _draw() -> void:
	var c: Vector2 = _center()
	var dark: Color = _body_color.darkened(0.45)
	# Horns.
	draw_colored_polygon(PackedVector2Array([c + Vector2(-100, -60), c + Vector2(-70, -150), c + Vector2(-40, -100)]), dark)
	draw_colored_polygon(PackedVector2Array([c + Vector2(100, -60), c + Vector2(70, -150), c + Vector2(40, -100)]), dark)
	# Body, outline first.
	draw_circle(c, BODY_RADIUS + 5.0, dark)
	draw_circle(c, BODY_RADIUS, _body_color)
	# Eyes.
	draw_circle(c + Vector2(-42, -20), 24.0, Color.WHITE)
	draw_circle(c + Vector2(42, -20), 24.0, Color.WHITE)
	draw_circle(c + Vector2(-38, -16), 11.0, Color.BLACK)
	draw_circle(c + Vector2(38, -16), 11.0, Color.BLACK)
	# Mouth.
	draw_rect(Rect2(c + Vector2(-50, 42), Vector2(100, 14)), dark)


func _center() -> Vector2:
	return size / 2.0
