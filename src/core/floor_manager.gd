class_name FloorManager
extends RefCounted
## One enemy per stage: tracks the current enemy's HP, applies damage, and on
## death grants gold and starts the next stage. Stage and gold live in the
## injected [GameState]; the numbers come from the injected [Combat].
## Implements design/game-brief.md "Core loop" (story 002). No UI references:
## the UI listens to the signals.
##
## The current enemy's HP is NOT saved: after a load, the enemy of the saved
## stage starts at full HP. Overkill damage is discarded (no carry-over).
## Single-thread only.
##
## Usage:
## [codeblock]
## var floors: FloorManager = FloorManager.new(game_state, combat)
## floors.enemy_killed.connect(func(stage: int, gold: BigNumber) -> void: print(stage, gold.format()))
## floors.click()   # a player click; story 003 auto-attacks call apply_damage()
## [/codeblock]

## The enemy took damage and survived. [param remaining_hp] is its HP now.
signal enemy_damaged(damage: BigNumber, remaining_hp: BigNumber)
## The enemy of [param stage] died; [param gold_reward] was already added to the
## state, and GameState.stage already points at the next stage.
signal enemy_killed(stage: int, gold_reward: BigNumber)
## The next stage began after a kill. Not emitted for the first stage after
## construction (read [method current_stage] and [method max_hp] instead).
signal stage_started(stage: int, max_hp: BigNumber)

var _state: GameState
var _combat: Combat
var _max_hp: BigNumber
var _current_hp: BigNumber


## [param state] and [param combat] are required; [param combat] must be valid.
## The enemy of state.stage is spawned at full HP. No signal is emitted.
func _init(state: GameState, combat: Combat) -> void:
	_state = state
	_combat = combat
	_spawn_enemy()


## Current stage (same as the state's stage; this is the score).
func current_stage() -> int:
	return _state.stage


## Current enemy HP.
func current_hp() -> BigNumber:
	return _current_hp


## Current enemy max HP.
func max_hp() -> BigNumber:
	return _max_hp


## Damage a click deals right now (base + companion share).
func click_damage() -> BigNumber:
	return _combat.click_damage(_state.companion_levels)


## Enemy HP as a ratio 0.0..1.0 with 1/1000 resolution, exact for any HP size
## (BigNumber division, no float on big values). Meant for a progress bar.
func hp_ratio() -> float:
	var permille: BigNumber = _current_hp.multiply(BigNumber.from_int(1000)).divide(_max_hp)
	return float(permille.to_decimal_string().to_int()) / 1000.0


## A player click: deals [method click_damage] to the enemy. Returns the damage dealt.
func click() -> BigNumber:
	var damage: BigNumber = click_damage()
	apply_damage(damage)
	return damage


## Deals [param damage] to the current enemy. If it dies: gold is granted, the
## next stage starts with a fresh enemy, then [signal enemy_killed] and
## [signal stage_started] are emitted (state already consistent).
func apply_damage(damage: BigNumber) -> void:
	if damage.compare(_current_hp) < 0:
		_current_hp = _current_hp.subtract(damage)
		enemy_damaged.emit(damage, _current_hp)
		return
	var killed_stage: int = _state.stage
	var reward: BigNumber = _combat.gold_per_kill(killed_stage)
	_state.gold = _state.gold.add(reward)
	_state.stage = killed_stage + 1
	_state.max_stage_reached = maxi(_state.max_stage_reached, _state.stage)
	_spawn_enemy()
	enemy_killed.emit(killed_stage, reward)
	stage_started.emit(_state.stage, _max_hp)


func _spawn_enemy() -> void:
	_max_hp = _combat.enemy_max_hp(_state.stage)
	_current_hp = _max_hp
