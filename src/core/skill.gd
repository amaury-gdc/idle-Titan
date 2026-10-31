class_name Skill
extends RefCounted
## One active skill: its definition (one entry of skills.json, schema 1, see
## assets/data/data_schema.md) and its two timers. Implements design/game-brief.md
## MVP feature 5 "Compétences actives" (story 005).
## Pure logic: no Node, no clock, no UI. [SkillManager] owns the skills and drives them.
##
## Timers (seconds of game time, fed by [method tick]):
## [codeblock]
## READY     cooldown_left == 0
## ACTIVE    active_left > 0        (a buff running; its cooldown runs at the same time)
## COOLDOWN  cooldown_left > 0 and active_left == 0
## [/codeblock]
## The cooldown starts at activation and includes the effect duration, so a 15 s buff with
## a 90 s cooldown is back after 90 s, not 105 s. The data guarantees cooldown >= duration.
## A burst has no duration: it goes straight from READY to COOLDOWN.
##
## Single-thread only. Build with [method from_entry] and check [method is_valid].
##
## Usage:
## [codeblock]
## var skill: Skill = Skill.from_entry(entry)
## if skill.is_valid() and skill.state() == Skill.State.READY:
##     skill.start(60.0)             # SkillManager passes the cooldown with modifiers applied
## skill.tick(0.1)
## print(skill.cooldown_left())
## [/codeblock]

## What a skill does when activated.
enum Effect {
	## Immediate damage.
	BURST,
	## Multiplies all damage dealt while it lasts.
	DAMAGE_MULTIPLIER,
	## Multiplies the gold earned by kills while it lasts.
	GOLD_MULTIPLIER,
}

## Where a skill is in its cycle.
enum State {
	## Can be activated.
	READY,
	## Its effect is running.
	ACTIVE,
	## Its effect is over (or it is a burst) and it recharges.
	COOLDOWN,
}

## Value of the "effect" key in skills.json -> [enum Effect].
const EFFECT_BY_NAME: Dictionary = {
	"burst": Effect.BURST,
	"damage_multiplier": Effect.DAMAGE_MULTIPLIER,
	"gold_multiplier": Effect.GOLD_MULTIPLIER,
}

## Stable id (unique in the file); the key used in [member GameState.skill_timers].
var id: String = ""
## Display name (French, passed to the UI as is).
var display_name: String = ""
## What the skill does.
var effect: Effect = Effect.BURST
## Strength as a decimal string: seconds of damage for a burst ("dps_seconds" in the
## data, see [method SkillManager.burst_damage]), factor for a buff ("multiplier").
var amount: String = "1"
## Seconds the effect lasts (0 for a burst).
var duration_seconds: float = 0.0
## Base recharge in seconds, before any modifier (always >= [member duration_seconds]).
var cooldown_seconds: float = 1.0

var _error: String = ""
var _cooldown_left: float = 0.0
var _active_left: float = 0.0


## Parses and validates one skills.json entry. Always returns an instance; check [method is_valid].
static func from_entry(entry: Dictionary) -> Skill:
	var skill: Skill = Skill.new()
	skill._load(entry)
	return skill


## True when the entry parsed cleanly.
func is_valid() -> bool:
	return _error.is_empty()


## First validation problem found, or "" when valid.
func get_error() -> String:
	return _error


## Where the skill is in its cycle.
func state() -> State:
	if _active_left > 0.0:
		return State.ACTIVE
	if _cooldown_left > 0.0:
		return State.COOLDOWN
	return State.READY


## Seconds before the skill can be used again (0 when ready).
func cooldown_left() -> float:
	return _cooldown_left


## Seconds of effect left (0 when none is running).
func active_left() -> float:
	return _active_left


## Starts the skill: its cooldown becomes [param cooldown] and, for a buff, the effect
## runs for [member duration_seconds]. The caller checks the state is READY first.
func start(cooldown: float) -> void:
	_cooldown_left = maxf(cooldown, duration_seconds)
	_active_left = duration_seconds


## Advances both timers by [param step] seconds (already clamped by the caller). Returns
## true on the call where a running effect ends.
func tick(step: float) -> bool:
	var ended: bool = false
	if _active_left > 0.0:
		_active_left = maxf(_active_left - step, 0.0)
		ended = _active_left <= 0.0
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - step, 0.0)
	return ended


## Puts the timers back from a save. Values are cut to what the data allows (a retuned
## file never leaves a timer longer than its new maximum), negatives and NaN count as 0,
## and the effect never outlasts the cooldown.
func restore(cooldown_left_value: float, active_left_value: float) -> void:
	_cooldown_left = clampf(cooldown_left_value, 0.0, cooldown_seconds) if is_finite(cooldown_left_value) else 0.0
	_active_left = clampf(active_left_value, 0.0, minf(duration_seconds, _cooldown_left)) if is_finite(active_left_value) else 0.0


func _load(entry: Dictionary) -> void:
	var raw_id: Variant = entry.get("id")
	if not (raw_id is String and not (raw_id as String).is_empty()):
		_error = "skills.json: each skill needs a non-empty 'id'"
		return
	id = raw_id
	var raw_name: Variant = entry.get("name")
	if not (raw_name is String and not (raw_name as String).is_empty()):
		_error = "skills.json: skill '%s' needs a non-empty 'name'" % id
		return
	display_name = raw_name
	var raw_effect: Variant = entry.get("effect")
	if not (raw_effect is String and EFFECT_BY_NAME.has(raw_effect)):
		_error = "skills.json: skill '%s': 'effect' must be one of %s" % [id, str(EFFECT_BY_NAME.keys())]
		return
	effect = EFFECT_BY_NAME[raw_effect]
	if effect == Effect.BURST:
		if not _read_amount(entry, "dps_seconds", 0.0):
			return
	else:
		if not _read_amount(entry, "multiplier", 1.0):
			return
		var duration: Variant = entry.get("duration_seconds")
		if not _is_positive_number(duration):
			_error = "skills.json: skill '%s': 'duration_seconds' must be a number > 0" % id
			return
		duration_seconds = float(duration)
	var cooldown: Variant = entry.get("cooldown_seconds")
	if not _is_positive_number(cooldown):
		_error = "skills.json: skill '%s': 'cooldown_seconds' must be a number > 0" % id
		return
	cooldown_seconds = float(cooldown)
	if cooldown_seconds < duration_seconds:
		_error = "skills.json: skill '%s': 'cooldown_seconds' must be >= 'duration_seconds'" % id


# Reads a decimal string in [param key], which must be above [param min_value]. A buff of
# exactly 1 is refused: the damage floor of FloorManager.buffed_damage would turn it into +1.
func _read_amount(entry: Dictionary, key: String, min_value: float) -> bool:
	var raw: Variant = entry.get(key)
	if raw is String and GrowthCurve.is_valid_factor(raw) and (raw as String).to_float() > min_value:
		amount = raw
		return true
	_error = "skills.json: skill '%s': '%s' must be a decimal string > %s" % [id, key, str(min_value)]
	return false


func _is_positive_number(value: Variant) -> bool:
	return (value is int or value is float) and float(value) > 0.0 and is_finite(float(value))
