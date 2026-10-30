class_name GameState
extends RefCounted
## Per-run state: current stage (floor), gold and companion levels.
## Reset on a new run; never holds or touches [PermanentState].
##
## Usage:
## [codeblock]
## var state := GameState.new()
## state.gold = state.gold.add(BigNumber.from_int(50))
## var restored := GameState.from_dict(state.to_dict())
## [/codeblock]

## Current stage (floor, the score). Starts at 1.
var stage: int = 1
## Gold on hand.
var gold: BigNumber = BigNumber.new()
## Companion id (String) -> level (int). Absent id means not bought.
var companion_levels: Dictionary = {}


## Returns the state to a fresh run.
func reset() -> void:
	stage = 1
	gold = BigNumber.new()
	companion_levels = {}


## JSON-safe payload (gold as decimal string).
func to_dict() -> Dictionary:
	return {
		"stage": stage,
		"gold": gold.to_decimal_string(),
		"companion_levels": companion_levels.duplicate(),
	}


## Builds a state from a payload; missing or invalid fields fall back to defaults.
static func from_dict(data: Dictionary) -> GameState:
	var state := GameState.new()
	var s: Variant = data.get("stage", 1)
	if s is float or s is int:
		state.stage = maxi(int(s), 1)
	var g: Variant = data.get("gold", "0")
	if g is String:
		var parsed: BigNumber = BigNumber.from_string(g)
		if parsed != null:
			state.gold = parsed
	var levels: Variant = data.get("companion_levels", {})
	if levels is Dictionary:
		for id: Variant in levels:
			var lvl: Variant = levels[id]
			if id is String and (lvl is float or lvl is int):
				state.companion_levels[id] = maxi(int(lvl), 0)
	return state
