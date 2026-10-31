class_name TalentScreen
extends Control
## Modal talent tree screen (story 006): one column per branch, one row per depth, the
## available points, the free reset and a close button. The dark background stops every
## click, and the keyboard focus stays inside (see [method open]).
## Pure presentation: reads a [TalentTree]; a press is reported through
## [signal buy_requested] or [signal reset_requested] and the composition root forwards it.
## The bonus is shown as text and the node state by color AND by a word, so that color is
## never the only cue.
##
## Usage:
## [codeblock]
## screen.buy_requested.connect(func(id: String) -> void: tree.buy(id))
## screen.reset_requested.connect(func() -> void: tree.reset())
## screen.closed.connect(on_closed)
## screen.setup(tree)    # builds the columns and the nodes, once
## screen.open()         # shows it; close() or the player hides it
## screen.refresh()      # after any change of the tree
## [/codeblock]

## The player pressed the buyable node [param id].
signal buy_requested(id: String)
## The player pressed the reset button.
signal reset_requested
## The screen was hidden (close button, Escape or [method close]).
signal closed

const FONT_SIZE_BRANCH: int = 24
const FONT_SIZE_NODE: int = 16
const NODE_MIN_SIZE: Vector2 = Vector2(170, 104)
const ROW_SEPARATION: int = 10
const COLUMN_SEPARATION: int = 8
const COLUMN_MARGIN: float = 8.0
const COLOR_OWNED: Color = Color(0.13, 0.5, 0.25)
const COLOR_OWNED_BORDER: Color = Color(0.5, 0.95, 0.6)
const COLOR_BUYABLE: Color = Color(0.55, 0.42, 0.05)
const COLOR_BUYABLE_HOVER: Color = Color(0.68, 0.53, 0.08)
const COLOR_BUYABLE_BORDER: Color = Color(1, 0.84, 0.25)
const COLOR_UNAFFORDABLE: Color = Color(0.25, 0.25, 0.3)
const COLOR_LOCKED: Color = Color(0.11, 0.11, 0.14)
const COLOR_TEXT_OWNED: Color = Color(0.9, 1, 0.92)
const COLOR_TEXT_UNAFFORDABLE: Color = Color(0.8, 0.8, 0.84)
const COLOR_TEXT_LOCKED: Color = Color(0.5, 0.5, 0.54)
const BORDER_WIDTH: int = 2
## Background of each branch column, by order of the branches in the data.
const BRANCH_COLORS: Array[Color] = [Color(0.2, 0.09, 0.08), Color(0.07, 0.12, 0.22), Color(0.17, 0.14, 0.05)]
const BRANCH_TITLE_COLORS: Array[Color] = [Color(1, 0.62, 0.45), Color(0.55, 0.75, 1), Color(1, 0.84, 0.25)]

var _tree: TalentTree
## One entry per node: {"def": TalentTree.TalentDef, "button": Button}.
var _rows: Array[Dictionary] = []

@onready var _points_label: Label = %PointsLabel
@onready var _info_label: Label = %InfoLabel
@onready var _reset_button: Button = %ResetButton
@onready var _close_button: Button = %CloseButton
@onready var _branches_box: HBoxContainer = %Branches


func _ready() -> void:
	_reset_button.pressed.connect(func() -> void: reset_requested.emit())
	_close_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Builds the columns and the nodes from [param tree] and draws them. Call once.
func setup(tree: TalentTree) -> void:
	_tree = tree
	var branches: Array[Dictionary] = tree.branches()
	for i in branches.size():
		_add_column(branches[i], i)
	refresh()


## Shows the screen, gives the keyboard focus to the close button and redraws. The caller
## first sets [member Control.focus_behavior_recursive] to disabled on the main screen: the
## engine then drops the focus of what lies behind, and this screen, enabled in its scene,
## is the only part that can take it.
func open() -> void:
	refresh()
	visible = true
	_close_button.grab_focus()


## Hides the screen and emits [signal closed]. Does nothing when it is not open.
func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Redraws the points and every node from the tree.
func refresh() -> void:
	var available: int = _tree.available_points()
	_points_label.text = tr("Points disponibles : %d") % available
	_info_label.text = tr("1 point tous les %d étages atteints. Meilleur étage : %d. Points dépensés : %d.") % [_tree.stages_per_point(), _tree.best_stage(), _tree.spent_points()]
	_reset_button.disabled = _tree.spent_points() == 0
	for row: Dictionary in _rows:
		_draw_node(row["button"], row["def"])


func _add_column(branch: Dictionary, index: int) -> void:
	var column: PanelContainer = PanelContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: StyleBoxFlat = _flat_box(BRANCH_COLORS[index % BRANCH_COLORS.size()])
	box.set_content_margin_all(COLUMN_MARGIN)
	column.add_theme_stylebox_override("panel", box)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", ROW_SEPARATION)
	column.add_child(content)
	var title: Label = Label.new()
	title.text = branch["name"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", FONT_SIZE_BRANCH)
	title.add_theme_color_override("font_color", BRANCH_TITLE_COLORS[index % BRANCH_TITLE_COLORS.size()])
	content.add_child(title)
	var rows: Dictionary = {}
	for def: TalentTree.TalentDef in _tree.nodes_of(branch["id"]):
		if not rows.has(def.depth):
			rows[def.depth] = _new_row()
		(rows[def.depth] as HBoxContainer).add_child(_new_node(def))
	var depths: Array = rows.keys()
	depths.sort()
	for depth: Variant in depths:
		content.add_child(rows[depth])
	_branches_box.add_child(column)


func _new_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", COLUMN_SEPARATION)
	return row


func _new_node(def: TalentTree.TalentDef) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = NODE_MIN_SIZE
	button.clip_text = true  # a long text must not widen the column past the screen
	button.add_theme_font_size_override("font_size", FONT_SIZE_NODE)
	button.add_theme_stylebox_override("normal", _border_box(COLOR_BUYABLE, COLOR_BUYABLE_BORDER))
	button.add_theme_stylebox_override("hover", _border_box(COLOR_BUYABLE_HOVER, COLOR_BUYABLE_BORDER))
	button.add_theme_stylebox_override("pressed", _border_box(COLOR_BUYABLE, COLOR_BUYABLE_BORDER))
	button.tooltip_text = _tooltip(def)
	button.pressed.connect(func() -> void: buy_requested.emit(def.id))
	_rows.append({"def": def, "button": button})
	return button


func _draw_node(button: Button, def: TalentTree.TalentDef) -> void:
	var state: TalentTree.NodeState = _tree.state_of(def.id)
	var status: String = ""
	match state:
		TalentTree.NodeState.OWNED:
			status = tr("Acheté")
			_set_disabled_look(button, _border_box(COLOR_OWNED, COLOR_OWNED_BORDER), COLOR_TEXT_OWNED)
		TalentTree.NodeState.BUYABLE:
			status = _cost_text(def.cost)
		TalentTree.NodeState.UNAFFORDABLE:
			status = tr("Coût : %d, manque %d") % [def.cost, def.cost - _tree.available_points()]
			_set_disabled_look(button, _flat_box(COLOR_UNAFFORDABLE), COLOR_TEXT_UNAFFORDABLE)
		TalentTree.NodeState.LOCKED:
			status = tr("Verrouillé")
			_set_disabled_look(button, _flat_box(COLOR_LOCKED), COLOR_TEXT_LOCKED)
	button.disabled = state != TalentTree.NodeState.BUYABLE
	button.text = "%s\n%s\n%s" % [def.display_name, _effect_text(def), status]


func _set_disabled_look(button: Button, box: StyleBoxFlat, text_color: Color) -> void:
	button.add_theme_stylebox_override("disabled", box)
	button.add_theme_color_override("font_disabled_color", text_color)


func _effect_text(def: TalentTree.TalentDef) -> String:
	match def.stat:
		TalentTree.STAT_CLICK_DAMAGE:
			return tr("Clic +%d %%") % def.percent
		TalentTree.STAT_COMPANION_DAMAGE:
			return tr("Compagnons +%d %%") % def.percent
		TalentTree.STAT_OFFLINE_GOLD:
			return tr("Hors-ligne +%d %%") % def.percent
	return tr("Or +%d %%") % def.percent


func _cost_text(cost: int) -> String:
	return tr("Coût : %d pt") % cost if cost == 1 else tr("Coût : %d pts") % cost


func _tooltip(def: TalentTree.TalentDef) -> String:
	var what: String = ""
	match def.stat:
		TalentTree.STAT_CLICK_DAMAGE:
			what = tr("Dégâts de clic : +%d %%") % def.percent
		TalentTree.STAT_COMPANION_DAMAGE:
			what = tr("Dégâts des compagnons : +%d %%") % def.percent
		TalentTree.STAT_OFFLINE_GOLD:
			what = tr("Or gagné hors-ligne : +%d %%") % def.percent
		_:
			what = tr("Or par ennemi vaincu : +%d %%") % def.percent
	if def.requires.is_empty():
		return what
	var names: PackedStringArray = PackedStringArray()
	for id: String in def.requires:
		names.append(_tree.node(id).display_name)
	return "%s\n%s" % [what, tr("Requiert : %s") % ", ".join(names)]


func _flat_box(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(6)
	return box


func _border_box(color: Color, border: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = _flat_box(color)
	box.border_color = border
	box.set_border_width_all(BORDER_WIDTH)
	return box
