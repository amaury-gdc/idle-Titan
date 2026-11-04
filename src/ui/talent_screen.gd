class_name TalentScreen
extends PanelContainer
## Content of the Talents tab (stories 006, 011, decision D5, reworked by story 019 after
## design/talent-tree-v2.md "Interface"): the available points, the free reset with its real-time
## countdown, the tree by tiers ("Palier 3 : 4 points sur 8") and the card of a node. A touch on a
## node opens its card (effect, total before → after, cost, "Exclut X" for a top node), with Retour
## and the fixed action Acheter; the card closes once the node is bought. The action is ignored for
## [constant ACTION_GUARD_MSEC] after a card opens, so a double touch never buys. The reset asks for a
## confirmation in that same place, or says why it is refused (boss fight, wait mm:ss). The game
## keeps running. Pure presentation: reads a [TalentTree]; a purchase is reported through
## [signal buy_requested] and a confirmed reset through [signal reset_requested], and the composition
## root forwards them. Every node state is a word (Acheté, Coût, Manque, Palier fermé, Requiert,
## Exclu), shown on the tile itself: nothing lives in a tooltip alone, and color is never the only cue.
## The texts come from [TalentCardText].
##
## Layout follows the pane's own size, not the orientation. Narrow (the phone, the reference): one
## branch at a time through the sub-tabs, its nodes as a grid of [constant COMPACT_GRID_COLUMNS] tiles
## under each tier header, a shorter points line, and the card replaces the tree. From
## [constant DETAIL_BAND_MIN_WIDTH] wide and [constant WIDE_MIN_HEIGHT] high, the card is a band under
## the tree, which stays visible. From [method fits_full_tree]: the three columns side by side, one
## tile per row. No column has a fixed width, and the selector wraps, so no data can push the pane
## wider. A shape change keeps branch, card, scroll and focus: same nodes, and [PaneFocus] settles
## what a redraw hides.
##
## Node buttons pass the mouse on: a drag in the tree scrolls it and never opens a card.
##
## In the panel of story 019b: the tab header ([PaneHeader], 46 u) tells "21 points à dépenser", the
## number in 32 u yellow, the words on two lines when the pane is too narrow for one, and carries
## "Réinitialiser" as a [HeaderButton]. A tier header is "Palier 2" with its progress on the right
## ("Ouvert", or "0 / 2 points" and a lock). The nodes are [TalentTile]s: 64 u at least, a check in
## front of a bought one, and the real cost on a tile whose state does not say it.
##
## Usage:
## [codeblock]
## screen.buy_requested.connect(func(id: String) -> void: tree.buy(id))
## screen.reset_requested.connect(func() -> void: tree.try_reset(now, floors.is_boss_fight()))
## screen.set_context(skills, 12.0, clock, floors.is_boss_fight)   # optional, before setup
## screen.setup(tree)    # builds the columns and the nodes, once
## screen.refresh()      # after any change of the tree
## screen.open_node("frenzy_unlock")
## screen.close_detail() # Escape: true when a card was open
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

const NODE_MIN_SIZE: Vector2 = Vector2(170, TalentTile.MIN_HEIGHT)
## Least width of a tile in the grid of two (phone); a long word still fits on one line.
const COMPACT_TILE_MIN_WIDTH: float = 116.0
## Tiles per row in one branch at a time.
const COMPACT_GRID_COLUMNS: int = 2
const TILE_FONT_SIZE: int = 16
const TILE_GAP: int = 8
const SEGMENT_HEIGHT: float = 50.0
const SEGMENT_FONT_SIZE: int = 16
## Height of the detail band under the tree, its action bar not counted.
const DETAIL_BAND_HEIGHT: float = 130.0
## Least pane width that keeps the tree visible over the card (design/talent-tree-v2.md, Interface).
const DETAIL_BAND_MIN_WIDTH: float = 560.0
## Least pane height of the band: lower, tree and band would crush each other.
const WIDE_MIN_HEIGHT: float = 480.0
## Time after a card opens during which its action is ignored: a double touch must not buy.
const ACTION_GUARD_MSEC: int = 250
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
## "x / y points" of a tier header: secondary text, 14 u (spec 019b).
const TIER_PROGRESS_FONT_SIZE: int = 14
const TIER_LOCK_SIZE: Vector2 = Vector2(16, 16)
## "Réinitialiser": its grey edge, corners and side margins; drawn 44 u in the 46 u header.
const RESET_EDGE: int = 2
const RESET_CORNER: int = 8
const RESET_TEXT_MARGIN: float = 10.0

var _tree: TalentTree
var _text: TalentCardText
var _skills: SkillManager
var _offline_base_hours: float = 0.0
## Unix time now, as an int; replaced by the tests.
var _clock_unix: Callable = func() -> int: return int(Time.get_unix_time_from_system())
## Whether a boss fight runs now.
var _in_boss_fight: Callable = func() -> bool: return false
## Milliseconds since start, for the double-touch guard; replaced by the tests.
var _clock_msec: Callable = Time.get_ticks_msec
## One entry per node: {"def": TalentTree.TalentDef, "button": Button, "branch": int}.
var _rows: Array[Dictionary] = []
## One entry per tier header: {"label": Label (its name), "progress": Label, "lock": UiIcon,
## "branch": String, "tier": int}.
var _headers: Array[Dictionary] = []
var _grids: Array[GridContainer] = []
var _columns: Array[Control] = []
var _column_titles: Array[Label] = []
var _segments: Array[Button] = []
var _branch_index: int = 0
var _detail: Detail = Detail.NONE
var _selected_id: String = ""
## Refusal told by the composition root after a refused reset; "" when none. Used only without a
## context ([method set_context]): with one, the live refusal decides.
var _forced_refusal: String = ""
var _has_context: bool = false
## Stage of the next point, computed once per redraw (0 for none).
var _next_point: int = 0
var _opened_msec: int = -ACTION_GUARD_MSEC
var _wide: bool = false
var _band: bool = false
## What the last redraw showed: see [method refresh_if_stale].
var _drawn_best_stage: int = -1
var _drawn_points: int = -1
## Unix second of the last countdown check.
var _countdown_second: int = -1
var _countdown_left: int = -1

@onready var _top: Control = %Top
@onready var _points_label: Label = %PointsLabel
@onready var _points_word: Label = %PointsWord
@onready var _points_box: Control = %PointsBox
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
	_style_reset_button()
	_reset_button.pressed.connect(_on_reset_pressed)
	_back_button.pressed.connect(close_detail)
	_action_button.pressed.connect(_on_action_pressed)
	resized.connect(_on_resized)
	_points_word.resized.connect(func() -> void:
		if _tree != null:
			_draw_points_word())
	# The countdown only runs while the tab shows. A hidden ancestor (another tab) also sends it.
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _process(_delta: float) -> void:
	if _tree == null:
		return
	var now: int = int(_clock_unix.call())
	if now == _countdown_second:
		return
	_countdown_second = now
	var left: int = _tree.reset_seconds_left(now)
	if left == _countdown_left:
		return
	_countdown_left = left
	_draw_reset_button()
	if _detail == Detail.RESET:
		_draw_detail()


## Gives what the cards need besides the tree: [param skills] for the names and current values of the
## skills, [param offline_base_hours] the offline cap without talents, [param clock_unix] a Callable
## returning the Unix time as an int and [param in_boss_fight] one returning whether a boss fight runs.
## Optional; call before [method setup].
func set_context(skills: SkillManager, offline_base_hours: float, clock_unix: Callable, in_boss_fight: Callable) -> void:
	_has_context = true
	_skills = skills
	_offline_base_hours = offline_base_hours
	_clock_unix = clock_unix
	_in_boss_fight = in_boss_fight


## Builds the columns, the selector and the nodes from [param tree] and draws them. Call once.
func setup(tree: TalentTree) -> void:
	_tree = tree
	_text = TalentCardText.new(tree, _skills, _offline_base_hours)
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


## True when a node's card or the reset confirmation is open.
func is_detail_open() -> bool:
	return _detail != Detail.NONE


## What the detail shows now, a [enum Detail].
func detail() -> Detail:
	return _detail


## Id of the node whose card is open, "" when none.
func selected_node() -> String:
	return _selected_id


## True when the pane shows the three columns.
func is_wide() -> bool:
	return _wide


## True when the card is a band under a tree that stays visible.
func has_band() -> bool:
	return _band


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


## True when a pane of size [param pane] keeps the tree visible over the card.
static func fits_band(pane: Vector2) -> bool:
	return pane.x >= DETAIL_BAND_MIN_WIDTH and pane.y >= WIDE_MIN_HEIGHT


## Id of the node that unlocks the skill [param skill_id] in [param tree], "" when none does.
static func unlock_node_of(tree: TalentTree, skill_id: String) -> String:
	for def: TalentTree.TalentDef in tree.nodes():
		for effect: Dictionary in def.effects:
			if effect["type"] == TalentTree.EFFECT_SKILL_UNLOCK and effect["skill"] == skill_id:
				return def.id
	return ""


## Why the reset is refused now, in French (see [method TalentCardText.reset_refusal_text]).
static func reset_refusal_text(tree: TalentTree, now_unix: int, in_boss_fight: bool) -> String:
	return TalentCardText.reset_refusal_text(tree, now_unix, in_boss_fight)


## Index of the branch shown one at a time, in the order of the data.
func open_branch() -> int:
	return _branch_index


## Opens the card of the node [param id], on its branch, as a touch on it does. Unknown ids do nothing.
func open_node(id: String) -> void:
	if _tree == null or _tree.node(id) == null:
		return
	_on_node_pressed(id)


## Opens the reset card with [param refusal], the reason the composition root got from the tree.
func show_reset_refused(refusal: String) -> void:
	var focus: PaneFocus = PaneFocus.capture(self)
	_forced_refusal = refusal
	_open(Detail.RESET, "")
	_redraw(focus)


## Closes the detail and gives the focus back to what opened it. False when none was open.
func close_detail() -> bool:
	if _detail == Detail.NONE:
		return false
	var focus: PaneFocus = PaneFocus.capture(self)
	focus.redirect(_reset_button if _detail == Detail.RESET else _button_of(_selected_id))
	_detail = Detail.NONE
	_selected_id = ""
	_forced_refusal = ""
	_redraw(focus)
	return true


## Closes the reset confirmation, for leaving the tab: a question must not wait there unseen. The
## card of a node stays open.
func close_confirmation() -> void:
	if _detail == Detail.RESET:
		close_detail()


## The header of the tab (the points and "Réinitialiser", story 019b), whose free part is a touch
## zone of the panel handle.
func pane_header() -> PaneHeader:
	return _top as PaneHeader


## The first control of this content for the Tab key, null when nothing can take the focus.
func first_focus() -> Control:
	var controls: Array[Control] = _focusables()
	return null if controls.is_empty() else controls[0]


## The last control of this content for the Tab key, null when nothing can take the focus.
func last_focus() -> Control:
	var controls: Array[Control] = _focusables()
	return null if controls.is_empty() else controls[-1]


func _open(what: Detail, id: String) -> void:
	_detail = what
	_selected_id = id
	_opened_msec = _clock_msec.call()


func _redraw(focus: PaneFocus) -> void:
	if _detail == Detail.RESET and _tree.spent_points() == 0 and _forced_refusal.is_empty():
		_detail = Detail.NONE
	var available: int = _tree.available_points()
	_drawn_points = available
	_drawn_best_stage = _tree.best_stage()
	_next_point = _next_point_stage()
	_points_label.text = str(available)
	_draw_points_word()
	# The number and its words are two labels, in every layout.
	_info_label.text = _info_text()
	_draw_reset_button()
	for row: Dictionary in _rows:
		_draw_node(row)
	for header: Dictionary in _headers:
		_draw_tier_header(header)
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


# The button names the wait while there is one: the real time left, from the first draw.
func _draw_reset_button() -> void:
	var spent: int = _tree.spent_points()
	_reset_button.disabled = spent == 0
	var left: int = _tree.reset_seconds_left(int(_clock_unix.call()))
	if spent > 0 and left > 0 and spent <= _tree.earned_points():
		_reset_button.text = "%s\n%s" % [tr("Réinitialiser"), tr("dans %s") % TalentCardText.clock_text(left)]
	else:
		_reset_button.text = tr("Réinitialiser")


# "point à dépenser" or "points à dépenser", on two lines when the width the header gives the words
# is short of one (at 320 u wide). The label asks only for the width of its two lines, and clips: so
# the one-line text never widens the pane, and the choice follows the width it really gets. The
# header shares its width between the points (stretch ratio 4 in the scene) and its free part (1):
# one line at 390 u wide, two at 320, and a free part of 30 u or more in both.
func _draw_points_word() -> void:
	var words: String = tr("point à dépenser") if _tree.available_points() < 2 else tr("points à dépenser")
	var two_lines: String = words.replace(" à ", "\nà ")
	var least: float = 0.0
	for line: String in two_lines.split("\n"):
		least = maxf(least, _text_width(line))
	if _points_word.custom_minimum_size.x != ceilf(least):
		_points_word.custom_minimum_size.x = ceilf(least)
	var text: String = words if _points_word.size.x >= _text_width(words) else two_lines
	if _points_word.text != text:
		_points_word.text = text


func _text_width(text: String) -> float:
	var font: Font = _points_word.get_theme_font(&"font")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _points_word.get_theme_font_size(&"font_size")).x


func _draw_tier_header(header: Dictionary) -> void:
	var open: bool = _tree.tier_open(header["branch"], header["tier"])
	(header["label"] as Label).text = _text.tier_name(header["tier"])
	var progress: Label = header["progress"]
	progress.text = _text.tier_progress(header["branch"], header["tier"])
	progress.add_theme_color_override(&"font_color", UiPalette.YELLOW if open else UiPalette.TEXT_MUTED)
	(header["lock"] as Control).visible = not open


# A dark fill with a grey edge, drawn 44 u in the 46 u header like "Achat ×N"; touched over 50 u.
func _style_reset_button() -> void:
	_reset_button.custom_minimum_size.y = AdaptiveLayout.PANE_HEADER_HEIGHT
	var fills: Dictionary = {&"normal": UiPalette.BUTTON, &"hover": UiPalette.BUTTON_HOVER,
			&"pressed": UiPalette.ROW, &"hover_pressed": UiPalette.ROW}
	for state: StringName in fills:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = fills[state]
		box.set_border_width_all(RESET_EDGE)
		box.border_color = UiPalette.TEXT_MUTED
		box.set_corner_radius_all(RESET_CORNER)
		_reset_box_margins(box)
		_reset_button.add_theme_stylebox_override(state, box)
	var disabled: StyleBox = _reset_button.get_theme_stylebox(&"disabled").duplicate()
	_reset_box_margins(disabled)
	_reset_button.add_theme_stylebox_override(&"disabled", disabled)


# Two lines of 16 u fit the 44 u frame: no margin above or below the text.
func _reset_box_margins(box: StyleBox) -> void:
	box.content_margin_left = RESET_TEXT_MARGIN
	box.content_margin_right = RESET_TEXT_MARGIN
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	if box is StyleBoxFlat:
		(box as StyleBoxFlat).expand_margin_top = -HeaderButton.DRAWN_INSET
		(box as StyleBoxFlat).expand_margin_bottom = -HeaderButton.DRAWN_INSET


func _info_text() -> String:
	var next: int = _next_point
	var lines: String = tr("Meilleur étage : %d. Points dépensés : %d.") % [_tree.best_stage(), _tree.spent_points()]
	if next > 0:
		lines += " " + tr("Prochain point à l'étage %d.") % next
	return lines


# The first stage that earns one more point (0 for none); _redraw computes it once into _next_point.
func _next_point_stage() -> int:
	return _tree.stage_for_points(_tree.earned_points() + 1)


func _apply_layout() -> void:
	var detail_open: bool = _detail != Detail.NONE
	var tree_shown: bool = _band or not detail_open
	_top.visible = tree_shown
	_selector.visible = tree_shown and not _wide and _segments.size() > 1
	_scroll.visible = tree_shown
	_detail_panel.visible = detail_open
	_detail_panel.size_flags_vertical = Control.SIZE_FILL if _band else Control.SIZE_EXPAND_FILL
	_detail_scroll.custom_minimum_size.y = DETAIL_BAND_HEIGHT if _band else 0.0
	for i in _columns.size():
		_columns[i].visible = _wide or i == _branch_index
		_column_titles[i].visible = _wide
	var grid_columns: int = 1 if _wide else COMPACT_GRID_COLUMNS
	for grid: GridContainer in _grids:
		if grid.columns != grid_columns:
			grid.columns = grid_columns
	var tile_width: float = NODE_MIN_SIZE.x if _wide else COMPACT_TILE_MIN_WIDTH
	for row: Dictionary in _rows:
		var button: Button = row["button"]
		if button.custom_minimum_size.x != tile_width:
			button.custom_minimum_size = Vector2(tile_width, NODE_MIN_SIZE.y)
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


# A column holds, per tier, its header (when the tree has more than one tier) and a grid of tiles.
func _add_column(branch: Dictionary, index: int) -> void:
	var style: int = index % BRANCH_STYLES
	var column: PanelContainer = PanelContainer.new()
	column.theme_type_variation = StringName("BranchPanel%d" % style)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", TILE_GAP)
	column.add_child(content)
	var title: Label = Label.new()
	title.text = tr(branch["name"])
	title.theme_type_variation = StringName("BranchTitle%d" % style)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a long name must not widen the column
	content.add_child(title)
	_column_titles.append(title)
	var tiered: bool = _tree.tier_thresholds().size() > 1
	var grids: Dictionary = {}
	for def: TalentTree.TalentDef in _tree.nodes_of(branch["id"]):
		if not grids.has(def.tier):
			if tiered:
				content.add_child(_new_header(branch["id"], def.tier))
			var grid: GridContainer = GridContainer.new()
			grid.columns = COMPACT_GRID_COLUMNS
			grid.add_theme_constant_override("h_separation", TILE_GAP)
			grid.add_theme_constant_override("v_separation", TILE_GAP)
			grid.mouse_filter = Control.MOUSE_FILTER_PASS
			content.add_child(grid)
			_grids.append(grid)
			grids[def.tier] = grid
		(grids[def.tier] as GridContainer).add_child(_new_node(def, index))
	_branches_box.add_child(column)
	_columns.append(column)


# "Palier 2" on the left; on the right a lock while the tier is closed, and its progress.
func _new_header(branch_id: String, tier: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 6)
	var label: Label = Label.new()
	label.theme_type_variation = &"PaneBody"
	label.add_theme_font_size_override("font_size", TILE_FONT_SIZE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var lock: UiIcon = UiIcon.new()
	lock.kind = UiIcon.Kind.LOCK
	lock.color = UiPalette.TEXT_MUTED
	lock.custom_minimum_size = TIER_LOCK_SIZE
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lock)
	var progress: Label = Label.new()
	progress.add_theme_font_size_override("font_size", TIER_PROGRESS_FONT_SIZE)
	progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(progress)
	_headers.append({"label": label, "progress": progress, "lock": lock, "branch": branch_id, "tier": tier})
	return row


func _new_node(def: TalentTree.TalentDef, branch_index: int) -> Button:
	var button: TalentTile = TalentTile.new()
	button.custom_minimum_size = NODE_MIN_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # also keeps a long text from widening it
	button.add_theme_font_size_override("font_size", TILE_FONT_SIZE)
	button.toggle_mode = true
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(_on_node_pressed.bind(def.id))
	_rows.append({"def": def, "button": button, "branch": branch_index})
	return button


func _draw_node(row: Dictionary) -> void:
	var def: TalentTree.TalentDef = row["def"]
	var button: Button = row["button"]
	var variation: StringName = &"TalentLocked"
	match _tree.state_of(def.id):
		TalentTree.NodeState.OWNED:
			variation = &"TalentOwned"
		TalentTree.NodeState.BUYABLE:
			variation = &"TalentBuyable"
		TalentTree.NodeState.UNAFFORDABLE:
			variation = &"TalentUnaffordable"
	if button.theme_type_variation != variation:
		button.theme_type_variation = variation
	(button as TalentTile).set_owned(variation == &"TalentOwned")
	var chosen: bool = _detail == Detail.NODE and def.id == _selected_id
	button.set_pressed_no_signal(chosen)
	var lines: PackedStringArray = PackedStringArray([SELECTED_MARK + tr(def.display_name) if chosen else tr(def.display_name)])
	lines.append(_text.effect_short(def))
	var excludes: String = _text.excludes_text(def)
	if not excludes.is_empty():
		lines.append(excludes)
	lines.append(_text.tile_state_text(def))
	button.text = "\n".join(lines)


func _draw_detail() -> void:
	match _detail:
		Detail.NODE:
			var def: TalentTree.TalentDef = _tree.node(_selected_id)
			_detail_title.text = tr(def.display_name)
			_detail_status.text = "\n".join(_text.card_lines(def))
			_action_button.visible = true
			_action_button.theme_type_variation = &"BuyButton"
			_action_button.text = tr("Acheter")
			_action_button.disabled = not _tree.can_buy(def.id)
		Detail.RESET:
			var refusal: String = _reset_refusal()
			_action_button.visible = refusal.is_empty()
			_action_button.disabled = not refusal.is_empty()
			if refusal.is_empty():
				_detail_title.text = tr("Réinitialiser les talents ?")
				_detail_status.text = tr("Tes talents achetés sont retirés et leurs points te sont rendus, gratuitement. Ensuite, attends 1 h avant la suivante.")
				_action_button.theme_type_variation = &"DangerButton"
				_action_button.text = tr("Oui, réinitialiser")
			else:
				_detail_title.text = tr("Réinitialisation impossible")
				_detail_status.text = refusal


# What the tree says now. With a context the live answer is the only one: a refusal told during a
# boss fight or a wait must not outlive them. Without one, what the composition root was told.
func _reset_refusal() -> String:
	var refusal: String = TalentCardText.reset_refusal_text(_tree, int(_clock_unix.call()), bool(_in_boss_fight.call()))
	if _has_context or not refusal.is_empty():
		return refusal
	return _forced_refusal


func _empty_text() -> String:
	var all_owned: bool = true
	for row: Dictionary in _rows:
		var state: TalentTree.NodeState = _tree.state_of((row["def"] as TalentTree.TalentDef).id)
		if state == TalentTree.NodeState.BUYABLE:
			return ""
		all_owned = all_owned and state == TalentTree.NodeState.OWNED
	if all_owned:
		return tr("Tous les talents sont achetés.")
	var next: int = _next_point
	if next > 0:
		return tr("Aucun talent achetable pour le moment : prochain point à l'étage %d.") % next
	return tr("Aucun talent achetable pour le moment.")


func _missing_text(def: TalentTree.TalentDef) -> String:
	return _text.state_text(def)


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
	_forced_refusal = ""
	_open(Detail.NODE, id)
	for row: Dictionary in _rows:
		if (row["def"] as TalentTree.TalentDef).id == id:
			_show_branch(row["branch"])
	_redraw(focus)
	_reveal_node(_button_of(id))


# The band opening shrinks the tree: only the next frame's layout says where the node stands.
func _reveal_node(button: Button) -> void:
	if not _band or not is_inside_tree():
		return
	await get_tree().process_frame
	if _band and _scroll.is_visible_in_tree():
		_scroll.ensure_control_visible(button)


func _on_reset_pressed() -> void:
	var focus: PaneFocus = PaneFocus.capture(self)
	_forced_refusal = ""
	_open(Detail.RESET, "")
	_redraw(focus)
	# The confirmation is the next thing to read; in the band layout the button above stays usable.
	if focus.focused() != null:
		_back_button.grab_focus(focus.is_hidden())


func _on_action_pressed() -> void:
	# The second touch of a double touch lands here right after the first opened the card.
	if int(_clock_msec.call()) - _opened_msec < ACTION_GUARD_MSEC:
		return
	match _detail:
		Detail.NODE:
			var id: String = _selected_id
			buy_requested.emit(id)
			if _tree.is_owned(id):
				close_detail()
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


func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree())


func _on_resized() -> void:
	var wide: bool = fits_full_tree(size, _columns.size())
	var band: bool = wide or fits_band(size)
	if wide == _wide and band == _band:
		return
	_wide = wide
	_band = band
	if _tree != null:
		refresh()
