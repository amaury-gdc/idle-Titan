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

## What the icon shows. COIN ignores [member color]: a coin is always gold. New kinds go at the end:
## the scenes store the number.
enum Kind { GEAR, COIN, CHEVRON, ARROW, STAR, BOLT, LOCK, ROTATE, MOUSE, SHIELD }

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
	draw_kind(self, kind, size / 2.0, minf(size.x, size.y) / 2.0, color)


## Draws an icon of [param icon] on [param canvas], from its own [method CanvasItem._draw]: for a
## control that draws its icon among other shapes (a skill orb) rather than holding a child.
static func draw_kind(canvas: CanvasItem, icon: Kind, center: Vector2, radius: float, tint: Color) -> void:
	match icon:
		Kind.GEAR:
			_draw_gear(canvas, center, radius, tint)
		Kind.COIN:
			_draw_coin(canvas, center, radius)
		Kind.CHEVRON:
			_draw_chevron(canvas, center, radius, tint)
		Kind.ARROW:
			_draw_arrow(canvas, center, radius, tint)
		Kind.STAR:
			_draw_star(canvas, center, radius, tint)
		Kind.BOLT:
			_draw_bolt(canvas, center, radius, tint)
		Kind.LOCK:
			_draw_lock(canvas, center, radius, tint)
		Kind.ROTATE:
			_draw_rotate(canvas, center, radius, tint)
		Kind.MOUSE:
			_draw_mouse(canvas, center, radius, tint)
		Kind.SHIELD:
			_draw_shield(canvas, center, radius, tint)


# A ring and its teeth: the hole is the inside of the ring, so the icon works on any background.
static func _draw_gear(canvas: CanvasItem, center: Vector2, radius: float, tint: Color) -> void:
	canvas.draw_arc(center, radius * 0.52, 0.0, TAU, CIRCLE_POINTS, tint, radius * 0.36, true)
	for i in GEAR_TEETH:
		canvas.draw_set_transform(center, TAU * float(i) / float(GEAR_TEETH))
		canvas.draw_rect(Rect2(-radius * 0.17, -radius, radius * 0.34, radius * 0.4), tint)
	canvas.draw_set_transform(Vector2.ZERO)


static func _draw_coin(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center, radius, UiPalette.YELLOW_PRESSED)
	canvas.draw_circle(center, radius * 0.8, UiPalette.YELLOW)
	canvas.draw_arc(center, radius * 0.5, 0.0, TAU, CIRCLE_POINTS, UiPalette.YELLOW_PRESSED, radius * 0.14, true)
	canvas.draw_arc(center, radius - COIN_OUTLINE / 2.0, 0.0, TAU, CIRCLE_POINTS, Color.BLACK, COIN_OUTLINE, true)


# Points up and right: "go up", the boss of the next stage.
static func _draw_arrow(canvas: CanvasItem, center: Vector2, radius: float, tint: Color) -> void:
	var tip: Vector2 = center + Vector2(radius, -radius) * 0.8
	canvas.draw_line(center + Vector2(-radius, radius) * 0.8, tip, tint, radius * 0.28, true)
	canvas.draw_colored_polygon(PackedVector2Array([
		tip + Vector2(radius * 0.15, -radius * 0.15),
		tip + Vector2(-radius * 0.85, 0.0),
		tip + Vector2(0.0, radius * 0.85),
	]), tint)


# Points down: "this opens".
static func _draw_chevron(canvas: CanvasItem, center: Vector2, radius: float, tint: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(-radius, -radius * 0.5),
		center + Vector2(radius, -radius * 0.5),
		center + Vector2(0.0, radius * 0.5),
	])
	canvas.draw_colored_polygon(points, tint)


# Five points, the inner ones at 40 % of the radius: a hit, "Gros coup".
static func _draw_star(canvas: CanvasItem, center: Vector2, radius: float, tint: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in 10:
		var reach: float = radius if i % 2 == 0 else radius * 0.42
		points.append(center + Vector2.from_angle(-PI / 2.0 + PI * float(i) / 5.0) * reach)
	canvas.draw_colored_polygon(points, tint)


# A zigzag in one polygon, leaning right: the frenzy.
static func _draw_bolt(canvas: CanvasItem, center: Vector2, radius: float, tint: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.2, -1.0) * radius,
		center + Vector2(-0.6, 0.15) * radius,
		center + Vector2(-0.05, 0.15) * radius,
		center + Vector2(-0.25, 1.0) * radius,
		center + Vector2(0.6, -0.2) * radius,
		center + Vector2(0.05, -0.2) * radius,
	]), tint)


# Three quarters of a circle and an arrow head at its end: "the next one", the buy mode that cycles.
static func _draw_rotate(canvas: CanvasItem, center: Vector2, radius: float, tint: Color) -> void:
	var ring: float = radius * 0.7
	var start: float = -PI * 0.35
	var end: float = start + PI * 1.5
	canvas.draw_arc(center, ring, start, end, CIRCLE_POINTS, tint, radius * 0.22, true)
	var tip: Vector2 = center + Vector2.from_angle(end) * ring
	var along: Vector2 = Vector2.from_angle(end + PI / 2.0)
	var across: Vector2 = Vector2.from_angle(end)
	canvas.draw_colored_polygon(PackedVector2Array([
		tip + along * radius * 0.45,
		tip + across * radius * 0.4,
		tip - across * radius * 0.4,
	]), tint)


# A head and two ears: the companions, "Souris".
static func _draw_mouse(canvas: CanvasItem, center: Vector2, radius: float, tint: Color) -> void:
	canvas.draw_circle(center + Vector2(-radius * 0.55, -radius * 0.45), radius * 0.4, tint)
	canvas.draw_circle(center + Vector2(radius * 0.55, -radius * 0.45), radius * 0.4, tint)
	canvas.draw_circle(center + Vector2(0.0, radius * 0.2), radius * 0.68, tint)


# An outline of a shield: the items, "Objets". Hollow, so it reads apart from a filled icon.
static func _draw_shield(canvas: CanvasItem, center: Vector2, radius: float, tint: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(-0.75, -0.8) * radius,
		center + Vector2(0.0, -1.0) * radius,
		center + Vector2(0.75, -0.8) * radius,
		center + Vector2(0.7, 0.15) * radius,
		center + Vector2(0.0, 1.0) * radius,
		center + Vector2(-0.7, 0.15) * radius,
		center + Vector2(-0.75, -0.8) * radius,
	])
	canvas.draw_polyline(points, tint, radius * 0.2, true)


# A body and its shackle: "locked".
static func _draw_lock(canvas: CanvasItem, center: Vector2, radius: float, tint: Color) -> void:
	canvas.draw_arc(center + Vector2(0.0, -radius * 0.2), radius * 0.4, PI, TAU, CIRCLE_POINTS / 2, tint, radius * 0.2, true)
	canvas.draw_line(center + Vector2(-radius * 0.4, -radius * 0.2), center + Vector2(-radius * 0.4, radius * 0.05), tint, radius * 0.2)
	canvas.draw_line(center + Vector2(radius * 0.4, -radius * 0.2), center + Vector2(radius * 0.4, radius * 0.05), tint, radius * 0.2)
	canvas.draw_rect(Rect2(center + Vector2(-radius * 0.7, 0.0), Vector2(radius * 1.4, radius * 0.95)), tint)
