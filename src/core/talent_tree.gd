class_name TalentTree
extends RefCounted
## Talent tree (story 006, design/game-brief.md MVP feature 6, reworked by story 018 after
## design/talent-tree-v2.md): branches of nodes read from talents.json (see
## assets/data/data_schema.md), points earned from the best stage reached, purchases with
## prerequisites, tiers and exclusive groups, a reset with rules, and the effects the bought
## nodes give to the game. Pure logic: no disk, no clock, no UI; the bought nodes live in the
## injected [PermanentState], the stage in the injected [GameState], the time and the boss
## fight are passed by the caller.
##
## Two file formats are read: schema 1 (flat nodes with one stat effect, one point every
## [code]stages_per_point[/code] stages, no versioning) and schema 2 (tiers, exclusive groups,
## [code]effects[/code], points by stage bands, [code]tree_version[/code]). A schema 1 file reads as a
## schema 2 tree with one band, one open tier, no group, version 0 and a single stat effect per
## node, so the rest of the game sees one model.
##
## Points:
## [codeblock]
## earned    = sum over the bands of floor(stages of the best stage inside the band / stages_per_point)
## spent     = sum of the cost of every bought node
## available = max(earned - spent, 0)
## [/codeblock]
## Bands (schema 2 [code]stage_point_bands[/code]): [{up_to: 100, stages_per_point: 5}, {stages_per_point: 20}]
## gives 1 point per 5 stages up to stage 100 (20 points), then 1 per 20 (25 at stage 200).
## best_stage_record is [member PermanentState.best_stage_record], the highest
## [member GameState.max_stage_reached] ever seen. [member GameState.max_stage_reached] alone
## would not do: [method GameState.reset] sets it back to 1 while the talents survive, and
## the available points would go negative. [method sync_best_stage] raises the record
## from the game state (idempotent, never lowers it); every points query calls it, and the
## main screen calls it before a save. Points earned in a past run therefore stay earned.
##
## Spent points are derived from the bought nodes and their CURRENT cost, not stored: a
## cost retuned in talents.json is applied to old saves at once, and a reset always gives
## back exactly what is spent. Ids of [member PermanentState.talents] unknown to the data
## are ignored. If the spent points exceed the earned ones (data retuned), nothing more
## can be bought until a reset.
##
## Tiers and groups: a node of tier t can be bought once the points SPENT in its branch reach
## [code]tier_thresholds[t - 1][/code]. A tier that closes again (a cost retuned) never takes a
## bought node away. A node of an [code]exclusive_group[/code] is refused when another node of
## the group is bought; a save that holds two of them keeps the first in data order (the other
## counts for nothing and its points are given back), so the rule needs no repair of the save.
##
## Effects: each node has a list of [code]effects[/code], each of a type in [constant EFFECT_FIELDS]. The percentages
## of a [code]stat[/code] add up and [method factor] gives the factor ("1.40" for +40%) as the decimal
## string [method FloorManager.set_talent_modifiers] and [method BigNumber.multiply_decimal]
## take. [code]skill_unlock[/code] and [code]skill_mod[/code] are read through [method skill_unlocked] and
## [method skill_override] (by [ModifierHub] and [SkillManager]). The other types are validated
## and carried, see [method owned_effects], but nothing applies them yet (story 019 and after).
## [method apply_to] pushes the stat factors to the [FloorManager] and the [OfflineIncome]; call
## it after building and after [signal changed].
##
## Reset: [method try_reset] is refused during a boss fight and during the real-time wait since
## the last reset ([member PermanentState.talent_reset_unix]), except that the wait does not
## apply when the spent points exceed the earned ones. [method reset] is the unconditional
## version, with no rule and no wait.
##
## Version: when talents.json has a [code]tree_version[/code] the player has not acknowledged
## ([member PermanentState.talent_tree_seen]), [method apply_tree_version] hands every point
## back (all keys of the save, old ids included), and [method version_notice_due] stays true
## until [method acknowledge_version]. Nothing happens by itself at construction, so the main
## screen pays the offline absence with the old bonuses first.
##
## Single-thread only. Build with [method from_data] and check [method is_valid].
##
## Usage:
## [codeblock]
## var tree: TalentTree = TalentTree.from_data(
##         DataLoader.load_json("res://assets/data/talents.json"), permanent_state, game_state)
## if tree.is_valid():
##     tree.changed.connect(func() -> void: tree.apply_to(floors, offline))
##     tree.apply_to(floors, offline)
##     if tree.buy("click_1"):
##         print(tree.available_points())
##     tree.try_reset(int(Time.get_unix_time_from_system()), floors.is_boss_fight())
## else:
##     push_error(tree.get_error())
## [/codeblock]

## A node was bought or the tree was reset. The factors may have changed.
signal changed

## State of a node, from the player's point of view.
enum NodeState {
	## Bought.
	OWNED,
	## Prerequisites met, tier open and enough points: can be bought now.
	BUYABLE,
	## Prerequisites met and tier open, but fewer points than the cost.
	UNAFFORDABLE,
	## A prerequisite is not bought yet.
	LOCKED,
	## Prerequisites met, but the branch has not spent enough points to open its tier.
	TIER_CLOSED,
	## Another node of its exclusive group is bought.
	EXCLUDED,
}

## Why [method try_reset] would refuse.
enum ResetBlock {
	## Nothing in the way.
	NONE,
	## A boss fight is running.
	BOSS,
	## The real-time wait since the last reset is not over.
	COOLDOWN,
}

## Version of talents.json this code understands: the flat format (schema 1).
const SUPPORTED_SCHEMA: int = 1
## The tiered format (schema 2).
const TIERED_SCHEMA: int = 2
## Stat names an effect may have. click_damage: damage of a click; companion_damage: damage
## of the companions' attacks; gold: gold of every kill; offline_gold: gold of an absence.
const STAT_CLICK_DAMAGE: String = "click_damage"
const STAT_COMPANION_DAMAGE: String = "companion_damage"
const STAT_GOLD: String = "gold"
const STAT_OFFLINE_GOLD: String = "offline_gold"
const STATS: PackedStringArray = [STAT_CLICK_DAMAGE, STAT_COMPANION_DAMAGE, STAT_GOLD, STAT_OFFLINE_GOLD]
## Effect types (value of the [code]type[/code] key).
const EFFECT_STAT: String = "stat"
const EFFECT_SKILL_UNLOCK: String = "skill_unlock"
const EFFECT_SKILL_MOD: String = "skill_mod"
## Fields of a skill a [code]skill_mod[/code] replaces: its amount (the decimal string of skills.json,
## "dps_seconds" or "multiplier"), its duration and its cooldown.
const SKILL_AMOUNT: String = "amount"
const SKILL_DURATION: String = "duration_seconds"
const SKILL_COOLDOWN: String = "cooldown_seconds"
const SKILL_FIELDS: PackedStringArray = [SKILL_AMOUNT, SKILL_DURATION, SKILL_COOLDOWN]
## Keys of each effect type and the kind of their value: "id" (non-empty string), "stat_name"
## (one of [constant STATS]), "skill_field" (one of [constant SKILL_FIELDS]), "factor" (decimal
## string > 0), "int" (whole number >= 1), "number" (number > 0), "seconds" (number >= 0), and
## "value" (a skill_mod value: a factor for the amount, a number otherwise). Every key is required.
const EFFECT_FIELDS: Dictionary = {
	"stat": {"stat": "stat_name", "percent": "int"},
	"skill_unlock": {"skill": "id"},
	"skill_mod": {"skill": "id", "field": "skill_field", "value": "value"},
	"skill_passive": {"skill": "id", "multiplier": "factor"},
	"rhythm": {"clicks": "int", "dps_seconds": "factor", "min_gap_seconds": "seconds"},
	"boss_timer": {"seconds": "number"},
	"offline_cap_hours": {"hours": "number"},
	"synergy": {"percent_per_companion": "int", "level": "int", "max_percent": "int"},
	"champion": {"percent": "int"},
	"loot_shift": {"from": "id", "to": "id", "weight": "int"},
}
## Wait between two resets, in seconds, when talents.json has no [code]reset_cooldown_seconds[/code].
const DEFAULT_RESET_COOLDOWN_SECONDS: int = 3600

## One node of the tree, as read from the data. Read-only: do not modify.
class TalentDef extends RefCounted:
	## Unique stable id; the key used in [member PermanentState.talents].
	var id: String = ""
	## Id of the branch it belongs to.
	var branch: String = ""
	## Display name (French).
	var display_name: String = ""
	## Cost in talent points (>= 1).
	var cost: int = 1
	## Ids of the nodes that must be bought first (all of them), earlier in the data
	## and in the same branch.
	var requires: PackedStringArray = PackedStringArray()
	## Tier, 1-based: the node opens when its branch has spent [code]tier_thresholds[tier - 1][/code]
	## points. 1 for a schema 1 file.
	var tier: int = 1
	## Id of its exclusive group ("" for none): at most one node of a group is bought.
	var exclusive_group: String = ""
	## The effects, each a Dictionary with a "type" and the keys of [constant TalentTree.EFFECT_FIELDS].
	var effects: Array[Dictionary] = []
	## Stat of the first [code]stat[/code] effect ("" when there is none), for the screen that shows one
	## effect per node.
	var stat: String = ""
	## Percentage of that first stat effect (0 when there is none).
	var percent: int = 0
	## Distance from a root node (a node without prerequisite is 0): the row it is
	## drawn on.
	var depth: int = 0
	## Ids of the nodes of its exclusive group that come before it in the data.
	var earlier_in_group: PackedStringArray = PackedStringArray()

var _error: String = ""
var _permanent: PermanentState
var _game: GameState
var _tree_version: int = 0
## Stage bands in order: {"up_to": int (0 = no limit, the last band), "per": int (stages per point)}.
var _bands: Array[Dictionary] = []
var _tier_thresholds: PackedInt32Array = PackedInt32Array()
var _reset_cooldown: int = DEFAULT_RESET_COOLDOWN_SECONDS
## Branches in data order: {"id": String, "name": String}.
var _branches: Array[Dictionary] = []
## Nodes in data order.
var _nodes: Array[TalentDef] = []
## Node id (String) -> [TalentDef].
var _by_id: Dictionary = {}
## Exclusive group id (String) -> ids of its nodes (PackedStringArray), in data order.
var _groups: Dictionary = {}
## Skill ids (String -> true) that some node unlocks: only these can be locked.
var _gated_skills: Dictionary = {}


## Parses and validates talents.json (as returned by [method DataLoader.load_json], null
## allowed). [param permanent] holds the bought nodes and the stage record, [param game] the
## best stage of the run. Always returns an instance; check [method is_valid].
static func from_data(data: Variant, permanent: PermanentState, game: GameState) -> TalentTree:
	var tree: TalentTree = TalentTree.new()
	tree._permanent = permanent
	tree._game = game
	tree._load(data)
	return tree


## True when the data parsed cleanly.
func is_valid() -> bool:
	return _error.is_empty()


## First validation problem found, or "" when valid.
func get_error() -> String:
	return _error


## Stages between two points in the first band (the only one of a schema 1 file).
func stages_per_point() -> int:
	return _bands[0]["per"] if not _bands.is_empty() else 1


## Version of the tree (schema 2 [code]tree_version[/code]); 0 for a schema 1 file, which has no
## versioning.
func tree_version() -> int:
	return _tree_version


## Points spent in a branch that open each tier: element t - 1 is the threshold of tier t.
func tier_thresholds() -> PackedInt32Array:
	return _tier_thresholds


## Seconds between two resets.
func reset_cooldown_seconds() -> int:
	return _reset_cooldown


## The branches in data order, each {"id": String, "name": String} (empty when the data is
## invalid). Read-only: do not modify.
func branches() -> Array[Dictionary]:
	return _branches


## The nodes in data order (empty when the data is invalid). Read-only: do not modify.
func nodes() -> Array[TalentDef]:
	return _nodes


## The nodes of branch [param branch_id], in data order.
func nodes_of(branch_id: String) -> Array[TalentDef]:
	var found: Array[TalentDef] = []
	for def: TalentDef in _nodes:
		if def.branch == branch_id:
			found.append(def)
	return found


## The node with [param id], or null.
func node(id: String) -> TalentDef:
	return _by_id.get(id)


## Raises [member PermanentState.best_stage_record] to the best stage of the game state when
## that is higher. Never lowers it. Idempotent.
func sync_best_stage() -> void:
	_permanent.best_stage_record = maxi(_permanent.best_stage_record, _game.max_stage_reached)


## Best stage ever reached, the base of [method earned_points].
func best_stage() -> int:
	sync_best_stage()
	return _permanent.best_stage_record


## Points a best stage of [param stage] earns: each band gives one point per its
## [code]stages_per_point[/code] stages of [param stage] that fall inside it.
func points_at_stage(stage: int) -> int:
	var total: int = 0
	var from: int = 0
	for band: Dictionary in _bands:
		var up_to: int = band["up_to"]
		var top: int = stage if up_to == 0 else mini(stage, up_to)
		if top <= from:
			break
		@warning_ignore("integer_division")
		total += (top - from) / int(band["per"])
		from = up_to
	return total


## Points earned so far: [method points_at_stage] of the best stage ever reached.
func earned_points() -> int:
	return points_at_stage(best_stage())


## Points spent on the bought nodes.
func spent_points() -> int:
	var total: int = 0
	for def: TalentDef in _nodes:
		if is_owned(def.id):
			total += def.cost
	return total


## Points spent on the bought nodes of branch [param branch_id], the base of its tiers.
func spent_in_branch(branch_id: String) -> int:
	var total: int = 0
	for def: TalentDef in _nodes:
		if def.branch == branch_id and is_owned(def.id):
			total += def.cost
	return total


## True when the branch [param branch_id] has spent enough points to open [param tier] (1-based).
func tier_open(branch_id: String, tier: int) -> bool:
	return spent_in_branch(branch_id) >= _tier_thresholds[tier - 1]


## Points that can still be spent (never negative).
func available_points() -> int:
	return maxi(earned_points() - spent_points(), 0)


## True when [param id] is bought and counts. Of two nodes of one exclusive group in a save, only
## the first in data order counts.
func is_owned(id: String) -> bool:
	if int(_permanent.talents.get(id, 0)) <= 0:
		return false
	var def: TalentDef = _by_id.get(id)
	if def != null:
		for earlier: String in def.earlier_in_group:
			if int(_permanent.talents.get(earlier, 0)) > 0:
				return false
	return true


## True when every prerequisite of [param id] is bought. False for an unknown id.
func prerequisites_met(id: String) -> bool:
	var def: TalentDef = _by_id.get(id)
	if def == null:
		return false
	for required: String in def.requires:
		if not is_owned(required):
			return false
	return true


## State of [param id], which must be in the data. When several apply, the first of: bought,
## excluded, locked, tier closed, then the points decide.
func state_of(id: String) -> NodeState:
	if is_owned(id):
		return NodeState.OWNED
	var def: TalentDef = _by_id[id]
	if _group_taken(def):
		return NodeState.EXCLUDED
	if not prerequisites_met(id):
		return NodeState.LOCKED
	if not tier_open(def.branch, def.tier):
		return NodeState.TIER_CLOSED
	return NodeState.BUYABLE if available_points() >= def.cost else NodeState.UNAFFORDABLE


## True when [param id] is known, not bought, has its prerequisites, an open tier and a free
## group, costs no more than the available points, and no version notice waits for the player.
func can_buy(id: String) -> bool:
	return _by_id.has(id) and not version_notice_due() and state_of(id) == NodeState.BUYABLE


## Buys [param id]. Returns false and changes nothing when [method can_buy] is false.
## Emits [signal changed] on success.
func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	_permanent.talents[id] = 1
	changed.emit()
	return true


## Unconditional free reset: removes every bought node of the data, giving all the spent points
## back, with no rule and no wait. The game goes through [method try_reset]. Returns the number of
## points given back (0 and no signal when nothing was bought). Emits [signal changed] when something
## was bought.
func reset() -> int:
	var refunded: int = spent_points()
	var had_any: bool = false
	for def: TalentDef in _nodes:
		if _permanent.talents.has(def.id):
			_permanent.talents.erase(def.id)
			had_any = true
	if had_any:
		changed.emit()
	return refunded


## What would stop a reset at Unix time [param now_unix]: a boss fight ([param in_boss_fight])
## first, then the wait since the last reset, which does not apply when more points are spent than
## earned (a retuned tree must always be escapable).
func reset_block(now_unix: int, in_boss_fight: bool) -> ResetBlock:
	if in_boss_fight:
		return ResetBlock.BOSS
	if reset_seconds_left(now_unix) > 0 and spent_points() <= earned_points():
		return ResetBlock.COOLDOWN
	return ResetBlock.NONE


## Seconds of wait left before the next reset at Unix time [param now_unix], from 0 to
## [method reset_cooldown_seconds]. A last reset dated after [param now_unix] (the clock was set
## back) counts as [param now_unix], so the wait never exceeds one cooldown. A pure query: the stamp
## itself is pulled back by [method try_reset].
func reset_seconds_left(now_unix: int) -> int:
	var stamp: int = mini(_permanent.talent_reset_unix, now_unix)
	return clampi(stamp + _reset_cooldown - now_unix, 0, _reset_cooldown)


## The reset of the game. First pulls a last reset dated after [param now_unix] (clock set back)
## back to it, so that the wait then runs out one cooldown later and a wrong clock cannot lock the
## reset for good. Then does nothing and returns false while [method version_notice_due], when
## [method reset_block] says so or when nothing is bought (no wait starts); else removes every
## bought node, stamps [param now_unix] as the last reset and returns true. Emits [signal changed].
func try_reset(now_unix: int, in_boss_fight: bool) -> bool:
	_permanent.talent_reset_unix = mini(_permanent.talent_reset_unix, now_unix)
	if version_notice_due() or reset_block(now_unix, in_boss_fight) != ResetBlock.NONE or spent_points() <= 0:
		return false
	_permanent.talent_reset_unix = now_unix
	reset()
	return true


## True when talents.json has a [code]tree_version[/code] that the player has not acknowledged yet
## ([member PermanentState.talent_tree_seen]): the screen must show the one-time message, and
## [method buy] refuses until [method acknowledge_version].
func version_notice_due() -> bool:
	return _tree_version > 0 and _permanent.talent_tree_seen != _tree_version


## Hands every point back when [method version_notice_due]: empties [member PermanentState.talents]
## (old ids included) and lifts the reset wait. Safe to repeat until the player acknowledges: the
## save keeps the old version number until then, and buying is refused meanwhile. A save of a
## player who never got past stage 1 and bought nothing has nothing to say and is acknowledged at
## once. Returns true when the message is due. Call it once after the load, AFTER the offline
## absence was paid: that absence is worth the bonuses the player had. Emits [signal changed] when
## talents were removed.
func apply_tree_version() -> bool:
	if not version_notice_due():
		return false
	if _permanent.talents.is_empty() and best_stage() <= 1:
		_permanent.talent_tree_seen = _tree_version
		return false
	var had_any: bool = not _permanent.talents.is_empty()
	_permanent.talents.clear()
	_permanent.talent_reset_unix = 0
	if had_any:
		changed.emit()
	return true


## The player read the version message: records the current [method tree_version] so that it is
## not due again and purchases are allowed. Emits [signal changed].
func acknowledge_version() -> void:
	_permanent.talent_tree_seen = _tree_version
	changed.emit()


## Factor the bought nodes give to [param stat] (one of [constant STATS]), as a decimal
## string: "1" when there is none, else "1.40" for +40%. Percentages of the same stat add up.
func factor(stat: String) -> String:
	return factor_from_percent(percent(stat))


## Sum of the percentages the bought nodes give to [param stat] (0 for none or a stat no
## node has).
func percent(stat: String) -> int:
	var total: int = 0
	for effect: Dictionary in owned_effects(EFFECT_STAT):
		if effect["stat"] == stat:
			total += int(effect["percent"])
	return total


## The effects of type [param type] of the bought nodes, in data order. This is how the types
## nothing applies yet (rhythm, champion...) reach the game.
func owned_effects(type: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for def: TalentDef in _nodes:
		if not is_owned(def.id):
			continue
		for effect: Dictionary in def.effects:
			if effect["type"] == type:
				found.append(effect)
	return found


## False only for a skill that some node of the data unlocks and none of the bought nodes does.
## Derived from the bought nodes, never stored: a reset locks it again at once.
func skill_unlocked(skill_id: String) -> bool:
	if not _gated_skills.has(skill_id):
		return true
	for effect: Dictionary in owned_effects(EFFECT_SKILL_UNLOCK):
		if effect["skill"] == skill_id:
			return true
	return false


## Value the bought nodes give to [param field] (one of [constant SKILL_FIELDS]) of the skill
## [param skill_id], replacing the one of skills.json: a decimal String for the amount, a float of
## seconds otherwise. null when no bought node changes it; the last one in data order wins.
func skill_override(skill_id: String, field: String) -> Variant:
	var found: Variant = null
	for effect: Dictionary in owned_effects(EFFECT_SKILL_MOD):
		if effect["skill"] == skill_id and effect["field"] == field:
			found = effect["value"]
	return found


## The decimal-string factor of a total of [param percentage] percent: "1" for 0, "1.40" for 40,
## "2.00" for 100. [ModifierHub] uses it on the sum of talents and items.
static func factor_from_percent(percentage: int) -> String:
	if percentage <= 0:
		return "1"
	@warning_ignore("integer_division")
	return "%d.%02d" % [1 + percentage / 100, percentage % 100]


## Pushes the talent factors ALONE to [param floors] (see [method FloorManager.set_talent_modifiers])
## and to [param offline] (see [method OfflineIncome.set_talent_factor]). With an [Inventory]
## in play, do NOT use it: it would overwrite the sum of talents and items. Use
## [ModifierHub.refresh] instead, the single place that merges both.
func apply_to(floors: FloorManager, offline: OfflineIncome) -> void:
	floors.set_talent_modifiers(factor(STAT_CLICK_DAMAGE), factor(STAT_COMPANION_DAMAGE), factor(STAT_GOLD))
	offline.set_talent_factor(factor(STAT_OFFLINE_GOLD))


# True when a node of the exclusive group of [param def] other than itself is bought.
func _group_taken(def: TalentDef) -> bool:
	if def.exclusive_group.is_empty():
		return false
	for other: String in _groups[def.exclusive_group]:
		if other != def.id and is_owned(other):
			return true
	return false


func _load(data: Variant) -> void:
	if not data is Dictionary:
		_error = "talents.json is missing or not an object"
		return
	var d: Dictionary = data
	var schema: int = _read_int(d.get("schema_version"), 0)
	if schema != SUPPORTED_SCHEMA and schema != TIERED_SCHEMA:
		_error = "talents.json: unsupported schema_version (expected %d or %d)" % [SUPPORTED_SCHEMA, TIERED_SCHEMA]
		return
	var tiered: bool = schema == TIERED_SCHEMA
	if tiered:
		if not _load_tiered_header(d):
			return
	else:
		var per: int = _read_int(d.get("stages_per_point"), 0)
		if per < 1:
			_error = "talents.json: 'stages_per_point' must be an integer >= 1"
			return
		_bands.append({"up_to": 0, "per": per})
		_tier_thresholds = PackedInt32Array([0])
	if not _load_branches(d.get("branches")):
		return
	var entries: Variant = d.get("nodes")
	if not entries is Array or (entries as Array).is_empty():
		_error = "talents.json: 'nodes' must be a non-empty array"
		return
	for entry: Variant in entries:
		if not entry is Dictionary:
			_error = "talents.json: each node must be an object"
			return
		var def: TalentDef = _read_node(entry, tiered)
		if def == null:
			return
		_by_id[def.id] = def
		_nodes.append(def)
		for effect: Dictionary in def.effects:
			if effect["type"] == EFFECT_SKILL_UNLOCK:
				_gated_skills[effect["skill"]] = true


# The keys only schema 2 has. Returns false with _error set.
func _load_tiered_header(d: Dictionary) -> bool:
	_tree_version = _read_int(d.get("tree_version"), 0)
	if _tree_version < 1:
		_error = "talents.json: 'tree_version' must be an integer >= 1"
		return false
	if d.has("reset_cooldown_seconds"):
		_reset_cooldown = _read_int(d["reset_cooldown_seconds"], -1)
		if _reset_cooldown < 0:
			_reset_cooldown = DEFAULT_RESET_COOLDOWN_SECONDS
			_error = "talents.json: 'reset_cooldown_seconds' must be an integer >= 0"
			return false
	return _load_bands(d.get("stage_point_bands")) and _load_thresholds(d.get("tier_thresholds"))


# Every band but the last has an "up_to" stage above the one before; the last has none.
func _load_bands(entries: Variant) -> bool:
	if not entries is Array or (entries as Array).is_empty():
		_error = "talents.json: 'stage_point_bands' must be a non-empty array"
		return false
	var previous: int = 0
	for index: int in (entries as Array).size():
		var entry: Variant = (entries as Array)[index]
		var per: int = _read_int((entry as Dictionary).get("stages_per_point"), 0) if entry is Dictionary else 0
		if per < 1:
			_error = "talents.json: each band needs an integer 'stages_per_point' >= 1"
			return false
		var up_to: int = 0
		if index < (entries as Array).size() - 1:
			up_to = _read_int((entry as Dictionary).get("up_to"), 0)
			if up_to <= previous:
				_error = "talents.json: 'up_to' of the bands must be integers in increasing order, and only the last band has none"
				return false
			previous = up_to
		elif (entry as Dictionary).has("up_to"):
			_error = "talents.json: the last band must have no 'up_to'"
			return false
		_bands.append({"up_to": up_to, "per": per})
	return true


# Strictly increasing whole numbers, the first one 0 (the first tier is always open).
func _load_thresholds(entries: Variant) -> bool:
	if not entries is Array or (entries as Array).is_empty():
		_error = "talents.json: 'tier_thresholds' must be a non-empty array"
		return false
	var previous: int = -1
	for entry: Variant in entries:
		var threshold: int = _read_int(entry, -1)
		if threshold <= previous:
			_error = "talents.json: 'tier_thresholds' must be increasing whole numbers starting at 0"
			return false
		previous = threshold
		_tier_thresholds.append(threshold)
	if _tier_thresholds[0] != 0:
		_error = "talents.json: 'tier_thresholds' must be increasing whole numbers starting at 0"
		return false
	return true


func _load_branches(entries: Variant) -> bool:
	if not entries is Array or (entries as Array).is_empty():
		_error = "talents.json: 'branches' must be a non-empty array"
		return false
	var seen: Dictionary = {}
	for entry: Variant in entries:
		var id: Variant = entry.get("id") if entry is Dictionary else null
		var branch_name: Variant = entry.get("name") if entry is Dictionary else null
		if not (id is String and not (id as String).is_empty() and branch_name is String and not (branch_name as String).is_empty()):
			_error = "talents.json: each branch needs a non-empty string 'id' and 'name'"
			return false
		if seen.has(id):
			_error = "talents.json: duplicate branch '%s'" % id
			return false
		seen[id] = true
		_branches.append({"id": id, "name": branch_name})
	return true


# Returns the parsed node, or null with _error set.
func _read_node(entry: Dictionary, tiered: bool) -> TalentDef:
	var def: TalentDef = TalentDef.new()
	var id: Variant = entry.get("id")
	if not (id is String and not (id as String).is_empty()):
		_error = "talents.json: each node needs a non-empty string 'id'"
		return null
	def.id = id
	if _by_id.has(def.id):
		_error = "talents.json: duplicate node '%s'" % def.id
		return null
	var branch: Variant = entry.get("branch")
	if not (branch is String and _has_branch(branch)):
		_error = "talents.json: node '%s' has an unknown 'branch'" % def.id
		return null
	def.branch = branch
	var node_name: Variant = entry.get("name")
	if not (node_name is String and not (node_name as String).is_empty()):
		_error = "talents.json: node '%s' needs a non-empty string 'name'" % def.id
		return null
	def.display_name = node_name
	def.cost = _read_int(entry.get("cost"), 0)
	if def.cost < 1:
		_error = "talents.json: node '%s': 'cost' must be an integer >= 1" % def.id
		return null
	var requires: Variant = entry.get("requires", [])
	if not requires is Array:
		_error = "talents.json: node '%s': 'requires' must be an array" % def.id
		return null
	for required: Variant in requires:
		# Only earlier nodes of the same branch: no cycle is possible, and the row of a
		# node (depth) is known when it is read.
		var parent: TalentDef = _by_id.get(required) if required is String else null
		if parent == null or parent.branch != def.branch:
			_error = "talents.json: node '%s': 'requires' must list earlier nodes of the same branch" % def.id
			return null
		def.requires.append(parent.id)
		def.depth = maxi(def.depth, parent.depth + 1)
	if tiered and not _read_tier_and_group(def, entry):
		return null
	var raw_effects: Variant = entry.get("effects") if tiered else _flat_effects(entry)
	if not raw_effects is Array or (raw_effects as Array).is_empty():
		_error = "talents.json: node '%s': 'effects' must be a non-empty array" % def.id if tiered else "talents.json: node '%s': 'effect' must be an object with 'stat' and 'percent'" % def.id
		return null
	for raw: Variant in raw_effects:
		var effect: Dictionary = _read_effect(def.id, raw)
		if effect.is_empty():
			return null
		def.effects.append(effect)
		if effect["type"] == EFFECT_STAT and def.stat.is_empty():
			def.stat = effect["stat"]
			def.percent = effect["percent"]
	return def


# The tier and the exclusive group of a schema 2 node. Returns false with _error set.
func _read_tier_and_group(def: TalentDef, entry: Dictionary) -> bool:
	def.tier = _read_int(entry.get("tier"), 0)
	if def.tier < 1 or def.tier > _tier_thresholds.size():
		_error = "talents.json: node '%s': 'tier' must be an integer from 1 to %d" % [def.id, _tier_thresholds.size()]
		return false
	if entry.has("exclusive_group"):
		var group: Variant = entry["exclusive_group"]
		if not (group is String and not (group as String).is_empty()):
			_error = "talents.json: node '%s': 'exclusive_group' must be a non-empty string" % def.id
			return false
		def.exclusive_group = group
		var members: PackedStringArray = _groups.get(group, PackedStringArray())
		def.earlier_in_group = members.duplicate()
		members.append(def.id)
		_groups[group] = members
	return true


# A schema 1 node has one "effect" {stat, percent}: the same as one schema 2 stat effect.
func _flat_effects(entry: Dictionary) -> Variant:
	var effect: Variant = entry.get("effect")
	if not effect is Dictionary:
		return null
	return [{"type": EFFECT_STAT, "stat": (effect as Dictionary).get("stat"), "percent": (effect as Dictionary).get("percent")}]


# One effect of node [param node_id], with the numbers as ints and floats; {} with _error set when
# it does not fit [constant EFFECT_FIELDS].
func _read_effect(node_id: String, raw: Variant) -> Dictionary:
	var kind: Variant = (raw as Dictionary).get("type") if raw is Dictionary else null
	if not (kind is String and EFFECT_FIELDS.has(kind)):
		_error = "talents.json: node '%s': each effect needs a 'type' among %s" % [node_id, str(EFFECT_FIELDS.keys())]
		return {}
	var effect: Dictionary = {"type": kind}
	var fields: Dictionary = EFFECT_FIELDS[kind]
	for key: String in fields:
		var value_kind: String = fields[key]
		if value_kind == "value":
			value_kind = "factor" if effect["field"] == SKILL_AMOUNT else "number"
		var value: Variant = _read_field((raw as Dictionary).get(key), value_kind)
		if value == null:
			_error = "talents.json: node '%s': effect '%s' needs '%s' (%s)" % [node_id, kind, key, value_kind]
			return {}
		effect[key] = value
	return effect


# [param value] as a [param kind] of [constant EFFECT_FIELDS], or null when it is not one.
func _read_field(value: Variant, kind: String) -> Variant:
	var is_number: bool = (value is int or value is float) and is_finite(float(value))
	match kind:
		"id":
			return value if value is String and not (value as String).is_empty() else null
		"stat_name":
			return value if value is String and STATS.has(value) else null
		"skill_field":
			return value if value is String and SKILL_FIELDS.has(value) else null
		"factor":
			return value if value is String and GrowthCurve.is_valid_factor(value) and (value as String).to_float() > 0.0 else null
		"int":
			var whole: int = _read_int(value, 0)
			return whole if whole >= 1 else null
		"number":
			return float(value) if is_number and float(value) > 0.0 else null
		"seconds":
			return float(value) if is_number and float(value) >= 0.0 else null
	return null


func _has_branch(branch_id: String) -> bool:
	for branch: Dictionary in _branches:
		if branch["id"] == branch_id:
			return true
	return false


# [param value] as an int when it is a whole number (JSON numbers load as floats), else
# [param fallback].
func _read_int(value: Variant, fallback: int) -> int:
	if (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)):
		return int(value)
	return fallback
