class_name TalentScreen
extends PanelContainer
## Content of the Talents tab (stories 006, 011, decision D5): the available points, the free reset,
## the tree and the detail of a node. A touch on a node opens its detail, with Retour and the fixed
## action Acheter; the reset asks for a confirmation in that same detail. The game keeps running.
## Pure presentation: reads a [TalentTree]; a purchase is reported through [signal buy_requested]
## and a confirmed reset through [signal reset_requested], and the composition root forwards them.
## The bonus is shown as text and the node state by color AND by a word, and what a locked node
## requires is printed on it: nothing lives in a tooltip alone, and color is never the only cue.
##
## Layout follows the pane's own size, not the orientation. Under
## [constant ManagementTabs.DETAIL_WIDE_WIDTH] or [constant WIDE_MIN_HEIGHT]: one branch at a time
## through a selector, as one column that scrolls, and the detail replaces the tree; the selector
## already names the branch, and the general text comes after the nodes, so that a short pane still
## shows a whole node. From both, and only if the data's branches fit ([method fits_full_tree]): the
## full tree, its columns sharing what the pane gives them, with the detail as a band under it
## (three columns of nodes leave no room beside them in a pane of about 680 u). The touched node
## stays visible over that band. No column has a fixed width, and the selector wraps, so no data can
## push the pane wider. A shape change keeps branch, detail, scroll and focus: same nodes, and
## [PaneFocus] settles what a redraw hides.
##
## Node buttons pass the mouse on: a drag in the tree scrolls it and never opens a detail.
##
## Usage:
## [codeblock]
## screen.buy_requested.connect(func(id: String) -> void: tree.buy(id))
## screen.reset_requested.connect(func() -> void: tree.reset())
## screen.setup(tree)    # builds the columns and the nodes, once
## screen.refresh()      # after any change of the tree
## screen.close_detail() # Escape: true when a detail was open
## [/codeblock]

## The player asked to buy the node [param id].
signal buy_requested(id: String)
## The player confirmed the reset.
signal reset_requested
## The first or the last focusable control may have changed (see [method first_focus]).
signal focus_ends_changed
## The focus was here and nothing usable remains; [param hidden] says if it showed a ring.
signal focus_lost(hidden: bool)

## What the detail shows.
enum Detail { NONE, NODE, RESET }

const NODE_MIN_SIZE: Vector2 = Vector2(170, 76)
const SEGMENT_HEIGHT: float = 50.0
const SEGMENT_FONT_SIZE: int = 16
## Height of the detail band under the full tree, its action bar not counted.
const DETAIL_BAND_HEIGHT: float = 130.0
## Least pane height of the full tree: lower, tree and band would crush each other.
const WIDE_MIN_HEIGHT: float = 480.0
const SELECTED_MARK: String = "» "
## Number of BranchPanelN and BranchTitleN variations of the theme, used in turn by the branches.
const BRANCH_STYLES: int = 3
## Branches of the data today; only a default for [method fits_full_tree].
const USUAL_BRANCHES: int = 3
## What the full tree adds around the nodes: the side margins of a column (BranchPanelN in the
## theme), the gap between columns, the side margins of the pane (ListPanel) and the scroll bar.
const COLUMN_SIDE_MARGINS: float = 12.0
const COLUMN_GAP: float = 8.0
const PANE_SIDE_MARGINS: float = 16.0
const SCROLL_BAR_ROOM: float = 16.0

var _tree: TalentTree
## One entry per node: {"def": TalentTree.TalentDef, "button": Button, "branch": int}.
var _rows: Array[Dictionary] = []
var _columns: Array[Control] = []
var _column_titles: Array[Label] = []
var _segments: Array[Button] = []
var _branch_index: int = 0
var _detail: Detail = Detail.NONE
var _selected_id: String = ""
var _wide: bool = false
## What the last redraw showed: see [method refresh_if_stale].
var _drawn_best_stage: int = -1
var _drawn_points: int = -1

@onready var _top: Control = %Top
@onready var _points_label: Label = %PointsLabel
@onready var _info_label: Label = %InfoLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _reset_button: Button = %ResetButton
@onready var _selector: HFlowContainer = %BranchSelector
@onready var _scroll: ScrollContainer = %Scroll
@onready var _scroll_body: Control = %ScrollBody
@onready var _branches_box: HBoxContainer = %Branches
@onready var _detail_panel: Control = %DetailPanel
@onready var _detail_scroll: ScrollContainer = %DetailScroll
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_status: Label = %DetailStatus
@onready var _back_button: Button = %BackButton
@onready var _action_button: Button = %ActionButton


func _ready() -> void:
	_reset_button.text = tr("Réinitialiser")
	_back_button.text = tr("Retour")
	_reset_button.pressed.connect(_on_reset_pressed)
	_back_button.pressed.connect(close_detail)
	_action_button.pressed.connect(_on_action_pressed)
	resized.connect(_on_resized)


## Builds the columns, the selector and the nodes from [param tree] and draws them. Call once.
func setup(tree: TalentTree) -> void:
	_tree = tree
	var branches: Array[Dictionary] = tree.branches()
	var group: ButtonGroup = ButtonGroup.new()
	for i in branches.size():
		_add_column(branches[i], i)
		_add_segment(branches[i], i, group)
	if not _segments.is_empty():
		_segments[0].button_pressed = true
	_on_resized()
	refresh()


## Redraws the points, every node and the detail from the tree. Safe while hidden.
func refresh() -> void:
	_redraw(PaneFocus.capture(self))


## Redraws only if the best stage or the unspent points moved since the last redraw: a stage change
## comes often and usually changes neither.
func refresh_if_stale() -> void:
	if _tree.best_stage() != _drawn_best_stage or _tree.available_points() != _drawn_points:
		refresh()


## True when a node's detail or the reset confirmation is open.
func is_detail_open() -> bool:
	return _detail != Detail.NONE


## What the detail shows now, a [enum Detail].
func detail() -> Detail:
	return _detail


## True when the pane is wide enough for the full tree.
func is_wide() -> bool:
	return _wide


## True when a pane of size [param pane] holds the full tree of [param branches] columns and its
## detail band. Past what the columns need at their least, the pane falls back on one branch at a
## time: more branches in the data never make the tab wider than its pane.
static func fits_full_tree(pane: Vector2, branches: int = USUAL_BRANCHES) -> bool:
	var least: float = maxf(ManagementTabs.DETAIL_WIDE_WIDTH, full_tree_min_width(branches))
	return pane.x >= least and pane.y >= WIDE_MIN_HEIGHT


## The least width of a pane showing [param branches] columns side by side.
static func full_tree_min_width(branches: int) -> float:
	var columns: float = float(branches) * (NODE_MIN_SIZE.x + COLUMN_SIDE_MARGINS)
	return columns + float(maxi(branches - 1, 0)) * COLUMN_GAP + PANE_SIDE_MARGINS + SCROLL_BAR_ROOM


## Index of the branch shown under the wide width, in the order of the data.
func open_branch() -> int:
	return _branch_index


## Closes the detail and gives the focus back to what opened it. False when none was open.
func close_detail() -> bool:
	if _detail == Detail.NONE:
		return false
	var focus: PaneFocus = PaneFocus.capture(self)
	focus.redirect(_reset_button if _detail == Detail.RESET else _button_of(_selected_id))
	_detail = Detail.NONE
	_selected_id = ""
	_redraw(focus)
	return true


## Closes the reset confirmation, for leaving the tab: a question must not wait there unseen. The
## detail of a node stays open.
func close_confirmation() -> void:
	if _detail == Detail.RESET:
		close_detail()


## The first control of this content for the Tab key, null when nothing can take the focus.
func first_focus() -> Control:
	var controls: Array[Control] = _focusables()
	return null if controls.is_empty() else controls[0]


## The last control of this content for the Tab key, null when nothing can take the focus.
func last_focus() -> Control:
	var controls: Array[Control] = _focusables()
	return null if controls.is_empty() else controls[-1]


func _redraw(focus: PaneFocus) -> void:
	if _detail == Detail.RESET and _tree.spent_points() == 0:
		_detail = Detail.NONE
	var available: int = _tree.available_points()
	_drawn_points = available
	_drawn_best_stage = _tree.best_stage()
	_points_label.text = tr("Points disponibles : %d") % available
	_info_label.text = tr("1 point tous les %d étages atteints. Meilleur étage : %d. Points dépensés : %d.") % [_tree.stages_per_point(), _tree.best_stage(), _tree.spent_points()]
	_reset_button.disabled = _tree.spent_points() == 0
	for row: Dictionary in _rows:
		_draw_node(row)
	var empty: String = _empty_text()
	_empty_label.text = empty
	_empty_label.visible = not empty.is_empty()
	_draw_detail()
	_apply_layout()
	var neighbours: Array[Control] = []
	if _detail != Detail.NONE:
		neighbours.append_array([_action_button, _back_button])
	neighbours.append_array(_focusables())
	if not focus.settle(neighbours):
		focus_lost.emit(focus.is_hidden())
	focus_ends_changed.emit()


func _apply_layout() -> void:
	var detail_open: bool = _detail != Detail.NONE
	var tree_shown: bool = _wide or not detail_open
	_top.visible = tree_shown
	_selector.visible = tree_shown and not _wide and _segments.size() > 1
	_scroll.visible = tree_shown
	_detail_panel.visible = detail_open
	_detail_panel.size_flags_vertical = Control.SIZE_FILL if _wide else Control.SIZE_EXPAND_FILL
	_detail_scroll.custom_minimum_size.y = DETAIL_BAND_HEIGHT if _wide else 0.0
	for i in _columns.size():
		_columns[i].visible = _wide or i == _branch_index
		_column_titles[i].visible = _wide
	_order_scroll_body()


# The general text goes under the nodes when the pane is short of room for them. Only on a real
# change: moving a child sorts its parent again.
func _order_scroll_body() -> void:
	var branches_index: int = 2 if _wide else 0
	var info_index: int = 0 if _wide else 2
	if _branches_box.get_index() == branches_index and _info_label.get_index() == info_index:
		return
	_scroll_body.move_child(_branches_box if _wide else _info_label, -1)
	_scroll_body.move_child(_info_label if _wide else _branches_box, 0)


func _add_segment(branch: Dictionary, index: int, group: ButtonGroup) -> void:
	var segment: Button = Button.new()
	segment.theme_type_variation = &"SegmentButton"
	segment.toggle_mode = true
	segment.button_group = group
	segment.text = tr(branch["name"])
	segment.custom_minimum_size.y = SEGMENT_HEIGHT
	segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	segment.add_theme_font_size_override("font_size", SEGMENT_FONT_SIZE)
	segment.pressed.connect(_on_branch_pressed.bind(index))
	_selector.add_child(segment)
	_segments.append(segment)


func _add_column(branch: Dictionary, index: int) -> void:
	var style: int = index % BRANCH_STYLES
	var column: PanelContainer = PanelContainer.new()
	column.theme_type_variation = StringName("BranchPanel%d" % style)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	column.add_child(content)
	var title: Label = Label.new()
	title.text = tr(branch["name"])
	title.theme_type_variation = StringName("BranchTitle%d" % style)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a long name must not widen the column
	content.add_child(title)
	_column_titles.append(title)
	var rows: Dictionary = {}
	for def: TalentTree.TalentDef in _tree.nodes_of(branch["id"]):
		if not rows.has(def.depth):
			rows[def.depth] = _new_row()
		(rows[def.depth] as VBoxContainer).add_child(_new_node(def, index))
	var depths: Array = rows.keys()
	depths.sort()
	for depth: Variant in depths:
		content.add_child(rows[depth])
	_branches_box.add_child(column)
	_columns.append(column)


# Nodes of the same depth stack: a branch is one column that scrolls, and only the width the pane
# gives it decides how wide its nodes are.
func _new_row() -> VBoxContainer:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	return row


func _new_node(def: TalentTree.TalentDef, branch_index: int) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = NODE_MIN_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # also keeps a long text from widening it
	button.toggle_mode = true
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.tooltip_text = _long_text(def)
	button.pressed.connect(_on_node_pressed.bind(def.id))
	_rows.append({"def": def, "button": button, "branch": branch_index})
	return button


func _draw_node(row: Dictionary) -> void:
	var def: TalentTree.TalentDef = row["def"]
	var button: Button = row["button"]
	var state: TalentTree.NodeState = _tree.state_of(def.id)
	var status: String = ""
	var variation: StringName = &"TalentLocked"
	match state:
		TalentTree.NodeState.OWNED:
			status = tr("Acheté")
			variation = &"TalentOwned"
		TalentTree.NodeState.BUYABLE:
			status = _cost_text(def.cost)
			variation = &"TalentBuyable"
		TalentTree.NodeState.UNAFFORDABLE:
			status = _missing_text(def)
			variation = &"TalentUnaffordable"
		TalentTree.NodeState.LOCKED:
			status = _requires_text(def)
	if button.theme_type_variation != variation:
		button.theme_type_variation = variation
	var chosen: bool = _detail == Detail.NODE and def.id == _selected_id
	button.set_pressed_no_signal(chosen)
	var shown_name: String = SELECTED_MARK + tr(def.display_name) if chosen else tr(def.display_name)
	button.text = "%s\n%s\n%s" % [shown_name, _effect_text(def), status]


func _draw_detail() -> void:
	match _detail:
		Detail.NODE:
			var def: TalentTree.TalentDef = _tree.node(_selected_id)
			_detail_title.text = tr(def.display_name)
			_detail_status.text = _detail_text(def)
			_action_button.theme_type_variation = &"BuyButton"
			_action_button.text = tr("Acheter")
			_action_button.disabled = not _tree.can_buy(def.id)
		Detail.RESET:
			_detail_title.text = tr("Réinitialiser les talents ?")
			_detail_status.text = tr("Tes talents achetés sont retirés et leurs points te sont rendus, gratuitement.")
			_action_button.theme_type_variation = &"DangerButton"
			_action_button.text = tr("Oui, réinitialiser")
			_action_button.disabled = false


func _detail_text(def: TalentTree.TalentDef) -> String:
	var lines: PackedStringArray = PackedStringArray([_stat_text(def)])
	match _tree.state_of(def.id):
		TalentTree.NodeState.OWNED:
			lines.append(tr("Talent acheté."))
		TalentTree.NodeState.BUYABLE:
			lines.append(_cost_text(def.cost))
		TalentTree.NodeState.UNAFFORDABLE:
			lines.append(_missing_text(def))
		TalentTree.NodeState.LOCKED:
			lines.append(_requires_text(def))
			lines.append(_cost_text(def.cost))
	return "\n".join(lines)


func _empty_text() -> String:
	var all_owned: bool = true
	for row: Dictionary in _rows:
		var state: TalentTree.NodeState = _tree.state_of((row["def"] as TalentTree.TalentDef).id)
		if state == TalentTree.NodeState.BUYABLE:
			return ""
		all_owned = all_owned and state == TalentTree.NodeState.OWNED
	if all_owned:
		return tr("Tous les talents sont achetés.")
	return tr("Aucun talent achetable pour le moment : un point s'obtient tous les %d étages.") % _tree.stages_per_point()


func _effect_text(def: TalentTree.TalentDef) -> String:
	match def.stat:
		TalentTree.STAT_CLICK_DAMAGE:
			return tr("Clic +%d %%") % def.percent
		TalentTree.STAT_COMPANION_DAMAGE:
			return tr("Compagnons +%d %%") % def.percent
		TalentTree.STAT_OFFLINE_GOLD:
			return tr("Hors-ligne +%d %%") % def.percent
	return tr("Or +%d %%") % def.percent


func _points_text(points: int) -> String:
	return tr("%d pt") % points if points == 1 else tr("%d pts") % points


func _cost_text(cost: int) -> String:
	return tr("Coût : %s") % _points_text(cost)


func _missing_text(def: TalentTree.TalentDef) -> String:
	return tr("%s, manque %s") % [_cost_text(def.cost), _points_text(def.cost - _tree.available_points())]


# A node needs all its prerequisites (TalentTree.prerequisites_met), hence "et" and never "ou".
func _requires_text(def: TalentTree.TalentDef) -> String:
	var names: PackedStringArray = PackedStringArray()
	for id: String in def.requires:
		names.append(tr(_tree.node(id).display_name))
	var count: int = names.size()
	if count < 2:
		return tr("Requiert : %s") % ", ".join(names)
	var head: String = ", ".join(names.slice(0, count - 1))
	return tr("Requiert : %s et %s") % [head, names[count - 1]]


func _stat_text(def: TalentTree.TalentDef) -> String:
	match def.stat:
		TalentTree.STAT_CLICK_DAMAGE:
			return tr("Dégâts de clic : +%d %%") % def.percent
		TalentTree.STAT_COMPANION_DAMAGE:
			return tr("Dégâts des compagnons : +%d %%") % def.percent
		TalentTree.STAT_OFFLINE_GOLD:
			return tr("Or gagné hors-ligne : +%d %%") % def.percent
	return tr("Or par ennemi vaincu : +%d %%") % def.percent


func _long_text(def: TalentTree.TalentDef) -> String:
	if def.requires.is_empty():
		return _stat_text(def)
	return "%s\n%s" % [_stat_text(def), _requires_text(def)]


func _focusables() -> Array[Control]:
	var controls: Array[Control] = [_reset_button]
	controls.append_array(_segments)
	for row: Dictionary in _rows:
		controls.append(row["button"])
	controls.append_array([_back_button, _action_button])
	return controls.filter(PaneFocus.usable)


func _button_of(id: String) -> Button:
	for row: Dictionary in _rows:
		if (row["def"] as TalentTree.TalentDef).id == id:
			return row["button"]
	return null


func _on_node_pressed(id: String) -> void:
	var focus: PaneFocus = PaneFocus.capture(self)
	_detail = Detail.NODE
	_selected_id = id
	for row: Dictionary in _rows:
		if (row["def"] as TalentTree.TalentDef).id == id:
			_show_branch(row["branch"])
	_redraw(focus)
	_reveal_node(_button_of(id))


# The band opening shrinks the tree: only the next frame's layout says where the node stands.
func _reveal_node(button: Button) -> void:
	if not _wide or not is_inside_tree():
		return
	await get_tree().process_frame
	if _wide and _scroll.is_visible_in_tree():
		_scroll.ensure_control_visible(button)


func _on_reset_pressed() -> void:
	var focus: PaneFocus = PaneFocus.capture(self)
	_detail = Detail.RESET
	_selected_id = ""
	_redraw(focus)
	# The confirmation is the next thing to read; in the wide layout the button above stays usable.
	if focus.focused() != null:
		_back_button.grab_focus(focus.is_hidden())


func _on_action_pressed() -> void:
	match _detail:
		Detail.NODE:
			buy_requested.emit(_selected_id)
		Detail.RESET:
			_detail = Detail.NONE
			reset_requested.emit()
			refresh()


func _on_branch_pressed(index: int) -> void:
	var focus: PaneFocus = PaneFocus.capture(self)
	_show_branch(index)
	_redraw(focus)


func _show_branch(index: int) -> void:
	_branch_index = index
	if index < _segments.size():
		# Not set_pressed_no_signal: it skips the group and would leave two segments lit.
		_segments[index].button_pressed = true


func _on_resized() -> void:
	var wide: bool = fits_full_tree(size, _columns.size())
	if wide == _wide:
		return
	_wide = wide
	if _tree != null:
		refresh()
