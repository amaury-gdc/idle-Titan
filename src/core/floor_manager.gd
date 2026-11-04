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
## TALENTS (story 006): the permanent bonuses of [TalentTree] are pushed here with
## [method set_talent_modifiers] and kept apart from the skill buffs above, which
## [SkillManager] overwrites each time a buff starts or ends. Each is one factor applied
## at one place: click damage in [method click_damage], companion damage in
## [method companion_damage] / [method companion_power], kill gold in [method apply_damage].
## They come BEFORE the skill buffs: a click is floor(base * talent) then, if the damage
## buff runs, floor(that * buff); the two minimums of +1 stack on the smallest hits.
## The skill burst ([method SkillManager.burst_damage]) gets the click and companion factors
## through those two methods. Offline gold has its own talent, see [OfflineIncome].
##
## ITEMS (story 007): the bonuses of the equipped [Inventory] items. The percentages of the
## stats that talents have too (click, companion, gold) are summed with the talents by
## [ModifierHub], which pushes ONE factor each through [method set_talent_modifiers]; never
## call [method TalentTree.apply_to] next to it. The stats only items have come through
## [method set_item_modifiers]. Global damage and boss damage are applied in
## [method buffed_damage] (the boss one only during a boss fight), after the click and
## companion factors and before the damage buff; boss gold after the gold factor, on a boss
## kill only. Critical hits ([method set_crit_roll]) only come from [method click], after
## the damage buff: companion attacks and the skill burst go through [method apply_damage]
## and are never critical. Different stats multiply each other (global x boss x buff); the
## same stat adds up.
## [signal boss_killed] is the hook of the loot.
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
## The boss of [param stage] died (story 007 loot hook). Emitted right after [signal enemy_killed]
## for the same kill, with the state already consistent; not emitted for a normal enemy.
signal boss_killed(stage: int)
## A click was a critical hit and deals [param damage] (the final damage, critical bonus
## included). Emitted before the matching [signal enemy_damaged] or [signal enemy_killed].
signal critical_hit(damage: BigNumber)
## Where a hit comes from, for the display only ([signal hit_landed]): [constant AUTO] is a
## companion attack (the default of [method apply_damage]), [constant CLICK] a plain player
## click, [constant CRITICAL] a click that rolled a critical hit, [constant BURST] the skill
## burst (Gros coup). It never changes the damage.
enum HitSource { AUTO, CLICK, CRITICAL, BURST }

## A hit was dealt: [param damage] is the FINAL damage (item stats, damage buff and critical
## hit included, overkill not subtracted), [param source] a [enum HitSource]. Emitted at the top
## of every hit, for the hit that kills as well, before [signal enemy_damaged] or
## [signal enemy_killed]. Display hook (story 009): nothing in the game listens to it.
signal hit_landed(damage: BigNumber, source: int)
## The enemy of [param stage] died and [param gold] (the final reward, already in the state) was
## granted; [param was_boss] says it was a boss. Emitted right after [signal enemy_killed], in
## the same call. Display hook (story 009): after the kill, [method is_boss_fight] already
## describes the next stage, so the boss flag is only known here.
signal kill_rewarded(stage: int, gold: BigNumber, was_boss: bool)
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
## "Rythme" (story 019) gave a free burst of [param damage] (already dealt as a [constant HitSource.BURST]
## hit). Display hook: nothing in the game listens to it.
signal rhythm_triggered(damage: BigNumber)

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
## Factor on every damage applied / on the gold of every kill, set by [SkillManager]
## (story 005) while a buff runs. "1" means none; compared as a string to skip the math.
var _damage_multiplier: String = "1"
var _gold_multiplier: String = "1"
## Permanent factors of the talents (story 006), "1" meaning none.
var _talent_click: String = "1"
var _talent_companion: String = "1"
var _talent_gold: String = "1"
## Effects of the talent tree (story 019), pushed by [ModifierHub]; "1" or 0 meaning none.
## Factor on the share of the companions in a click ("Frappe alliée").
var _click_share_factor: String = "1"
## Factor on the gold of the kills of farm mode ("Moisson").
var _farm_gold: String = "1"
## Percent off the gold cost of companion levels, not awakenings ("Négociation").
var _cost_discount_percent: int = 0
## Percent of attack speed of the companions ("Cadence").
var _attack_speed_percent: int = 0
## "Synergie": percent per companion at [member _synergy_level] or above, up to [member _synergy_max].
var _synergy_per_companion: int = 0
var _synergy_level: int = 0
var _synergy_max: int = 0
## "Champion": percent added to the strongest companion.
var _champion_percent: int = 0
## "Rythme": clicks per trigger (0 = off), seconds of damage of the free burst as a decimal string,
## minimum game seconds between two triggers. The counter and the time since the last trigger are
## NOT saved: a load starts from zero clicks and an open gap.
var _rhythm_clicks: int = 0
var _rhythm_dps_seconds: String = "1"
var _rhythm_min_gap: float = 0.0
var _rhythm_count: int = 0
## Companion cache (story 019, see [method strongest_companion_id]): the levels and awakenings it was
## computed from, whether it is valid, and the values.
var _cache_levels: Dictionary = {}
var _cache_awakenings: Dictionary = {}
var _cache_ready: bool = false
var _cached_strongest: String = ""
var _cached_synergy_count: int = 0
var _cached_power: BigNumber = null
var _rhythm_since: float = INF
## Factors only items give (story 007), "1" meaning none.
var _global_damage: String = "1"
var _boss_damage: String = "1"
var _boss_gold: String = "1"
## Critical hit: chance in percent (0 = never), factor of the damage of a critical hit, and
## the injected dice (a Callable returning a float in [0.0, 1.0)); without it, no hit is critical.
var _crit_chance: int = 0
var _crit_factor: String = "2"
var _crit_roll: Callable


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


## Full duration of a boss fight, in seconds, the talents' bonus included.
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
	var dps: BigNumber = companion_power().add(_click_dps)
	# Permanent item bonuses count, like the talents: the next fight is a boss fight.
	dps = _with_talent(_with_talent(dps, _global_damage), _boss_damage)
	return dps.multiply_decimal("%.3f" % _boss.timer_seconds()).compare(_safe_boss_hp) >= 0


## Sets the factor applied to every damage from now on (story 005 damage buff): clicks,
## companion attacks and skill bursts alike. [param factor] is a valid decimal string
## ("2", "1.5"); "1" removes the buff. The estimate of [method can_beat_next_boss] ignores
## it, so a buff only adds margin.
func set_damage_multiplier(factor: String) -> void:
	_damage_multiplier = factor


## Sets the factor applied to the gold of every kill from now on (story 005 gold bonus),
## boss kills included. [param factor] is a valid decimal string; "1" removes the bonus.
## Offline gold ([OfflineIncome]) never uses it.
func set_gold_multiplier(factor: String) -> void:
	_gold_multiplier = factor


## Sets the permanent factors of the talents (story 006): [param click] on click damage,
## [param companion] on companion damage, [param gold] on the gold of every kill, boss
## kills included. Each is a valid decimal string ("1.25"); "1" means none. Unlike the
## skill buffs they stay until the next call. The estimate of [method can_beat_next_boss]
## counts them, since they are permanent. With items in play, pass the SUM of talents and
## items for these three stats (see [ModifierHub]): a later call replaces the earlier one.
func set_talent_modifiers(click: String, companion: String, gold: String) -> void:
	_talent_click = click
	_talent_companion = companion
	_talent_gold = gold
	_drop_companion_cache()


## Sets the factors only items give (story 007), pushed by [ModifierHub]: [param global_damage]
## on every damage, [param boss_damage] on every damage during a boss fight, [param boss_gold]
## on the gold of a boss kill, each a valid decimal string ("1.25"), "1" meaning none.
## [param crit_chance_percent] (0..100) is the chance of a critical hit per click and
## [param crit_factor] the factor of its damage ("2.00" doubles it). They stay until the
## next call; the estimate of [method can_beat_next_boss] counts the first two factors, not
## the critical hits.
func set_item_modifiers(global_damage: String, boss_damage: String, boss_gold: String, crit_chance_percent: int, crit_factor: String) -> void:
	_global_damage = global_damage
	_boss_damage = boss_damage
	_boss_gold = boss_gold
	_crit_chance = clampi(crit_chance_percent, 0, 100)
	_crit_factor = crit_factor


## Sets the talent effects that [ModifierHub] pushes (story 019, design/talent-tree-v2.md), each
## replacing the previous call:
## [param click_share] factor on the share of the companions in a click, a decimal string ("1.50");
## [param farm_gold] factor on the gold of the kills of farm mode ("1.12"); [param cost_discount_percent]
## percent off every companion level, awakenings excluded (see [method discounted_cost]);
## [param attack_speed_percent] percent of attack speed of the companions (see [method attack_speed_factor]);
## [param boss_bonus_seconds] seconds added to every boss countdown that begins from now on.
## "1", 0 and 0.0 mean none.
func set_talent_effects(click_share: String, farm_gold: String, cost_discount_percent: int, attack_speed_percent: int, boss_bonus_seconds: float) -> void:
	_click_share_factor = click_share
	_farm_gold = farm_gold
	_cost_discount_percent = clampi(cost_discount_percent, 0, 99)
	_attack_speed_percent = maxi(attack_speed_percent, 0)
	_boss.set_bonus_seconds(boss_bonus_seconds)
	_drop_companion_cache()


## Sets the two talent effects that depend on which companion is which (story 019): "Synergie" gives
## [param per_companion] percent for each companion at [param level] or above, up to [param max_percent]
## (0 for per_companion means none); "Champion" gives [param champion_percent] percent more to
## [method strongest_companion_id]. Both multiply the companion talents of
## [method set_talent_modifiers] and each other.
func set_companion_effects(per_companion: int, level: int, max_percent: int, champion_percent: int) -> void:
	_synergy_per_companion = maxi(per_companion, 0)
	_synergy_level = level
	_synergy_max = maxi(max_percent, 0)
	_champion_percent = maxi(champion_percent, 0)
	_drop_companion_cache()


## Sets "Rythme" (story 019): every [param clicks] clicks of the player, a free burst of
## [param dps_seconds] seconds of damage (a decimal string, same formula as the skill "Gros coup"), but
## never twice within [param min_gap_seconds] seconds of game time ([method tick]). [param clicks] <= 0
## switches it off and forgets the count. A count already started is kept when the numbers change.
## When the count is full inside the gap, the burst comes with the first click after the gap.
func set_rhythm(clicks: int, dps_seconds: String, min_gap_seconds: float) -> void:
	_rhythm_clicks = maxi(clicks, 0)
	_rhythm_dps_seconds = dps_seconds
	_rhythm_min_gap = maxf(min_gap_seconds, 0.0)
	if _rhythm_clicks == 0:
		_rhythm_count = 0


## Clicks counted toward the next "Rythme" burst (0 when off); lost at a reload, by design.
func rhythm_count() -> int:
	return _rhythm_count


## Clicks that make a "Rythme" burst, 0 when the talent is not bought.
func rhythm_clicks() -> int:
	return _rhythm_clicks


## Injects the dice of the critical hits: a [Callable] returning a float in [0.0, 1.0), for
## example [code]rng.randf[/code] of a seeded [RandomNumberGenerator]. A click is critical when
## the roll * 100 is below the chance. Without a valid Callable, no click is ever critical
## (deterministic by default). It is read only when the chance is above 0.
func set_crit_roll(roll: Callable) -> void:
	_crit_roll = roll


## Damage a click deals right now (base + companion share, times the click talents),
## before the damage buff.
func click_damage() -> BigNumber:
	return _with_talent(_combat.click_damage(_state.companion_levels, _state.companion_awakenings, _click_share_factor), _talent_click)


## [param damage], a companion's attack or damage per second, with the companion talents
## applied. Unchanged when none is bought. The damage buff is not applied here. With the id of the
## companion it comes from ([param id], "" for none), the effects that depend on the companion apply too:
## "Synergie" (every companion) and "Champion" (the strongest one only).
func companion_damage(damage: BigNumber, id: String = "") -> BigNumber:
	var scaled: BigNumber = _with_talent(damage, _talent_companion)
	if id.is_empty():
		return scaled
	scaled = _with_talent(scaled, TalentTree.factor_from_percent(synergy_percent()))
	if _champion_percent > 0 and id == strongest_companion_id():
		scaled = _with_talent(scaled, TalentTree.factor_from_percent(_champion_percent))
	return scaled


## Damage of one attack of the companion [param id] now (0 when not bought), with its awakenings and
## all the companion talents.
func companion_attack_damage(id: String) -> BigNumber:
	return companion_damage(_combat.companion(id).damage_at_level(_level_of(id), _combat.awakening_count(_state.companion_awakenings, id), _combat.squad_awakenings(_state.companion_awakenings)), id)


## Damage per second of the companion [param id] now (0 when not bought): the attack damage with every
## companion talent, then the attack speed of "Cadence".
func companion_dps(id: String) -> BigNumber:
	return companion_dps_at(id, _level_of(id))


## What [method companion_dps] of [param id] would be at [param level], everything else as it is now:
## its awakenings and the squad's, the companion talents and "Cadence". A reading for the interface
## ("+X DPS" of a purchase, story 019b): it changes nothing. "Synergie" and "Champion" are read as they
## are now, so a purchase that moves them is not foreseen. 0 for a level of 0 or less.
## [codeblock]
## var gain: BigNumber = floors.companion_dps_at("scout", 11).subtract(floors.companion_dps("scout"))
## [/codeblock]
func companion_dps_at(id: String, level: int) -> BigNumber:
	var bare: BigNumber = _combat.companion(id).damage_per_second_at_level(level, _combat.awakening_count(_state.companion_awakenings, id), _combat.squad_awakenings(_state.companion_awakenings))
	return _with_talent(companion_damage(bare, id), TalentTree.factor_from_percent(_attack_speed_percent))


## Total damage per second of the companions, with the companion talents: the sum of
## [method companion_dps] over the roster. Cached, see [method strongest_companion_id].
func companion_power() -> BigNumber:
	_follow_companions()
	if _cached_power == null:
		var total: BigNumber = BigNumber.new()
		for def: Companion in _combat.companions():
			total = total.add(companion_dps(def.id))
		_cached_power = total
	return _cached_power


## Seconds of attack time a companion gains per second of game time: 1.0, or 1.05 with +5% attack
## speed. The [CompanionManager] feeds its attack timers with it.
func attack_speed_factor() -> float:
	return 1.0 + float(_attack_speed_percent) / 100.0


## The companion with the highest damage per second now, awakenings included and talents left out
## (story 019 "Champion": "strongest" is the current dps, so it follows the levels and awakenings); the
## first in roster order on a tie; "" when no companion is bought.
## Cache: this id, the synergy count and [method companion_power] are computed once and kept until the
## companion levels or awakenings of the state differ from the copy taken then (any change, through
## [CompanionManager] or not), or until a talent setter of this class runs.
func strongest_companion_id() -> String:
	_follow_companions()
	return _cached_strongest


## Percent "Synergie" gives to every companion now: [code]min(per_companion * companions at level or
## above, max)[/code], 0 when the talent is not bought. Cached, see [method strongest_companion_id].
func synergy_percent() -> int:
	if _synergy_per_companion <= 0:
		return 0
	_follow_companions()
	return mini(_cached_synergy_count * _synergy_per_companion, _synergy_max)


## [param cost], a gold cost of a companion level, with the discount of "Négociation" (never used on an
## awakening, which no node touches):
## floor(cost * (100 - percent) / 100), at least 1 for a cost that was not 0. Unchanged without the talent.
func discounted_cost(cost: BigNumber) -> BigNumber:
	return Companion.discounted_cost(cost, _cost_discount_percent)


## Percent off the costs now, 0 when "Négociation" is not bought.
func cost_discount_percent() -> int:
	return _cost_discount_percent


## [param dps_seconds] seconds (a decimal string) of the damage the player and the companions deal
## in one second: (companion power + click damage) * dps_seconds, floored. The skill "Gros coup" and
## "Rythme" both use it. The damage buff and item stats come later, in [method apply_damage].
func damage_over(dps_seconds: String) -> BigNumber:
	return companion_power().add(click_damage()).multiply_decimal(dps_seconds)


## [param damage] with the item stats (global damage, boss damage in a boss fight) and the damage
## buff applied, unchanged when none is on. Each adds at least 1: floor(1 * 1.5) would otherwise
## leave the smallest hits untouched. Critical hits are NOT included (random, see [method click]).
func buffed_damage(damage: BigNumber) -> BigNumber:
	if damage.is_zero():
		return damage
	# Item stats first: global damage, then boss damage during a boss fight (each at least +1).
	damage = _with_talent(damage, _global_damage)
	if _boss.is_active():
		damage = _with_talent(damage, _boss_damage)
	if _damage_multiplier == "1":
		return damage
	var buffed: BigNumber = damage.multiply_decimal(_damage_multiplier)
	return buffed if buffed.compare(damage) > 0 else damage.add(BigNumber.from_int(1))


## Enemy HP as a ratio 0.0..1.0 with 1/1000 resolution, exact for any HP size
## (BigNumber division, no float on big values). Meant for a progress bar.
func hp_ratio() -> float:
	var permille: BigNumber = _current_hp.multiply(BigNumber.from_int(1000)).divide(_max_hp)
	return float(permille.to_decimal_string().to_int()) / 1000.0


## A player click: deals [method click_damage] to the enemy (times the damage buff), and
## rolls a critical hit, the only damage that can be critical. Returns the click damage
## BEFORE the buff and the critical hit, so the measured click dps that feeds
## [method can_beat_next_boss] stays a buff-free estimate. The click also counts toward "Rythme"
## ([method set_rhythm]): the free burst, when it comes, is dealt right after the click.
func click() -> BigNumber:
	var damage: BigNumber = click_damage()
	var final_damage: BigNumber = buffed_damage(damage)
	var critical: bool = _rolls_critical()
	if critical:
		final_damage = _with_talent(final_damage, _crit_factor)
		critical_hit.emit(final_damage)
	_deal(final_damage, HitSource.CRITICAL if critical else HitSource.CLICK)
	_count_rhythm()
	return damage


## Deals [param damage] to the current enemy, multiplied by the damage buff when one is
## on ([method set_damage_multiplier]); the signals carry the damage actually dealt. If
## it dies: gold (boss gold for a boss, times the gold bonus when one is on) is granted,
## the next stage starts with a fresh enemy (in farm mode, the same
## stage again unless auto challenge is on and [method can_beat_next_boss] is true),
## then [signal enemy_killed], [signal kill_rewarded],
## [signal farming_changed] when farm mode was left, [signal stage_started] and, when
## a boss begins, [signal boss_started] are emitted (state already consistent).
## [param source] only tells the display where the hit comes from ([signal hit_landed]): the
## companions keep the default [constant HitSource.AUTO], the skill burst passes
## [constant HitSource.BURST].
func apply_damage(damage: BigNumber, source: HitSource = HitSource.AUTO) -> void:
	_deal(buffed_damage(damage), source)


# Takes [param damage], final, off the current enemy: see [method apply_damage].
func _deal(damage: BigNumber, source: HitSource) -> void:
	hit_landed.emit(damage, source)
	if damage.compare(_current_hp) < 0:
		_current_hp = _current_hp.subtract(damage)
		enemy_damaged.emit(damage, _current_hp)
		return
	var killed_stage: int = _state.stage
	var was_boss: bool = _boss.is_active()
	var reward: BigNumber = _with_talent(_reward, _talent_gold)
	if _state.farming:
		reward = _with_talent(reward, _farm_gold)
	if was_boss:
		reward = _with_talent(reward, _boss_gold)
	if _gold_multiplier != "1":
		reward = reward.multiply_decimal(_gold_multiplier)
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
	kill_rewarded.emit(killed_stage, reward, was_boss)
	if was_boss:
		boss_killed.emit(killed_stage)
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
	_rhythm_since += clampf(delta, 0.0, BossFight.MAX_TICK_SECONDS)
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


# Counts one click toward "Rythme". A full count waits for the gap since the last burst, then the
# first click deals the burst (damage_over, with the damage buff and item stats of apply_damage).
func _count_rhythm() -> void:
	if _rhythm_clicks <= 0:
		return
	_rhythm_count = mini(_rhythm_count + 1, _rhythm_clicks)
	if _rhythm_count < _rhythm_clicks or _rhythm_since < _rhythm_min_gap:
		return
	_rhythm_count = 0
	_rhythm_since = 0.0
	var burst: BigNumber = damage_over(_rhythm_dps_seconds)
	apply_damage(burst, HitSource.BURST)
	rhythm_triggered.emit(burst)


# Recomputes the companion cache when the levels or awakenings of the state are no longer those it was
# computed from (Dictionary == compares the contents), or after _drop_companion_cache. The copies are
# only taken on a change.
func _follow_companions() -> void:
	if _cache_ready and _state.companion_levels == _cache_levels and _state.companion_awakenings == _cache_awakenings:
		return
	_cache_levels = _state.companion_levels.duplicate()
	_cache_awakenings = _state.companion_awakenings.duplicate()
	_cache_ready = true
	_cached_power = null
	_cached_strongest = ""
	_cached_synergy_count = 0
	var best: BigNumber = BigNumber.new()
	var squad: int = _combat.squad_awakenings(_state.companion_awakenings)
	for def: Companion in _combat.companions():
		var level: int = _level_of(def.id)
		if level >= _synergy_level:
			_cached_synergy_count += 1
		var dps: BigNumber = def.damage_per_second_at_level(level, _combat.awakening_count(_state.companion_awakenings, def.id), squad)
		if dps.compare(best) > 0:
			best = dps
			_cached_strongest = def.id


# Forgets the companion cache: a factor it depends on changed.
func _drop_companion_cache() -> void:
	_cache_ready = false


# Level of the companion [param id] in the state, 0 when not bought.
func _level_of(id: String) -> int:
	return maxi(int(_state.companion_levels.get(id, 0)), 0)


# [param value] times a talent factor: floor(value * factor), but at least value + 1 when the
# factor is above 1, like the damage buff (see buffed_damage): a bonus that rounds to
# nothing on a small value would look broken. A zero value stays zero.
func _with_talent(value: BigNumber, factor: String) -> BigNumber:
	if factor == "1" or value.is_zero():
		return value
	var scaled: BigNumber = value.multiply_decimal(factor)
	return scaled if scaled.compare(value) > 0 else value.add(BigNumber.from_int(1))


# True when this click is critical. The dice are read only when a chance and a valid roll exist,
# so the default stays deterministic.
func _rolls_critical() -> bool:
	if _crit_chance <= 0 or not _crit_roll.is_valid():
		return false
	return float(_crit_roll.call()) * 100.0 < float(_crit_chance)


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
