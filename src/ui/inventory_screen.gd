class_name InventoryScreen
extends PanelContainer
## Content of the Objets tab (stories 007, 011, decision D5): the five equipped slots, the bag with
## its count, and the detail of a touched item with its comparison against the worn item of the same
## type, with Retour and the fixed action Équiper. A worn item has nothing to be compared with: its
## detail lists its bonuses. Each slot takes one line, so that the bag shows on a phone without
## scrolling; the whole item is one touch away. The game keeps running behind it.
## Pure presentation: reads an [Inventory]; a press on Équiper is reported through
## [signal equip_requested] and the composition root forwards it. Rarity is shown by color, border
## AND word, a gain or a loss by color AND by its sign: color is never the only cue.
##
## Layout follows the pane's own width, not the orientation. Under
## [constant ManagementTabs.DETAIL_WIDE_WIDTH] the detail replaces the list; from that width they
## stand side by side. A shape change keeps detail, scroll and focus: same nodes, and [PaneFocus]
## settles what a redraw hides.
##
## Rows are pooled and reused: a redraw frees nothing, so loot received with this tab open keeps the
## selection, the scroll and the focus, which follows its item if the bag moves. Texts wrap and are
## never cut, and rows pass the mouse on: a drag in the list scrolls it and never opens a detail.
##
## Usage:
## [codeblock]
## screen.equip_requested.connect(func(uid: int) -> void: inventory.equip(uid))
## screen.setup(inventory)  # builds the slots and the comparison rows, once
## screen.refresh()         # after any change of the inventory
## screen.close_detail()    # Escape: true when a detail was open
## label.text = screen.describe(item)   # "Rare : Épée", also for the loot message
## [/codeblock]

## The player asked to equip the bag item [param uid].
signal equip_requested(uid: int)
## The first or the last focusable control may have changed (see [method first_focus]).
signal focus_ends_changed
## The focus was here and nothing usable remains; [param hidden] says if it showed a ring.
signal focus_lost(hidden: bool)

## Selection value meaning "no item" (a real uid is never negative).
const NO_SELECTION: int = -1
const ROW_MIN_HEIGHT: float = 50.0
## Room of the stat name in the comparison: its longest word, so that it wraps between words.
const COMPARE_NAME_MIN_WIDTH: float = 96.0
const SELECTED_MARK: String = "» "
const COLOR_GAIN: Color = Color(0.5, 0.95, 0.6)
const COLOR_LOSS: Color = Color(1, 0.55, 0.45)
const COLOR_NEUTRAL: Color = Color(0.75, 0.75, 0.8)
## Color of each rarity id of items.json. An id missing here falls back to [constant COLOR_NEUTRAL].
const RARITY_COLORS: Dictionary = {
	"common": Color(0.85, 0.85, 0.88),
	"rare": Color(0.55, 0.75, 1),
	"legendary": Color(1, 0.84, 0.25),
}
## Button variation of the theme for each rarity id; a missing id falls back to ItemRow.
const RARITY_VARIATIONS: Dictionary = {
	"common": &"ItemRowCommon",
	"rare": &"ItemRowRare",
	"legendary": &"ItemRowLegendary",
}

var _inventory: Inventory
var _selected_uid: int = NO_SELECTION
var _wide: bool = false
var _slot_buttons: Array[Button] = []
## Pool: one button per bag item, in bag order; the extra ones stay hidden.
var _bag_buttons: Array[Button] = []
## The uid each pooled button shows now; lets the focus follow an item when the bag moves.
var _row_uids: Array[int] = []
## One entry per stat of [constant Item.STATS]: {"cells", "name", "active", "candidate", "delta"}.
var _compare_rows: Array[Dictionary] = []
var _compare_header: Array = []

@onready var _equipped_title: Control = %EquippedTitle
@onready var _list_column: Control = %ListColumn
@onready var _detail_column: Control = %DetailColumn
@onready var _detail_bar: Control = %DetailBar
@onready var _back_button: Button = %BackButton
@onready var _equip_button: Button = %EquipButton
@onready var _slots_box: VBoxContainer = %Slots
@onready var _header: PaneHeader = %Header
@onready var _bag_label: Label = %BagLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _bag_list: VBoxContainer = %BagList
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_status: Label = %DetailStatus
@onready var _compare_table: GridContainer = %CompareTable


func _ready() -> void:
	_back_button.text = tr("Retour")
	_equip_button.text = tr("Équiper")
	_back_button.pressed.connect(close_detail)
	_equip_button.pressed.connect(_on_equip_pressed)
	resized.connect(_on_resized)


## Builds the slots and the comparison rows from [param inventory] and draws them. Call once.
func setup(inventory: Inventory) -> void:
	_inventory = inventory
	for def: LootTable.TypeDef in inventory.table().types():
		_add_slot(def)
	_compare_header = _new_compare_row()["cells"]
	_fill_compare_header()
	for stat: String in Item.STATS:
		_compare_rows.append(_new_compare_row())
	_on_resized()
	refresh()


## Redraws the slots, the bag and the detail from the inventory. Safe while hidden. A selected
## item that was sold is forgotten; one that was equipped stays selected.
func refresh() -> void:
	var focus: PaneFocus = PaneFocus.capture(self)
	if _inventory.find_item(_selected_uid) == null:
		_selected_uid = NO_SELECTION
	var row: int = _bag_buttons.find(focus.focused()) if focus.focused() is Button else -1
	var focused_uid: int = _row_uids[row] if row >= 0 else NO_SELECTION
	_draw_slots()
	_draw_bag()
	_draw_detail()
	_apply_layout()
	var neighbours: Array[Control] = []
	if row >= 0:
		var moved_to: int = _row_uids.find(focused_uid)
		if moved_to >= 0:
			focus.redirect(_bag_buttons[moved_to])
		elif not _row_uids.is_empty():
			neighbours.append(_bag_buttons[mini(row, _row_uids.size() - 1)])
	if is_detail_open():
		neighbours.append_array([_equip_button, _back_button])
	neighbours.append_array(_focusables())
	if not focus.settle(neighbours):
		focus_lost.emit(focus.is_hidden())
	focus_ends_changed.emit()


## True when an item's detail is open.
func is_detail_open() -> bool:
	return _selected_uid != NO_SELECTION


## The uid of the item shown in the detail, [constant NO_SELECTION] when none is.
func selected_uid() -> int:
	return _selected_uid


## True when the pane is wide enough for the list and the detail side by side.
func is_wide() -> bool:
	return _wide


## Closes the detail and gives the focus back to the row that opened it. False when none was open.
func close_detail() -> bool:
	if not is_detail_open():
		return false
	var focus: PaneFocus = PaneFocus.capture(self)
	var row: Button = _button_of(_selected_uid)
	if row != null:
		focus.redirect(row)
	_selected_uid = NO_SELECTION
	_draw_all_settling(focus)
	return true


## The header of the tab ("Sac N / M", story 019b), whose free part is a touch zone of the panel
## handle.
func pane_header() -> PaneHeader:
	return _header


## The first control of this content for the Tab key, null when nothing can take the focus.
func first_focus() -> Control:
	var controls: Array[Control] = _focusables()
	return null if controls.is_empty() else controls[0]


## The last control of this content for the Tab key, null when nothing can take the focus.
func last_focus() -> Control:
	var controls: Array[Control] = _focusables()
	return null if controls.is_empty() else controls[-1]


## Rarity and type of [param item] in words, for example "Légendaire : Épée": the adjective would
## not agree with every type if it followed it, and the data has one form of each.
func describe(item: Item) -> String:
	return tr("%s : %s") % [_rarity_name(item.rarity), _type_name(item.type)]


## The loot message [param lines] (title, item, sale if any) from the longest version to the
## shortest, for a toast to take the first that fits. Index 0 has the title; from index 1 it is gone,
## and [param short_sale], a short form of the sale, replaces the long one when given.
static func loot_versions(lines: PackedStringArray, short_sale: String) -> PackedStringArray:
	var versions: PackedStringArray = PackedStringArray(["\n".join(lines)])
	var last_line: String = short_sale if not short_sale.is_empty() else lines[-1]
	if lines.size() > 2:
		versions.append("%s\n%s" % [lines[1], last_line])
	versions.append(last_line)
	return versions


## Index in [param versions] (see [method loot_versions]) of the first version a toast may show.
## A narrow slot goes without the title; if the sale has a short form, it is all that is shown.
static func loot_first_version(versions: PackedStringArray, short_sale: String, narrow: bool) -> int:
	if not narrow:
		return 0
	return versions.size() - 1 if not short_sale.is_empty() else 1


## Most lines of the loot message in a slot [param room] high, at least one: when no version fits,
## the end of the text goes, and the message still stays out of what is under the slot.
static func loot_max_lines(room: float, line_height: float, margins: float) -> int:
	return maxi(1, floori((room - margins) / line_height))


## Color of the rarity [param rarity_id]. Always pair it with the rarity word.
func rarity_color(rarity_id: String) -> Color:
	return RARITY_COLORS.get(rarity_id, COLOR_NEUTRAL)


func _draw_all_settling(focus: PaneFocus) -> void:
	_draw_slots()
	_draw_bag()
	_draw_detail()
	_apply_layout()
	if not focus.settle(_focusables()):
		focus_lost.emit(focus.is_hidden())
	focus_ends_changed.emit()


func _apply_layout() -> void:
	var detail_open: bool = is_detail_open()
	_list_column.visible = _wide or not detail_open
	_detail_column.visible = _wide or detail_open
	# The slots name themselves: on a phone this line is what the first bag row needs.
	_equipped_title.visible = _wide


func _add_slot(def: LootTable.TypeDef) -> void:
	var button: Button = _new_item_button()
	button.pressed.connect(_on_slot_pressed.bind(def.id))
	_slots_box.add_child(button)
	_slot_buttons.append(button)


func _new_item_button() -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = &"ItemRow"
	button.custom_minimum_size = Vector2(0, ROW_MIN_HEIGHT)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true  # its pressed look, with the mark, says "selected"
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	return button


func _draw_slots() -> void:
	var types: Array[LootTable.TypeDef] = _inventory.table().types()
	for i in _slot_buttons.size():
		var button: Button = _slot_buttons[i]
		var worn: Item = _inventory.equipped(types[i].id)
		button.disabled = worn == null
		if worn == null:
			button.text = tr("%s : emplacement vide") % tr(types[i].display_name)
			button.tooltip_text = ""
			button.set_pressed_no_signal(false)
			_set_variation(button, &"ItemRow")
			continue
		var primary: String = worn.primary_stat()
		button.text = _marked(tr("%s, +%d %%") % [describe(worn), worn.percent(primary)], worn.uid)
		button.tooltip_text = _full_text(worn)
		_style_item_button(button, worn)


func _draw_bag() -> void:
	var bag: Array[Item] = _inventory.bag()
	var count_text: String = tr("Sac : %d / %d") % [bag.size(), _inventory.capacity()]
	_bag_label.text = tr("%s (plein)") % count_text if _inventory.is_full() else count_text
	_empty_label.visible = bag.is_empty()
	while _bag_buttons.size() < bag.size():
		_add_bag_button()
	_row_uids.clear()
	for i in _bag_buttons.size():
		var button: Button = _bag_buttons[i]
		button.visible = i < bag.size()
		if button.visible:
			var item: Item = bag[i]
			var primary: String = item.primary_stat()
			button.text = _marked(tr("%s, %s") % [describe(item), _bonus_text(primary, item.percent(primary))], item.uid)
			button.tooltip_text = _full_text(item)
			_style_item_button(button, item)
			_row_uids.append(item.uid)


func _add_bag_button() -> void:
	var button: Button = _new_item_button()
	button.pressed.connect(_on_bag_pressed.bind(_bag_buttons.size()))
	_bag_list.add_child(button)
	_bag_buttons.append(button)


func _draw_detail() -> void:
	var item: Item = _inventory.find_item(_selected_uid)
	var worn: bool = item != null and _inventory.equipped(item.type) == item
	_detail_bar.visible = item != null
	_equip_button.disabled = item == null or not _inventory.can_equip(_selected_uid)
	_equip_button.text = tr("Équipé") if worn else tr("Équiper")
	_compare_table.visible = item != null and not worn
	if item == null:
		_detail_title.text = tr("Sélectionne un objet")
		_detail_title.remove_theme_color_override("font_color")
		_detail_status.text = tr("Choisis un objet du sac pour le comparer à ton équipement.")
	else:
		_detail_title.text = describe(item)
		_detail_title.add_theme_color_override("font_color", rarity_color(item.rarity))
		_detail_status.text = _status_text(item)
		if not worn:
			_draw_comparison(item)


func _status_text(item: Item) -> String:
	var worn: Item = _inventory.equipped(item.type)
	if worn == item:
		var lines: PackedStringArray = PackedStringArray([tr("Cet objet est équipé.")])
		lines.append_array(_bonus_lines(item))
		return "\n".join(lines)
	if not _inventory.can_equip(item.uid):
		return tr("Ce type d'objet n'existe plus : impossible de l'équiper.")
	if worn == null:
		return tr("Emplacement vide : rien à remplacer.")
	return tr("Comparé à l'objet équipé (%s)") % describe(worn)


func _draw_comparison(item: Item) -> void:
	var rows: Array[Dictionary] = _inventory.compare(item)
	for i in rows.size():
		var data: Dictionary = rows[i]
		var row: Dictionary = _compare_rows[i]
		var active: int = data["active"]
		var offered: int = data["candidate"]
		for cell: Label in row["cells"]:
			cell.visible = active != 0 or offered != 0
		(row["name"] as Label).text = _stat_name(data["stat"])
		(row["active"] as Label).text = tr("%d %%") % active
		(row["candidate"] as Label).text = tr("%d %%") % offered
		_draw_delta(row["delta"], data["delta"])


func _draw_delta(label: Label, delta: int) -> void:
	if delta > 0:
		label.text = tr("+%d %%") % delta
		label.add_theme_color_override("font_color", COLOR_GAIN)
	elif delta < 0:
		label.text = tr("-%d %%") % absi(delta)
		label.add_theme_color_override("font_color", COLOR_LOSS)
	else:
		label.text = "="
		label.add_theme_color_override("font_color", COLOR_NEUTRAL)


func _fill_compare_header() -> void:
	var titles: PackedStringArray = PackedStringArray([tr("Bonus"), tr("Équipé"), tr("Cet objet"), tr("Écart")])
	for i in _compare_header.size():
		var cell: Label = _compare_header[i]
		cell.text = titles[i]
		cell.add_theme_color_override("font_color", COLOR_NEUTRAL)


# Four cells of the grid: the value columns take the width of their content, the name the rest.
func _new_compare_row() -> Dictionary:
	var stat_name: Label = _new_compare_cell()
	stat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_name.custom_minimum_size = Vector2(COMPARE_NAME_MIN_WIDTH, 0)
	stat_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var values: Array[Label] = []
	for i in 3:
		var cell: Label = _new_compare_cell()
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		values.append(cell)
	return {"cells": [stat_name, values[0], values[1], values[2]], "name": stat_name,
			"active": values[0], "candidate": values[1], "delta": values[2]}


func _new_compare_cell() -> Label:
	var cell: Label = Label.new()
	cell.theme_type_variation = &"PaneBody"
	_compare_table.add_child(cell)
	return cell


func _focusables() -> Array[Control]:
	var controls: Array[Control] = []
	controls.append_array(_slot_buttons)
	controls.append_array(_bag_buttons)
	controls.append_array([_back_button, _equip_button])
	return controls.filter(PaneFocus.usable)


# The row showing [param uid], in the bag or among the slots, null when none does.
func _button_of(uid: int) -> Button:
	var row: int = _row_uids.find(uid)
	if row >= 0:
		return _bag_buttons[row]
	var types: Array[LootTable.TypeDef] = _inventory.table().types()
	for i in _slot_buttons.size():
		var worn: Item = _inventory.equipped(types[i].id)
		if worn != null and worn.uid == uid:
			return _slot_buttons[i]
	return null


func _on_slot_pressed(type_id: String) -> void:
	var worn: Item = _inventory.equipped(type_id)
	if worn != null:
		_select(worn.uid)


func _on_bag_pressed(index: int) -> void:
	_select(_inventory.bag()[index].uid)


func _select(uid: int) -> void:
	_selected_uid = uid
	refresh()


func _on_equip_pressed() -> void:
	if _selected_uid != NO_SELECTION:
		equip_requested.emit(_selected_uid)


func _on_resized() -> void:
	var wide: bool = size.x >= ManagementTabs.DETAIL_WIDE_WIDTH
	if wide == _wide:
		return
	_wide = wide
	if _inventory != null:
		refresh()


# The selection reads on the mark too, not only on the thicker border.
func _marked(text: String, uid: int) -> String:
	return SELECTED_MARK + text if uid == _selected_uid else text


func _full_text(item: Item) -> String:
	var lines: PackedStringArray = PackedStringArray([describe(item)])
	lines.append_array(_bonus_lines(item))
	return "\n".join(lines)


func _bonus_lines(item: Item) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for stat: Variant in item.stats:
		lines.append(_bonus_text(stat, item.percent(stat)))
	return lines


func _bonus_text(stat: String, value: int) -> String:
	return tr("+%d %% %s") % [value, _stat_name(stat)]


# Ids the current data no longer knows are shown as they are: an old save stays readable.
func _stat_name(stat: String) -> String:
	var def: LootTable.StatDef = _inventory.table().stat_def(stat)
	return tr(def.display_name) if def != null else stat


func _type_name(type_id: String) -> String:
	var def: LootTable.TypeDef = _inventory.table().type_def(type_id)
	return tr(def.display_name) if def != null else type_id


func _rarity_name(rarity_id: String) -> String:
	var def: LootTable.RarityDef = _inventory.table().rarity_def(rarity_id)
	return tr(def.display_name) if def != null else rarity_id


func _style_item_button(button: Button, item: Item) -> void:
	_set_variation(button, RARITY_VARIATIONS.get(item.rarity, &"ItemRow"))
	button.set_pressed_no_signal(item.uid == _selected_uid)


# Changing a variation redraws the theme of the button: only when it really changes.
func _set_variation(button: Button, variation: StringName) -> void:
	if button.theme_type_variation != variation:
		button.theme_type_variation = variation
