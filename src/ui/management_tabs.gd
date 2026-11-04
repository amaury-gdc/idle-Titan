class_name ManagementTabs
extends VBoxContainer
## The management zone of the main screen (stories 010, 011): the open tab's content, and the bar of
## three tabs under it, at the same place in both shapes. Souris, Objets and Talents are three
## panes of one tree: changing tab or shape only shows them, so each keeps its detail, branch and
## scroll. Holds which tab is selected and shows the notification dots it is told about; no game
## data. Left and right move the keyboard focus along the bar and wrap at its ends; Tab goes from
## the bar to the content, and each content reports when its first or last focusable control
## changes, because a detail or a selector moves them.
##
## Story 019b: each tab shows an icon and its name, and the open one a stripe of its colour; the
## Talents dot carries the number of points. In portrait a handle on top ([PanelHandle]) collapses
## the panel to the handle and the bar, and the free part of each tab header ([PaneHeader]) does the
## same; touching a tab unfolds it. Collapsed, the contents are hidden (never freed, so a list keeps
## its scroll) and no hidden control stays in the Tab order. The choice is reported through
## [signal collapsed_changed] and kept by the composition root ([DisplaySettings]). In landscape
## the handle is hidden and the panel always open; the choice is kept for the next portrait.
##
## Usage:
## [codeblock]
## tabs.selected()                                # ManagementTabs.Tab.COMPANIONS
## tabs.set_talent_points(3)                      # "3" in the dot of Talents
## tabs.set_dot(ManagementTabs.Tab.TALENTS, true)
## tabs.link_focus(last_of_game_zone, header_start)
## tabs.set_handle_enabled(true)                  # portrait
## tabs.set_collapsed(settings.panel_collapsed())
## tabs.close_open_detail()                       # Escape
## [/codeblock]

## The selection was set to [param tab] (a [enum Tab]), even to the same tab.
signal tab_selected(tab: int)
## The player collapsed or unfolded the panel (handle, header, or a tab that unfolds it).
signal collapsed_changed(collapsed: bool)

## The tabs, in the order of the bar.
enum Tab { COMPANIONS, INVENTORY, TALENTS }

## Font size of the tabs, under and from [constant CompanionPanel.WIDE_WIDTH] of zone width.
const FONT_SIZE_COMPACT: int = 16
const FONT_SIZE_WIDE: int = 20
## Width of a pane from which list and detail stand side by side and the tree is complete (spec,
## Layout Zones). Read against the pane's own width, never against the orientation.
const DETAIL_WIDE_WIDTH: float = 640.0
## Room around the number of the Talents dot (display setting).
const COUNT_MARGIN: float = 5.0

var _selected: Tab = Tab.COMPANIONS
var _collapsed: bool = false
var _handle_enabled: bool = false
var _talent_points: int = 0
var _talents_lit: bool = false
var _focus_before: Control
var _focus_after: Control
# The ends last linked: their links go when a detail or a tab change moves the ends.
var _linked_first: Control
var _linked_last: Control

@onready var _handle: PanelHandle = %PanelHandle
@onready var _companions_button: Button = %CompanionsTabButton
@onready var _inventory_button: Button = %InventoryButton
@onready var _talents_button: Button = %TalentsButton
@onready var _companions_dot: Control = %CompanionsDot
@onready var _inventory_dot: Control = %InventoryDot
@onready var _talents_dot: Control = %TalentsDot
@onready var _talents_count: Label = %TalentsCount
@onready var _labels: Array[Label] = [%CompanionsLabel, %InventoryLabel, %TalentsLabel]
@onready var _icons: Array[UiIcon] = [%CompanionsIcon, %InventoryIcon, %TalentsIcon]
@onready var _companion_panel: CompanionPanel = %CompanionPanel
@onready var _inventory_screen: InventoryScreen = %InventoryScreen
@onready var _talent_screen: TalentScreen = %TalentScreen


func _ready() -> void:
	var group: ButtonGroup = ButtonGroup.new()
	var buttons: Array[Button] = _buttons()
	for i in buttons.size():
		var button: Button = buttons[i]
		button.toggle_mode = true
		button.button_group = group
		button.focus_neighbor_left = button.get_path_to(buttons[posmod(i - 1, buttons.size())])
		button.focus_neighbor_right = button.get_path_to(buttons[posmod(i + 1, buttons.size())])
		button.text = ""
		_icons[i].color = tab_color(i)
		_stripe(button, tab_color(i))
	_labels[Tab.COMPANIONS].text = tr("Souris")
	_labels[Tab.INVENTORY].text = tr("Objets")
	_labels[Tab.TALENTS].text = tr("Talents")
	_style_count()
	_companions_button.pressed.connect(_on_tab_pressed.bind(Tab.COMPANIONS))
	_inventory_button.pressed.connect(_on_tab_pressed.bind(Tab.INVENTORY))
	_talents_button.pressed.connect(_on_tab_pressed.bind(Tab.TALENTS))
	_inventory_screen.focus_lost.connect(focus_active)
	_talent_screen.focus_lost.connect(focus_active)
	_handle.pressed.connect(toggle_collapsed)
	for pane: Variant in [_companion_panel, _inventory_screen, _talent_screen]:
		(pane.pane_header() as PaneHeader).handle_pressed.connect(toggle_collapsed)
	set_talent_points(0)
	_apply_collapse()
	select(Tab.COMPANIONS)
	resized.connect(_on_resized)
	_on_resized()


## The colour of the tab [param tab] (a [enum Tab]): its icon and its stripe.
static func tab_color(tab: int) -> Color:
	match tab:
		Tab.INVENTORY:
			return UiPalette.YELLOW
		Tab.TALENTS:
			return UiPalette.VIOLET_EDGE
	return UiPalette.TAB_MICE


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
	_show_contents()
	_relink_focus()
	tab_selected.emit(tab)


## Shows the unspent talent points in the dot of the Talents tab, and in its accessible name. The
## dot stays while points are left: it replaces the "(N)" the label used to carry.
func set_talent_points(points: int) -> void:
	_talent_points = points
	_talents_count.text = str(points) if points > 0 else ""
	_talents_button.accessibility_name = tr("Talents, %d points") % points if points > 0 else tr("Talents")
	_talents_dot.visible = _talents_lit or points > 0


## Turns the notification dot of [param tab] on or off. The Talents dot also shows while points
## are left (see [method set_talent_points]).
func set_dot(tab: Tab, lit: bool) -> void:
	match tab:
		Tab.INVENTORY:
			_inventory_dot.visible = lit
		Tab.TALENTS:
			_talents_lit = lit
			_talents_dot.visible = lit or _talent_points > 0
		_:
			_companions_dot.visible = lit


## Whether the handle is offered: true in portrait. Without it the panel shows open, whatever was
## chosen, and the choice stays for when it comes back.
func set_handle_enabled(enabled: bool) -> void:
	_handle_enabled = enabled
	_apply_collapse()


## Collapses or unfolds the panel without reporting it: the state read back from the settings.
func set_collapsed(collapsed: bool) -> void:
	_collapsed = collapsed
	_apply_collapse()


## True when the panel shows collapsed now: chosen so, and the handle offered.
func is_collapsed() -> bool:
	return _collapsed and _handle_enabled


## The handle and the header zones: collapses an open panel, unfolds a collapsed one, and reports it.
func toggle_collapsed() -> void:
	if not _handle_enabled:
		return
	_collapsed = not _collapsed
	_apply_collapse()
	collapsed_changed.emit(_collapsed)


## The Tab key order of the spec, which the tree cannot give as the bar sits under its content:
## [param before], then the handle in portrait, then the tab bar (one stop, the arrows move inside
## it), then the content, then [param after]. Keeps itself up to date afterwards. Call once, after
## the contents are set up.
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
	if is_collapsed():
		return false
	match _selected:
		Tab.INVENTORY:
			return _inventory_screen.close_detail()
		Tab.TALENTS:
			return _talent_screen.close_detail()
	return false


# The tab already open means "back to its list". A touch on a tab of a collapsed panel unfolds it.
func _on_tab_pressed(tab: Tab) -> void:
	if is_collapsed():
		_collapsed = false
		_apply_collapse()
		collapsed_changed.emit(false)
	elif tab == _selected:
		close_open_detail()
	select(tab)


func _apply_collapse() -> void:
	_handle.visible = _handle_enabled
	_handle.show_collapsed(is_collapsed())
	_show_contents()
	_relink_focus()


func _show_contents() -> void:
	for pane: int in Tab.values():
		_content_of(pane).visible = pane == _selected and not is_collapsed()
	for i in _labels.size():
		_labels[i].add_theme_color_override("font_color", UiPalette.TEXT_SOFT if i == _selected else UiPalette.TEXT_MUTED)


func _relink_focus() -> void:
	if _focus_before == null:
		return
	if _linked_first != null:
		_linked_first.focus_previous = NodePath()
	if _linked_last != null:
		_linked_last.focus_next = NodePath()
	var first: Control = null
	var last: Control = null
	if not is_collapsed():
		var content: Variant = _content_of(_selected)
		first = content.first_focus()
		last = content.last_focus()
	var stop: Button = _button_of(_selected)
	# The handle, when offered, comes between the game zone and the bar.
	var entry: Control = _handle if _handle_enabled else stop
	_focus_before.focus_next = _focus_before.get_path_to(entry)
	if _handle_enabled:
		_handle.focus_previous = _handle.get_path_to(_focus_before)
		_handle.focus_next = _handle.get_path_to(stop)
	_focus_after.focus_previous = _focus_after.get_path_to(last if last != null else stop)
	for button: Button in _buttons():
		button.focus_next = button.get_path_to(first if first != null else _focus_after)
		button.focus_previous = button.get_path_to(entry if _handle_enabled else _focus_before)
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


func _buttons() -> Array[Button]:
	return [_companions_button, _inventory_button, _talents_button]


# The open tab's stripe in the colour of the tab, on the theme's style of an open tab.
func _stripe(button: Button, color: Color) -> void:
	for state: StringName in [&"pressed", &"hover_pressed"]:
		var box: StyleBoxFlat = (button.get_theme_stylebox(state) as StyleBoxFlat).duplicate()
		box.border_color = color
		button.add_theme_stylebox_override(state, box)


# The Talents dot holds a number: the same red pill, with room on both sides of the digits.
func _style_count() -> void:
	var box: StyleBoxFlat = (_talents_dot.get_theme_stylebox(&"panel") as StyleBoxFlat).duplicate()
	box.content_margin_left = COUNT_MARGIN
	box.content_margin_right = COUNT_MARGIN
	box.set_corner_radius_all(10)
	_talents_dot.add_theme_stylebox_override(&"panel", box)


func _on_resized() -> void:
	var font_size: int = FONT_SIZE_COMPACT if size.x < CompanionPanel.WIDE_WIDTH else FONT_SIZE_WIDE
	for label: Label in _labels:
		label.add_theme_font_size_override("font_size", font_size)
