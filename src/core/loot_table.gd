class_name LootTable
extends RefCounted
## The item catalog and the boss loot table (story 007, design/game-brief.md MVP feature 7),
## read from items.json (see assets/data/data_schema.md): stats and their value ranges per
## rarity, rarities (secondary stat count, sale price), types (slots and their primary
## stat), inventory size, critical-hit base values and the boss loot tiers. It also rolls the
## items. Pure logic: no disk, no clock, no UI.
##
## RANDOMNESS IS INJECTED. Every roll reads a [Callable] that returns a float in [0.0, 1.0)
## (for example [method RandomNumberGenerator.randf] of a seeded generator, or a scripted
## sequence in a test). Nothing here calls a global random function, so a seeded run is
## reproducible. Without a valid roll, [method roll_item] and [method roll_boss_loot]
## return null and push an error.
##
## Boss loot: the tier with the highest from_stage that is <= the boss stage applies; a boss
## below the first tier drops nothing. A tier gives drop_percent (0..100) and rarity weights;
## the type is picked by the drop_weight of the types. Item roll: the primary stat of the
## type, then as many distinct secondary stats as the rarity says, drawn among the other
## stats; each value is uniform in the range of (stat, rarity).
##
## Single-thread only. Build with [method from_data] and check [method is_valid].
##
## Usage:
## [codeblock]
## var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## rng.seed = 1
## var table: LootTable = LootTable.from_data(DataLoader.load_json("res://assets/data/items.json"), rng.randf)
## if table.is_valid():
##     var item: Item = table.roll_boss_loot(10)   # the boss of stage 10: null when nothing drops
## else:
##     push_error(table.get_error())
## [/codeblock]

## Version of items.json this code understands.
const SUPPORTED_SCHEMA: int = 1

## A rarity, as read from the data. Read-only: do not modify.
class RarityDef extends RefCounted:
	## Unique stable id.
	var id: String = ""
	## Display name (French).
	var display_name: String = ""
	## Number of secondary stats (>= 0).
	var secondary_stats: int = 0
	## Sale price, in normal kills of gold at the stage of the boss (>= 0).
	var sell_kills: int = 0
	## Position in the data: 0 is the least rare. The "worse item" rule compares it first.
	var rank: int = 0

## A type (slot), as read from the data. Read-only: do not modify.
class TypeDef extends RefCounted:
	## Unique stable id; the key of the equipped pieces.
	var id: String = ""
	## Display name.
	var display_name: String = ""
	## Stat id every item of this type has.
	var primary_stat: String = ""
	## Weight of the type in the type draw (>= 1).
	var drop_weight: int = 1

## A stat, as read from the data. Read-only: do not modify.
class StatDef extends RefCounted:
	## One of [constant Item.STATS].
	var id: String = ""
	## Display name (French).
	var display_name: String = ""
	## Rarity id -> Vector2i(min, max), whole percentages, 1 <= min <= max.
	var ranges: Dictionary = {}

var _error: String = ""
var _roll: Callable
var _worse_rule: String = ""
var _capacity: int = 1
var _crit_base_chance: int = 0
var _crit_base_bonus: int = 0
var _crit_max_chance: int = 100
## In data order.
var _stats: Array[StatDef] = []
var _rarities: Array[RarityDef] = []
var _types: Array[TypeDef] = []
var _stat_by_id: Dictionary = {}
var _rarity_by_id: Dictionary = {}
var _type_by_id: Dictionary = {}
## Tiers in data order: {"from_stage": int, "drop_percent": int, "weights": Array[int] (one per rarity)}.
var _tiers: Array[Dictionary] = []
## Weight moves of the talents (story 019), see [method set_weight_shifts].
var _shifts: Array[Dictionary] = []


## Parses and validates items.json (as returned by [method DataLoader.load_json], null
## allowed). [param roll] returns a float in [0.0, 1.0) (see the class comment); it may be
## given later with [method set_roll]. Always returns an instance; check [method is_valid].
static func from_data(data: Variant, roll: Callable = Callable()) -> LootTable:
	var table: LootTable = LootTable.new()
	table._roll = roll
	table._load(data)
	return table


## True when the data parsed cleanly.
func is_valid() -> bool:
	return _error.is_empty()


## First validation problem found, or "" when valid.
func get_error() -> String:
	return _error


## Replaces the injected roll ([Callable] returning a float in [0.0, 1.0)).
func set_roll(roll: Callable) -> void:
	_roll = roll


## Text of the "worse item" rule written in the data (see [method Inventory.is_worse]).
func worse_item_rule() -> String:
	return _worse_rule


## Number of items the bag holds before the worst are sold automatically.
func inventory_capacity() -> int:
	return _capacity


## Base chance of a critical hit, in percent, before the items.
func crit_base_chance() -> int:
	return _crit_base_chance


## Base bonus of a critical hit, in percent: 100 means a critical hit deals double.
func crit_base_bonus() -> int:
	return _crit_base_bonus


## Highest chance of a critical hit, in percent, whatever the items give.
func crit_max_chance() -> int:
	return _crit_max_chance


## The stats in data order (empty when invalid). Read-only: do not modify.
func stats() -> Array[StatDef]:
	return _stats


## The rarities, the least rare first (empty when invalid). Read-only: do not modify.
func rarities() -> Array[RarityDef]:
	return _rarities


## The types in data order (empty when invalid). Read-only: do not modify.
func types() -> Array[TypeDef]:
	return _types


## The stat with [param id], or null.
func stat_def(id: String) -> StatDef:
	return _stat_by_id.get(id)


## The rarity with [param id], or null.
func rarity_def(id: String) -> RarityDef:
	return _rarity_by_id.get(id)


## The type with [param id], or null.
func type_def(id: String) -> TypeDef:
	return _type_by_id.get(id)


## Rank of [param rarity_id] (0 = least rare), -1 when unknown to the data.
func rarity_rank(rarity_id: String) -> int:
	var def: RarityDef = _rarity_by_id.get(rarity_id)
	return def.rank if def != null else -1


## The loot tier that applies to a boss of [param stage]: {"from_stage": int, "drop_percent":
## int, "weights": {rarity id: int}}, or {} when the stage is below the first tier.
func tier_at(stage: int) -> Dictionary:
	var found: Dictionary = {}
	for tier: Dictionary in _tiers:
		if int(tier["from_stage"]) > stage:
			break
		found = tier
	if found.is_empty():
		return {}
	var shifted: Array[int] = _shifted(found["weights"])
	var weights: Dictionary = {}
	for i in _rarities.size():
		weights[_rarities[i].id] = shifted[i]
	return {"from_stage": found["from_stage"], "drop_percent": found["drop_percent"], "weights": weights}


## Moves rarity weight in every boss tier (story 019 "Flair"), replacing the previous call: each entry
## {"from": rarity id, "to": rarity id, "weight": int} moves that much weight from one rarity to the other,
## but never more than the "from" rarity has, so no weight goes negative and the sum stays the same (a
## tier with 0 on "from" is unchanged). Unknown rarity ids are ignored. Applied by [method tier_at] and
## [method roll_boss_loot]; the data is untouched.
func set_weight_shifts(shifts: Array[Dictionary]) -> void:
	_shifts = shifts


## Rolls the loot of the boss of [param stage]: an [Item] with uid 0 ([Inventory] gives it its
## uid), or null when the tier says nothing drops (or no tier applies, or no roll is set).
func roll_boss_loot(stage: int) -> Item:
	if not is_valid() or not _can_roll():
		return null
	var tier: Dictionary = {}
	for candidate: Dictionary in _tiers:
		if int(candidate["from_stage"]) > stage:
			break
		tier = candidate
	if tier.is_empty():
		return null
	var percent: int = tier["drop_percent"]
	if percent <= 0 or (percent < 100 and _pick(100) >= percent):
		return null
	var rarity: RarityDef = _rarities[_pick_weighted(_shifted(tier["weights"]))]
	var weights: Array[int] = []
	for def: TypeDef in _types:
		weights.append(def.drop_weight)
	return roll_item(_types[_pick_weighted(weights)].id, rarity.id)


## Rolls an item of the given type and rarity (both ids must be in the data, else null): the
## primary stat of the type, then the secondary stats the rarity allows. uid is 0.
func roll_item(type_id: String, rarity_id: String) -> Item:
	var type_def_: TypeDef = _type_by_id.get(type_id)
	var rarity: RarityDef = _rarity_by_id.get(rarity_id)
	if not is_valid() or type_def_ == null or rarity == null or not _can_roll():
		return null
	var item: Item = Item.new()
	item.type = type_id
	item.rarity = rarity_id
	item.stats[type_def_.primary_stat] = _value(type_def_.primary_stat, rarity_id)
	var pool: Array[String] = []
	for stat: StatDef in _stats:
		if stat.id != type_def_.primary_stat:
			pool.append(stat.id)
	for i in rarity.secondary_stats:
		var stat_id: String = pool.pop_at(_pick(pool.size()))
		item.stats[stat_id] = _value(stat_id, rarity_id)
	return item


# The rarity weights of a tier (one per rarity, data order) after the shifts of set_weight_shifts.
func _shifted(weights: Array) -> Array[int]:
	var result: Array[int] = []
	for w: Variant in weights:
		result.append(int(w))
	for shift: Dictionary in _shifts:
		var from: int = rarity_rank(shift["from"])
		var to: int = rarity_rank(shift["to"])
		if from < 0 or to < 0:
			continue
		var moved: int = mini(int(shift["weight"]), result[from])
		result[from] -= moved
		result[to] += moved
	return result


func _can_roll() -> bool:
	if _roll.is_valid():
		return true
	push_error("LootTable: no roll Callable was injected (see LootTable.from_data / set_roll)")
	return false


# A value uniform in the range of (stat, rarity).
func _value(stat_id: String, rarity_id: String) -> int:
	var range_: Vector2i = (_stat_by_id[stat_id] as StatDef).ranges[rarity_id]
	return range_.x + _pick(range_.y - range_.x + 1)


# An int in [0, count): the roll scaled, kept inside even if the Callable returns 1.0.
func _pick(count: int) -> int:
	return clampi(int(float(_roll.call()) * float(count)), 0, count - 1)


# An index of [param weights], drawn in proportion to the weights (their sum is > 0).
func _pick_weighted(weights: Variant) -> int:
	var total: int = 0
	for w: int in weights:
		total += w
	var point: int = _pick(total)
	for i in (weights as Array).size():
		point -= int(weights[i])
		if point < 0:
			return i
	return (weights as Array).size() - 1


func _load(data: Variant) -> void:
	if not data is Dictionary:
		_error = "items.json is missing or not an object"
		return
	var d: Dictionary = data
	if _whole(d.get("schema_version"), 0) != SUPPORTED_SCHEMA:
		_error = "items.json: unsupported schema_version (expected %d)" % SUPPORTED_SCHEMA
		return
	var rule: Variant = d.get("worse_item_rule")
	if not (rule is String and not (rule as String).is_empty()):
		_error = "items.json: 'worse_item_rule' must be a non-empty string (the rule is written in the data)"
		return
	_worse_rule = rule
	_capacity = _whole(d.get("inventory_capacity"), 0)
	if _capacity < 1:
		_capacity = 1
		_error = "items.json: 'inventory_capacity' must be an integer >= 1"
		return
	if not _load_crit(d.get("crit")) or not _load_rarities(d.get("rarities")) or not _load_stats(d.get("stats")):
		return
	if not _load_types(d.get("types")) or not _load_tiers(d.get("boss_loot")):
		return


func _load_crit(entry: Variant) -> bool:
	if not entry is Dictionary:
		_error = "items.json: 'crit' must be an object"
		return false
	var c: Dictionary = entry
	_crit_base_chance = _whole(c.get("base_chance_percent"), -1)
	_crit_base_bonus = _whole(c.get("base_bonus_percent"), -1)
	_crit_max_chance = _whole(c.get("max_chance_percent"), -1)
	if _crit_base_chance < 0 or _crit_base_bonus < 0 or _crit_max_chance < 0 or _crit_max_chance > 100 or _crit_base_chance > _crit_max_chance:
		_error = "items.json: 'crit' needs integers 'base_chance_percent' (<= max), 'base_bonus_percent' >= 0 and 'max_chance_percent' in 0..100"
		return false
	return true


func _load_rarities(entries: Variant) -> bool:
	if not entries is Array or (entries as Array).is_empty():
		_error = "items.json: 'rarities' must be a non-empty array (least rare first)"
		return false
	for entry: Variant in entries:
		var e: Dictionary = entry if entry is Dictionary else {}
		var def: RarityDef = RarityDef.new()
		var id: Variant = e.get("id")
		var rarity_name: Variant = e.get("name")
		if not (id is String and not (id as String).is_empty() and rarity_name is String and not (rarity_name as String).is_empty()):
			_error = "items.json: each rarity needs a non-empty string 'id' and 'name'"
			return false
		if _rarity_by_id.has(id):
			_error = "items.json: duplicate rarity '%s'" % id
			return false
		def.id = id
		def.display_name = rarity_name
		def.secondary_stats = _whole(e.get("secondary_stats"), -1)
		def.sell_kills = _whole(e.get("sell_kills"), -1)
		if def.secondary_stats < 0 or def.sell_kills < 0:
			_error = "items.json: rarity '%s': 'secondary_stats' and 'sell_kills' must be integers >= 0" % id
			return false
		def.rank = _rarities.size()
		_rarities.append(def)
		_rarity_by_id[def.id] = def
	return true


func _load_stats(entries: Variant) -> bool:
	if not entries is Array:
		_error = "items.json: 'stats' must be an array"
		return false
	for entry: Variant in entries:
		var e: Dictionary = entry if entry is Dictionary else {}
		var id: Variant = e.get("id")
		if not (id is String and Item.STATS.has(id)):
			_error = "items.json: each stat 'id' must be one of %s" % str(Item.STATS)
			return false
		if _stat_by_id.has(id):
			_error = "items.json: duplicate stat '%s'" % id
			return false
		var stat_name: Variant = e.get("name")
		if not (stat_name is String and not (stat_name as String).is_empty()):
			_error = "items.json: stat '%s' needs a non-empty string 'name'" % id
			return false
		var def: StatDef = StatDef.new()
		def.id = id
		def.display_name = stat_name
		var ranges: Variant = e.get("ranges")
		for rarity: RarityDef in _rarities:
			var pair: Variant = (ranges as Dictionary).get(rarity.id) if ranges is Dictionary else null
			var low: int = _whole((pair as Array)[0], 0) if pair is Array and (pair as Array).size() == 2 else 0
			var high: int = _whole((pair as Array)[1], 0) if pair is Array and (pair as Array).size() == 2 else 0
			if low < 1 or high < low:
				_error = "items.json: stat '%s': 'ranges.%s' must be [min, max] with 1 <= min <= max" % [id, rarity.id]
				return false
			def.ranges[rarity.id] = Vector2i(low, high)
		_stats.append(def)
		_stat_by_id[def.id] = def
	if _stats.size() != Item.STATS.size():
		_error = "items.json: 'stats' must list all %d stats %s" % [Item.STATS.size(), str(Item.STATS)]
		return false
	return true


func _load_types(entries: Variant) -> bool:
	if not entries is Array or (entries as Array).is_empty():
		_error = "items.json: 'types' must be a non-empty array"
		return false
	var most_secondary: int = 0
	for rarity: RarityDef in _rarities:
		most_secondary = maxi(most_secondary, rarity.secondary_stats)
	if most_secondary > _stats.size() - 1:
		_error = "items.json: a rarity asks for more secondary stats than there are stats besides the primary one"
		return false
	for entry: Variant in entries:
		var e: Dictionary = entry if entry is Dictionary else {}
		var id: Variant = e.get("id")
		var type_name: Variant = e.get("name")
		if not (id is String and not (id as String).is_empty() and type_name is String and not (type_name as String).is_empty()):
			_error = "items.json: each type needs a non-empty string 'id' and 'name'"
			return false
		if _type_by_id.has(id):
			_error = "items.json: duplicate type '%s'" % id
			return false
		var def: TypeDef = TypeDef.new()
		def.id = id
		def.display_name = type_name
		var primary: Variant = e.get("primary_stat")
		if not (primary is String and _stat_by_id.has(primary)):
			_error = "items.json: type '%s': 'primary_stat' must be one of the stats" % id
			return false
		def.primary_stat = primary
		def.drop_weight = _whole(e.get("drop_weight"), 0)
		if def.drop_weight < 1:
			_error = "items.json: type '%s': 'drop_weight' must be an integer >= 1" % id
			return false
		_types.append(def)
		_type_by_id[def.id] = def
	return true


func _load_tiers(entries: Variant) -> bool:
	if not entries is Array or (entries as Array).is_empty():
		_error = "items.json: 'boss_loot' must be a non-empty array"
		return false
	var previous: int = 0
	for entry: Variant in entries:
		var e: Dictionary = entry if entry is Dictionary else {}
		var from_stage: int = _whole(e.get("from_stage"), 0)
		if from_stage < 1 or from_stage <= previous:
			_error = "items.json: 'boss_loot[].from_stage' must be integers >= 1, strictly increasing"
			return false
		previous = from_stage
		var percent: int = _whole(e.get("drop_percent"), -1)
		if percent < 0 or percent > 100:
			_error = "items.json: boss_loot from_stage %d: 'drop_percent' must be an integer in 0..100" % from_stage
			return false
		var given: Variant = e.get("rarity_weights")
		if not given is Dictionary:
			_error = "items.json: boss_loot from_stage %d: 'rarity_weights' must be an object" % from_stage
			return false
		for key: Variant in given:
			if not (key is String and _rarity_by_id.has(key)):
				_error = "items.json: boss_loot from_stage %d: unknown rarity '%s' in 'rarity_weights'" % [from_stage, str(key)]
				return false
		var weights: Array[int] = []
		var total: int = 0
		for rarity: RarityDef in _rarities:
			var weight: int = _whole((given as Dictionary).get(rarity.id, 0), -1)
			if weight < 0:
				_error = "items.json: boss_loot from_stage %d: weight of '%s' must be an integer >= 0" % [from_stage, rarity.id]
				return false
			weights.append(weight)
			total += weight
		if total < 1:
			_error = "items.json: boss_loot from_stage %d: the rarity weights must not all be 0" % from_stage
			return false
		_tiers.append({"from_stage": from_stage, "drop_percent": percent, "weights": weights})
	return true


# [param value] as an int when it is a whole number (JSON numbers load as floats), else
# [param fallback].
func _whole(value: Variant, fallback: int) -> int:
	if (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)):
		return int(value)
	return fallback
