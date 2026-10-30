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
## Highest stage reached this run (the score); never below [member stage] and kept
## when [member stage] goes back down (story 004 boss fallback). A stage counts as
## reached as soon as its fight begins, boss included (see [FloorManager]).
var max_stage_reached: int = 1
## True in farm mode after a failed boss: kills respawn the same stage until the
## boss is challenged (story 004, see [FloorManager]). Saved, so a reload stays in it.
var farming: bool = false
## Gold on hand.
var gold: BigNumber = BigNumber.new()
## Companion id (String) -> level (int). Absent id means not bought.
var companion_levels: Dictionary = {}
## Real time of the last save, in Unix seconds (story 004b, brief "Hors-ligne"). 0 means
## unknown: a fresh state or a save written before this field existed, which earns no
## offline gold. Stamped by [SaveManager] on every save and read by [OfflineIncome].
var last_saved_unix: int = 0

## Largest saved time accepted: 2^53, the limit of exact integers in a JSON number
## (a float). Anything above is a corrupt value and is read as "unknown".
const MAX_SAVED_UNIX: float = 9007199254740992.0


## Returns the state to a fresh run.
func reset() -> void:
	stage = 1
	max_stage_reached = 1
	farming = false
	gold = BigNumber.new()
	companion_levels = {}
	last_saved_unix = 0


## JSON-safe payload (gold as decimal string).
func to_dict() -> Dictionary:
	return {
		"stage": stage,
		"max_stage_reached": max_stage_reached,
		"farming": farming,
		"gold": gold.to_decimal_string(),
		"companion_levels": companion_levels.duplicate(),
		"last_saved_unix": last_saved_unix,
	}


## Builds a state from a payload; missing or invalid fields fall back to defaults.
## A save without max_stage_reached (older format) defaults it to the saved stage;
## one without farming defaults it to false; one without last_saved_unix (or with a
## negative, non-numeric or absurd value) defaults it to 0 and stays valid.
static func from_dict(data: Dictionary) -> GameState:
	var state := GameState.new()
	var s: Variant = data.get("stage", 1)
	if s is float or s is int:
		state.stage = maxi(int(s), 1)
	state.max_stage_reached = state.stage
	var m: Variant = data.get("max_stage_reached", state.stage)
	if m is float or m is int:
		state.max_stage_reached = maxi(int(m), state.stage)
	var f: Variant = data.get("farming", false)
	if f is bool:
		state.farming = f
	var g: Variant = data.get("gold", "0")
	if g is String:
		var parsed: BigNumber = BigNumber.from_string(g)
		if parsed != null:
			state.gold = parsed
	var saved_at: Variant = data.get("last_saved_unix", 0)
	if (saved_at is float or saved_at is int) and float(saved_at) > 0.0 and float(saved_at) <= MAX_SAVED_UNIX:
		state.last_saved_unix = int(saved_at)
	var levels: Variant = data.get("companion_levels", {})
	if levels is Dictionary:
		for id: Variant in levels:
			var lvl: Variant = levels[id]
			if id is String and (lvl is float or lvl is int):
				state.companion_levels[id] = maxi(int(lvl), 0)
	return state
