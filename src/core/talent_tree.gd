class_name TalentTree
extends RefCounted
## Talent tree (story 006, design/game-brief.md MVP feature 6): three branches of nodes
## read from talents.json (see assets/data/data_schema.md), points earned from the best
## stage reached, purchases with prerequisites, free reset, and the factors the bought
## nodes give to the game formulas. Pure logic: no disk, no clock, no UI; the bought nodes
## live in the injected [PermanentState], the stage in the injected [GameState].
##
## Points:
## [codeblock]
## earned    = floor(best_stage_record / stages_per_point)
## spent     = sum of the cost of every bought node
## available = max(earned - spent, 0)
## [/codeblock]
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
## can be bought until a reset, which stays free and always possible.
##
## Effects: each node adds a percentage to one stat; the percentages of a stat add up and
## [method factor] gives the factor ("1.40" for +40%) as the decimal string
## [method FloorManager.set_talent_modifiers] and [method BigNumber.multiply_decimal] take.
## [method apply_to] pushes the factors to the [FloorManager] and the [OfflineIncome]; call
## it after building and after [signal changed].
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
##     tree.reset()       # free: gives every spent point back
## else:
##     push_error(tree.get_error())
## [/codeblock]

## A node was bought or the tree was reset. The factors may have changed.
signal changed

## State of a node, from the player's point of view.
enum NodeState {
	## Bought.
	OWNED,
	## Prerequisites met and enough points: can be bought now.
	BUYABLE,
	## Prerequisites met, but fewer points than the cost.
	UNAFFORDABLE,
	## A prerequisite is not bought yet.
	LOCKED,
}

## Version of talents.json this code understands.
const SUPPORTED_SCHEMA: int = 1
## Stat names an effect may have. click_damage: damage of a click; companion_damage: damage
## of the companions' attacks; gold: gold of every kill; offline_gold: gold of an absence.
const STAT_CLICK_DAMAGE: String = "click_damage"
const STAT_COMPANION_DAMAGE: String = "companion_damage"
const STAT_GOLD: String = "gold"
const STAT_OFFLINE_GOLD: String = "offline_gold"
const STATS: PackedStringArray = [STAT_CLICK_DAMAGE, STAT_COMPANION_DAMAGE, STAT_GOLD, STAT_OFFLINE_GOLD]

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
	## One of [constant TalentTree.STATS].
	var stat: String = ""
	## Percentage added to the stat (integer >= 1).
	var percent: int = 0
	## Distance from a root node (a node without prerequisite is 0): the row it is
	## drawn on.
	var depth: int = 0

var _error: String = ""
var _permanent: PermanentState
var _game: GameState
var _stages_per_point: int = 1
## Branches in data order: {"id": String, "name": String}.
var _branches: Array[Dictionary] = []
## Nodes in data order.
var _nodes: Array[TalentDef] = []
## Node id (String) -> [TalentDef].
var _by_id: Dictionary = {}


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


## Stages between two points (stages_per_point of the data).
func stages_per_point() -> int:
	return _stages_per_point


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


## Points earned so far: one per [method stages_per_point] stages of the best stage ever reached.
func earned_points() -> int:
	@warning_ignore("integer_division")
	return best_stage() / _stages_per_point


## Points spent on the bought nodes.
func spent_points() -> int:
	var total: int = 0
	for def: TalentDef in _nodes:
		if is_owned(def.id):
			total += def.cost
	return total


## Points that can still be spent (never negative).
func available_points() -> int:
	return maxi(earned_points() - spent_points(), 0)


## True when [param id] is bought.
func is_owned(id: String) -> bool:
	return int(_permanent.talents.get(id, 0)) > 0


## True when every prerequisite of [param id] is bought. False for an unknown id.
func prerequisites_met(id: String) -> bool:
	var def: TalentDef = _by_id.get(id)
	if def == null:
		return false
	for required: String in def.requires:
		if not is_owned(required):
			return false
	return true


## State of [param id], which must be in the data.
func state_of(id: String) -> NodeState:
	if is_owned(id):
		return NodeState.OWNED
	if not prerequisites_met(id):
		return NodeState.LOCKED
	return NodeState.BUYABLE if available_points() >= _by_id[id].cost else NodeState.UNAFFORDABLE


## True when [param id] is known, not bought, has its prerequisites and costs no more than the
## available points.
func can_buy(id: String) -> bool:
	return _by_id.has(id) and state_of(id) == NodeState.BUYABLE


## Buys [param id]. Returns false and changes nothing when [method can_buy] is false.
## Emits [signal changed] on success.
func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	_permanent.talents[id] = 1
	changed.emit()
	return true


## Free reset: removes every bought node, giving all the spent points back. Possible at any
## time. Returns the number of points given back (0 and no signal when nothing was bought).
## Emits [signal changed] when something was bought.
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


## Factor the bought nodes give to [param stat] (one of [constant STATS]), as a decimal
## string: "1" when there is none, else "1.40" for +40%. Percentages of the same stat add up.
func factor(stat: String) -> String:
	var percent: int = 0
	for def: TalentDef in _nodes:
		if def.stat == stat and is_owned(def.id):
			percent += def.percent
	if percent == 0:
		return "1"
	@warning_ignore("integer_division")
	return "%d.%02d" % [1 + percent / 100, percent % 100]


## Pushes the factors to [param floors] (see [method FloorManager.set_talent_modifiers]) and
## to [param offline] (see [method OfflineIncome.set_talent_factor]).
func apply_to(floors: FloorManager, offline: OfflineIncome) -> void:
	floors.set_talent_modifiers(factor(STAT_CLICK_DAMAGE), factor(STAT_COMPANION_DAMAGE), factor(STAT_GOLD))
	offline.set_talent_factor(factor(STAT_OFFLINE_GOLD))


func _load(data: Variant) -> void:
	if not data is Dictionary:
		_error = "talents.json is missing or not an object"
		return
	var d: Dictionary = data
	if _read_int(d.get("schema_version"), 0) != SUPPORTED_SCHEMA:
		_error = "talents.json: unsupported schema_version (expected %d)" % SUPPORTED_SCHEMA
		return
	_stages_per_point = _read_int(d.get("stages_per_point"), 0)
	if _stages_per_point < 1:
		_stages_per_point = 1  # keeps earned_points() dividing by a valid number
		_error = "talents.json: 'stages_per_point' must be an integer >= 1"
		return
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
		var def: TalentDef = _read_node(entry)
		if def == null:
			return
		_by_id[def.id] = def
		_nodes.append(def)


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
func _read_node(entry: Dictionary) -> TalentDef:
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
	var effect: Variant = entry.get("effect")
	var stat: Variant = (effect as Dictionary).get("stat") if effect is Dictionary else null
	if not (stat is String and STATS.has(stat)):
		_error = "talents.json: node '%s': 'effect.stat' must be one of %s" % [def.id, str(STATS)]
		return null
	def.stat = stat
	def.percent = _read_int((effect as Dictionary).get("percent"), 0)
	if def.percent < 1:
		_error = "talents.json: node '%s': 'effect.percent' must be an integer >= 1" % def.id
		return null
	return def


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
