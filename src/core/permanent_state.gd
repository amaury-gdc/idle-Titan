class_name PermanentState
extends RefCounted
## State that survives run resets: talent points/ranks and (later) artifacts.
## Saved separately from [GameState].
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
const CURRENT_VERSION: int = 1

## Unspent talent points.
var talent_points: int = 0
## Talent id (String) -> rank (int).
var talents: Dictionary = {}
## Reserved for post-V1 artifacts; stored untouched.
var artifacts: Array = []


## JSON-safe payload including the format version.
func to_dict() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"talent_points": talent_points,
		"talents": talents.duplicate(),
		"artifacts": artifacts.duplicate(),
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
	var a: Variant = data.get("artifacts", [])
	if a is Array:
		state.artifacts = a.duplicate()
	return state
