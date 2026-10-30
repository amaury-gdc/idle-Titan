class_name EnemyView
extends Control
## Draws the enemy as simple original shapes (no external art) and reports clicks
## that land on its body. Pure presentation: knows nothing about HP or gold.
##
## A boss (story 004) is drawn bigger, dark red with a gold outline, a gold crown
## and red pupils, so it can never be mistaken for a normal enemy.
##
## Usage: place in a scene, connect [signal clicked], call [method set_stage]
## when the stage changes (with [code]is_boss = true[/code] on a boss stage) and
## [method play_hit] on each hit.

## The body was clicked (left button / touch-emulated press).
signal clicked

const BODY_RADIUS: float = 120.0
## Bigger body of a boss. Its horns and crown keep the same height as a normal
## enemy's, so the boss banner above the enemy is never covered.
const BOSS_BODY_RADIUS: float = 140.0
const COLOR_BOSS_BODY: Color = Color(0.36, 0.05, 0.1)
const COLOR_BOSS_OUTLINE: Color = Color(1.0, 0.8, 0.2)
const COLOR_BOSS_PUPIL: Color = Color(0.95, 0.1, 0.1)

var _body_color: Color = Color(0.8, 0.4, 0.4)
var _is_boss: bool = false
var _tween: Tween


func _ready() -> void:
	pivot_offset = size / 2.0


## Recolors the enemy for [param stage] (visual variety only, not gameplay data).
## With [param is_boss] it is drawn as the boss instead.
func set_stage(stage: int, is_boss: bool = false) -> void:
	_is_boss = is_boss
	if is_boss:
		_body_color = COLOR_BOSS_BODY
	else:
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
	if button.position.distance_to(_center()) <= _radius():
		clicked.emit()
		accept_event()


func _draw() -> void:
	var c: Vector2 = _center()
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


func _radius() -> float:
	return BOSS_BODY_RADIUS if _is_boss else BODY_RADIUS


func _center() -> Vector2:
	return size / 2.0
