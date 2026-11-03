class_name MouseFace
extends RefCounted
## The companions are mice (story 019b): a round head in the companion's colour, two big round
## ears with a pink inside, a pink nose, two black eyes, a dark outline. A few flat circles, drawn
## on any canvas item, so the spheres beside the monster and the portraits of the list share one
## drawing until the real artwork comes. Display only.
##
## Usage:
## [codeblock]
## func _draw() -> void:
##     MouseFace.draw(self, size / 2.0, 38.0, Color("#8bc34a"))
## [/codeblock]

const EAR_INSIDE: Color = Color("#F4A6B8")
const NOSE: Color = Color("#F06292")
const EYE: Color = Color("#10121C")
const OUTLINE: Color = Color("#0F1220")
## Shares of [param size] (the width of the whole silhouette); display settings.
const HEAD_RADIUS: float = 0.34
const EAR_RADIUS: float = 0.2
const EAR_OFFSET: Vector2 = Vector2(0.27, -0.25)
const EAR_INSIDE_RATIO: float = 0.55
const EYE_OFFSET: Vector2 = Vector2(0.12, -0.03)
const EYE_RADIUS: float = 0.045
const NOSE_OFFSET: Vector2 = Vector2(0.0, 0.1)
const NOSE_RADIUS: float = 0.06
## The silhouette (ears to chin) is centered on [param center]: the head sits this much lower.
const HEAD_DROP: float = 0.055
## Outline width: this share of the size, never under [constant MIN_OUTLINE] units.
const OUTLINE_RATIO: float = 0.06
const MIN_OUTLINE: float = 1.5


## Draws a mouse [param size] units wide, centered on [param center], on [param canvas].
static func draw(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	var head: Vector2 = center + Vector2(0.0, size * HEAD_DROP)
	var outline: float = maxf(size * OUTLINE_RATIO, MIN_OUTLINE)
	var ears: Array[Vector2] = [
		head + Vector2(-EAR_OFFSET.x, EAR_OFFSET.y) * size,
		head + EAR_OFFSET * size,
	]
	# Outlines first, so that the ears and the head merge into one silhouette.
	for ear: Vector2 in ears:
		canvas.draw_circle(ear, size * EAR_RADIUS + outline, OUTLINE)
	canvas.draw_circle(head, size * HEAD_RADIUS + outline, OUTLINE)
	for ear: Vector2 in ears:
		canvas.draw_circle(ear, size * EAR_RADIUS, color)
		canvas.draw_circle(ear, size * EAR_RADIUS * EAR_INSIDE_RATIO, EAR_INSIDE)
	canvas.draw_circle(head, size * HEAD_RADIUS, color)
	for side: float in [-1.0, 1.0]:
		canvas.draw_circle(head + Vector2(EYE_OFFSET.x * side, EYE_OFFSET.y) * size, size * EYE_RADIUS, EYE)
	canvas.draw_circle(head + NOSE_OFFSET * size, size * NOSE_RADIUS, NOSE)


## Half the height of the silhouette above and below [param center], outline included: what a
## layout must keep free around a mouse [param size] units wide.
static func half_extent(size: float) -> Vector2:
	var outline: float = maxf(size * OUTLINE_RATIO, MIN_OUTLINE)
	var half_width: float = size * (EAR_OFFSET.x + EAR_RADIUS) + outline
	var top: float = size * (-EAR_OFFSET.y + EAR_RADIUS - HEAD_DROP) + outline
	var bottom: float = size * (HEAD_RADIUS + HEAD_DROP) + outline
	return Vector2(half_width, maxf(top, bottom))
