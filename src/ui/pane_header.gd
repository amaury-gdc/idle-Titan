class_name PaneHeader
extends HBoxContainer
## The header of a tab of the management panel (story 019b): what the tab tells on the left, its
## action on the right, both children set in the scene. Between them it puts a free part, a flat
## button with no focus and no text, that also collapses the panel: [signal handle_pressed]. That
## part never covers the children around it, so a touch on "DPS des souris" or "Achat ×N" always
## reaches them (Amaury, 2026-11-04). The keyboard collapses the panel through the handle itself.
##
## Usage (in a scene: an HBoxContainer with this script, then its children):
## [codeblock]
## header.handle_pressed.connect(func() -> void: tabs.toggle_collapsed())
## header.free_part()   # the extra touch zone of the handle, between the children
## [/codeblock]

## The free part of the header was touched: the panel handle's job.
signal handle_pressed

## Space between the parts (display setting).
const SEPARATION: int = 8

var _free: Button = Button.new()


func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, AdaptiveLayout.PANE_HEADER_HEIGHT)
	add_theme_constant_override("separation", SEPARATION)
	_free.name = "FreePart"
	_free.flat = true
	_free.focus_mode = Control.FOCUS_NONE
	_free.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_free.size_flags_vertical = Control.SIZE_FILL
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		_free.add_theme_stylebox_override(state, empty)
	_free.pressed.connect(handle_pressed.emit)
	add_child(_free)
	# After the first child: the left part, the free part, then the action.
	move_child(_free, mini(1, get_child_count() - 1))


## The flat button between the left part and the action.
func free_part() -> Button:
	return _free
