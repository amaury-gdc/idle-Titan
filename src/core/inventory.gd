class_name Inventory
extends RefCounted
## The player's items (story 007, design/game-brief.md MVP feature 7): a bag of limited size
## with automatic sale of the worst items, one equipped item per type, the comparison of an item
## with the equipped one, the totals the equipped items give to the game formulas, and the loot
## of the bosses. Pure logic: no disk, no clock, no UI. The items live in the injected
## [PermanentState] (permanent, like the talents: they survive [method GameState.reset]), the
## gold of a sale goes to the injected [GameState]. The catalog and the dice are in [LootTable].
## Texts are the UI's job: this class gives ids (type, rarity, stat) to translate with tr().
##
## BAG AND EQUIPPED. The bag ([method bag]) holds the items not worn; its size is limited
## ([method capacity], from items.json). The equipped items ([method equipped],
## [method equipped_items]) are outside the bag and never counted in the limit. Equipping
## ([method equip]) swaps the bag item with the one worn in its type, which goes back to
## the bag: the bag never grows by it. There is no unequip.
##
## AUTOMATIC SALE. When an item arrives ([method on_boss_killed], [method receive]) and the bag
## goes over [method capacity], the worst item is sold, again until it fits. The worst is
## the one that [method is_worse] puts first, the new item included (a new item that is
## itself the worst is sold at once). RULE, also written in items.json ("worse_item_rule"):
## 1. the less rare goes first (rarity order of the data, the least rare first);
## 2. at equal rarity, the smaller [method Item.total_percent] (all stats weighed alike);
## 3. at equal sum, the oldest (smallest uid).
## An equipped item is never sold. A sold item gives gold:
## [code]sell_kills(rarity) * gold_per_kill(stage of the boss)[/code] (exact BigNumber), added
## to [member GameState.gold]. If the data shrinks the capacity below the bag, nothing is sold
## at load; the next arrival sells down to the capacity.
##
## COMPARISON. [method compare] gives, for each of the nine stats, the value of the equipped
## item of the candidate's type, the candidate's and the difference.
##
## BONUSES. [method percent] and [method totals] sum the equipped items per stat. The game
## formulas do not read them directly: [ModifierHub] merges them with the talents and pushes
## the result, so that one source never overwrites the other.
##
## Single-thread only. Build with [method from_data] and check [method is_valid].
##
## Usage:
## [codeblock]
## var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## var inventory: Inventory = Inventory.from_data(
##         DataLoader.load_json("res://assets/data/items.json"), permanent, game, combat, rng.randf)
## if inventory.is_valid():
##     floors.boss_killed.connect(inventory.on_boss_killed)
##     inventory.loot_received.connect(func(item: Item, sold: Array[Item], gold: BigNumber) -> void: print(item.type, sold.size()))
##     var candidate: Item = inventory.bag()[0]
##     for row: Dictionary in inventory.compare(candidate):
##         print(row["stat"], row["active"], row["candidate"], row["delta"])
##     inventory.equip(candidate.uid)
## else:
##     push_error(inventory.get_error())
## [/codeblock]

## The bag or the equipped items changed (loot, sale, equip). The bonuses may have changed.
## Emitted before [signal loot_received].
signal changed
## An item dropped. [param item] is the new item (its uid is set); [param sold] lists the items
## sold to make room, oldest sale first, and contains [param item] itself when it was the worst
## (check [code]sold.has(item)[/code] to know whether it was kept); [param gold_gained] is the
## gold of the sales, already added to the state (zero when nothing was sold).
signal loot_received(item: Item, sold: Array[Item], gold_gained: BigNumber)

var _table: LootTable
var _permanent: PermanentState
var _game: GameState
var _combat: Combat


## Builds the inventory on the items of [param permanent]. [param data] is items.json (see
## [method LootTable.from_data]); [param game] receives the gold of the sales; [param combat]
## gives the gold of a kill for the price; [param roll] is the injected dice (a [Callable]
## returning a float in [0.0, 1.0), see [LootTable]) and may be given later with
## [method set_roll]. Always returns an instance; check [method is_valid].
static func from_data(data: Variant, permanent: PermanentState, game: GameState, combat: Combat, roll: Callable = Callable()) -> Inventory:
	var inventory: Inventory = Inventory.new()
	inventory._table = LootTable.from_data(data, roll)
	inventory._permanent = permanent
	inventory._game = game
	inventory._combat = combat
	return inventory


## True when the data parsed cleanly.
func is_valid() -> bool:
	return _table.is_valid()


## First validation problem found, or "" when valid.
func get_error() -> String:
	return _table.get_error()


## The catalog (types, rarities, stats, ranges, tiers). Read-only for the caller.
func table() -> LootTable:
	return _table


## Replaces the injected dice (see [method LootTable.set_roll]).
func set_roll(roll: Callable) -> void:
	_table.set_roll(roll)


## Size limit of the bag.
func capacity() -> int:
	return _table.inventory_capacity()


## The items in the bag, in order of arrival (oldest first). Read-only: do not modify.
func bag() -> Array[Item]:
	return _permanent.inventory_items


## True when the bag holds [method capacity] items or more.
func is_full() -> bool:
	return _permanent.inventory_items.size() >= capacity()


## The item worn in the type [param type_id], or null.
func equipped(type_id: String) -> Item:
	return _permanent.equipped_items.get(type_id)


## The worn items, in the order of the types of the data (those the data knows). Read-only
## for the caller: do not modify.
func equipped_items() -> Array[Item]:
	var worn: Array[Item] = []
	for def: LootTable.TypeDef in _table.types():
		var item: Item = equipped(def.id)
		if item != null:
			worn.append(item)
	return worn


## The item with [param uid], in the bag or worn, or null.
func find_item(uid: int) -> Item:
	for owned: Item in _permanent.inventory_items:
		if owned.uid == uid:
			return owned
	for owned: Item in equipped_items():
		if owned.uid == uid:
			return owned
	return null


## True when [param uid] is in the bag and its type is known to the data.
func can_equip(uid: int) -> bool:
	var found: Item = _bag_item(uid)
	return found != null and _table.type_def(found.type) != null


## Equips the bag item [param uid] in place of the worn item of its type (which goes back to
## the bag). Returns false and changes nothing when [method can_equip] is false. Emits
## [signal changed] on success.
func equip(uid: int) -> bool:
	var found: Item = _bag_item(uid)
	if found == null or _table.type_def(found.type) == null:
		return false
	var previous: Item = equipped(found.type)
	var slot: int = _permanent.inventory_items.find(found)
	if previous != null:
		_permanent.inventory_items[slot] = previous
	else:
		_permanent.inventory_items.remove_at(slot)
	_permanent.equipped_items[found.type] = found
	changed.emit()
	return true


## Percentage the worn items give to [param stat] (one of [constant Item.STATS]), the percentages
## of the same stat adding up. 0 for none or an unknown stat.
func percent(stat: String) -> int:
	var total: int = 0
	for worn: Item in equipped_items():
		total += worn.percent(stat)
	return total


## [method percent] for each of the nine stats: {stat id: int}, in the order of [constant Item.STATS].
func totals() -> Dictionary:
	var result: Dictionary = {}
	for stat: String in Item.STATS:
		result[stat] = percent(stat)
	return result


## Compares [param candidate] with the worn item of its type, for each of the nine stats in
## the order of [constant Item.STATS]: [code]{"stat": id, "active": the worn item's
## percentage (0 when none is worn), "candidate": the candidate's, "delta": candidate - active}[/code].
## Rows where both are 0 are included: the UI may hide them.
func compare(candidate: Item) -> Array[Dictionary]:
	var worn: Item = equipped(candidate.type)
	var rows: Array[Dictionary] = []
	for stat: String in Item.STATS:
		var active: int = worn.percent(stat) if worn != null else 0
		var offered: int = candidate.percent(stat)
		rows.append({"stat": stat, "active": active, "candidate": offered, "delta": offered - active})
	return rows


## True when [param a] is worse than [param b] by the rule of the class comment: less rare,
## else a smaller sum of bonuses, else older. Never true for an item against itself.
func is_worse(a: Item, b: Item) -> bool:
	var rank_a: int = _table.rarity_rank(a.rarity)
	var rank_b: int = _table.rarity_rank(b.rarity)
	if rank_a != rank_b:
		return rank_a < rank_b
	var sum_a: int = a.total_percent()
	var sum_b: int = b.total_percent()
	if sum_a != sum_b:
		return sum_a < sum_b
	return a.uid < b.uid


## Gold a sold item of [param rarity_id] gives for a boss of [param stage]: sell_kills * gold of
## a kill at that stage. Zero for a rarity the data does not know.
func sell_price(rarity_id: String, stage: int) -> BigNumber:
	var def: LootTable.RarityDef = _table.rarity_def(rarity_id)
	if def == null:
		return BigNumber.new()
	return _combat.gold_per_kill(stage).multiply(BigNumber.from_int(def.sell_kills))


## Handler for [signal FloorManager.boss_killed]: rolls the loot of the boss of [param stage]
## ([method LootTable.roll_boss_loot]) and, when something dropped, [method receive]s it.
## Returns the new item, or null when nothing dropped.
func on_boss_killed(stage: int) -> Item:
	if not is_valid():
		return null
	var dropped: Item = _table.roll_boss_loot(stage)
	if dropped != null:
		receive(dropped, stage)
	return dropped


## Puts [param new_item] in the bag (its uid is replaced by a fresh one, higher than every uid
## owned), then sells the worst items until the bag fits, gold priced for [param stage]. Returns
## the items sold. Emits [signal changed] then [signal loot_received].
func receive(new_item: Item, stage: int) -> Array[Item]:
	new_item.uid = _next_uid()
	_permanent.inventory_items.append(new_item)
	var sold: Array[Item] = []
	var gold: BigNumber = BigNumber.new()
	while _permanent.inventory_items.size() > capacity():
		var worst: Item = _permanent.inventory_items[0]
		for candidate: Item in _permanent.inventory_items:
			if is_worse(candidate, worst):
				worst = candidate
		_permanent.inventory_items.erase(worst)
		sold.append(worst)
		gold = gold.add(sell_price(worst.rarity, stage))
	if not gold.is_zero():
		_game.gold = _game.gold.add(gold)
	changed.emit()
	loot_received.emit(new_item, sold, gold)
	return sold


func _bag_item(uid: int) -> Item:
	for owned: Item in _permanent.inventory_items:
		if owned.uid == uid:
			return owned
	return null


# One above the highest uid owned (bag and worn, even types the data no longer knows).
func _next_uid() -> int:
	var highest: int = 0
	for owned: Item in _permanent.inventory_items:
		highest = maxi(highest, owned.uid)
	for type_id: Variant in _permanent.equipped_items:
		highest = maxi(highest, (_permanent.equipped_items[type_id] as Item).uid)
	return highest + 1
