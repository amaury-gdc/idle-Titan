class_name Item
extends RefCounted
## One piece of equipment (story 007, design/game-brief.md MVP feature 7): a type (one of
## five slots), a rarity and a list of stat bonuses, each a whole percentage. Plain data:
## the catalog (which types, rarities and ranges exist) lives in [LootTable], the bag and the
## equipped pieces in [Inventory]. An item only holds IDS; the UI translates them (tr()).
##
## The first stat of [member stats] is the primary stat of the type, the others are the
## secondary ones (their number depends on the rarity, see items.json). A stat appears once.
## Values are fixed when the item is rolled: retuning the ranges in items.json never changes
## an item already owned.
##
## Usage:
## [codeblock]
## var item: Item = Item.new()
## item.uid = 7
## item.type = "sword"
## item.rarity = "rare"
## item.stats = {"click_damage": 6, "gold": 3}
## print(item.percent(Item.STAT_GOLD), " ", item.total_percent())   # 3 9
## var copy: Item = Item.from_dict(item.to_dict())                  # null when malformed
## [/codeblock]

## Stat ids. The first four are the stats talents have too (same ids, so the percentages
## of a stat add up across both sources, see [ModifierHub]).
const STAT_CLICK_DAMAGE: String = TalentTree.STAT_CLICK_DAMAGE
const STAT_GLOBAL_DAMAGE: String = "global_damage"
const STAT_CRIT_DAMAGE: String = "crit_damage"
const STAT_CRIT_CHANCE: String = "crit_chance"
const STAT_COMPANION_DAMAGE: String = TalentTree.STAT_COMPANION_DAMAGE
const STAT_BOSS_DAMAGE: String = "boss_damage"
const STAT_GOLD: String = TalentTree.STAT_GOLD
const STAT_BOSS_GOLD: String = "boss_gold"
const STAT_OFFLINE_GOLD: String = TalentTree.STAT_OFFLINE_GOLD
## The nine stats, in display order.
const STATS: PackedStringArray = [
	STAT_CLICK_DAMAGE, STAT_GLOBAL_DAMAGE, STAT_CRIT_DAMAGE, STAT_CRIT_CHANCE, STAT_COMPANION_DAMAGE,
	STAT_BOSS_DAMAGE, STAT_GOLD, STAT_BOSS_GOLD, STAT_OFFLINE_GOLD,
]

## Unique id inside one player's items (bag and equipped). Assigned by [Inventory], growing:
## a higher uid is a newer item.
var uid: int = 0
## Type id (a slot: "sword", "helmet", ...), from items.json.
var type: String = ""
## Rarity id ("common", "rare", "legendary"), from items.json.
var rarity: String = ""
## Stat id (one of [constant STATS]) -> whole percentage (>= 1). Insertion order: the primary
## stat first.
var stats: Dictionary = {}


## Percentage this item gives to [param stat], 0 when it has none.
func percent(stat: String) -> int:
	return int(stats.get(stat, 0))


## Sum of every percentage of the item, all stats alike (the tie-break of the "worse item"
## rule, see [method Inventory.is_worse]).
func total_percent() -> int:
	var total: int = 0
	for stat: Variant in stats:
		total += int(stats[stat])
	return total


## The primary stat (the first one), "" when the item has no stat.
func primary_stat() -> String:
	for stat: Variant in stats:
		return stat
	return ""


## JSON-safe payload: {"uid", "type", "rarity", "stats": [{"stat", "percent"}, ...]}.
## The array keeps the order of the stats.
func to_dict() -> Dictionary:
	var list: Array = []
	for stat: Variant in stats:
		list.append({"stat": stat, "percent": int(stats[stat])})
	return {"uid": uid, "type": type, "rarity": rarity, "stats": list}


## Builds an item from a payload of [method to_dict] (JSON numbers are floats). Returns null
## when it is malformed: not an object, empty type or rarity, a negative or fractional uid, a
## stat repeated, with an empty id or a percentage below 1. Ids unknown to the current data
## are NOT refused here, [Inventory] ignores them.
static func from_dict(data: Variant) -> Item:
	if not data is Dictionary:
		return null
	var d: Dictionary = data
	var item: Item = Item.new()
	var read_uid: Variant = _whole(d.get("uid"))
	if read_uid == null or int(read_uid) < 0:
		return null
	item.uid = int(read_uid)
	var read_type: Variant = d.get("type")
	var read_rarity: Variant = d.get("rarity")
	if not (read_type is String and not (read_type as String).is_empty() and read_rarity is String and not (read_rarity as String).is_empty()):
		return null
	item.type = read_type
	item.rarity = read_rarity
	var list: Variant = d.get("stats")
	if not list is Array:
		return null
	for entry: Variant in list:
		var stat: Variant = (entry as Dictionary).get("stat") if entry is Dictionary else null
		var value: Variant = _whole((entry as Dictionary).get("percent")) if entry is Dictionary else null
		if not (stat is String and not (stat as String).is_empty()) or value == null or int(value) < 1 or item.stats.has(stat):
			return null
		item.stats[stat] = int(value)
	return item


# [param value] as an int when it is a whole number, else null.
static func _whole(value: Variant) -> Variant:
	if (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)):
		return int(value)
	return null
