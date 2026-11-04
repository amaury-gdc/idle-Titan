class_name TalentTile
extends Button
## A node of the Talents tab (story 019b): a toggle button whose text is the node's lines, left
## aligned, at least [constant MIN_HEIGHT] tall and taller when its text needs it. A bought node also
## draws a yellow check in front of its first line, on top of the word "Acheté": color is never the
## only cue, and the word stays the one the tests and the screen reader read.
##
## Usage:
## [codeblock]
## var tile: TalentTile = TalentTile.new()
## tile.text = "Poigne ferme\nClic +8 %\nAcheté"
## tile.set_owned(true)    # after the theme variation is set: the check and its room
## [/codeblock]

## Least height of a tile (spec 019b: tiles of 64 u at least, taller with their text).
const MIN_HEIGHT: float = 64.0
## Room the check takes before the text, its own width and the gap after it.
const CHECK_ROOM: float = 22.0
## Radius of the drawn check.
const CHECK_RADIUS: float = 8.0
const CHECK_COLOR: Color = UiPalette.YELLOW
const STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]

var _owned: bool = false
## The variation the room was made for: a new variation needs new boxes.
var _room_for: StringName = &""


func _init() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT


## Shows or hides the check, and gives the text the room it takes.
func set_owned(owned: bool) -> void:
	if owned == _owned and (not owned or _room_for == theme_type_variation):
		return
	_owned = owned
	_room_for = theme_type_variation if owned else &""
	for state: StringName in STATES:
		remove_theme_stylebox_override(state)
	if owned:
		for state: StringName in STATES:
			var box: StyleBox = get_theme_stylebox(state).duplicate()
			box.content_margin_left += CHECK_ROOM
			add_theme_stylebox_override(state, box)
	queue_redraw()


## True when the check shows.
func is_owned() -> bool:
	return _owned


## Center of the check in the tile's coordinates: in the room before the first line of the text.
func check_center() -> Vector2:
	var box: StyleBox = get_theme_stylebox(&"normal")
	var line: float = get_theme_font(&"font").get_height(get_theme_font_size(&"font_size"))
	# The text block is centered in the tile when a row mate makes it taller than its text.
	var top: float = maxf((size.y - get_minimum_size().y) / 2.0, 0.0) + box.get_margin(SIDE_TOP)
	return Vector2(box.get_margin(SIDE_LEFT) - CHECK_ROOM + CHECK_RADIUS, top + line / 2.0)


func _draw() -> void:
	if _owned:
		UiIcon.draw_kind(self, UiIcon.Kind.CHECK, check_center(), CHECK_RADIUS, CHECK_COLOR)
