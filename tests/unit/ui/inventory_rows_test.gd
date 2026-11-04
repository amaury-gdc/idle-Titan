extends GdUnitTestSuite
## Unit tests for the Objets tab of story 019b (lot 7): the cards of the bag (type and rarity in
## words, the main bonus, the grey line that compares only the same bonus), the "Équiper" of a card
## that equips at once while the rest of the card only opens the comparison, the slots of the header
## (icon, edge and 1 to 3 dots of the rarity), "Sac N / M", the Tab order and the sizes.
## Story: production/epics/idle-titans/story-019b-mobile-ui-refonte.md

const SCENE: String = "res://src/ui/inventory_screen.tscn"
const PHONE: Vector2 = Vector2(374, 400)
const AT_320: Vector2 = Vector2(347, 300)
const CAPACITY: int = 12
const MIN_TARGET: float = 50.0
const STAT_NAMES: Dictionary = {
	Item.STAT_CLICK_DAMAGE: "Dégâts de clic",
	Item.STAT_GLOBAL_DAMAGE: "Dégâts globaux",
	Item.STAT_COMPANION_DAMAGE: "Dégâts des compagnons",
}

var _permanent: PermanentState
var _inventory: Inventory
var _screen: InventoryScreen
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
	_inventory = Inventory.from_data(_items_data(), _permanent, GameState.new(), Combat.from_data(curves, roster), func() -> float: return 0.0)
	assert_str(_inventory.get_error()).is_empty()
	_screen = auto_free((load(SCENE) as PackedScene).instantiate())
	_screen.visible = true
	add_child(_screen)
	_equip_uids = []
	_screen.equip_requested.connect(func(uid: int) -> void: _equip_uids.append(uid))


func _items_data() -> Dictionary:
	var stats: Array = []
	for id: String in Item.STATS:
		stats.append({"id": id, "name": STAT_NAMES.get(id, "Or"), "ranges": {"common": [2, 4], "rare": [5, 8], "legendary": [10, 20]}})
	return {
		"schema_version": LootTable.SUPPORTED_SCHEMA,
		"worse_item_rule": "rareté, puis somme, puis le plus ancien",
		"inventory_capacity": CAPACITY,
		"crit": {"base_chance_percent": 0, "base_bonus_percent": 100, "max_chance_percent": 100},
		"stats": stats,
		"rarities": [
			{"id": "common", "name": "Commun", "secondary_stats": 0, "sell_kills": 10},
			{"id": "rare", "name": "Rare", "secondary_stats": 1, "sell_kills": 50},
			{"id": "legendary", "name": "Légendaire", "secondary_stats": 2, "sell_kills": 200},
		],
		"types": [
			{"id": "sword", "name": "Épée", "primary_stat": Item.STAT_CLICK_DAMAGE, "drop_weight": 1},
			{"id": "chest", "name": "Plastron", "primary_stat": Item.STAT_COMPANION_DAMAGE, "drop_weight": 1},
		],
		"boss_loot": [{"from_stage": 10, "drop_percent": 100, "rarity_weights": {"common": 100, "rare": 0, "legendary": 0}}],
	}


func _item(uid: int, type: String, rarity: String, stats: Dictionary) -> Item:
	var item: Item = Item.new()
	item.uid = uid
	item.type = type
	item.rarity = rarity
	item.stats = stats
	return item


func _start(bag: Array[Item], worn: Array[Item] = [], pane: Vector2 = PHONE) -> void:
	_permanent.inventory_items = bag
	var equipped: Dictionary = {}
	for item: Item in worn:
		equipped[item.type] = item
	_permanent.equipped_items = equipped
	_screen.size = pane
	_screen.setup(_inventory)


func _card(index: int = 0) -> Dictionary:
	return _screen._cards[index]


func _text(index: int, key: String) -> String:
	return (_card(index)[key] as Label).text


func _laid_out() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


# --- card ------------------------------------------------------------------------------------

func test_card_names_the_type_and_the_rarity_in_words_and_colour() -> void:
	_start([_item(1, "chest", "legendary", {Item.STAT_COMPANION_DAMAGE: 18})])
	assert_str(_text(0, "name")).is_equal("Plastron")
	assert_str(_text(0, "rarity")).is_equal("Légendaire")
	assert_bool((_card()["rarity"] as Label).get_theme_color("font_color").is_equal_approx(UiPalette.YELLOW)).is_true()
	assert_str(_text(0, "bonus")).is_equal("+18 % Dégâts des compagnons")


func test_card_band_and_tile_take_the_rarity_colour() -> void:
	_start([_item(1, "sword", "rare", {Item.STAT_CLICK_DAMAGE: 6})])
	var band: StyleBoxFlat = (_card()["card"] as PanelContainer).get_theme_stylebox("panel")
	assert_int(band.border_width_left).is_equal(InventoryScreen.CARD_BAND)
	assert_bool(band.border_color.is_equal_approx(UiPalette.BLUE)).is_true()
	assert_bool((_card()["icon"] as ItemIcon).tint().is_equal_approx(UiPalette.BLUE)).is_true()
	assert_int((_card()["icon"] as ItemIcon).kind()).is_equal(UiIcon.Kind.SWORD)


func test_grey_line_compares_the_same_bonus_with_its_number_only() -> void:
	_start([_item(1, "sword", "rare", {Item.STAT_CLICK_DAMAGE: 6})], [_item(9, "sword", "common", {Item.STAT_CLICK_DAMAGE: 5})])
	assert_str(_text(0, "worn")).is_equal("Équipé : +5 %")
	assert_bool((_card()["worn"] as Label).get_theme_color("font_color").is_equal_approx(UiPalette.TEXT_MUTED)).is_true()
	assert_int((_card()["worn"] as Label).get_theme_font_size("font_size")).is_equal(InventoryScreen.FONT_SIZE_SECONDARY)


func test_grey_line_writes_the_whole_bonus_when_the_worn_one_is_another() -> void:
	# Amaury, 2026-11-04: two different bonuses are never set against each other by a bare number.
	_start([_item(1, "sword", "rare", {Item.STAT_CLICK_DAMAGE: 6})], [_item(9, "sword", "common", {Item.STAT_GLOBAL_DAMAGE: 5})])
	assert_str(_text(0, "worn")).is_equal("Équipé : +5 % Dégâts globaux")


func test_grey_line_says_the_slot_is_empty() -> void:
	_start([_item(1, "chest", "common", {Item.STAT_COMPANION_DAMAGE: 3})])
	assert_str(_text(0, "worn")).is_equal("Emplacement vide")


# --- equip -----------------------------------------------------------------------------------

func test_equiper_on_a_card_equips_at_once_without_a_detail() -> void:
	_start([_item(1, "sword", "common", {Item.STAT_CLICK_DAMAGE: 3}), _item(2, "chest", "common", {Item.STAT_COMPANION_DAMAGE: 3})])
	(_card(1)["equip"] as Button).pressed.emit()
	assert_array(_equip_uids).contains_exactly([2])
	assert_bool(_screen.is_detail_open()).is_false()


func test_rest_of_the_card_opens_the_comparison_and_never_equips() -> void:
	_start([_item(1, "sword", "common", {Item.STAT_CLICK_DAMAGE: 3})])
	(_card()["body"] as Button).pressed.emit()
	assert_array(_equip_uids).is_empty()
	assert_int(_screen.selected_uid()).is_equal(1)
	assert_bool(_screen._compare_table.visible).is_true()


func test_equiper_of_an_item_of_an_unknown_type_is_disabled_and_asks_for_nothing() -> void:
	_start([_item(1, "boots", "common", {Item.STAT_CLICK_DAMAGE: 3})])
	var equip: Button = _card()["equip"]
	assert_bool(equip.disabled).is_true()
	equip.pressed.emit()
	assert_array(_equip_uids).is_empty()


func test_card_and_its_two_parts_pass_the_mouse_on_so_that_a_drag_scrolls() -> void:
	_start([_item(1, "sword", "common", {Item.STAT_CLICK_DAMAGE: 3})])
	for key: String in ["card", "body", "equip"]:
		assert_int((_card()[key] as Control).mouse_filter).override_failure_message(key).is_equal(Control.MOUSE_FILTER_PASS)


func test_tab_goes_through_each_card_then_its_equiper() -> void:
	_start([_item(1, "sword", "common", {Item.STAT_CLICK_DAMAGE: 3}), _item(2, "chest", "common", {Item.STAT_COMPANION_DAMAGE: 3})])
	var order: Array[Control] = _screen._focusables()
	assert_array(order.slice(0, 4)).contains_exactly([_card(0)["body"], _card(0)["equip"], _card(1)["body"], _card(1)["equip"]])


func test_after_equiping_from_a_card_the_focus_stays_on_its_card() -> void:
	# Arrange: a worn sword; equiping the bag sword puts the old one back at the same place
	_start([_item(1, "sword", "rare", {Item.STAT_CLICK_DAMAGE: 6})], [_item(9, "sword", "common", {Item.STAT_CLICK_DAMAGE: 5})])
	await _laid_out()
	var equip: Button = _card()["equip"]
	equip.grab_focus()

	# Act
	_inventory.equip(1)
	_screen.refresh()

	# Assert
	assert_object(_screen.get_viewport().gui_get_focus_owner()).is_same(equip)
	assert_str(_text(0, "name")).is_equal("Épée")
	assert_str(_text(0, "worn")).is_equal("Équipé : +6 %")


# --- slots and header -------------------------------------------------------------------------

func test_slot_shows_its_rarity_by_colour_edge_and_dots() -> void:
	_start([], [_item(9, "sword", "legendary", {Item.STAT_CLICK_DAMAGE: 12}), _item(8, "chest", "common", {Item.STAT_COMPANION_DAMAGE: 3})])
	var sword: Button = _screen._slot_buttons[0]
	var chest: Button = _screen._slot_buttons[1]
	assert_int((sword.get_child(0) as ItemIcon).marks()).is_equal(3)
	assert_int((chest.get_child(0) as ItemIcon).marks()).is_equal(1)
	assert_bool((sword.get_theme_stylebox("normal") as StyleBoxFlat).border_color.is_equal_approx(UiPalette.YELLOW)).is_true()
	assert_bool((chest.get_theme_stylebox("normal") as StyleBoxFlat).border_color.is_equal_approx(UiPalette.COMMON)).is_true()
	assert_bool(sword.disabled).is_false()


func test_dots_follow_the_rank_of_the_rarity() -> void:
	_start([])
	assert_int(_screen.rarity_marks("common")).is_equal(1)
	assert_int(_screen.rarity_marks("rare")).is_equal(2)
	assert_int(_screen.rarity_marks("legendary")).is_equal(3)
	assert_int(_screen.rarity_marks("unknown")).is_equal(0)


func test_empty_slot_is_grey_without_dots_and_takes_no_touch() -> void:
	_start([])
	var slot: Button = _screen._slot_buttons[0]
	assert_bool(slot.disabled).is_true()
	assert_int((slot.get_child(0) as ItemIcon).marks()).is_equal(0)
	assert_bool((slot.get_child(0) as ItemIcon).tint().is_equal_approx(UiPalette.TEXT_DISABLED)).is_true()
	assert_str(slot.accessibility_name).is_equal("Épée : emplacement vide")


func test_touching_a_worn_slot_opens_its_detail_with_equipe_greyed() -> void:
	_start([], [_item(9, "sword", "rare", {Item.STAT_CLICK_DAMAGE: 6})])
	_screen._slot_buttons[0].pressed.emit()
	assert_int(_screen.selected_uid()).is_equal(9)
	assert_str(_screen._equip_button.text).is_equal("Équipé")
	assert_bool(_screen._equip_button.disabled).is_true()
	assert_bool(_screen._worn_tick.visible).is_true()
	await _laid_out()
	var tick: Rect2 = _screen._worn_tick.get_global_rect()
	var button: Rect2 = _screen._equip_button.get_global_rect()
	assert_bool(button.encloses(tick)).is_true()
	assert_float(absf(tick.get_center().y - button.get_center().y)).is_less_equal(1.0)


func test_header_counts_the_bag_and_says_when_it_is_full() -> void:
	var bag: Array[Item] = []
	for i in CAPACITY - 1:
		bag.append(_item(i + 1, "sword", "common", {Item.STAT_CLICK_DAMAGE: 2}))
	_start(bag)
	assert_str(_screen._bag_label.text).is_equal("%d / %d" % [CAPACITY - 1, CAPACITY])
	assert_str(_screen._bag_title.text).is_equal("Sac")
	_permanent.inventory_items.append(_item(99, "sword", "common", {Item.STAT_CLICK_DAMAGE: 2}))
	_screen.refresh()
	assert_str(_screen._bag_label.text).is_equal("%d / %d" % [CAPACITY, CAPACITY])
	assert_str(_screen._bag_title.text).is_equal("Sac plein")


# --- sizes -----------------------------------------------------------------------------------

func test_card_is_70_high_with_an_equiper_of_112_by_56_and_slots_of_50() -> void:
	_start([_item(1, "sword", "common", {Item.STAT_CLICK_DAMAGE: 3})], [_item(9, "chest", "rare", {Item.STAT_COMPANION_DAMAGE: 6})])
	await _laid_out()
	assert_float((_card()["card"] as Control).size.y).is_greater_equal(InventoryScreen.CARD_HEIGHT)
	assert_vector((_card()["equip"] as Control).size).is_equal(InventoryScreen.EQUIP_SIZE)
	for slot: Button in _screen._slot_buttons:
		assert_vector(slot.size).is_equal(Vector2.ONE * MIN_TARGET)


func test_header_and_a_full_bag_of_long_bonuses_hold_at_320_wide() -> void:
	# Arrange: the longest bonus name and the longest rarity, a full bag, every slot worn
	var bag: Array[Item] = []
	for i in CAPACITY:
		bag.append(_item(i + 1, "chest", "legendary", {Item.STAT_COMPANION_DAMAGE: 20}))
	_start(bag, [_item(90, "sword", "legendary", {Item.STAT_CLICK_DAMAGE: 20}), _item(91, "chest", "legendary", {Item.STAT_COMPANION_DAMAGE: 20})], AT_320)

	# Act
	await _laid_out()

	# Assert: nothing wider than the pane, every text whole inside its card
	assert_float(_screen.get_combined_minimum_size().x).is_less_equal(AT_320.x)
	assert_float(_screen.pane_header().get_combined_minimum_size().x).is_less_equal(AT_320.x)
	for card: Dictionary in _screen._cards:
		var body: Button = card["body"]
		assert_float(body.size.y).is_greater_equal(body.get_combined_minimum_size().y)
		assert_float((card["card"] as Control).size.x).is_less_equal(AT_320.x)
		for key: String in ["name", "rarity", "bonus", "worn"]:
			var label: Label = card[key]
			assert_bool(Rect2(body.global_position, body.size).encloses(Rect2(label.global_position, label.size))).override_failure_message(key).is_true()
