class_name InventoryScreen
extends Control
## Modal inventory screen (story 007): the five equipped slots, the bag with its count, and the
## detail of the selected item with its comparison against the worn item of the same type.
## The dark background stops every click, and the keyboard focus stays inside (see [method open]).
## Pure presentation: reads an [Inventory]; a press on Équiper is reported through
## [signal equip_requested] and the composition root forwards it. Rarity is shown by color AND
## by its word, a gain or a loss by color AND by its sign: color is never the only cue.
##
## Rows are pooled and reused: a redraw never frees the button that holds the focus. Button
## texts are clipped, so a long text cannot widen a column past the window.
##
## Usage:
## [codeblock]
## screen.equip_requested.connect(func(uid: int) -> void: inventory.equip(uid))
## screen.closed.connect(on_closed)
## screen.setup(inventory)  # builds the slots and the comparison rows, once
## screen.open()            # shows it; close() or the player hides it
## screen.refresh()         # after any change of the inventory
## label.text = screen.describe(item)   # "Épée (Rare)", also for the loot message
## [/codeblock]

## The player asked to equip the bag item [param uid].
signal equip_requested(uid: int)
## The screen was hidden (close button, Escape or [method close]).
signal closed

## Selection value meaning "no item" (a real uid is never negative).
const NO_SELECTION: int = -1
const FONT_SIZE_SLOT: int = 15
const FONT_SIZE_BAG: int = 16
const FONT_SIZE_COMPARE: int = 16
const BAG_ROW_HEIGHT: float = 42.0
const SLOT_MIN_HEIGHT: float = 96.0
const COMPARE_VALUE_WIDTH: float = 76.0
const COMPARE_ROW_SEPARATION: int = 6
const BORDER_WIDTH: int = 2
const BORDER_WIDTH_SELECTED: int = 4
const BUTTON_MARGIN: float = 8.0
const SELECTED_MARK: String = "» "
const COLOR_ROW: Color = Color(0.13, 0.13, 0.18)
const COLOR_ROW_HOVER: Color = Color(0.2, 0.2, 0.26)
const COLOR_EMPTY: Color = Color(0.11, 0.11, 0.14)
const COLOR_TEXT_EMPTY: Color = Color(0.75, 0.75, 0.8)
const COLOR_TEXT: Color = Color(1, 1, 1)
const COLOR_GAIN: Color = Color(0.5, 0.95, 0.6)
const COLOR_LOSS: Color = Color(1, 0.55, 0.45)
const COLOR_NEUTRAL: Color = Color(0.75, 0.75, 0.8)
## Color of each rarity id of items.json. An id missing here falls back to [constant COLOR_NEUTRAL].
const RARITY_COLORS: Dictionary = {
	"common": Color(0.85, 0.85, 0.88),
	"rare": Color(0.55, 0.75, 1),
	"legendary": Color(1, 0.84, 0.25),
}

var _inventory: Inventory
var _selected_uid: int = NO_SELECTION
var _slot_buttons: Array[Button] = []
## Pool: one button per bag item, in bag order; the extra ones stay hidden.
var _bag_buttons: Array[Button] = []
## One entry per stat of [constant Item.STATS]: {"row", "name", "active", "candidate", "delta"}.
var _compare_rows: Array[Dictionary] = []
var _compare_header: HBoxContainer

@onready var _close_button: Button = %CloseButton
@onready var _equip_button: Button = %EquipButton
@onready var _slots_box: VBoxContainer = %Slots
@onready var _bag_label: Label = %BagLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _bag_list: VBoxContainer = %BagList
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_status: Label = %DetailStatus
@onready var _compare_table: VBoxContainer = %CompareTable


func _ready() -> void:
	_close_button.pressed.connect(close)
	_equip_button.pressed.connect(_on_equip_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Builds the slots and the comparison rows from [param inventory] and draws them. Call once.
func setup(inventory: Inventory) -> void:
	_inventory = inventory
	for def: LootTable.TypeDef in inventory.table().types():
		_add_slot(def)
	_compare_header = _new_compare_row()["row"]
	_fill_compare_header()
	for stat: String in Item.STATS:
		_compare_rows.append(_new_compare_row())
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


## Redraws the slots, the bag and the detail from the inventory. Safe while hidden. A selected
## item that was sold is forgotten; one that was equipped stays selected.
func refresh() -> void:
	if _inventory.find_item(_selected_uid) == null:
		_selected_uid = NO_SELECTION
	_draw_slots()
	_draw_bag()
	_draw_detail()


## Type and rarity of [param item] in words, for example "Épée (Légendaire)".
func describe(item: Item) -> String:
	return tr("%s (%s)") % [_type_name(item.type), _rarity_name(item.rarity)]


## Color of the rarity [param rarity_id]. Always pair it with the rarity word.
func rarity_color(rarity_id: String) -> Color:
	return RARITY_COLORS.get(rarity_id, COLOR_NEUTRAL)


func _add_slot(def: LootTable.TypeDef) -> void:
	var button: Button = _new_item_button()
	button.custom_minimum_size = Vector2(0, SLOT_MIN_HEIGHT)
	button.add_theme_font_size_override("font_size", FONT_SIZE_SLOT)
	button.add_theme_stylebox_override("disabled", _button_box(COLOR_EMPTY, COLOR_NEUTRAL, BORDER_WIDTH))
	button.add_theme_color_override("font_disabled_color", COLOR_TEXT_EMPTY)
	button.pressed.connect(_on_slot_pressed.bind(def.id))
	_slots_box.add_child(button)
	_slot_buttons.append(button)


func _new_item_button() -> Button:
	var button: Button = Button.new()
	button.clip_text = true  # a long text must not widen the column past the window
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return button


func _draw_slots() -> void:
	var types: Array[LootTable.TypeDef] = _inventory.table().types()
	for i in _slot_buttons.size():
		var button: Button = _slot_buttons[i]
		var worn: Item = _inventory.equipped(types[i].id)
		button.disabled = worn == null
		if worn == null:
			button.text = "%s\n%s" % [tr(types[i].display_name), tr("Emplacement vide")]
			continue
		var lines: PackedStringArray = PackedStringArray([describe(worn)])
		for stat: Variant in worn.stats:
			lines.append(_bonus_text(stat, worn.percent(stat)))
		button.text = _marked("\n".join(lines), worn.uid)
		button.tooltip_text = "\n".join(lines)
		_style_item_button(button, worn)


func _draw_bag() -> void:
	var bag: Array[Item] = _inventory.bag()
	var count_text: String = tr("Sac : %d / %d") % [bag.size(), _inventory.capacity()]
	_bag_label.text = tr("%s (plein)") % count_text if _inventory.is_full() else count_text
	_empty_label.visible = bag.is_empty()
	while _bag_buttons.size() < bag.size():
		_add_bag_button()
	for i in _bag_buttons.size():
		var button: Button = _bag_buttons[i]
		button.visible = i < bag.size()
		if button.visible:
			var item: Item = bag[i]
			var primary: String = item.primary_stat()
			button.text = _marked(tr("%s, %s") % [describe(item), _bonus_text(primary, item.percent(primary))], item.uid)
			button.tooltip_text = _tooltip(item)
			_style_item_button(button, item)


func _add_bag_button() -> void:
	var button: Button = _new_item_button()
	button.custom_minimum_size = Vector2(0, BAG_ROW_HEIGHT)
	button.add_theme_font_size_override("font_size", FONT_SIZE_BAG)
	button.pressed.connect(_on_bag_pressed.bind(_bag_buttons.size()))
	_bag_list.add_child(button)
	# By geometry "right" would land on Fermer: a gamepad player goes from an item to Équiper.
	button.focus_neighbor_right = button.get_path_to(_equip_button)
	_bag_buttons.append(button)


func _draw_detail() -> void:
	var item: Item = _inventory.find_item(_selected_uid)
	_equip_button.disabled = item == null or not _inventory.can_equip(_selected_uid)
	_compare_table.visible = item != null
	if item == null:
		_detail_title.text = tr("Sélectionne un objet")
		_detail_title.remove_theme_color_override("font_color")
		_detail_status.text = tr("Choisis un objet du sac pour le comparer à ton équipement.")
	else:
		_detail_title.text = describe(item)
		_detail_title.add_theme_color_override("font_color", rarity_color(item.rarity))
		_detail_status.text = _status_text(item)
		_draw_comparison(item)
	# A disabled button keeps the focus but does nothing: give it to something usable.
	if _equip_button.disabled and _equip_button.has_focus():
		_close_button.grab_focus()


func _status_text(item: Item) -> String:
	var worn: Item = _inventory.equipped(item.type)
	if worn == item:
		return tr("Cet objet est équipé.")
	if not _inventory.can_equip(item.uid):
		return tr("Ce type d'objet n'existe plus : impossible de l'équiper.")
	if worn == null:
		return tr("Emplacement vide : rien à remplacer.")
	return tr("Comparé à l'objet équipé : %s") % describe(worn)


func _draw_comparison(item: Item) -> void:
	var rows: Array[Dictionary] = _inventory.compare(item)
	for i in rows.size():
		var data: Dictionary = rows[i]
		var row: Dictionary = _compare_rows[i]
		var active: int = data["active"]
		var offered: int = data["candidate"]
		(row["row"] as HBoxContainer).visible = active != 0 or offered != 0
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
	var cells: Array[Node] = _compare_header.get_children()
	var titles: PackedStringArray = PackedStringArray([tr("Stat"), tr("Équipé"), tr("Cet objet"), tr("Écart")])
	for i in cells.size():
		(cells[i] as Label).text = titles[i]
		(cells[i] as Label).add_theme_color_override("font_color", COLOR_NEUTRAL)


func _new_compare_row() -> Dictionary:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", COMPARE_ROW_SEPARATION)
	var stat_name: Label = _new_compare_cell(row)
	stat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_name.clip_text = true  # a long stat name must not widen the column past the window
	var cells: Array[Label] = []
	for i in 3:
		var cell: Label = _new_compare_cell(row)
		cell.custom_minimum_size = Vector2(COMPARE_VALUE_WIDTH, 0)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cells.append(cell)
	_compare_table.add_child(row)
	return {"row": row, "name": stat_name, "active": cells[0], "candidate": cells[1], "delta": cells[2]}


func _new_compare_cell(row: HBoxContainer) -> Label:
	var cell: Label = Label.new()
	cell.add_theme_font_size_override("font_size", FONT_SIZE_COMPARE)
	row.add_child(cell)
	return cell


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


# The selection reads on the word of the mark too, not only on the thicker border.
func _marked(text: String, uid: int) -> String:
	return SELECTED_MARK + text if uid == _selected_uid else text


func _tooltip(item: Item) -> String:
	var lines: PackedStringArray = PackedStringArray([describe(item)])
	for stat: Variant in item.stats:
		lines.append(_bonus_text(stat, item.percent(stat)))
	return "\n".join(lines)


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
	var color: Color = rarity_color(item.rarity)
	var width: int = BORDER_WIDTH_SELECTED if item.uid == _selected_uid else BORDER_WIDTH
	button.add_theme_stylebox_override("normal", _button_box(COLOR_ROW, color, width))
	button.add_theme_stylebox_override("hover", _button_box(COLOR_ROW_HOVER, color, width))
	button.add_theme_stylebox_override("pressed", _button_box(COLOR_ROW_HOVER, color, width))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, color)


func _button_box(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	box.content_margin_left = BUTTON_MARGIN
	box.content_margin_right = BUTTON_MARGIN
	return box
