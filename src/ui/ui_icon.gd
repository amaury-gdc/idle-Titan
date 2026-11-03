class_name UiIcon
extends Control
## A small vector icon drawn in a few flat shapes (story 019b): no asset, no texture, so it stays
## sharp at every scale of the web export. Decoration only: it takes no mouse and no focus, and the
## control around it carries the accessible name.
##
## Usage:
## [codeblock]
## var gear: UiIcon = UiIcon.new()
## gear.kind = UiIcon.Kind.GEAR
## gear.custom_minimum_size = Vector2(26, 26)
## button.add_child(gear)
## [/codeblock]

## What the icon shows. COIN ignores [member color]: a coin is always gold.
enum Kind { GEAR, COIN, CHEVRON, ARROW }

## Teeth of the gear (display setting).
const GEAR_TEETH: int = 8
## Points of a full circle (display setting).
const CIRCLE_POINTS: int = 32
## Width of the dark outline of the coin, in units (display setting).
const COIN_OUTLINE: float = 1.5

@export var kind: Kind = Kind.GEAR:
	set(value):
		kind = value
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	resized.connect(queue_redraw)


func _draw() -> void:
	var radius: float = minf(size.x, size.y) / 2.0
	var center: Vector2 = size / 2.0
	match kind:
		Kind.GEAR:
			_draw_gear(center, radius)
		Kind.COIN:
			_draw_coin(center, radius)
		Kind.CHEVRON:
			_draw_chevron(center, radius)
		Kind.ARROW:
			_draw_arrow(center, radius)


# A ring and its teeth: the hole is the inside of the ring, so the icon works on any background.
func _draw_gear(center: Vector2, radius: float) -> void:
	draw_arc(center, radius * 0.52, 0.0, TAU, CIRCLE_POINTS, color, radius * 0.36, true)
	for i in GEAR_TEETH:
		draw_set_transform(center, TAU * float(i) / float(GEAR_TEETH))
		draw_rect(Rect2(-radius * 0.17, -radius, radius * 0.34, radius * 0.4), color)
	draw_set_transform(Vector2.ZERO)


func _draw_coin(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, UiPalette.YELLOW_PRESSED)
	draw_circle(center, radius * 0.8, UiPalette.YELLOW)
	draw_arc(center, radius * 0.5, 0.0, TAU, CIRCLE_POINTS, UiPalette.YELLOW_PRESSED, radius * 0.14, true)
	draw_arc(center, radius - COIN_OUTLINE / 2.0, 0.0, TAU, CIRCLE_POINTS, Color.BLACK, COIN_OUTLINE, true)


# Points up and right: "go up", the boss of the next stage.
func _draw_arrow(center: Vector2, radius: float) -> void:
	var tip: Vector2 = center + Vector2(radius, -radius) * 0.8
	draw_line(center + Vector2(-radius, radius) * 0.8, tip, color, radius * 0.28, true)
	draw_colored_polygon(PackedVector2Array([
		tip + Vector2(radius * 0.15, -radius * 0.15),
		tip + Vector2(-radius * 0.85, 0.0),
		tip + Vector2(0.0, radius * 0.85),
	]), color)


# Points down: "this opens".
func _draw_chevron(center: Vector2, radius: float) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(-radius, -radius * 0.5),
		center + Vector2(radius, -radius * 0.5),
		center + Vector2(0.0, radius * 0.5),
	])
	draw_colored_polygon(points, color)
