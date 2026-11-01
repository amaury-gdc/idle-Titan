class_name PaneFocus
extends RefCounted
## Keeps the keyboard focus alive across a redraw of a tab's content (story 011). The engine drops
## the focus of a node that hides, and a disabled button keeps a focus it cannot use. So a pane
## captures the focus before changing anything and settles it afterwards: the owner keeps it if it
## can, otherwise the first usable neighbour takes it. Display only, holds no game data.
##
## The focus ring stays as it was: a focus moved for a mouse or touch player remains hidden.
##
## Usage:
## [codeblock]
## var focus: PaneFocus = PaneFocus.capture(self)
## list.visible = false
## if not focus.settle([back_button, first_row]):
##     focus_lost.emit(focus.is_hidden())    # nothing usable here: the active tab takes it
## [/codeblock]

var _owner: Control
var _hidden: bool = true


## What holds the focus inside [param pane] now; the result is empty when it is held elsewhere.
static func capture(pane: Control) -> PaneFocus:
	var focus: PaneFocus = PaneFocus.new()
	if not pane.is_inside_tree():
		return focus
	var current: Control = pane.get_viewport().gui_get_focus_owner()
	if current != null and pane.is_ancestor_of(current):
		focus._owner = current
		focus._hidden = not current.has_focus(true)
	return focus


## True when [param control] can hold the focus and do something with it.
static func usable(control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	if not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	var button: BaseButton = control as BaseButton
	return button == null or not button.disabled


## The captured focus owner, null when the focus was elsewhere.
func focused() -> Control:
	return _owner


## True when the captured focus showed no ring (mouse or touch player).
func is_hidden() -> bool:
	return _hidden


## Sends the focus to [param target] at [method settle], if this pane held it.
func redirect(target: Control) -> void:
	if _owner != null:
		_owner = target


## Puts the focus back: on the owner if it is still usable, else on the first usable of
## [param neighbours]. False when the pane held the focus and nothing here can take it.
func settle(neighbours: Array[Control]) -> bool:
	if _owner == null:
		return true
	if usable(_owner):
		if not _owner.has_focus():
			_owner.grab_focus(_hidden)
		return true
	for neighbour: Control in neighbours:
		if usable(neighbour):
			neighbour.grab_focus(_hidden)
			return true
	return false
