class_name ModifierHub
extends RefCounted
## The SINGLE place that merges the permanent bonuses (talents, story 006, and equipped
## items, story 007) and pushes them to the game formulas. Several callers pushing their
## own part would overwrite each other ([method FloorManager.set_talent_modifiers] and
## [method OfflineIncome.set_talent_factor] keep only the last call): here the percentages
## of each stat are SUMMED over both sources (two +10% give +20%, not +21%), then one factor
## per stat is pushed. Do not call [method TalentTree.apply_to] when a hub exists.
##
## Merged stats (talents + items): click_damage, companion_damage, gold, offline_gold.
## Item-only stats: global_damage, boss_damage, boss_gold, crit_damage, crit_chance.
## Critical hit: chance = clamp(base + crit_chance, 0, max), damage bonus = base +
## crit_damage, as percentages (bases and max come from items.json, see [LootTable]); the
## factor pushed is 1 + bonus / 100.
##
## The hub refreshes itself when the talents or the inventory emit changed, and once when built.
## The caller must keep a reference to the hub for as long as the game runs. Either source
## may be null (the simulator runs with or without items, a test with neither).
##
## Usage:
## [codeblock]
## var hub: ModifierHub = ModifierHub.new(floors, offline, talents, inventory)
## talents.buy("click_1")     # the hub re-pushes by itself
## inventory.equip(uid)       # same
## print(hub.percent("click_damage"), " ", hub.crit_chance_percent())
## [/codeblock]

var _floors: FloorManager
var _offline: OfflineIncome
var _talents: TalentTree
var _inventory: Inventory


## Builds the hub, connects to [signal TalentTree.changed] and [signal Inventory.changed], then
## pushes once. [param talents] and [param inventory] may be null.
func _init(floors: FloorManager, offline: OfflineIncome, talents: TalentTree = null, inventory: Inventory = null) -> void:
	_floors = floors
	_offline = offline
	_talents = talents
	_inventory = inventory
	if _talents != null:
		_talents.changed.connect(refresh)
	if _inventory != null:
		_inventory.changed.connect(refresh)
	refresh()


## Total percentage of [param stat] (one of [constant Item.STATS]): talents plus equipped items.
func percent(stat: String) -> int:
	var total: int = 0
	if _talents != null:
		total += _talents.percent(stat)
	if _inventory != null:
		total += _inventory.percent(stat)
	return total


## The decimal-string factor of [method percent] for [param stat]: "1" for none, "1.40" for 40%.
func factor(stat: String) -> String:
	return TalentTree.factor_from_percent(percent(stat))


## Chance of a critical hit, in percent: the base of the data plus the items, never above the
## maximum of the data. 0 without an inventory.
func crit_chance_percent() -> int:
	if _inventory == null or not _inventory.is_valid():
		return 0
	var table: LootTable = _inventory.table()
	return clampi(table.crit_base_chance() + percent(Item.STAT_CRIT_CHANCE), 0, table.crit_max_chance())


## Bonus of a critical hit, in percent: 100 means it deals double. The base of the data plus the
## items; 0 without an inventory.
func crit_bonus_percent() -> int:
	if _inventory == null or not _inventory.is_valid():
		return 0
	return _inventory.table().crit_base_bonus() + percent(Item.STAT_CRIT_DAMAGE)


## Pushes the merged factors to the floors and the offline income. Called by the signals; call it
## by hand after changing the sources without a signal.
func refresh() -> void:
	_floors.set_talent_modifiers(factor(Item.STAT_CLICK_DAMAGE), factor(Item.STAT_COMPANION_DAMAGE), factor(Item.STAT_GOLD))
	_floors.set_item_modifiers(
			factor(Item.STAT_GLOBAL_DAMAGE), factor(Item.STAT_BOSS_DAMAGE), factor(Item.STAT_BOSS_GOLD),
			crit_chance_percent(), TalentTree.factor_from_percent(crit_bonus_percent()))
	_offline.set_talent_factor(factor(Item.STAT_OFFLINE_GOLD))
