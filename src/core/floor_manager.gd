class_name FloorManager
extends RefCounted
## One enemy per stage: tracks the current enemy's HP, applies damage, and on
## death grants gold and starts the next stage. Stage and gold live in the
## injected [GameState]; the numbers come from the injected [Combat], and from
## the injected [BossFight] on boss stages.
## Implements design/game-brief.md "Core loop" (story 002) and the boss fight with
## its fallback (story 004). No UI references: the UI listens to the signals.
##
## Boss stages (story 004): on a boss stage the enemy is the boss (HP and gold from
## [BossFight]) and a countdown starts when that stage begins. Killing the boss
## before it ends moves to the next stage as usual. When it runs out, the stage goes
## back by one (boss at stage 10 -> stage 9) with a fresh enemy, in farm mode.
## RETRY RULE: FARM MODE AND CHALLENGE. In farm mode ([member GameState.farming],
## saved) a kill grants gold and respawns an enemy of the same stage, with no stage
## advance, for as long as the player wants. [method challenge_boss] (the "Défier le
## boss" button) leaves farm mode and starts the boss of the next stage at full HP
## with a full countdown; failing again returns to farm mode. Giving up
## ([method abandon_boss], the "Abandonner le boss" button) counts as a failed fight:
## same fallback, same signals. With the "Défi
## automatique" setting ([member PermanentState.auto_challenge], off by default) a
## kill in farm mode does the same by itself, but only when
## [method can_beat_next_boss] says the estimated damage covers the boss; otherwise
## the player keeps farming.
## Fallback below stage 1 cannot happen: boss_every_stages is >= 2, so the first
## boss stage is >= 2 and its fallback stage is >= 1 (a boss at stage 2 falls back to 1).
## A loaded save that says farming while the next stage is not a boss stage (the boss
## data changed) has its flag cleared at construction, and normal progression goes on.
##
## "Reached": a stage counts as reached (GameState.max_stage_reached, the score) as
## soon as its fight begins, boss included. Reaching stage 10 (its boss appears)
## scores 10 even if the boss is never beaten. The record is never lowered by a
## fallback.
##
## Order inside one frame: damage (clicks, companion attacks) is applied first, then
## [method tick] advances the countdown. A boss killed by the damage of a frame is
## therefore killed even when that same frame's delta would have run the countdown
## out; the expiry is only checked afterwards, against the stage the player is on.
## The main screen calls [method CompanionManager.tick] before [method tick].
##
## The current enemy's HP and the countdown are NOT saved: after a load, the enemy of
## the saved stage (the boss, on a boss stage) starts at full HP with a fresh
## countdown. Overkill damage is discarded (no carry-over). Single-thread only.
##
## Usage:
## [codeblock]
## var boss: BossFight = BossFight.from_data(DataLoader.load_json("res://assets/data/boss_curves.json"))
## var floors: FloorManager = FloorManager.new(game_state, combat, boss, permanent_state)
## floors.enemy_killed.connect(func(stage: int, gold: BigNumber) -> void: print(stage, gold.format()))
## floors.boss_failed.connect(func(failed: int, back_to: int) -> void: print(failed, back_to))
## floors.click()      # a player click; story 003 auto-attacks call apply_damage()
## floors.tick(delta)  # every frame, after the companions' attacks
## if floors.is_farming():
##     floors.challenge_boss()   # the "Défier le boss" button
## [/codeblock]

## The enemy took damage and survived. [param remaining_hp] is its HP now.
signal enemy_damaged(damage: BigNumber, remaining_hp: BigNumber)
## The enemy of [param stage] died; [param gold_reward] was already added to the
## state, and GameState.stage already points at the next stage (it stays on
## [param stage] for a kill that farm mode respawns).
signal enemy_killed(stage: int, gold_reward: BigNumber)
## A new enemy began: next stage after a kill, boss fallback, farm mode respawn
## (same [param stage]) or boss challenge. It is already spawned at full HP. Not
## emitted for the first stage after construction (read [method current_stage] and
## [method max_hp] instead).
signal stage_started(stage: int, max_hp: BigNumber)
## A boss fight began at [param stage] with [param seconds] on the countdown. Emitted
## after [signal stage_started]. Not emitted after construction (read [method is_boss_fight]).
signal boss_started(stage: int, seconds: float)
## The countdown of the boss at [param failed_stage] ran out; the player is now on
## [param fallback_stage] in farm mode (state already consistent). Emitted before
## [signal farming_changed] and [signal stage_started].
signal boss_failed(failed_stage: int, fallback_stage: int)
## Farm mode was entered or left; [param farming] is the new value. Emitted before
## [signal stage_started]. Not emitted after construction (read [method is_farming]).
signal farming_changed(farming: bool)

var _state: GameState
var _combat: Combat
var _boss: BossFight
var _permanent: PermanentState
var _max_hp: BigNumber
var _current_hp: BigNumber
## Gold of the current enemy, computed once per spawn: farm mode kills many enemies
## per second and the curves are too costly to recompute for each ([GrowthCurve]).
var _reward: BigNumber
## HP the estimate must cover for the boss farm mode leads to, margin included,
## computed once per fallback for the same reason.
var _safe_boss_hp: BigNumber = BigNumber.new()
## Player's click damage per second, for [method can_beat_next_boss].
var _click_dps: BigNumber = BigNumber.new()


## [param state] and [param combat] are required; [param combat] must be valid.
## [param boss] must be valid when given; without it no stage is a boss stage.
## [param permanent] holds the auto challenge setting; without it the setting starts
## off and is not kept. The enemy of state.stage is spawned at full HP (the boss, with
## a fresh countdown, on a boss stage). No signal is emitted.
func _init(state: GameState, combat: Combat, boss: BossFight = null, permanent: PermanentState = null) -> void:
	_state = state
	_combat = combat
	_boss = boss if boss != null else BossFight.new()
	_permanent = permanent if permanent != null else PermanentState.new()
	if not _boss.is_boss_stage(_state.stage + 1):
		_state.farming = false
	_spawn_enemy()
	if _state.farming:
		_update_safe_boss_hp()


## Current stage (same as the state's stage).
func current_stage() -> int:
	return _state.stage


## Best stage reached (the score): [member GameState.max_stage_reached], kept after a fallback.
func best_stage() -> int:
	return _state.max_stage_reached


## Current enemy HP.
func current_hp() -> BigNumber:
	return _current_hp


## Current enemy max HP.
func max_hp() -> BigNumber:
	return _max_hp


## True while the current enemy is a boss and its countdown is running.
func is_boss_fight() -> bool:
	return _boss.is_active()


## Seconds left on the boss countdown (0 when there is no boss fight).
func boss_time_left() -> float:
	return _boss.time_left()


## Full duration of a boss fight, in seconds.
func boss_timer_seconds() -> float:
	return _boss.timer_seconds()


## True in farm mode: kills respawn the same stage until [method challenge_boss].
func is_farming() -> bool:
	return _state.farming


## True when a farm kill may start the boss by itself ("Défi automatique").
func auto_challenge() -> bool:
	return _permanent.auto_challenge


## Sets the "Défi automatique" preference; it applies from the next farm kill.
func set_auto_challenge(enabled: bool) -> void:
	_permanent.auto_challenge = enabled


## Sets the player's click damage per second, as measured or modeled by the caller;
## [method can_beat_next_boss] counts it with the companions' damage per second.
func set_click_dps(dps: BigNumber) -> void:
	_click_dps = dps


## In farm mode, true when the estimated damage over a full countdown covers the
## boss with a margin: (companion power + click dps) * timer_seconds >= boss HP *
## auto_challenge_margin (see [method BossFight.safe_boss_hp]). It stays an estimate:
## a win it predicts can still fail.
func can_beat_next_boss() -> bool:
	if not _state.farming:
		return false
	var dps: BigNumber = _combat.companion_power(_state.companion_levels).add(_click_dps)
	return dps.multiply_decimal("%.3f" % _boss.timer_seconds()).compare(_safe_boss_hp) >= 0


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


## Deals [param damage] to the current enemy. If it dies: gold is granted (boss gold
## for a boss), the next stage starts with a fresh enemy (in farm mode, the same
## stage again unless auto challenge is on and [method can_beat_next_boss] is true),
## then [signal enemy_killed],
## [signal farming_changed] when farm mode was left, [signal stage_started] and, when
## a boss begins, [signal boss_started] are emitted (state already consistent).
func apply_damage(damage: BigNumber) -> void:
	if damage.compare(_current_hp) < 0:
		_current_hp = _current_hp.subtract(damage)
		enemy_damaged.emit(damage, _current_hp)
		return
	var killed_stage: int = _state.stage
	var reward: BigNumber = _reward
	_state.gold = _state.gold.add(reward)
	var left_farm: bool = _permanent.auto_challenge and can_beat_next_boss()
	if left_farm:
		_state.farming = false
	if not _state.farming:
		_state.stage = killed_stage + 1
		_state.max_stage_reached = maxi(_state.max_stage_reached, _state.stage)
		_spawn_enemy()
	else:
		_current_hp = _max_hp
	enemy_killed.emit(killed_stage, reward)
	if left_farm:
		farming_changed.emit(false)
	stage_started.emit(_state.stage, _max_hp)
	if _boss.is_active():
		boss_started.emit(_state.stage, _boss.timer_seconds())


## Leaves farm mode and starts the boss of the next stage at full HP with a full
## countdown. Returns false and changes nothing outside farm mode. Emits
## [signal farming_changed], [signal stage_started] and [signal boss_started].
func challenge_boss() -> bool:
	if not _state.farming:
		return false
	_state.farming = false
	_state.stage += 1
	_state.max_stage_reached = maxi(_state.max_stage_reached, _state.stage)
	_spawn_enemy()
	farming_changed.emit(false)
	stage_started.emit(_state.stage, _max_hp)
	boss_started.emit(_state.stage, _boss.timer_seconds())
	return true


## Advances the boss countdown by [param delta] seconds (clamped, see
## [constant BossFight.MAX_TICK_SECONDS]). Does nothing outside a boss fight. When the
## countdown runs out, the stage goes back by one with a fresh enemy in farm mode,
## then [signal boss_failed], [signal farming_changed] and [signal stage_started] are
## emitted. Call it once per frame, after the damage of that frame has been applied (see the class comment).
func tick(delta: float) -> void:
	if _boss.tick(delta):
		_fall_back()


## Gives up the running boss fight: same fallback as when the countdown runs out,
## with the same signals. Returns false and changes nothing outside a boss fight.
func abandon_boss() -> bool:
	if not _boss.is_active():
		return false
	_fall_back()
	return true


func _fall_back() -> void:
	var failed_stage: int = _state.stage
	_state.stage = failed_stage - 1
	_state.farming = true
	_spawn_enemy()
	_update_safe_boss_hp()
	boss_failed.emit(failed_stage, _state.stage)
	farming_changed.emit(true)
	stage_started.emit(_state.stage, _max_hp)


func _update_safe_boss_hp() -> void:
	_safe_boss_hp = _boss.safe_boss_hp(_boss.boss_max_hp(_combat.enemy_max_hp(_state.stage + 1)))


func _spawn_enemy() -> void:
	if _boss.is_boss_stage(_state.stage):
		_max_hp = _boss.boss_max_hp(_combat.enemy_max_hp(_state.stage))
		_reward = _boss.boss_gold(_state.stage)
		_boss.begin()
	else:
		_max_hp = _combat.enemy_max_hp(_state.stage)
		_reward = _combat.gold_per_kill(_state.stage)
		_boss.stop()
	_current_hp = _max_hp
