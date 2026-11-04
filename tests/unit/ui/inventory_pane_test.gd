extends GdUnitTestSuite
## Unit tests for the Objets tab: the detail of D5, the two widths read on the pane itself, loot
## received while open, the focus when a control goes away, and no width past the pane.
## Story: production/epics/idle-titans/story-011-management-tabs.md.

const SCENE: String = "res://src/ui/inventory_screen.tscn"
const COMPACT: Vector2 = Vector2(348, 300)
const WIDE: Vector2 = Vector2(700, 500)
const CAPACITY: int = 12
const MIN_TARGET: float = 50.0
const LONG_ROW_UID: int = 99
const MIN_MARGIN: float = 8.0

var _permanent: PermanentState
var _state: GameState
var _inventory: Inventory
var _screen: InventoryScreen
var _lost: Array = []
var _equip_uids: Array = []


func before_test() -> void:
	var curves: Dictionary = {
		"schema_version": Combat.SUPPORTED_CURVES_SCHEMA,
		"enemy_hp_base": "1000",
		"enemy_hp_growth": "1",
		"gold_per_kill_base": "1",
		"gold_per_kill_growth": "1",
		"click_damage_base": "1",
		"click_companion_power_factor": "0",
		"cost_growth": "1.08",
		"offline_efficiency": "0.5",
		"offline_max_hours": 12,
		"offline_min_seconds": 60,
	}
	var roster: Dictionary = {"schema_version": 2, "companions": [{
		"id": "scout", "name": "Scout", "base_cost": "10", "base_damage": "1", "cost_growth": "1.08",
		"attack_interval_seconds": 1.0, "tiers": [],
	}]}
	_permanent = PermanentState.new()
	_state = GameState.new()
	_inventory = Inventory.from_data(_items_data(), _permanent, _state, Combat.from_data(curves, roster), func() -> float: return 0.0)
	assert_str(_inventory.get_error()).is_empty()
	_screen = auto_free((load(SCENE) as PackedScene).instantiate())
	_screen.visible = true
	add_child(_screen)
	_lost = []
	_equip_uids = []
	_screen.focus_lost.connect(func(_hidden: bool) -> void: _lost.append(true))
	_screen.equip_requested.connect(func(uid: int) -> void: _equip_uids.append(uid))


func _items_data() -> Dictionary:
	var stats: Array = []
	for id: String in Item.STATS:
		stats.append({"id": id, "name": "Dégâts des compagnons", "ranges": {"common": [2, 4], "rare": [5, 8], "legendary": [10, 20]}})
	return {
		"schema_version": LootTable.SUPPORTED_SCHEMA,
		"worse_item_rule": "rareté, puis somme, puis le plus ancien",
		"inventory_capacity": CAPACITY,
		"crit": {"base_chance_percent": 0, "base_bonus_percent": 100, "max_chance_percent": 100},
		"stats": stats,
		"rarities": [
			{"id": "common", "name": "Commun", "secondary_stats": 0, "sell_kills": 10},
			{"id": "legendary", "name": "Légendaire", "secondary_stats": 2, "sell_kills": 200},
		],
		"types": [
			{"id": "sword", "name": "Épée", "primary_stat": Item.STAT_CLICK_DAMAGE, "drop_weight": 1},
			{"id": "chest", "name": "Plastron", "primary_stat": Item.STAT_COMPANION_DAMAGE, "drop_weight": 1},
		],
		"boss_loot": [{"from_stage": 10, "drop_percent": 100, "rarity_weights": {"common": 100, "legendary": 0}}],
	}


func _item(uid: int, type: String = "sword", rarity: String = "common") -> Item:
	var item: Item = Item.new()
	item.uid = uid
	item.type = type
	item.rarity = rarity
	item.stats = {Item.STAT_CLICK_DAMAGE if type == "sword" else Item.STAT_COMPANION_DAMAGE: 3}
	return item


func _start(items: Array[Item], pane: Vector2) -> void:
	_permanent.inventory_items = items
	_screen.size = pane
	_screen.setup(_inventory)


func _rows() -> Array[Button]:
	return _screen._bag_buttons


func _focus(control: Control) -> void:
	control.grab_focus()


func _focused() -> Control:
	return _screen.get_viewport().gui_get_focus_owner()


func test_describe_puts_the_rarity_first() -> void:
	_start([], COMPACT)
	assert_str(_screen.describe(_item(1, "sword", "common"))).is_equal("Commun : Épée")


func test_slot_takes_one_line_and_keeps_the_full_item_for_the_touch() -> void:
	# Arrange: the longest slot of the data, with three bonuses
	var item: Item = _item(1, "chest", "legendary")
	item.stats = {Item.STAT_COMPANION_DAMAGE: 10, Item.STAT_CLICK_DAMAGE: 9, Item.STAT_GOLD: 8}
	_start([item], COMPACT)
	_inventory.equip(1)

	# Act
	_screen.refresh()
	await await_idle_frame()
	await await_idle_frame()

	# Assert
	var slot: Button = _screen._slot_buttons[1]
	assert_float(slot.size.y).is_equal(MIN_TARGET)
	assert_str(slot.text).not_contains("\n")
	assert_int(slot.tooltip_text.count("\n")).is_equal(3)
	# Story 019b: an icon, not words, on the slot; its name says the item and its main bonus.
	assert_str(slot.text).is_empty()
	assert_str(slot.accessibility_name).is_equal("Légendaire : Plastron, +10 % Dégâts des compagnons, équipé")


func test_slots_stay_in_the_header_in_both_widths() -> void:
	# Story 019b: the "Équipement" title is gone; the worn items sit in the header, narrow or wide,
	# with the detail open too.
	_start([_item(1)], COMPACT)
	var header: Control = _screen.pane_header()
	for slot: Button in _screen._slot_buttons:
		assert_bool(header.is_ancestor_of(slot)).is_true()
	_rows()[0].pressed.emit()
	assert_bool(_screen._slot_buttons[0].is_visible_in_tree()).is_true()
	_screen.size = WIDE
	assert_bool(_screen._slot_buttons[0].is_visible_in_tree()).is_true()


func test_worn_item_lists_its_bonuses_with_a_disabled_equipe() -> void:
	# Arrange
	_start([_item(1)], COMPACT)
	_inventory.equip(1)
	_screen.refresh()

	# Act
	_screen._slot_buttons[0].pressed.emit()

	# Assert
	assert_bool(_screen._compare_table.visible).is_false()
	assert_str(_screen._detail_status.text).contains("+3 %")
	assert_str(_screen._equip_button.text).is_equal("Équipé")
	assert_bool(_screen._equip_button.disabled).is_true()


func test_bag_item_keeps_the_comparison_and_equiper() -> void:
	_start([_item(1)], COMPACT)
	_rows()[0].pressed.emit()
	assert_bool(_screen._compare_table.visible).is_true()
	assert_str(_screen._equip_button.text).is_equal("Équiper")


func test_comparison_header_says_bonus() -> void:
	_start([_item(1)], COMPACT)
	assert_str((_screen._compare_header[0] as Label).text).is_equal("Bonus")


func test_last_comparison_column_keeps_a_margin_from_the_scroll_bar() -> void:
	_start([_item(1)], COMPACT)
	_rows()[0].pressed.emit()
	await await_idle_frame()
	await await_idle_frame()
	var gap: float = _screen._detail_column.get_global_rect().end.x - _screen._compare_table.get_global_rect().end.x
	assert_float(gap).is_greater_equal(MIN_MARGIN)


func test_loot_versions_drop_the_title_then_shorten_the_sale() -> void:
	var lines: PackedStringArray = PackedStringArray(["Butin !", "Rare : Épée", "Sac plein, vendu (Rare : Aura), +5 or"])
	var versions: PackedStringArray = InventoryScreen.loot_versions(lines, "Sac plein : +5 or")
	assert_str(versions[0]).is_equal("\n".join(lines))
	assert_str(versions[1]).is_equal("Rare : Épée\nSac plein : +5 or")
	assert_str(versions[2]).is_equal("Sac plein : +5 or")


func test_loot_message_keeps_to_the_lines_of_its_slot() -> void:
	# Boundary values: margins 20, lines of 24 u.
	assert_int(InventoryScreen.loot_max_lines(100.0, 24.0, 20.0)).is_equal(3)
	assert_int(InventoryScreen.loot_max_lines(99.0, 24.0, 20.0)).is_equal(3)
	assert_int(InventoryScreen.loot_max_lines(91.0, 24.0, 20.0)).is_equal(2)
	assert_int(InventoryScreen.loot_max_lines(10.0, 24.0, 20.0)).is_equal(1)


func test_narrow_slot_with_a_full_bag_shows_only_the_short_line() -> void:
	var lines: PackedStringArray = PackedStringArray(["Butin !", "Rare : Épée", "Sac plein, vendu (Rare : Aura), +5 or"])
	var versions: PackedStringArray = InventoryScreen.loot_versions(lines, "Sac plein : +5 or")
	var first: int = InventoryScreen.loot_first_version(versions, "Sac plein : +5 or", true)
	assert_str(versions[first]).is_equal("Sac plein : +5 or")


func test_wide_slot_starts_on_the_whole_message() -> void:
	var versions: PackedStringArray = PackedStringArray(["a", "b", "c"])
	assert_int(InventoryScreen.loot_first_version(versions, "c", false)).is_equal(0)


func test_narrow_slot_without_a_short_sale_only_loses_the_title() -> void:
	var versions: PackedStringArray = PackedStringArray(["Butin !\nRare : Épée", "Rare : Épée"])
	assert_int(InventoryScreen.loot_first_version(versions, "", true)).is_equal(1)


func test_loot_versions_without_a_sale_end_on_the_item() -> void:
	var versions: PackedStringArray = InventoryScreen.loot_versions(PackedStringArray(["Butin !", "Rare : Épée"]), "")
	assert_int(versions.size()).is_equal(2)
	assert_str(versions[1]).is_equal("Rare : Épée")


func test_compact_touch_opens_a_detail_that_replaces_the_list() -> void:
	_start([_item(1)], COMPACT)
	_rows()[0].pressed.emit()
	assert_bool(_screen.is_detail_open()).is_true()
	assert_bool(_screen._list_column.visible).is_false()
	assert_bool(_screen._detail_column.visible).is_true()
	assert_bool(_screen._back_button.visible).is_true()
	assert_bool(_screen._equip_button.visible).is_true()


func test_a_touch_never_equips_by_itself() -> void:
	_start([_item(1)], COMPACT)
	_rows()[0].pressed.emit()
	assert_array(_equip_uids).is_empty()


func test_action_equips_the_item_of_the_detail() -> void:
	_start([_item(1)], COMPACT)
	_rows()[0].pressed.emit()
	_screen._equip_button.pressed.emit()
	assert_array(_equip_uids).contains_exactly([1])


func test_from_640_list_and_detail_stand_side_by_side() -> void:
	_start([_item(1)], Vector2(ManagementTabs.DETAIL_WIDE_WIDTH, 500))
	_rows()[0].pressed.emit()
	assert_bool(_screen._list_column.visible).is_true()
	assert_bool(_screen._detail_column.visible).is_true()


func test_just_under_640_the_detail_still_replaces_the_list() -> void:
	_start([_item(1)], Vector2(ManagementTabs.DETAIL_WIDE_WIDTH - 1.0, 500))
	_rows()[0].pressed.emit()
	assert_bool(_screen._list_column.visible).is_false()


func test_width_change_keeps_the_detail_and_shows_the_list_again() -> void:
	_start([_item(1)], COMPACT)
	_rows()[0].pressed.emit()
	_screen.size = WIDE
	assert_int(_screen.selected_uid()).is_equal(1)
	assert_bool(_screen._list_column.visible).is_true()
	_screen.size = COMPACT
	assert_int(_screen.selected_uid()).is_equal(1)
	assert_bool(_screen._list_column.visible).is_false()


func test_narrowing_with_the_focus_in_the_list_moves_it_to_the_detail() -> void:
	_start([_item(1)], WIDE)
	_focus(_rows()[0])
	_rows()[0].pressed.emit()
	_screen.size = COMPACT
	assert_object(_focused()).is_same(_screen._equip_button)


func test_close_detail_goes_back_to_the_row_that_opened_it() -> void:
	_start([_item(1), _item(2)], COMPACT)
	_focus(_rows()[1])
	_rows()[1].pressed.emit()
	assert_bool(_screen.close_detail()).is_true()
	assert_bool(_screen.is_detail_open()).is_false()
	assert_object(_focused()).is_same(_rows()[1])


func test_close_detail_without_a_detail_does_nothing() -> void:
	_start([_item(1)], COMPACT)
	assert_bool(_screen.close_detail()).is_false()


func test_equipping_moves_the_focus_from_the_disabled_action_to_retour() -> void:
	_start([_item(1)], COMPACT)
	_rows()[0].pressed.emit()
	_focus(_screen._equip_button)
	_inventory.equip(1)
	_screen.refresh()
	assert_bool(_screen._equip_button.disabled).is_true()
	assert_object(_focused()).is_same(_screen._back_button)


func test_selected_item_sold_closes_the_detail_and_keeps_a_focus() -> void:
	_start([_item(1), _item(2)], COMPACT)
	_rows()[0].pressed.emit()
	_focus(_screen._back_button)
	_permanent.inventory_items = [_item(2)]
	_screen.refresh()
	assert_bool(_screen.is_detail_open()).is_false()
	assert_object(_focused()).is_same(_rows()[0])


func test_nothing_left_to_focus_hands_it_to_the_tabs() -> void:
	_start([_item(1)], COMPACT)
	_focus(_rows()[0])
	_permanent.inventory_items = []
	_screen.refresh()
	assert_int(_lost.size()).is_equal(1)


func test_focus_follows_its_item_when_the_bag_moves() -> void:
	_start([_item(1), _item(2), _item(3)], COMPACT)
	_focus(_rows()[1])
	_permanent.inventory_items = [_item(2), _item(3)]
	_screen.refresh()
	assert_object(_focused()).is_same(_rows()[0])


func test_loot_received_updates_the_list_and_keeps_selection_and_scroll() -> void:
	# Arrange
	var items: Array[Item] = []
	for i in CAPACITY - 1:
		items.append(_item(i + 1))
	_start(items, Vector2(WIDE.x, 200))
	await await_idle_frame()
	await await_idle_frame()
	_rows()[3].pressed.emit()
	_screen._list_column.scroll_vertical = 120
	await await_idle_frame()

	# Act
	_inventory.receive(_item(LONG_ROW_UID, "chest"), 1)
	_screen.refresh()
	await await_idle_frame()

	# Assert
	assert_str(_screen._bag_label.text).contains("%d / %d" % [CAPACITY, CAPACITY])
	assert_int(_screen.selected_uid()).is_equal(4)
	assert_int(_screen._list_column.scroll_vertical).is_equal(120)


func test_going_through_the_detail_keeps_the_scroll() -> void:
	var items: Array[Item] = []
	for i in CAPACITY:
		items.append(_item(i + 1))
	_start(items, COMPACT)
	await await_idle_frame()
	await await_idle_frame()
	_screen._list_column.scroll_vertical = 120
	_rows()[6].pressed.emit()
	await await_idle_frame()
	_screen.close_detail()
	await await_idle_frame()
	assert_int(_screen._list_column.scroll_vertical).is_equal(120)


func test_empty_bag_says_so() -> void:
	_start([], COMPACT)
	assert_bool(_screen._empty_label.visible).is_true()


func test_ends_of_the_tab_order_follow_the_detail() -> void:
	_start([_item(1)], COMPACT)
	assert_object(_screen.first_focus()).is_same(_rows()[0])
	_rows()[0].pressed.emit()
	assert_object(_screen.first_focus()).is_same(_screen._back_button)
	assert_object(_screen.last_focus()).is_same(_screen._equip_button)


func test_does_not_stay_enabled_past_the_settings_modal() -> void:
	assert_int(_screen.focus_behavior_recursive).is_equal(Control.FOCUS_BEHAVIOR_INHERITED)


func test_rows_pass_the_mouse_on_so_that_a_drag_scrolls() -> void:
	_start([_item(1)], COMPACT)
	assert_int(_rows()[0].mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_int(_screen._slot_buttons[0].mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)


func test_full_bag_stays_inside_the_pane_with_targets_and_whole_texts() -> void:
	# Arrange: the longest row text of the data, in the narrowest pane
	var items: Array[Item] = []
	for i in CAPACITY:
		var item: Item = _item(i + 1, "chest", "legendary")
		items.append(item)
	_start(items, COMPACT)

	# Act
	await await_idle_frame()
	await await_idle_frame()

	# Assert
	assert_float(_screen.get_combined_minimum_size().x).is_less_equal(COMPACT.x)
	for button: Button in _rows():
		assert_float(button.size.x).is_less_equal(COMPACT.x)
		assert_float(button.size.y).is_greater_equal(MIN_TARGET)
		assert_float(button.size.y).is_greater_equal(button.get_combined_minimum_size().y)


func test_detail_stays_inside_the_pane() -> void:
	var item: Item = _item(1, "chest", "legendary")
	_start([item], COMPACT)
	_rows()[0].pressed.emit()
	await await_idle_frame()
	await await_idle_frame()
	assert_float(_screen.get_combined_minimum_size().x).is_less_equal(COMPACT.x)
	assert_float(_screen._compare_table.get_global_rect().end.x).is_less_equal(_screen.get_global_rect().end.x)


func test_comparison_does_not_break_the_longest_word_of_a_stat_name() -> void:
	_start([_item(1, "chest", "legendary")], Vector2(700, 500))
	await await_idle_frame()
	await await_idle_frame()
	var cell: Label = _screen._compare_rows[Item.STATS.find(Item.STAT_COMPANION_DAMAGE)]["name"]
	var font: Font = cell.get_theme_font("font")
	var word: float = font.get_string_size("compagnons", HORIZONTAL_ALIGNMENT_LEFT, -1, cell.get_theme_font_size("font_size")).x
	_rows()[0].pressed.emit()
	await await_idle_frame()
	await await_idle_frame()
	assert_float(cell.size.x).is_greater_equal(word)
