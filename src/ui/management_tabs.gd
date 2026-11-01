class_name ManagementTabs
extends VBoxContainer
## The management zone of the main screen (stories 010, 011): the open tab's content, and the bar of
## three tabs under it, at the same place in both shapes. Compagnons, Objets and Talents are three
## panes of one tree: changing tab or shape only shows them, so each keeps its detail, branch and
## scroll. Holds which tab is selected and shows the notification dots it is told about; no game
## data, and no choice saved anywhere. Left and right move the keyboard focus along the bar and
## wrap at its ends; Tab goes from the bar to the content, and each content reports when its first
## or last focusable control changes, because a detail or a selector moves them.
##
## Usage:
## [codeblock]
## tabs.selected()                                # ManagementTabs.Tab.COMPANIONS
## tabs.set_talent_points(3)                      # "Talents (3)"
## tabs.set_dot(ManagementTabs.Tab.TALENTS, true)
## tabs.link_focus(last_of_game_zone, header_start)
## tabs.close_open_detail()                       # Escape
## [/codeblock]

## The selection was set to [param tab] (a [enum Tab]), even to the same tab.
signal tab_selected(tab: int)

## The tabs, in the order of the bar.
enum Tab { COMPANIONS, INVENTORY, TALENTS }

## Font size of the tabs, under and from [constant CompanionPanel.WIDE_WIDTH] of zone width.
const FONT_SIZE_COMPACT: int = 16
const FONT_SIZE_WIDE: int = 20
## Width of a pane from which list and detail stand side by side and the tree is complete (spec,
## Layout Zones). Read against the pane's own width, never against the orientation.
const DETAIL_WIDE_WIDTH: float = 640.0

var _selected: Tab = Tab.COMPANIONS
var _focus_before: Control
var _focus_after: Control
# The ends last linked: their links go when a detail or a tab change moves the ends.
var _linked_first: Control
var _linked_last: Control

@onready var _companions_button: Button = %CompanionsTabButton
@onready var _inventory_button: Button = %InventoryButton
@onready var _talents_button: Button = %TalentsButton
@onready var _companions_dot: Control = %CompanionsDot
@onready var _inventory_dot: Control = %InventoryDot
@onready var _talents_dot: Control = %TalentsDot
@onready var _companion_panel: CompanionPanel = %CompanionPanel
@onready var _inventory_screen: InventoryScreen = %InventoryScreen
@onready var _talent_screen: TalentScreen = %TalentScreen


func _ready() -> void:
	var group: ButtonGroup = ButtonGroup.new()
	var buttons: Array[Button] = [_companions_button, _inventory_button, _talents_button]
	for i in buttons.size():
		var button: Button = buttons[i]
		button.toggle_mode = true
		button.button_group = group
		button.focus_neighbor_left = button.get_path_to(buttons[posmod(i - 1, buttons.size())])
		button.focus_neighbor_right = button.get_path_to(buttons[posmod(i + 1, buttons.size())])
	_companions_button.text = tr("Compagnons")
	_inventory_button.text = tr("Objets")
	_companions_button.pressed.connect(_on_tab_pressed.bind(Tab.COMPANIONS))
	_inventory_button.pressed.connect(_on_tab_pressed.bind(Tab.INVENTORY))
	_talents_button.pressed.connect(_on_tab_pressed.bind(Tab.TALENTS))
	_inventory_screen.focus_lost.connect(focus_active)
	_talent_screen.focus_lost.connect(focus_active)
	select(Tab.COMPANIONS)
	resized.connect(_on_resized)
	_on_resized()


## The tab selected now.
func selected() -> Tab:
	return _selected


## Selects [param tab], shows its content and lights it in the bar.
func select(tab: Tab) -> void:
	if tab != Tab.TALENTS:
		_talent_screen.close_confirmation()
	_selected = tab
	# Not set_pressed_no_signal: it skips the group and would leave two tabs lit.
	_button_of(tab).button_pressed = true
	for pane: int in Tab.values():
		_content_of(pane).visible = pane == tab
	_relink_focus()
	tab_selected.emit(tab)


## Shows the unspent talent points in the label of the Talents tab.
func set_talent_points(points: int) -> void:
	_talents_button.text = tr("Talents (%d)") % points


## Turns the notification dot of [param tab] on or off.
func set_dot(tab: Tab, lit: bool) -> void:
	match tab:
		Tab.INVENTORY:
			_inventory_dot.visible = lit
		Tab.TALENTS:
			_talents_dot.visible = lit
		_:
			_companions_dot.visible = lit


## The Tab key order of the spec, which the tree cannot give as the bar sits under its content:
## [param before], then the tab bar (one stop, the arrows move inside it), then the content, then
## [param after]. Keeps itself up to date afterwards. Call once, after the contents are set up.
func link_focus(before: Control, after: Control) -> void:
	_focus_before = before
	_focus_after = after
	_inventory_screen.focus_ends_changed.connect(_relink_focus)
	_talent_screen.focus_ends_changed.connect(_relink_focus)
	_relink_focus()


## Gives the focus to the selected tab; [param hidden] keeps the ring off for a mouse user.
func focus_active(hidden: bool) -> void:
	_button_of(_selected).grab_focus(hidden)


## Closes the detail of the open tab, for Escape. False when there was none: Escape then does nothing.
func close_open_detail() -> bool:
	match _selected:
		Tab.INVENTORY:
			return _inventory_screen.close_detail()
		Tab.TALENTS:
			return _talent_screen.close_detail()
	return false


# The tab already open means "back to its list".
func _on_tab_pressed(tab: Tab) -> void:
	if tab == _selected:
		close_open_detail()
	select(tab)


func _relink_focus() -> void:
	if _focus_before == null:
		return
	if _linked_first != null:
		_linked_first.focus_previous = NodePath()
	if _linked_last != null:
		_linked_last.focus_next = NodePath()
	var content: Variant = _content_of(_selected)
	var first: Control = content.first_focus()
	var last: Control = content.last_focus()
	var stop: Button = _button_of(_selected)
	_focus_before.focus_next = _focus_before.get_path_to(stop)
	_focus_after.focus_previous = _focus_after.get_path_to(last if last != null else stop)
	for button: Button in [_companions_button, _inventory_button, _talents_button]:
		button.focus_next = button.get_path_to(first if first != null else _focus_after)
		button.focus_previous = button.get_path_to(_focus_before)
	if first != null:
		first.focus_previous = first.get_path_to(stop)
	if last != null:
		last.focus_next = last.get_path_to(_focus_after)
	_linked_first = first
	_linked_last = last


func _content_of(tab: int) -> Control:
	match tab:
		Tab.INVENTORY:
			return _inventory_screen
		Tab.TALENTS:
			return _talent_screen
	return _companion_panel


func _button_of(tab: Tab) -> Button:
	match tab:
		Tab.INVENTORY:
			return _inventory_button
		Tab.TALENTS:
			return _talents_button
	return _companions_button


func _on_resized() -> void:
	var font_size: int = FONT_SIZE_COMPACT if size.x < CompanionPanel.WIDE_WIDTH else FONT_SIZE_WIDE
	for button: Button in [_companions_button, _inventory_button, _talents_button]:
		button.add_theme_font_size_override("font_size", font_size)
