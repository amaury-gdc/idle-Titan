extends GdUnitTestSuite
## Unit tests for the items: catalog, boss loot, bag and automatic sale, equipping, comparison,
## saves, the effect of each stat and the critical hit, which only a click can land.
## Story: production/epics/idle-titans/story-007-loot.md

const ENEMY_HP: String = "1000000"
const CLICK_BASE: String = "100"
const COMPANION_DAMAGE: String = "100"
const GOLD_PER_KILL: String = "1000"
const CAPACITY: int = 3
const BOSS_STAGE: int = 10
const SECOND_TIER_STAGE: int = 30
const NORMAL_STAGE: int = 1
const OFFLINE_SECONDS: int = 3600
const NOW: int = 1_000_000
## A roll below every chance, and one above every chance.
const DIE_HIT: float = 0.0
const DIE_MISS: float = 0.99

var _die: float = DIE_HIT
var _curves: Dictionary
var _combat: Combat
var _state: GameState
var _permanent: PermanentState
var _floors: FloorManager
var _offline: OfflineIncome
var _talents: TalentTree
var _inventory: Inventory
var _hub: ModifierHub


func before_test() -> void:
	_die = DIE_HIT
	_curves = {
		"schema_version": Combat.SUPPORTED_CURVES_SCHEMA,
		"enemy_hp_base": ENEMY_HP,
		"enemy_hp_growth": "1",
		"gold_per_kill_base": GOLD_PER_KILL,
		"gold_per_kill_growth": "1",
		"click_damage_base": CLICK_BASE,
		"click_companion_power_factor": "0",
		"cost_growth": "1.08",
		"offline_efficiency": "0.5",
		"offline_max_hours": 12,
		"offline_min_seconds": 60,
	}
	var roster: Dictionary = {
		"schema_version": 2,
		"companions": [{
			"id": "scout",
			"name": "Scout",
			"base_cost": "10",
			"base_damage": COMPANION_DAMAGE,
			"cost_growth": "1.08",
			"attack_interval_seconds": 1.0,
			"tiers": [],
		}],
	}
	_combat = Combat.from_data(_curves, roster)
	assert_str(_combat.get_error()).is_empty()
	_permanent = PermanentState.new()
	_build(NORMAL_STAGE)


func _dice() -> float:
	return _die


# Builds the game on [param stage]; a stage multiple of 10 starts its boss fight.
func _build(stage: int) -> void:
	_state = GameState.new()
	_state.stage = stage
	_state.max_stage_reached = maxi(stage, 100)
	_state.companion_levels = {"scout": 1}
	var boss: BossFight = BossFight.from_data({
		"schema_version": BossFight.SUPPORTED_SCHEMA,
		"boss_every_stages": BOSS_STAGE,
		"timer_seconds": 30,
		"boss_hp_multiplier": "2",
		"boss_gold_base": "2000",
		"boss_gold_growth": "1",
		"auto_challenge_margin": "1.2",
	})
	assert_str(boss.get_error()).is_empty()
	_floors = FloorManager.new(_state, _combat, boss, _permanent)
	_floors.set_crit_roll(_dice)
	_offline = OfflineIncome.from_data(_curves, _combat)
	assert_str(_offline.get_error()).is_empty()
	_talents = TalentTree.from_data({
		"schema_version": TalentTree.SUPPORTED_SCHEMA,
		"stages_per_point": 5,
		"branches": [{"id": "main", "name": "Branche"}],
		"nodes": [
			{"id": "click", "branch": "main", "name": "Clic", "cost": 1, "effect": {"stat": TalentTree.STAT_CLICK_DAMAGE, "percent": 10}},
			{"id": "rentes", "branch": "main", "name": "Rentes", "cost": 1, "effect": {"stat": TalentTree.STAT_OFFLINE_GOLD, "percent": 25}},
		],
	}, _permanent, _state)
	assert_str(_talents.get_error()).is_empty()
	_inventory = Inventory.from_data(_items_data(), _permanent, _state, _combat, _dice)
	assert_str(_inventory.get_error()).is_empty()
	_floors.boss_killed.connect(_inventory.on_boss_killed)
	_hub = ModifierHub.new(_floors, _offline, _talents, _inventory)


func _items_data() -> Dictionary:
	var stats: Array = []
	for id: String in Item.STATS:
		stats.append({"id": id, "name": id, "ranges": {"common": [2, 4], "rare": [5, 8], "legendary": [10, 20]}})
	return {
		"schema_version": LootTable.SUPPORTED_SCHEMA,
		"worse_item_rule": "rareté, puis somme, puis le plus ancien",
		"inventory_capacity": CAPACITY,
		"crit": {"base_chance_percent": 0, "base_bonus_percent": 100, "max_chance_percent": 100},
		"stats": stats,
		"rarities": [
			{"id": "common", "name": "Commun", "secondary_stats": 0, "sell_kills": 10},
			{"id": "rare", "name": "Rare", "secondary_stats": 1, "sell_kills": 40},
			{"id": "legendary", "name": "Légendaire", "secondary_stats": 2, "sell_kills": 200},
		],
		"types": [
			{"id": "sword", "name": "Épée", "primary_stat": Item.STAT_CLICK_DAMAGE, "drop_weight": 1},
			{"id": "helmet", "name": "Casque", "primary_stat": Item.STAT_GLOBAL_DAMAGE, "drop_weight": 1},
			{"id": "chest", "name": "Plastron", "primary_stat": Item.STAT_COMPANION_DAMAGE, "drop_weight": 1},
			{"id": "aura", "name": "Aura", "primary_stat": Item.STAT_GOLD, "drop_weight": 1},
			{"id": "slash", "name": "Entaille", "primary_stat": Item.STAT_CRIT_DAMAGE, "drop_weight": 1},
		],
		"boss_loot": [
			{"from_stage": BOSS_STAGE, "drop_percent": 100, "rarity_weights": {"common": 100, "rare": 0, "legendary": 0}},
			{"from_stage": SECOND_TIER_STAGE, "drop_percent": 100, "rarity_weights": {"common": 0, "rare": 100, "legendary": 0}},
		],
	}


func _item(uid: int, type: String, rarity: String, stats: Dictionary) -> Item:
	var item: Item = Item.new()
	item.uid = uid
	item.type = type
	item.rarity = rarity
	item.stats = stats
	return item


func _commons(values: Array[int]) -> Array[Item]:
	var items: Array[Item] = []
	for i in values.size():
		items.append(_item(i + 1, "helmet", "common", {Item.STAT_GLOBAL_DAMAGE: values[i]}))
	return items


func _fill_bag(items: Array[Item]) -> void:
	_permanent.inventory_items = items


# Wears a new item of the sword type with [param stats].
func _wear(stats: Dictionary) -> void:
	var worn: Item = _item(50, "sword", "legendary", stats)
	_permanent.inventory_items.append(worn)
	assert_bool(_inventory.equip(worn.uid)).is_true()


func _damage_dealt_by(hit: Callable) -> String:
	var before: BigNumber = _floors.current_hp()
	hit.call()
	return before.subtract(_floors.current_hp()).to_decimal_string()


func _kill() -> void:
	_floors.apply_damage(_floors.current_hp())


func _offline_gold() -> String:
	_state.last_saved_unix = NOW - OFFLINE_SECONDS
	return (_offline.grant(_state, NOW)["gold"] as BigNumber).to_decimal_string()


func _skills() -> SkillManager:
	var skills: SkillManager = SkillManager.from_data({
		"schema_version": SkillManager.SUPPORTED_SCHEMA,
		"skills": [
			{"id": "big_hit", "name": "Gros coup", "effect": "burst", "dps_seconds": "6", "cooldown_seconds": 60},
			{"id": "damage_buff", "name": "Frénésie", "effect": "damage_multiplier", "multiplier": "1.5", "duration_seconds": 15, "cooldown_seconds": 90},
			{"id": "gold_bonus", "name": "Bonus d'or", "effect": "gold_multiplier", "multiplier": "1.5", "duration_seconds": 20, "cooldown_seconds": 120},
		],
	}, _state, _combat, _floors)
	assert_str(skills.get_error()).is_empty()
	return skills


# Catalog

func test_catalog_has_five_types_three_rarities_and_nine_stats() -> void:
	# Arrange
	var table: LootTable = _inventory.table()

	# Act
	var counts: Array[int] = [table.types().size(), table.rarities().size(), table.stats().size()]

	# Assert
	assert_array(counts).is_equal([5, 3, 9])


func test_rolled_item_has_one_stat_plus_the_secondary_stats_of_its_rarity() -> void:
	for rarity: String in ["common", "rare", "legendary"]:
		# Arrange
		var expected: int = 1 + _inventory.table().rarity_def(rarity).secondary_stats

		# Act
		var item: Item = _inventory.table().roll_item("sword", rarity)

		# Assert
		assert_int(item.stats.size()).is_equal(expected)
		assert_int(item.percent(Item.STAT_CLICK_DAMAGE)).is_greater(0)


func test_rolled_values_stay_in_the_range_of_their_rarity() -> void:
	# Arrange
	_die = DIE_MISS

	# Act
	var item: Item = _inventory.table().roll_item("sword", "rare")

	# Assert
	assert_int(item.percent(Item.STAT_CLICK_DAMAGE)).is_between(5, 8)


func test_catalog_without_all_nine_stats_is_refused() -> void:
	# Arrange
	var data: Dictionary = _items_data()
	(data["stats"] as Array).pop_back()

	# Act
	var table: LootTable = LootTable.from_data(data, _dice)

	# Assert
	assert_bool(table.is_valid()).is_false()


func test_catalog_with_inverted_range_is_refused() -> void:
	# Arrange
	var data: Dictionary = _items_data()
	(data["stats"] as Array)[0]["ranges"]["rare"] = [8, 5]

	# Act
	var table: LootTable = LootTable.from_data(data, _dice)

	# Assert
	assert_bool(table.is_valid()).is_false()


func test_catalog_with_unordered_loot_tiers_is_refused() -> void:
	# Arrange
	var data: Dictionary = _items_data()
	(data["boss_loot"] as Array).reverse()

	# Act
	var table: LootTable = LootTable.from_data(data, _dice)

	# Assert
	assert_bool(table.is_valid()).is_false()


# Loot

func test_boss_below_the_first_tier_drops_nothing() -> void:
	# Arrange
	var stage: int = BOSS_STAGE - 1

	# Act
	var dropped: Item = _inventory.on_boss_killed(stage)

	# Assert
	assert_object(dropped).is_null()
	assert_int(_inventory.bag().size()).is_equal(0)


func test_first_item_drops_on_the_boss_of_stage_10() -> void:
	# Arrange
	_build(BOSS_STAGE)

	# Act
	_kill()

	# Assert
	assert_int(_inventory.bag().size()).is_equal(1)


func test_normal_enemy_drops_nothing() -> void:
	# Arrange
	_build(BOSS_STAGE + 1)

	# Act
	_kill()

	# Assert
	assert_int(_inventory.bag().size()).is_equal(0)


func test_boss_loot_uses_the_last_tier_reached() -> void:
	# Arrange
	var before: Item = _inventory.on_boss_killed(SECOND_TIER_STAGE - 1)

	# Act
	var after: Item = _inventory.on_boss_killed(SECOND_TIER_STAGE)

	# Assert
	assert_str(before.rarity).is_equal("common")
	assert_str(after.rarity).is_equal("rare")


func test_tier_lookup_changes_at_the_exact_stage() -> void:
	# Arrange
	var table: LootTable = _inventory.table()

	# Act
	var before_first: Dictionary = table.tier_at(BOSS_STAGE - 1)
	var before_second: Dictionary = table.tier_at(SECOND_TIER_STAGE - 1)
	var at_second: Dictionary = table.tier_at(SECOND_TIER_STAGE)

	# Assert
	assert_bool(before_first.is_empty()).is_true()
	assert_int(before_second["from_stage"]).is_equal(BOSS_STAGE)
	assert_int(at_second["from_stage"]).is_equal(SECOND_TIER_STAGE)


func test_boss_loot_without_dice_drops_nothing() -> void:
	# Arrange
	_inventory.set_roll(Callable())

	# Act
	var dropped: Item = _inventory.on_boss_killed(BOSS_STAGE)

	# Assert
	assert_object(dropped).is_null()


# Bag and automatic sale

func test_item_fits_in_a_bag_with_room_and_nothing_is_sold() -> void:
	# Arrange
	_fill_bag(_commons([5, 6]))

	# Act
	var sold: Array[Item] = _inventory.receive(_item(0, "helmet", "common", {Item.STAT_GLOBAL_DAMAGE: 1}), BOSS_STAGE)

	# Assert
	assert_int(sold.size()).is_equal(0)
	assert_int(_inventory.bag().size()).is_equal(CAPACITY)
	assert_bool(_inventory.is_full()).is_true()


func test_full_bag_sells_the_smallest_sum_at_equal_rarity() -> void:
	# Arrange
	_fill_bag(_commons([5, 3, 4]))

	# Act
	var sold: Array[Item] = _inventory.receive(_item(0, "helmet", "common", {Item.STAT_GLOBAL_DAMAGE: 9}), BOSS_STAGE)

	# Assert
	assert_int(sold.size()).is_equal(1)
	assert_int(sold[0].total_percent()).is_equal(3)
	assert_int(_inventory.bag().size()).is_equal(CAPACITY)


func test_rarity_comes_before_the_sum() -> void:
	# Arrange: the common has by far the biggest sum
	var strong_common: Item = _item(1, "helmet", "common", {Item.STAT_GLOBAL_DAMAGE: 90})
	_fill_bag([strong_common, _item(2, "helmet", "rare", {Item.STAT_GLOBAL_DAMAGE: 1}), _item(3, "helmet", "rare", {Item.STAT_GLOBAL_DAMAGE: 1})])

	# Act
	var sold: Array[Item] = _inventory.receive(_item(0, "helmet", "rare", {Item.STAT_GLOBAL_DAMAGE: 1}), BOSS_STAGE)

	# Assert
	assert_int(sold[0].uid).is_equal(strong_common.uid)


func test_equal_items_sell_the_oldest() -> void:
	# Arrange
	_fill_bag(_commons([4, 4, 4]))

	# Act
	var sold: Array[Item] = _inventory.receive(_item(0, "helmet", "common", {Item.STAT_GLOBAL_DAMAGE: 4}), BOSS_STAGE)

	# Assert
	assert_int(sold[0].uid).is_equal(1)


func test_new_item_that_is_the_worst_is_sold_at_once() -> void:
	# Arrange
	_fill_bag(_commons([5, 6, 7]))
	var incoming: Item = _item(0, "helmet", "common", {Item.STAT_GLOBAL_DAMAGE: 1})

	# Act
	var sold: Array[Item] = _inventory.receive(incoming, BOSS_STAGE)

	# Assert
	assert_bool(sold.has(incoming)).is_true()
	assert_bool(_inventory.bag().has(incoming)).is_false()


func test_equipped_item_is_never_sold() -> void:
	# Arrange: the worn item is the worst of all
	var worn: Item = _item(9, "sword", "common", {Item.STAT_CLICK_DAMAGE: 1})
	_permanent.equipped_items["sword"] = worn
	_fill_bag(_commons([5, 6, 7]))

	# Act
	var sold: Array[Item] = _inventory.receive(_item(0, "helmet", "common", {Item.STAT_GLOBAL_DAMAGE: 8}), BOSS_STAGE)

	# Assert
	assert_bool(sold.has(worn)).is_false()
	assert_object(_inventory.equipped("sword")).is_same(worn)


func test_sale_gives_the_gold_of_its_rarity() -> void:
	# Arrange
	_fill_bag(_commons([5, 6, 7]))

	# Act
	_inventory.receive(_item(0, "helmet", "common", {Item.STAT_GLOBAL_DAMAGE: 1}), BOSS_STAGE)

	# Assert: 10 kills of 1000 gold
	assert_str(_state.gold.to_decimal_string()).is_equal("10000")


func test_sale_price_depends_on_the_rarity() -> void:
	# Arrange
	_fill_bag([
		_item(1, "helmet", "rare", {Item.STAT_GLOBAL_DAMAGE: 5}),
		_item(2, "helmet", "legendary", {Item.STAT_GLOBAL_DAMAGE: 10}),
		_item(3, "helmet", "legendary", {Item.STAT_GLOBAL_DAMAGE: 11}),
	])

	# Act: the rare is the worst, then a legendary when the capacity leaves no choice
	_inventory.receive(_item(0, "helmet", "legendary", {Item.STAT_GLOBAL_DAMAGE: 12}), BOSS_STAGE)
	var rare_gold: String = _state.gold.to_decimal_string()
	_inventory.receive(_item(0, "helmet", "legendary", {Item.STAT_GLOBAL_DAMAGE: 13}), BOSS_STAGE)

	# Assert: 40 kills of 1000 gold, then 200 more
	assert_str(rare_gold).is_equal("40000")
	assert_str(_state.gold.to_decimal_string()).is_equal("240000")


func test_loot_signal_carries_the_item_the_sales_and_the_gold() -> void:
	# Arrange
	_fill_bag(_commons([5, 6, 7]))
	var received: Array = []
	_inventory.loot_received.connect(func(item: Item, sold: Array[Item], gold: BigNumber) -> void: received.append([item, sold, gold]))
	var incoming: Item = _item(0, "helmet", "rare", {Item.STAT_GLOBAL_DAMAGE: 6})

	# Act
	_inventory.receive(incoming, BOSS_STAGE)

	# Assert
	assert_int(received.size()).is_equal(1)
	assert_object(received[0][0]).is_same(incoming)
	assert_int((received[0][1] as Array).size()).is_equal(1)
	assert_str((received[0][2] as BigNumber).to_decimal_string()).is_equal("10000")


func test_bag_over_a_reduced_capacity_is_sold_down_on_the_next_arrival() -> void:
	# Arrange: the data shrank the capacity below the bag
	_fill_bag(_commons([5, 6, 7, 8, 9]))

	# Act
	var sold: Array[Item] = _inventory.receive(_item(0, "helmet", "common", {Item.STAT_GLOBAL_DAMAGE: 1}), BOSS_STAGE)

	# Assert
	assert_int(sold.size()).is_equal(3)
	assert_int(_inventory.bag().size()).is_equal(CAPACITY)


func test_received_items_get_a_uid_above_all_owned() -> void:
	# Arrange
	_permanent.equipped_items["sword"] = _item(40, "sword", "common", {Item.STAT_CLICK_DAMAGE: 1})
	_fill_bag(_commons([5]))
	var incoming: Item = _item(0, "helmet", "common", {Item.STAT_GLOBAL_DAMAGE: 1})

	# Act
	_inventory.receive(incoming, BOSS_STAGE)

	# Assert
	assert_int(incoming.uid).is_equal(41)


# Equipping and comparison

func test_equip_in_an_empty_slot_leaves_the_bag() -> void:
	# Arrange
	var item: Item = _item(1, "sword", "common", {Item.STAT_CLICK_DAMAGE: 3})
	_fill_bag([item])

	# Act
	var equipped: bool = _inventory.equip(item.uid)

	# Assert
	assert_bool(equipped).is_true()
	assert_object(_inventory.equipped("sword")).is_same(item)
	assert_int(_inventory.bag().size()).is_equal(0)


func test_equip_swaps_with_the_item_of_its_type_only() -> void:
	# Arrange
	var old_sword: Item = _item(1, "sword", "common", {Item.STAT_CLICK_DAMAGE: 3})
	var helmet: Item = _item(2, "helmet", "common", {Item.STAT_GLOBAL_DAMAGE: 3})
	var new_sword: Item = _item(3, "sword", "rare", {Item.STAT_CLICK_DAMAGE: 7})
	_permanent.equipped_items = {"sword": old_sword, "helmet": helmet}
	_fill_bag([new_sword])

	# Act
	_inventory.equip(new_sword.uid)

	# Assert
	assert_object(_inventory.equipped("sword")).is_same(new_sword)
	assert_object(_inventory.equipped("helmet")).is_same(helmet)
	assert_bool(_inventory.bag().has(old_sword)).is_true()
	assert_int(_inventory.bag().size()).is_equal(1)


func test_equip_item_not_in_the_bag_is_refused() -> void:
	# Arrange
	var worn: Item = _item(1, "sword", "common", {Item.STAT_CLICK_DAMAGE: 3})
	_permanent.equipped_items["sword"] = worn

	# Act
	var equipped: bool = _inventory.equip(worn.uid)

	# Assert
	assert_bool(equipped).is_false()


func test_equip_type_unknown_to_the_data_is_refused() -> void:
	# Arrange
	var item: Item = _item(1, "boots", "common", {Item.STAT_CLICK_DAMAGE: 3})
	_fill_bag([item])

	# Act
	var equipped: bool = _inventory.equip(item.uid)

	# Assert
	assert_bool(equipped).is_false()
	assert_int(_inventory.bag().size()).is_equal(1)


func test_compare_gives_nine_rows_with_the_difference() -> void:
	# Arrange
	_permanent.equipped_items["sword"] = _item(1, "sword", "common", {Item.STAT_CLICK_DAMAGE: 6})
	var candidate: Item = _item(2, "sword", "rare", {Item.STAT_CLICK_DAMAGE: 4, Item.STAT_GOLD: 7})

	# Act
	var rows: Array[Dictionary] = _inventory.compare(candidate)

	# Assert
	assert_int(rows.size()).is_equal(9)
	var by_stat: Dictionary = {}
	for row: Dictionary in rows:
		by_stat[row["stat"]] = row
	assert_int(by_stat[Item.STAT_CLICK_DAMAGE]["delta"]).is_equal(-2)
	assert_int(by_stat[Item.STAT_GOLD]["delta"]).is_equal(7)
	assert_int(by_stat[Item.STAT_BOSS_GOLD]["delta"]).is_equal(0)


func test_compare_on_an_empty_slot_counts_from_zero() -> void:
	# Arrange
	var candidate: Item = _item(2, "aura", "common", {Item.STAT_GOLD: 3})

	# Act
	var rows: Array[Dictionary] = _inventory.compare(candidate)

	# Assert
	for row: Dictionary in rows:
		assert_int(row["active"]).is_equal(0)


# Saves

func test_save_round_trip_keeps_the_bag_and_the_equipped_items() -> void:
	# Arrange
	_fill_bag(_commons([5]))
	_permanent.equipped_items["sword"] = _item(9, "sword", "rare", {Item.STAT_CLICK_DAMAGE: 7, Item.STAT_GOLD: 4})

	# Act
	var restored: PermanentState = PermanentState.from_dict(JSON.parse_string(JSON.stringify(_permanent.to_dict())))

	# Assert
	assert_int(restored.inventory_items.size()).is_equal(1)
	assert_int(restored.inventory_items[0].percent(Item.STAT_GLOBAL_DAMAGE)).is_equal(5)
	var worn: Item = restored.equipped_items["sword"]
	assert_str(worn.rarity).is_equal("rare")
	assert_int(worn.percent(Item.STAT_GOLD)).is_equal(4)


func test_saves_older_than_version_5_load_with_no_items() -> void:
	for version: int in range(1, PermanentState.CURRENT_VERSION):
		# Arrange
		var data: Dictionary = {"version": version, "talents": {"click": 1}}

		# Act
		var restored: PermanentState = PermanentState.from_dict(data)

		# Assert
		assert_int(restored.inventory_items.size()).is_equal(0)
		assert_int(restored.equipped_items.size()).is_equal(0)
		assert_bool(restored.talents.has("click")).is_true()


func test_malformed_saved_items_are_dropped() -> void:
	# Arrange
	var good: Dictionary = _item(3, "helmet", "common", {Item.STAT_GLOBAL_DAMAGE: 2}).to_dict()
	var data: Dictionary = {"inventory": [{"uid": "a"}, null, 5, good], "equipped": {"sword": 7, "helmet": []}}

	# Act
	var restored: PermanentState = PermanentState.from_dict(data)

	# Assert
	assert_int(restored.inventory_items.size()).is_equal(1)
	assert_int(restored.equipped_items.size()).is_equal(0)


func test_items_survive_a_run_reset() -> void:
	# Arrange
	_fill_bag(_commons([5]))
	_wear({Item.STAT_CLICK_DAMAGE: 10})

	# Act
	_state.reset()

	# Assert
	assert_int(_inventory.bag().size()).is_equal(1)
	assert_int(_inventory.percent(Item.STAT_CLICK_DAMAGE)).is_equal(10)


# Effects

func test_equipping_applies_the_bonus_at_once() -> void:
	# Arrange
	_wear({Item.STAT_CLICK_DAMAGE: 10})

	# Act
	var dealt: String = _damage_dealt_by(_floors.click)

	# Assert
	assert_str(dealt).is_equal("110")


func test_only_equipped_items_count() -> void:
	# Arrange
	_fill_bag([_item(1, "sword", "legendary", {Item.STAT_CLICK_DAMAGE: 50})])

	# Act
	var dealt: String = _damage_dealt_by(_floors.click)

	# Assert
	assert_str(dealt).is_equal(CLICK_BASE)


func test_item_and_talent_of_a_stat_add_up() -> void:
	# Arrange
	assert_bool(_talents.buy("click")).is_true()
	_wear({Item.STAT_CLICK_DAMAGE: 10})

	# Act
	var dealt: String = _damage_dealt_by(_floors.click)

	# Assert: +10% and +10% give +20%, not +21%
	assert_str(dealt).is_equal("120")


func test_talent_reset_keeps_the_item_bonus() -> void:
	# Arrange
	assert_bool(_talents.buy("click")).is_true()
	_wear({Item.STAT_CLICK_DAMAGE: 10})

	# Act
	_talents.reset()

	# Assert
	assert_str(_damage_dealt_by(_floors.click)).is_equal("110")


func test_companion_stat_raises_attacks() -> void:
	# Arrange
	_wear({Item.STAT_COMPANION_DAMAGE: 50})
	var companions: CompanionManager = CompanionManager.new(_state, _combat, _floors)

	# Act
	var dealt: String = _damage_dealt_by(func() -> void: companions.tick(1.0))

	# Assert
	assert_str(dealt).is_equal("150")


func test_global_damage_raises_clicks_companions_and_big_hit() -> void:
	# Arrange
	_wear({Item.STAT_GLOBAL_DAMAGE: 50})
	var companions: CompanionManager = CompanionManager.new(_state, _combat, _floors)
	var skills: SkillManager = _skills()

	# Act
	var click: String = _damage_dealt_by(_floors.click)
	var attack: String = _damage_dealt_by(func() -> void: companions.tick(1.0))
	var big_hit: String = _damage_dealt_by(func() -> void: skills.activate("big_hit"))

	# Assert
	assert_str(click).is_equal("150")
	assert_str(attack).is_equal("150")
	assert_str(big_hit).is_equal("1800")


func test_boss_damage_counts_in_a_boss_fight() -> void:
	# Arrange
	_build(BOSS_STAGE)
	_wear({Item.STAT_BOSS_DAMAGE: 50})

	# Act
	var dealt: String = _damage_dealt_by(_floors.click)

	# Assert
	assert_str(dealt).is_equal("150")


func test_boss_damage_is_ignored_on_a_normal_enemy() -> void:
	# Arrange
	_wear({Item.STAT_BOSS_DAMAGE: 50})

	# Act
	var dealt: String = _damage_dealt_by(_floors.click)

	# Assert
	assert_str(dealt).is_equal(CLICK_BASE)


func test_global_and_boss_damage_multiply_each_other() -> void:
	# Arrange
	_build(BOSS_STAGE)
	_wear({Item.STAT_GLOBAL_DAMAGE: 50, Item.STAT_BOSS_DAMAGE: 100})

	# Act
	var dealt: String = _damage_dealt_by(_floors.click)

	# Assert: 100 * 1.5 * 2
	assert_str(dealt).is_equal("300")


func test_gold_stat_raises_kill_gold() -> void:
	# Arrange
	_wear({Item.STAT_GOLD: 50})

	# Act
	_kill()

	# Assert
	assert_str(_state.gold.to_decimal_string()).is_equal("1500")


func test_boss_gold_is_ignored_on_a_normal_kill() -> void:
	# Arrange
	_wear({Item.STAT_BOSS_GOLD: 50})

	# Act
	_kill()

	# Assert
	assert_str(_state.gold.to_decimal_string()).is_equal(GOLD_PER_KILL)


func test_boss_gold_raises_the_gold_of_a_boss_kill() -> void:
	# Arrange
	_build(BOSS_STAGE)
	_kill()
	var boss_gold: BigNumber = _state.gold
	_build(BOSS_STAGE)
	_wear({Item.STAT_BOSS_GOLD: 50})

	# Act
	_kill()

	# Assert
	assert_str(_state.gold.to_decimal_string()).is_equal(boss_gold.multiply_decimal("1.5").to_decimal_string())


func test_offline_stat_and_rentes_add_up() -> void:
	# Arrange
	assert_bool(_talents.buy("rentes")).is_true()
	_wear({Item.STAT_OFFLINE_GOLD: 25})

	# Act
	var gold: String = _offline_gold()

	# Assert: 180 without bonus, +25% and +25% give +50%
	assert_str(gold).is_equal("270")


# Critical hit, clicks only

func test_critical_click_deals_double() -> void:
	# Arrange
	_wear({Item.STAT_CRIT_CHANCE: 100})

	# Act
	var dealt: String = _damage_dealt_by(_floors.click)

	# Assert
	assert_str(dealt).is_equal("200")


func test_click_without_crit_chance_is_never_critical() -> void:
	# Arrange
	_die = DIE_HIT

	# Act
	var dealt: String = _damage_dealt_by(_floors.click)

	# Assert
	assert_str(dealt).is_equal(CLICK_BASE)


func test_click_is_critical_only_below_the_chance() -> void:
	# Arrange: 25% is a hit at 0.24 and a miss at 0.25
	_wear({Item.STAT_CRIT_CHANCE: 25})

	# Act
	_die = 0.24
	var below: String = _damage_dealt_by(_floors.click)
	_die = 0.25
	var at_chance: String = _damage_dealt_by(_floors.click)

	# Assert
	assert_str(below).is_equal("200")
	assert_str(at_chance).is_equal(CLICK_BASE)


func test_click_without_dice_is_never_critical() -> void:
	# Arrange
	_wear({Item.STAT_CRIT_CHANCE: 100})
	_floors.set_crit_roll(Callable())

	# Act
	var dealt: String = _damage_dealt_by(_floors.click)

	# Assert
	assert_str(dealt).is_equal(CLICK_BASE)


func test_crit_damage_raises_the_critical_bonus() -> void:
	# Arrange
	_wear({Item.STAT_CRIT_CHANCE: 100, Item.STAT_CRIT_DAMAGE: 50})

	# Act
	var dealt: String = _damage_dealt_by(_floors.click)

	# Assert: +100% and +50% give +150%
	assert_str(dealt).is_equal("250")


func test_critical_comes_after_the_other_damage_stats() -> void:
	# Arrange
	_wear({Item.STAT_CRIT_CHANCE: 100, Item.STAT_GLOBAL_DAMAGE: 50})

	# Act
	var dealt: String = _damage_dealt_by(_floors.click)

	# Assert: 100 * 1.5 * 2
	assert_str(dealt).is_equal("300")


func test_critical_click_emits_its_final_damage() -> void:
	# Arrange
	_wear({Item.STAT_CRIT_CHANCE: 100})
	var hits: Array[String] = []
	_floors.critical_hit.connect(func(damage: BigNumber) -> void: hits.append(damage.to_decimal_string()))

	# Act
	_floors.click()

	# Assert
	assert_array(hits).is_equal(["200"])


func test_click_returns_its_damage_before_the_critical() -> void:
	# Arrange: the measured click dps must stay free of random hits
	_wear({Item.STAT_CRIT_CHANCE: 100})

	# Act
	var returned: BigNumber = _floors.click()

	# Assert
	assert_str(returned.to_decimal_string()).is_equal(CLICK_BASE)


func test_companion_attack_is_never_critical() -> void:
	# Arrange
	_wear({Item.STAT_CRIT_CHANCE: 100})
	var companions: CompanionManager = CompanionManager.new(_state, _combat, _floors)
	var hits: Array[BigNumber] = []
	_floors.critical_hit.connect(func(damage: BigNumber) -> void: hits.append(damage))

	# Act
	var dealt: String = _damage_dealt_by(func() -> void: companions.tick(1.0))

	# Assert
	assert_str(dealt).is_equal(COMPANION_DAMAGE)
	assert_int(hits.size()).is_equal(0)


func test_big_hit_is_never_critical() -> void:
	# Arrange
	_wear({Item.STAT_CRIT_CHANCE: 100})
	var skills: SkillManager = _skills()
	var hits: Array[BigNumber] = []
	_floors.critical_hit.connect(func(damage: BigNumber) -> void: hits.append(damage))

	# Act
	var dealt: String = _damage_dealt_by(func() -> void: skills.activate("big_hit"))

	# Assert: (100 + 100) * 6
	assert_str(dealt).is_equal("1200")
	assert_int(hits.size()).is_equal(0)


func test_crit_chance_is_capped_by_the_data() -> void:
	# Arrange
	var data: Dictionary = _items_data()
	data["crit"]["max_chance_percent"] = 30
	_inventory = Inventory.from_data(data, _permanent, _state, _combat, _dice)
	_hub = ModifierHub.new(_floors, _offline, _talents, _inventory)
	_wear({Item.STAT_CRIT_CHANCE: 90})

	# Act
	var chance: int = _hub.crit_chance_percent()

	# Assert
	assert_int(chance).is_equal(30)
