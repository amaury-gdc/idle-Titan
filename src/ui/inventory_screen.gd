class_name InventoryScreen
extends PanelContainer
## Content of the Objets tab (stories 007, 011, decision D5; story 019b, lot 7). The header holds
## the slots of the worn items, one per type of the data, and "Sac N / M"; the list holds the bag, one
## card per item; a touched item opens its detail, with its comparison against the worn item of the
## same type, Retour and the fixed action Équiper. A worn item has nothing to be compared with: its
## detail lists its bonuses and its action reads "Équipé", greyed, with a tick. The game keeps running
## behind it.
##
## A slot (48 u drawn, 50 u touched) shows the icon of its type in the colour of the rarity, a border
## of that colour, and 1, 2 or 3 dots in a corner for Commun, Rare, Légendaire (Amaury, 2026-11-04):
## rarity reads by a shape too. An empty slot is grey and takes no touch. A card of the bag (70 u, more
## when a long bonus wraps) has a band of the rarity colour, the icon tile, the type in bold and the
## rarity in words and colour ("Plastron Légendaire"), the main bonus in bold, and a grey line: what the
## slot wears for the same bonus ("Équipé : +5 %"), the whole bonus of the worn item when it is another
## one ("Équipé : +5 % Dégâts globaux"), or "Emplacement vide". Its "Équiper" button (green, 112 x 56)
## equips at once; the rest of the card opens the comparison and never equips by itself.
##
## Pure presentation: reads an [Inventory]; a press on Équiper is reported through
## [signal equip_requested] and the composition root forwards it. Rarity is shown by colour, border,
## dots AND word, a gain or a loss by colour AND by its sign: colour is never the only cue.
##
## Layout follows the pane's own width, not the orientation. Under
## [constant ManagementTabs.DETAIL_WIDE_WIDTH] the detail replaces the list; from that width they
## stand side by side. A shape change keeps detail, scroll and focus: same nodes, and [PaneFocus]
## settles what a redraw hides.
##
## Cards are pooled and reused: a redraw frees nothing, so loot received with this tab open keeps the
## selection, the scroll and the focus, which follows its item if the bag moves. Texts wrap and are
## never cut, and the cards pass the mouse on: a drag in the list scrolls it, never opens a detail and
## never equips.
##
## Usage:
## [codeblock]
## screen.equip_requested.connect(func(uid: int) -> void: inventory.equip(uid))
## screen.setup(inventory)  # builds the slots and the comparison rows, once
## screen.refresh()         # after any change of the inventory
## screen.close_detail()    # Escape: true when a detail was open
## label.text = screen.describe(item)   # "Rare : Épée", also for the loot message
## screen.worn_line(item)   # "Équipé : +5 %"
## [/codeblock]

## The player asked to equip the bag item [param uid].
signal equip_requested(uid: int)
## The first or the last focusable control may have changed (see [method first_focus]).
signal focus_ends_changed
## The focus was here and nothing usable remains; [param hidden] says if it showed a ring.
signal focus_lost(hidden: bool)

## Selection value meaning "no item" (a real uid is never negative).
const NO_SELECTION: int = -1
## A touch target (spec): the slots, and the least height of a card.
const ROW_MIN_HEIGHT: float = 50.0
## Sizes of the lot 7 (display settings): a card of 70 u at least, its band, its tile, its button; a
## slot drawn 48 u in a touch zone of 50 u, its border.
const CARD_HEIGHT: float = 70.0
const CARD_BAND: int = 4
const CARD_CORNER: int = 10
const CARD_PADDING: float = 6.0
const CARD_PADDING_Y: float = 3.0
const CARD_GAP: int = 8
const TILE_SIZE: float = 52.0
const EQUIP_SIZE: Vector2 = Vector2(112.0, 56.0)
const SLOT_SIZE: float = 50.0
const SLOT_DRAWN_INSET: float = 1.0
const SLOT_BORDER: int = 2
const SLOT_CORNER: int = 8
## The tick of "Équipé" in the detail button (display settings).
const TICK_SIZE: float = 18.0
const TICK_MARGIN: float = 16.0
const FONT_SIZE_MAIN: int = 16
const FONT_SIZE_SECONDARY: int = 14
## Weight added to the font of the type and of the bonus: bold (display setting).
const BOLD_EMBOLDEN: float = 0.6
## Room of the stat name in the comparison: its longest word, so that it wraps between words.
const COMPARE_NAME_MIN_WIDTH: float = 96.0
const SELECTED_MARK: String = "» "
const COLOR_GAIN: Color = Color(0.5, 0.95, 0.6)
const COLOR_LOSS: Color = Color(1, 0.55, 0.45)
const COLOR_NEUTRAL: Color = Color(0.75, 0.75, 0.8)
## Colour of each rarity id of items.json (story 019b tokens). An id missing here falls back to
## [constant COLOR_NEUTRAL].
const RARITY_COLORS: Dictionary = {
	"common": UiPalette.COMMON,
	"rare": UiPalette.BLUE,
	"legendary": UiPalette.YELLOW,
}
## Icon of each type id of items.json; a type the interface does not know shows a star.
const TYPE_ICONS: Dictionary = {
	"sword": UiIcon.Kind.SWORD,
	"helmet": UiIcon.Kind.HELMET,
	"chest": UiIcon.Kind.CHEST,
	"aura": UiIcon.Kind.AURA,
	"slash": UiIcon.Kind.SLASH,
}

var _inventory: Inventory
var _selected_uid: int = NO_SELECTION
var _wide: bool = false
var _slot_buttons: Array[Button] = []
## Pool: the part of each card that opens the detail, in bag order; the extra ones stay hidden.
var _bag_buttons: Array[Button] = []
## One entry per pooled card: {"card", "body", "icon", "name", "rarity", "bonus", "worn", "equip"}.
var _cards: Array[Dictionary] = []
## The uid each pooled card shows now; lets the focus follow an item when the bag moves.
var _row_uids: Array[int] = []
## One entry per stat of [constant Item.STATS]: {"cells", "name", "active", "candidate", "delta"}.
var _compare_rows: Array[Dictionary] = []
var _compare_header: Array = []
var _bold: FontVariation
## Card styles by rarity id ("" for an unknown one), built once.
var _card_styles: Dictionary = {}
var _body_styles: Dictionary = {}
var _worn_tick: UiIcon

@onready var _list_column: Control = %ListColumn
@onready var _detail_column: Control = %DetailColumn
@onready var _detail_bar: Control = %DetailBar
@onready var _back_button: Button = %BackButton
@onready var _equip_button: Button = %EquipButton
@onready var _slots_box: HBoxContainer = %Slots
@onready var _header: PaneHeader = %Header
@onready var _bag_title: Label = %BagTitle
@onready var _bag_label: Label = %BagLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _bag_list: VBoxContainer = %BagList
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_status: Label = %DetailStatus
@onready var _compare_table: GridContainer = %CompareTable


func _ready() -> void:
	_bold = FontVariation.new()
	_bold.base_font = get_theme_font("font")
	_bold.variation_embolden = BOLD_EMBOLDEN
	_bag_label.add_theme_font_override("font", _bold)
	_back_button.text = tr("Retour")
	_equip_button.text = tr("Équiper")
	_back_button.pressed.connect(close_detail)
	_equip_button.pressed.connect(_on_equip_pressed)
	# The tick of "Équipé": drawn, not a glyph the font may lack.
	_worn_tick = UiIcon.new()
	_worn_tick.kind = UiIcon.Kind.CHECK
	_worn_tick.color = UiPalette.TEXT_DISABLED
	# Centred on the height of the button, left of its word.
	_worn_tick.anchor_top = 0.5
	_worn_tick.anchor_bottom = 0.5
	_worn_tick.offset_left = TICK_MARGIN
	_worn_tick.offset_right = TICK_MARGIN + TICK_SIZE
	_worn_tick.offset_top = -TICK_SIZE / 2.0
	_worn_tick.offset_bottom = TICK_SIZE / 2.0
	_worn_tick.visible = false
	_equip_button.add_child(_worn_tick)
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
	var focused: Control = focus.focused()
	var row: int = _bag_buttons.find(focused) if focused is Button else -1
	var equip_row: int = _equip_buttons().find(focused) if focused is Button else -1
	var focused_uid: int = _row_uids[maxi(row, equip_row)] if maxi(row, equip_row) >= 0 else NO_SELECTION
	_draw_slots()
	_draw_bag()
	_draw_detail()
	_apply_layout()
	var neighbours: Array[Control] = []
	if row >= 0 or equip_row >= 0:
		var at: int = maxi(row, equip_row)
		var moved_to: int = _row_uids.find(focused_uid)
		var pool: Array = _bag_buttons if row >= 0 else _equip_buttons()
		if moved_to >= 0:
			focus.redirect(pool[moved_to])
		elif not _row_uids.is_empty():
			# The equipped item left the bag and the old one took its place: the same card stays.
			neighbours.append(pool[mini(at, _row_uids.size() - 1)])
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


## Closes the detail and gives the focus back to the card that opened it. False when none was open.
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


## The header of the tab (the slots and "Sac N / M", story 019b), whose free part is a touch zone
## of the panel handle.
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


## The grey line of the card of [param item] (Amaury, 2026-11-04): what the slot of its type wears,
## compared only for the same bonus ("Équipé : +5 %"), else the whole bonus of the worn item
## ("Équipé : +5 % Dégâts globaux"); "Emplacement vide" when nothing is worn there.
func worn_line(item: Item) -> String:
	var worn: Item = _inventory.equipped(item.type)
	if worn == null:
		return tr("Emplacement vide")
	var stat: String = item.primary_stat()
	if not stat.is_empty() and worn.primary_stat() == stat:
		return tr("Équipé : +%d %%") % worn.percent(stat)
	var worn_stat: String = worn.primary_stat()
	return tr("Équipé : %s") % _bonus_text(worn_stat, worn.percent(worn_stat))


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


## Dots of the rarity [param rarity_id] on a slot: 1 for the least rare of the data, then one more
## per rank, 3 at most; 0 for a rarity the data does not know.
func rarity_marks(rarity_id: String) -> int:
	var rank: int = _inventory.table().rarity_rank(rarity_id)
	return clampi(rank + 1, 0, ItemIcon.MAX_MARKS)


## The icon of the type [param type_id].
static func type_icon(type_id: String) -> UiIcon.Kind:
	return TYPE_ICONS.get(type_id, UiIcon.Kind.STAR)


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


func _add_slot(def: LootTable.TypeDef) -> void:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2.ONE * SLOT_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.toggle_mode = true  # its pressed look says "selected"
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	var icon: ItemIcon = ItemIcon.new()
	icon.draw_tile = false
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.show_item(type_icon(def.id), UiPalette.TEXT_DISABLED, 0)
	button.add_child(icon)
	button.pressed.connect(_on_slot_pressed.bind(def.id))
	_slots_box.add_child(button)
	_slot_buttons.append(button)


func _draw_slots() -> void:
	var types: Array[LootTable.TypeDef] = _inventory.table().types()
	for i in _slot_buttons.size():
		var button: Button = _slot_buttons[i]
		var icon: ItemIcon = button.get_child(0)
		var worn: Item = _inventory.equipped(types[i].id)
		button.disabled = worn == null
		if worn == null:
			icon.show_item(type_icon(types[i].id), UiPalette.TEXT_DISABLED, 0)
			button.accessibility_name = tr("%s : emplacement vide") % tr(types[i].display_name)
			button.tooltip_text = ""
			button.set_pressed_no_signal(false)
			_style_slot(button, "")
			continue
		var primary: String = worn.primary_stat()
		icon.show_item(type_icon(worn.type), rarity_color(worn.rarity), rarity_marks(worn.rarity))
		button.accessibility_name = _marked(tr("%s, %s, équipé") % [describe(worn), _bonus_text(primary, worn.percent(primary))], worn.uid)
		button.tooltip_text = _full_text(worn)
		button.set_pressed_no_signal(worn.uid == _selected_uid)
		_style_slot(button, worn.rarity)


func _draw_bag() -> void:
	var bag: Array[Item] = _inventory.bag()
	_bag_label.text = tr("%d / %d") % [bag.size(), _inventory.capacity()]
	# "Sac plein" in words: the full bag never reads by a colour alone.
	_bag_title.text = tr("Sac plein") if _inventory.is_full() else tr("Sac")
	_empty_label.visible = bag.is_empty()
	while _cards.size() < bag.size():
		_add_card()
	_row_uids.clear()
	for i in _cards.size():
		var card: Dictionary = _cards[i]
		(card["card"] as Control).visible = i < bag.size()
		if i < bag.size():
			_draw_card(card, bag[i])
			_row_uids.append(bag[i].uid)


func _draw_card(card: Dictionary, item: Item) -> void:
	var primary: String = item.primary_stat()
	var name_label: Label = card["name"]
	name_label.text = _marked(_type_name(item.type), item.uid)
	var rarity: Label = card["rarity"]
	rarity.text = _rarity_name(item.rarity)
	if card["rarity_id"] != item.rarity:
		card["rarity_id"] = item.rarity
		rarity.add_theme_color_override("font_color", rarity_color(item.rarity))
		(card["card"] as PanelContainer).add_theme_stylebox_override("panel", _card_style(item.rarity))
	(card["icon"] as ItemIcon).show_item(type_icon(item.type), rarity_color(item.rarity), 0)
	(card["bonus"] as Label).text = _bonus_text(primary, item.percent(primary))
	(card["worn"] as Label).text = worn_line(item)
	var body: Button = card["body"]
	body.set_pressed_no_signal(item.uid == _selected_uid)
	body.accessibility_name = tr("%s, %s. %s. Voir la comparaison") % [describe(item), (card["bonus"] as Label).text, (card["worn"] as Label).text]
	body.tooltip_text = _full_text(item)
	var equip: Button = card["equip"]
	equip.disabled = not _inventory.can_equip(item.uid)
	equip.accessibility_name = tr("Équiper %s") % describe(item)


func _add_card() -> void:
	var card: PanelContainer = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", _card_style(""))
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", CARD_GAP)
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	# The body: a flat toggle that opens the comparison; its content is drawn over it and takes no input.
	var body: Button = Button.new()
	body.toggle_mode = true
	body.focus_mode = Control.FOCUS_ALL
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size.y = CARD_HEIGHT - CARD_PADDING_Y * 2.0
	for state: StringName in _body_style_states():
		body.add_theme_stylebox_override(state, _body_style(state))
	var inside: HBoxContainer = HBoxContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.add_theme_constant_override("separation", CARD_GAP)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: ItemIcon = ItemIcon.new()
	icon.custom_minimum_size = Vector2.ONE * TILE_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title: HFlowContainer = HFlowContainer.new()
	title.add_theme_constant_override("h_separation", 6)
	title.add_theme_constant_override("v_separation", 0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label: Label = _new_label(FONT_SIZE_MAIN, Color.WHITE, true)
	var rarity: Label = _new_label(FONT_SIZE_MAIN, COLOR_NEUTRAL, true)
	title.add_child(name_label)
	title.add_child(rarity)
	# A long stat name ("Dégâts des compagnons") wraps between its words; the card grows.
	var bonus: Label = _new_label(FONT_SIZE_MAIN, Color.WHITE, true)
	bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var worn: Label = _new_label(FONT_SIZE_SECONDARY, UiPalette.TEXT_MUTED, false)
	worn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(title)
	texts.add_child(bonus)
	texts.add_child(worn)
	inside.add_child(icon)
	inside.add_child(texts)
	body.add_child(inside)
	# The content does not size a Button: the body follows what its texts need.
	inside.minimum_size_changed.connect(_fit_body.bind(body, inside))
	var equip: Button = Button.new()
	equip.theme_type_variation = &"EquipButton"
	equip.custom_minimum_size = EQUIP_SIZE
	equip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	equip.mouse_filter = Control.MOUSE_FILTER_PASS
	equip.text = tr("Équiper")
	equip.add_theme_font_size_override("font_size", FONT_SIZE_MAIN)
	line.add_child(body)
	line.add_child(equip)
	card.add_child(line)
	_bag_list.add_child(card)
	var index: int = _cards.size()
	body.pressed.connect(_on_bag_pressed.bind(index))
	equip.pressed.connect(_on_card_equip_pressed.bind(index))
	_bag_buttons.append(body)
	_cards.append({"card": card, "body": body, "icon": icon, "name": name_label, "rarity": rarity,
			"bonus": bonus, "worn": worn, "equip": equip, "rarity_id": "?"})


func _fit_body(body: Button, inside: Control) -> void:
	body.custom_minimum_size.y = maxf(CARD_HEIGHT - CARD_PADDING_Y * 2.0, inside.get_combined_minimum_size().y)


func _new_label(font_size: int, color: Color, bold: bool) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", _bold)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# The card: a row fill, rounded, its left edge a band of the rarity colour.
func _card_style(rarity_id: String) -> StyleBoxFlat:
	if not _card_styles.has(rarity_id):
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = UiPalette.ROW
		box.set_corner_radius_all(CARD_CORNER)
		box.border_width_left = CARD_BAND
		box.border_color = rarity_color(rarity_id) if not rarity_id.is_empty() else UiPalette.BUTTON
		box.content_margin_left = CARD_PADDING
		box.content_margin_right = CARD_PADDING
		box.content_margin_top = CARD_PADDING_Y
		box.content_margin_bottom = CARD_PADDING_Y
		_card_styles[rarity_id] = box
	return _card_styles[rarity_id]


func _body_style_states() -> Array[StringName]:
	return [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]


# The body is flat on the card; under the pointer or chosen it lights, and the mark says "chosen".
func _body_style(state: StringName) -> StyleBox:
	if not _body_styles.has(state):
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color(UiPalette.ROW_HOVER, 0.0) if state == &"normal" or state == &"disabled" else UiPalette.ROW_HOVER
		box.set_corner_radius_all(CARD_CORNER)
		_body_styles[state] = box
	return _body_styles[state]


# A slot: drawn 48 u in its 50 u, edged in the colour of the rarity (grey when empty).
func _style_slot(button: Button, rarity_id: String) -> void:
	if button.get_meta(&"rarity", "?") == rarity_id:
		return
	button.set_meta(&"rarity", rarity_id)
	var edge: Color = rarity_color(rarity_id) if not rarity_id.is_empty() else UiPalette.BUTTON_HOVER
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = UiPalette.ROW_HOVER if state in [&"hover", &"pressed", &"hover_pressed"] else UiPalette.ROW
		box.set_border_width_all(SLOT_BORDER)
		box.border_color = edge
		box.set_corner_radius_all(SLOT_CORNER)
		box.set_expand_margin_all(-SLOT_DRAWN_INSET)
		button.add_theme_stylebox_override(state, box)


func _draw_detail() -> void:
	var item: Item = _inventory.find_item(_selected_uid)
	var worn: bool = item != null and _inventory.equipped(item.type) == item
	_detail_bar.visible = item != null
	_equip_button.disabled = item == null or not _inventory.can_equip(_selected_uid)
	_equip_button.text = tr("Équipé") if worn else tr("Équiper")
	_worn_tick.visible = worn
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


# The slots, then each card (its body, then its "Équiper"), then the detail bar.
func _focusables() -> Array[Control]:
	var controls: Array[Control] = []
	controls.append_array(_slot_buttons)
	for card: Dictionary in _cards:
		controls.append(card["body"])
		controls.append(card["equip"])
	controls.append_array([_back_button, _equip_button])
	return controls.filter(PaneFocus.usable)


func _equip_buttons() -> Array:
	return _cards.map(func(card: Dictionary) -> Button: return card["equip"])


# The card showing [param uid], in the bag or among the slots, null when none does.
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


# "Équiper" on a card equips at once (Amaury, 2026-11-04): no detail needed.
func _on_card_equip_pressed(index: int) -> void:
	var bag: Array[Item] = _inventory.bag()
	if index < bag.size() and _inventory.can_equip(bag[index].uid):
		equip_requested.emit(bag[index].uid)


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


# The selection reads on the mark too, not only on the lit card.
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
