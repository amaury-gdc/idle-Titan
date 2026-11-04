class_name ItemIcon
extends Control
## The tile of an item (story 019b, lot 7): a dark rounded tile, the vector icon of its type
## ([UiIcon]) in the colour of its rarity, and, when [member marks] is above 0, as many dots in the
## top right corner (1 Commun, 2 Rare, 3 Légendaire): the rarity reads by a shape too, never by a
## colour alone. Drawn once, and again only when a property changes. Decoration only: no mouse, no
## focus; the control around it carries the name.
##
## Usage:
## [codeblock]
## var tile: ItemIcon = ItemIcon.new()
## tile.custom_minimum_size = Vector2(52, 52)
## tile.show_item(UiIcon.Kind.SWORD, Color("#7CC0FF"), 2)   # a rare sword, two dots
## [/codeblock]

## Corner of the tile, share of the tile the icon takes, and the dots (display settings).
const CORNER: int = 8
const ICON_RATIO: float = 0.3
const MARK_RADIUS: float = 2.5
const MARK_PITCH: float = 7.0
const MARK_INSET: float = 6.0
const MARK_OUTLINE: float = 1.0
## Most dots drawn: the rarities of the data beyond the third share three.
const MAX_MARKS: int = 3

var _kind: UiIcon.Kind = UiIcon.Kind.STAR
var _tint: Color = Color.WHITE
var _marks: int = 0
var _tile: StyleBoxFlat = StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_tile.bg_color = UiPalette.BACKGROUND
	_tile.set_corner_radius_all(CORNER)
	resized.connect(queue_redraw)


## Shows the icon [param kind] in [param tint], with [param marks] dots (0 for none). Redraws only
## when one of them changed.
func show_item(kind: UiIcon.Kind, tint: Color, marks: int) -> void:
	var shown: int = clampi(marks, 0, MAX_MARKS)
	if kind == _kind and tint == _tint and shown == _marks:
		return
	_kind = kind
	_tint = tint
	_marks = shown
	queue_redraw()


## The number of dots drawn now.
func marks() -> int:
	return _marks


## The icon drawn now.
func kind() -> UiIcon.Kind:
	return _kind


## The colour of the icon and of the dots now.
func tint() -> Color:
	return _tint


## Whether the tile itself is drawn: an icon inside a framed slot draws no tile of its own.
var draw_tile: bool = true:
	set(value):
		draw_tile = value
		queue_redraw()


func _draw() -> void:
	if draw_tile:
		draw_style_box(_tile, Rect2(Vector2.ZERO, size))
	UiIcon.draw_kind(self, _kind, size / 2.0, minf(size.x, size.y) * ICON_RATIO, _tint)
	# From the corner inwards, each dot on a dark ring so that it reads on any fill.
	for i in _marks:
		var dot: Vector2 = Vector2(size.x - MARK_INSET - float(i) * MARK_PITCH, MARK_INSET)
		draw_circle(dot, MARK_RADIUS + MARK_OUTLINE, UiPalette.BACKGROUND)
		draw_circle(dot, MARK_RADIUS, _tint)
