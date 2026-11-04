class_name MousePortrait
extends Control
## The portrait of a companion in its row (story 019b, lot 6): a dark rounded tile and the vector
## mouse of [MouseFace] in the companion's colour, until the real artwork comes. Drawn once, and again
## only when its size or colour changes: a list of eight never redraws per frame. Decoration only: no
## mouse, no focus; the row carries the name.
##
## Usage:
## [codeblock]
## var portrait: MousePortrait = MousePortrait.new()
## portrait.custom_minimum_size = Vector2(52, 52)
## portrait.mouse_size = 40.0
## portrait.color = Color("#8bc34a")
## [/codeblock]

## Corner of the tile (display setting).
const CORNER: int = 10

## Width of the mouse drawn in the tile, in units.
var mouse_size: float = 40.0:
	set(value):
		mouse_size = value
		queue_redraw()
## Colour of the mouse.
var color: Color = Color.WHITE:
	set(value):
		if value == color:
			return
		color = value
		queue_redraw()

var _tile: StyleBoxFlat = StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_tile.bg_color = UiPalette.BACKGROUND
	_tile.set_corner_radius_all(CORNER)
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_style_box(_tile, Rect2(Vector2.ZERO, size))
	MouseFace.draw(self, size / 2.0, minf(mouse_size, minf(size.x, size.y)), color)
