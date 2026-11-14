class_name PermanentState
extends RefCounted
## State that survives run resets: talents, the stage record that earns their points,
## player preferences and (later) artifacts. Saved separately from [GameState].
##
## Versioning: [constant CURRENT_VERSION] is written on save. from_dict() reads
## every known field with a default and ignores unknown keys, so adding a field
## later (bump the version, default it in from_dict) never breaks older saves.
##
## Usage:
## [codeblock]
## var perm := PermanentState.new()
## perm.talent_points = 3
## var restored := PermanentState.from_dict(perm.to_dict())
## [/codeblock]

## Save-format version written by this build.
const CURRENT_VERSION: int = 7

## Unused since version 4, kept so that older saves keep their value: spent points are
## derived from [member talents] and their costs, earned points from
## [member best_stage_record] (see [TalentTree]).
var talent_points: int = 0
## Talent id (String) -> rank (int); a bought node has rank 1 (story 006). Ids that the
## talent data no longer knows are kept untouched and ignored by [TalentTree].
var talents: Dictionary = {}
## Highest stage ever reached, across runs (story 006). [member GameState.max_stage_reached]
## is reset with the run, but the talents it paid for are not: this record, raised by
## [method TalentTree.sync_best_stage] and never lowered, keeps the earned points above
## the spent ones after a reset. Added in version 4; 0 means unknown.
var best_stage_record: int = 0
## Reserved for post-V1 artifacts; stored untouched.
var artifacts: Array = []
## Player preference "Défi automatique" (story 004): a kill in farm mode starts the
## boss by itself when it can be beaten. Off by default; added in version 2. See
## [FloorManager].
var auto_challenge: bool = false
## True once the message of the first failed boss was shown (story 004): it appears
## only once per player. Added in version 3.
var boss_hint_shown: bool = false
## The bag of the [Inventory] (story 007): items owned and not equipped, in order of arrival.
## Permanent, so it survives [method GameState.reset] like the talents. Added in version 5;
## older saves have none. Items unknown to the current data are kept and ignored.
var inventory_items: Array[Item] = []
## The equipped items of the [Inventory], type id (String) -> [Item]; at most one per type.
## Not counted in the bag. Added in version 5.
var equipped_items: Dictionary = {}
## The talents.json [code]tree_version[/code] whose message the player acknowledged (story 018, see
## [method TalentTree.apply_tree_version]). Added in version 6; older saves have 0, so the first
## versioned tree hands their points back once.
var talent_tree_seen: int = 0
## Real time of the last talent reset, in Unix seconds, start of the reset wait (story 018, see
## [method TalentTree.try_reset]). Added in version 6; 0 means none, and so does a negative,
## non-numeric or absurd value.
var talent_reset_unix: int = 0
## The core_curves.json [code]balance_version[/code] whose message the player saw, or that did not
## concern them (story 020, see [BalanceNotice]). Added in version 7; older saves have 0.
var balance_seen: int = 0


## JSON-safe payload including the format version.
func to_dict() -> Dictionary:
	var bag: Array = []
	for item: Item in inventory_items:
		bag.append(item.to_dict())
	var worn: Dictionary = {}
	for type_id: Variant in equipped_items:
		worn[type_id] = (equipped_items[type_id] as Item).to_dict()
	return {
		"version": CURRENT_VERSION,
		"talent_points": talent_points,
		"talents": talents.duplicate(),
		"best_stage_record": best_stage_record,
		"artifacts": artifacts.duplicate(),
		"auto_challenge": auto_challenge,
		"boss_hint_shown": boss_hint_shown,
		"inventory": bag,
		"equipped": worn,
		"talent_tree_seen": talent_tree_seen,
		"talent_reset_unix": talent_reset_unix,
		"balance_seen": balance_seen,
	}


## Builds a state from a payload of any older/newer version; unknown or invalid
## fields are ignored/defaulted.
static func from_dict(data: Dictionary) -> PermanentState:
	var state := PermanentState.new()
	var tp: Variant = data.get("talent_points", 0)
	if tp is float or tp is int:
		state.talent_points = maxi(int(tp), 0)
	var t: Variant = data.get("talents", {})
	if t is Dictionary:
		for id: Variant in t:
			var rank: Variant = t[id]
			if id is String and (rank is float or rank is int):
				state.talents[id] = maxi(int(rank), 0)
	var record: Variant = data.get("best_stage_record", 0)
	if record is float or record is int:
		state.best_stage_record = maxi(int(record), 0)
	var a: Variant = data.get("artifacts", [])
	if a is Array:
		state.artifacts = a.duplicate()
	var auto: Variant = data.get("auto_challenge", false)
	if auto is bool:
		state.auto_challenge = auto
	var hint: Variant = data.get("boss_hint_shown", false)
	if hint is bool:
		state.boss_hint_shown = hint
	# Talent tree version and reset (version 6).
	var tree_seen: Variant = data.get("talent_tree_seen", 0)
	if (tree_seen is float or tree_seen is int) and float(tree_seen) > 0.0 and float(tree_seen) <= GameState.MAX_SAVED_UNIX:
		state.talent_tree_seen = int(tree_seen)
	var reset_at: Variant = data.get("talent_reset_unix", 0)
	if (reset_at is float or reset_at is int) and float(reset_at) > 0.0 and float(reset_at) <= GameState.MAX_SAVED_UNIX:
		state.talent_reset_unix = int(reset_at)
	# Balance version seen (version 7).
	var balance: Variant = data.get("balance_seen", 0)
	if (balance is float or balance is int) and float(balance) > 0.0 and float(balance) <= GameState.MAX_SAVED_UNIX:
		state.balance_seen = int(balance)
	# Items (version 5). A malformed item, a repeated uid or an equipped item filed under
	# another type than its own is dropped, so a uid always names one item.
	var seen: Dictionary = {}
	var bag: Variant = data.get("inventory", [])
	if bag is Array:
		for entry: Variant in bag:
			var item: Item = Item.from_dict(entry)
			if item != null and not seen.has(item.uid):
				seen[item.uid] = true
				state.inventory_items.append(item)
	var worn: Variant = data.get("equipped", {})
	if worn is Dictionary:
		for type_id: Variant in worn:
			var item: Item = Item.from_dict(worn[type_id])
			if item != null and type_id is String and item.type == type_id and not seen.has(item.uid):
				seen[item.uid] = true
				state.equipped_items[type_id] = item
	return state
