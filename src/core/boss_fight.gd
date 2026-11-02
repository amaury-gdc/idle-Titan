class_name BossFight
extends RefCounted
## Boss data (boss_curves.json), boss formulas and the boss countdown. Holds no
## run state beyond the countdown itself; [FloorManager] drives it.
## Implements design/game-brief.md "Core loop" and "Player goal & fail state"
## (story 004). No Node, no Timer and no UI reference: time is fed through
## [method tick], like [CompanionManager], so a headless simulation drives it
## exactly like the game does.
##
## RETRY RULE (decided in story 004): FARM MODE AND CHALLENGE. When the countdown
## runs out the player falls back to the previous stage and farms it for as long as
## they want, then challenges the boss again (button, or the "auto challenge"
## setting). [FloorManager] applies that rule, see its class comment; this class
## only says when the countdown is over. Nothing about a running fight is saved.
##
## Formulas (stage >= 1, BigNumber-exact):
## [codeblock]
## is_boss_stage(S) = (S % boss_every_stages == 0)
## boss_max_hp      = floor(normal enemy HP of the stage * boss_hp_multiplier)    (at least 1)
## boss_gold(S)     = boss_gold_base * boss_gold_growth^(S - 1)                   (see [GrowthCurve])
## [/codeblock]
##
## Single-thread only. Build with [method from_data] and check [method is_valid].
## [code]BossFight.new()[/code] is a valid "no boss at all" instance (no stage is a
## boss stage); it is what [FloorManager] uses when none is injected.
##
## Usage:
## [codeblock]
## var boss: BossFight = BossFight.from_data(
##         DataLoader.load_json("res://assets/data/boss_curves.json"))
## if boss.is_valid():
##     if boss.is_boss_stage(10):
##         var hp: BigNumber = boss.boss_max_hp(combat.enemy_max_hp(10))
##         boss.begin()                  # countdown starts (full duration)
##     var expired: bool = boss.tick(delta)   # every frame while the fight lasts
## else:
##     push_error(boss.get_error())
## [/codeblock]

## Version of boss_curves.json this code understands.
const SUPPORTED_SCHEMA: int = 3
## Largest [param delta] one [method tick] call honors, in seconds. A longer frame
## (tab in the background, debugger pause) is cut to this, so a stall cannot eat
## the whole countdown at once. Same bound as [constant CompanionManager.MAX_TICK_SECONDS];
## infrastructure safety bound, not balance.
const MAX_TICK_SECONDS: float = 5.0
## Largest accepted boss_every_stages (keeps the modulo well defined; not balance).
const MAX_EVERY_STAGES: int = 2147483647

var _error: String = ""
## 0 means "no boss stage" (only for [code]BossFight.new()[/code]; from_data requires >= 2).
var _every_stages: int = 0
var _timer_seconds: float = 0.0
## Seconds the talents add to every fight (story 019), 0 for none.
var _bonus_seconds: float = 0.0
var _hp_multiplier: String = "1"
var _gold_base: BigNumber = BigNumber.new()
var _gold_growth: String = "1"
var _challenge_margin: String = "1"
var _active: bool = false
var _time_left: float = 0.0


## Parses and validates boss_curves.json (as returned by [method DataLoader.load_json],
## null allowed). Always returns an instance; check [method is_valid].
static func from_data(data: Variant) -> BossFight:
	var fight: BossFight = BossFight.new()
	fight._load(data)
	return fight


## True when the data parsed cleanly.
func is_valid() -> bool:
	return _error.is_empty()


## First validation problem found, or "" when valid.
func get_error() -> String:
	return _error


## True when [param stage] holds a boss (every boss_every_stages-th stage).
## Always false for stages below 1 and for [code]BossFight.new()[/code].
func is_boss_stage(stage: int) -> bool:
	return _every_stages > 0 and stage >= 1 and stage % _every_stages == 0


## Boss HP for a stage whose normal enemy has [param enemy_hp] HP
## (see [method Combat.enemy_max_hp]): floored product with boss_hp_multiplier. Never zero.
func boss_max_hp(enemy_hp: BigNumber) -> BigNumber:
	var hp: BigNumber = enemy_hp.multiply_decimal(_hp_multiplier)
	return hp if not hp.is_zero() else BigNumber.from_int(1)


## Gold granted for killing the boss at [param stage] (values below 1 are treated as 1).
func boss_gold(stage: int) -> BigNumber:
	return GrowthCurve.value_at(_gold_base, _gold_growth, maxi(stage, 1) - 1)


## Boss HP the estimated damage must cover before "Défi automatique" challenges:
## [param boss_hp] times auto_challenge_margin. The estimate is optimistic (attacks
## land on whole intervals), so without this margin a narrow estimate fails each time.
func safe_boss_hp(boss_hp: BigNumber) -> BigNumber:
	return boss_hp.multiply_decimal(_challenge_margin)


## Duration of one boss fight, in seconds: the data plus [method set_bonus_seconds] (0 for
## [code]BossFight.new()[/code] without bonus).
func timer_seconds() -> float:
	return _timer_seconds + _bonus_seconds


## Adds [param seconds] (>= 0, story 019 "Sursis") to the countdown of every fight that begins from now
## on; the saved data is untouched. A running fight keeps the time it has, cut to the new duration if
## that is shorter.
func set_bonus_seconds(seconds: float) -> void:
	_bonus_seconds = maxf(seconds, 0.0)
	_time_left = minf(_time_left, timer_seconds())


## True while a boss fight is running (between [method begin] and the end of the countdown or [method stop]).
func is_active() -> bool:
	return _active


## Seconds left in the current fight (0 when none is running).
func time_left() -> float:
	return _time_left


## Starts a fight: full countdown. Calling it again restarts the countdown.
func begin() -> void:
	_active = true
	_time_left = timer_seconds()


## Ends the fight without expiry (boss killed, or the stage is not a boss stage).
func stop() -> void:
	_active = false
	_time_left = 0.0


## Advances the countdown by [param delta] seconds (clamped to 0..[constant MAX_TICK_SECONDS]).
## Does nothing and returns false while no fight is running (the countdown never
## runs outside a boss fight). Returns true exactly once, on the call where the
## countdown reaches zero; the fight is then over ([method is_active] is false).
func tick(delta: float) -> bool:
	if not _active:
		return false
	_time_left = maxf(_time_left - clampf(delta, 0.0, MAX_TICK_SECONDS), 0.0)
	if _time_left > 0.0:
		return false
	_active = false
	return true


func _load(data: Variant) -> void:
	if not data is Dictionary:
		_error = "boss_curves.json is missing or not an object"
		return
	var d: Dictionary = data
	var v: Variant = d.get("schema_version")
	if not (v is int or v is float) or int(v) != SUPPORTED_SCHEMA:
		_error = "boss_curves.json: unsupported schema_version (expected %d)" % SUPPORTED_SCHEMA
		return
	_every_stages = _read_every_stages(d)
	_timer_seconds = _read_timer_seconds(d)
	_hp_multiplier = _read_factor(d, "boss_hp_multiplier")
	_gold_base = _read_big(d, "boss_gold_base")
	_gold_growth = _read_factor(d, "boss_gold_growth")
	_challenge_margin = _read_factor(d, "auto_challenge_margin")


func _read_every_stages(data: Dictionary) -> int:
	var v: Variant = data.get("boss_every_stages")
	if (v is int or v is float) and float(v) == floorf(float(v)) \
			and float(v) >= 2.0 and float(v) <= float(MAX_EVERY_STAGES):
		return int(v)
	_fail("boss_curves.json: 'boss_every_stages' must be an integer >= 2")
	return 0


func _read_timer_seconds(data: Dictionary) -> float:
	var v: Variant = data.get("timer_seconds")
	if (v is int or v is float) and float(v) > 0.0 and is_finite(float(v)):
		return float(v)
	_fail("boss_curves.json: 'timer_seconds' must be a number > 0")
	return 0.0


func _read_big(data: Dictionary, key: String) -> BigNumber:
	var v: Variant = data.get(key)
	if v is String:
		var parsed: BigNumber = BigNumber.from_string(v)
		if parsed != null:
			return parsed
	_fail("boss_curves.json: '%s' must be a digit string" % key)
	return BigNumber.new()


func _read_factor(data: Dictionary, key: String) -> String:
	var v: Variant = data.get(key)
	if v is String and GrowthCurve.is_valid_factor(v):
		return v
	_fail("boss_curves.json: '%s' must be a decimal string such as \"1.3\"" % key)
	return "1"


# Keeps the first error only.
func _fail(message: String) -> void:
	if _error.is_empty():
		_error = message
