extends GdUnitTestSuite
## Unit tests for the companion awakening: thresholds that block the purchase, the cost, the
## damage multipliers (own and squad), the memos, and every reader of the power (companions,
## click, Gros coup, boss estimate, offline gold, displays), plus the validation of the data.
## Expected damages are computed by hand from the fixture, never through the code under test.
## Story: production/epics/idle-titans/story-016-awakening.md; design/economy-rework.md "Éveil".

const A: String = "a"
const B: String = "b"
## Fixture: every level of every companion costs BASE_COST (cost_growth "1"), so an awakening costs
## 10 x 10 = 100 at any threshold.
const BASE_COST: String = "10"
const AWAKEN_COST: int = 100
const ENEMY_HP: String = "100000"
const FIRST_THRESHOLD: int = 200
const SECOND_THRESHOLD: int = 300
const LAST_THRESHOLD: int = 1000
const THRESHOLD_COUNT: int = 9
## The block of design/economy-rework.md "Éveil".
const DESIGN_BLOCK: Dictionary = {
	"thresholds": [200, 300, 400, 500, 600, 700, 800, 900, 1000],
	"self_multiplier": "3.4",
	"squad_multiplier": "2.10",
	"squad_until_threshold": 600,
	"cost_level_multiplier": "10",
}
## Hand values. Companion a: base_damage 10, one tier x3 at level 200, 1 attack per second.
## Companion b: base_damage 100, no tier, 1 attack every 2 s.
## a at 200, no awakening: 10 * 200 * 3.
const A_200_PLAIN: String = "6000"
## a at 200, awakened once (counted for the squad): 6000 * 3.4 * 2.10 = 42840.
const A_200_AWAKENED: String = "42840"
## a at 200 with one awakening of its own and none counted for the squad: 6000 * 3.4.
const A_200_OWN_ONLY: String = "20400"
## b at 10 (damage 1000 per attack), with the squad x2.10 of a's first awakening: 2100 per attack.
const B_10_SQUAD_1: String = "2100"
## b at 10, damage per second (one attack every 2 s): floor(2100 / 2).
const B_10_SQUAD_1_DPS: String = "1050"
## b at 10 with 5 counted squad awakenings: floor(1000 * 2.10^5) = floor(40841.01).
const B_10_SQUAD_5: String = "40841"
## a at 700 with 6 awakenings (5 counted): floor(21000 * 3.4^6 * 2.10^5).
const A_700_SIX: String = "1324918824"
## Click: base 1 + floor(power * 0.1). Before: 1 + 600; after: 1 + floor(4284.0).
const CLICK_PLAIN: String = "601"
const CLICK_AWAKENED: String = "4285"
## Click with a share of "0.5" on every companion: 1 + floor(0.5 * dps).
const CLICK_SHARE_PLAIN: String = "3001"
const CLICK_SHARE_AWAKENED: String = "21421"
## Gros coup: (power + click) * 6.
const BURST_PLAIN: String = "39606"
const BURST_AWAKENED: String = "282750"
## Offline gold for OFFLINE_SECONDS at stage 1: floor(power * seconds * 1 * 0.5 / 100000).
const OFFLINE_SECONDS: int = 1000
const OFFLINE_PLAIN: String = "30"
const OFFLINE_AWAKENED: String = "214"
const NOW: int = 1_000_000

var _state: GameState
var _combat: Combat
var _floors: FloorManager
var _companions: CompanionManager
var _curves: Dictionary
var _awakened: Array = []


func before_test() -> void:
	_build({A: FIRST_THRESHOLD}, BigNumber.from_int(AWAKEN_COST * 10))


func _curves_data() -> Dictionary:
	return {
		"schema_version": Combat.SUPPORTED_CURVES_SCHEMA,
		"enemy_hp_base": ENEMY_HP,
		"enemy_hp_growth": "1",
		"gold_per_kill_base": "1",
		"gold_per_kill_growth": "1",
		"click_damage_base": "1",
		"click_companion_power_factor": "0.1",
		"cost_growth": "1",
		"offline_efficiency": "0.5",
		"offline_max_hours": 12,
		"offline_min_seconds": 60,
	}


func _entry(id: String, damage: String, interval: float, tiers: Array, share: String) -> Dictionary:
	var entry: Dictionary = {
		"id": id,
		"name": id,
		"base_cost": BASE_COST,
		"base_damage": damage,
		"cost_growth": "1",
		"attack_interval_seconds": interval,
		"tiers": tiers,
	}
	if not share.is_empty():
		entry["click_share"] = share
	return entry


func _roster(block: Variant, share: String = "") -> Dictionary:
	var roster: Dictionary = {
		"schema_version": Combat.SUPPORTED_ROSTER_SCHEMA,
		"companions": [
			_entry(A, "10", 1.0, [{"level": 200, "damage_multiplier": "3"}], share),
			_entry(B, "100", 2.0, [], share),
		],
	}
	if block != null:
		roster["awakening"] = block
	return roster


# A game with [param levels], [param gold] and the design block (or [param block]), with an optional
# boss and click share.
func _build(levels: Dictionary, gold: BigNumber, block: Variant = DESIGN_BLOCK, boss: BossFight = null, share: String = "") -> void:
	_curves = _curves_data()
	_combat = Combat.from_data(_curves, _roster(block, share))
	assert_str(_combat.get_error()).is_empty()
	_state = GameState.new()
	_state.companion_levels = levels.duplicate()
	_state.gold = gold
	_floors = FloorManager.new(_state, _combat, boss)
	_companions = CompanionManager.new(_state, _combat, _floors)
	_awakened = []
	_companions.awakened.connect(func(id: String) -> void: _awakened.append(id))


func _rich() -> BigNumber:
	return BigNumber.from_string("1" + "0".repeat(30))


func _error_of(block: Variant) -> String:
	return Combat.from_data(_curves_data(), _roster(block)).get_error()


func _block_with(key: String, value: Variant) -> Dictionary:
	var block: Dictionary = DESIGN_BLOCK.duplicate(true)
	block[key] = value
	return block


# --- Blocking at the thresholds ---

func test_level_199_cannot_awaken_and_can_buy_one_level() -> void:
	# Arrange
	_build({A: FIRST_THRESHOLD - 1}, _rich())

	# Act
	var awoke: bool = _companions.awaken(A)

	# Assert
	assert_bool(awoke).is_false()
	assert_bool(_companions.can_awaken(A)).is_false()
	assert_int(_companions.buyable_levels_cap(A)).is_equal(1)
	assert_bool(_companions.can_buy(A)).is_true()
	assert_int(_companions.awakenings(A)).is_equal(0)


func test_level_200_exact_is_blocked_and_can_awaken() -> void:
	# Arrange
	_build({A: FIRST_THRESHOLD}, _rich())

	# Act
	var bought_one: bool = _companions.buy_or_upgrade(A)
	var bought_batch: bool = _companions.buy_levels(A, 1)

	# Assert
	assert_bool(bought_one).is_false()
	assert_bool(bought_batch).is_false()
	assert_int(_companions.level(A)).is_equal(FIRST_THRESHOLD)
	assert_int(_companions.buyable_levels_cap(A)).is_equal(0)
	assert_bool(_companions.can_buy(A)).is_false()
	assert_int(_companions.affordable_levels(A)).is_equal(0)
	assert_bool(_companions.can_awaken(A)).is_true()
	assert_int(_companions.next_awakening(A)["level"]).is_equal(FIRST_THRESHOLD)


func test_level_201_from_a_save_without_awakening_is_blocked_until_awakened() -> void:
	# Arrange: a save written before the awakening, past the first threshold
	var payload: Dictionary = {"stage": 50, "gold": _rich().to_decimal_string(), "companion_levels": {A: FIRST_THRESHOLD + 1}}
	_state = GameState.from_dict(payload)
	_floors = FloorManager.new(_state, _combat)
	_companions = CompanionManager.new(_state, _combat, _floors)

	# Act
	var blocked: bool = not _companions.can_buy(A)
	var awoke: bool = _companions.awaken(A)

	# Assert: level kept, blocked, then free again after paying
	assert_bool(blocked).is_true()
	assert_bool(awoke).is_true()
	assert_int(_companions.level(A)).is_equal(FIRST_THRESHOLD + 1)
	assert_int(_companions.buyable_levels_cap(A)).is_equal(SECOND_THRESHOLD - FIRST_THRESHOLD - 1)
	assert_bool(_companions.can_buy(A)).is_true()


func test_two_pending_thresholds_awaken_in_order() -> void:
	# Arrange: level 350 passes 200 and 300
	var level: int = 350
	_build({A: level}, _rich())

	# Act
	var first_next: int = _companions.next_awakening(A)["level"]
	var first: bool = _companions.awaken(A)
	var second_next: int = _companions.next_awakening(A)["level"]
	var blocked_between: bool = not _companions.can_buy(A)
	var second: bool = _companions.awaken(A)
	var third: bool = _companions.awaken(A)

	# Assert
	assert_int(first_next).is_equal(FIRST_THRESHOLD)
	assert_bool(first).is_true()
	assert_int(second_next).is_equal(SECOND_THRESHOLD)
	assert_bool(blocked_between).is_true()
	assert_bool(second).is_true()
	assert_bool(third).is_false()
	assert_int(_companions.awakenings(A)).is_equal(2)
	assert_int(_companions.buyable_levels_cap(A)).is_equal(400 - level)
	assert_array(_awakened).is_equal([A, A])


# --- Cost ---

func test_gold_one_below_the_cost_is_refused_and_gold_unchanged() -> void:
	# Arrange
	_build({A: FIRST_THRESHOLD}, BigNumber.from_int(AWAKEN_COST - 1))

	# Act
	var awoke: bool = _companions.awaken(A)

	# Assert
	assert_bool(awoke).is_false()
	assert_bool(_companions.can_awaken(A)).is_false()
	assert_str(_state.gold.to_decimal_string()).is_equal(str(AWAKEN_COST - 1))
	assert_int(_companions.awakenings(A)).is_equal(0)
	assert_array(_awakened).is_empty()


func test_gold_equal_to_the_cost_awakens_and_leaves_zero() -> void:
	# Arrange
	_build({A: FIRST_THRESHOLD}, BigNumber.from_int(AWAKEN_COST))

	# Act
	var awoke: bool = _companions.awaken(A)

	# Assert
	assert_bool(awoke).is_true()
	assert_str(_state.gold.to_decimal_string()).is_equal("0")
	assert_int(_companions.awakenings(A)).is_equal(1)
	assert_dict(_state.companion_awakenings).is_equal({A: 1})
	assert_array(_awakened).is_equal([A])


func test_awakening_cost_is_the_multiplier_times_the_cost_of_the_threshold_level() -> void:
	# Arrange: cost_growth 2, so every level has its own price: level L costs 10 * 2^(L - 1)
	var block: Dictionary = _block_with("thresholds", [3, 5])
	var roster: Dictionary = _roster(block)
	for entry: Dictionary in roster["companions"]:
		entry["cost_growth"] = "2"
	_combat = Combat.from_data(_curves_data(), roster)
	assert_str(_combat.get_error()).is_empty()
	_state = GameState.new()
	_state.companion_levels = {A: 3}
	_state.gold = _rich()
	_companions = CompanionManager.new(_state, _combat, FloorManager.new(_state, _combat))

	# Act
	var first: BigNumber = _companions.next_awakening(A)["cost"]
	_companions.awaken(A)
	var second: BigNumber = _companions.next_awakening(A)["cost"]

	# Assert: 10 x cost_of_level(3) = 10 x 40, then 10 x cost_of_level(5) = 10 x 160
	assert_str(first.to_decimal_string()).is_equal("400")
	assert_str(second.to_decimal_string()).is_equal("1600")


func test_second_call_right_after_an_awakening_is_refused() -> void:
	# Arrange
	_build({A: FIRST_THRESHOLD}, BigNumber.from_int(AWAKEN_COST * 10))

	# Act
	var first: bool = _companions.awaken(A)
	var second: bool = _companions.awaken(A)

	# Assert: one payment only
	assert_bool(first).is_true()
	assert_bool(second).is_false()
	assert_str(_state.gold.to_decimal_string()).is_equal(str(AWAKEN_COST * 9))
	assert_int(_companions.awakenings(A)).is_equal(1)
	assert_array(_awakened).is_equal([A])


# --- x10 and Max stop at the threshold ---

func test_ten_and_max_stop_at_the_threshold() -> void:
	# Arrange: 5 levels left before 200, gold for far more
	var start: int = FIRST_THRESHOLD - 5
	_build({A: start}, BigNumber.from_int(1000))

	# Act
	var max_count: int = _companions.affordable_levels(A)
	var ten_count: int = _companions.affordable_levels(A, 10)
	var walk: Dictionary = _companions.affordable_walk(A)
	var ten_cost: String = _companions.cost_of_levels(A, 10).to_decimal_string()
	var bought: bool = _companions.buy_levels(A, 10)

	# Assert: 5 levels of 10 gold each
	assert_int(max_count).is_equal(5)
	assert_int(ten_count).is_equal(5)
	assert_int(walk["count"]).is_equal(5)
	assert_str((walk["total"] as BigNumber).to_decimal_string()).is_equal("50")
	assert_str(ten_cost).is_equal("50")
	assert_bool(bought).is_true()
	assert_int(_companions.level(A)).is_equal(FIRST_THRESHOLD)
	assert_str(_state.gold.to_decimal_string()).is_equal("950")


func test_level_1000_awakens_once_more_then_levels_are_free() -> void:
	# Arrange: every threshold but the last one awakened
	_build({A: LAST_THRESHOLD}, _rich())
	_state.companion_awakenings = {A: THRESHOLD_COUNT - 1}

	# Act
	var next_before: Dictionary = _companions.next_awakening(A)
	var blocked: bool = not _companions.can_buy(A)
	var awoke: bool = _companions.awaken(A)
	var bought: bool = _companions.buy_or_upgrade(A)

	# Assert
	assert_int(next_before["level"]).is_equal(LAST_THRESHOLD)
	assert_bool(blocked).is_true()
	assert_bool(awoke).is_true()
	assert_dict(_companions.next_awakening(A)).is_empty()
	assert_bool(_companions.can_awaken(A)).is_false()
	assert_int(_companions.buyable_levels_cap(A)).is_equal(CompanionManager.NO_CAP)
	assert_bool(bought).is_true()
	assert_int(_companions.level(A)).is_equal(LAST_THRESHOLD + 1)


# --- Damage ---

func test_own_awakening_multiplies_by_3_4_and_the_squad_by_2_10() -> void:
	# Arrange
	_build({A: FIRST_THRESHOLD, B: 10}, BigNumber.from_int(AWAKEN_COST))
	var before: String = _companions.damage(A).to_decimal_string()

	# Act
	_companions.awaken(A)

	# Assert
	assert_str(before).is_equal(A_200_PLAIN)
	assert_str(_companions.damage(A).to_decimal_string()).is_equal(A_200_AWAKENED)
	assert_str(_companions.damage(B).to_decimal_string()).is_equal(B_10_SQUAD_1)
	assert_str(_companions.damage_per_second(B).to_decimal_string()).is_equal(B_10_SQUAD_1_DPS)
	assert_int(_companions.squad_awakenings()).is_equal(1)


func test_awakening_above_the_squad_limit_gives_only_the_own_multiplier() -> void:
	# Arrange: limit at 100, so the awakening at 200 counts for a alone
	_build({A: FIRST_THRESHOLD, B: 10}, BigNumber.from_int(AWAKEN_COST), _block_with("squad_until_threshold", 100))

	# Act
	_companions.awaken(A)

	# Assert
	assert_int(_companions.squad_awakenings()).is_equal(0)
	assert_str(_companions.damage(A).to_decimal_string()).is_equal(A_200_OWN_ONLY)
	assert_str(_companions.damage(B).to_decimal_string()).is_equal("1000")


func test_thresholds_700_to_1000_add_no_squad_effect() -> void:
	# Arrange: a awakened at 200..600 (5 counted), b at level 10
	_build({A: 700, B: 10}, _rich())
	_state.companion_awakenings = {A: 5}
	var b_before: String = _companions.damage(B).to_decimal_string()

	# Act: the awakening at 700
	var awoke: bool = _companions.awaken(A)

	# Assert
	assert_bool(awoke).is_true()
	assert_str(b_before).is_equal(B_10_SQUAD_5)
	assert_int(_companions.squad_awakenings()).is_equal(5)
	assert_str(_companions.damage(B).to_decimal_string()).is_equal(B_10_SQUAD_5)
	assert_str(_companions.damage(A).to_decimal_string()).is_equal(A_700_SIX)


func test_dps_is_never_stale_after_an_awakening_at_the_same_level() -> void:
	# Arrange: read the dps (fills the memos) at level 200
	_build({A: FIRST_THRESHOLD}, BigNumber.from_int(AWAKEN_COST))
	var before_dps: String = _companions.damage_per_second(A).to_decimal_string()
	var before_power: String = _companions.total_power().to_decimal_string()

	# Act: same level, one more awakening
	_companions.awaken(A)

	# Assert
	assert_str(before_dps).is_equal(A_200_PLAIN)
	assert_str(before_power).is_equal(A_200_PLAIN)
	assert_str(_companions.damage_per_second(A).to_decimal_string()).is_equal(A_200_AWAKENED)
	assert_str(_companions.total_power().to_decimal_string()).is_equal(A_200_AWAKENED)


func test_companion_attacks_deal_the_awakened_damage() -> void:
	# Arrange
	_build({A: FIRST_THRESHOLD}, BigNumber.from_int(AWAKEN_COST))
	_companions.awaken(A)
	var hits: Array = []
	_companions.companion_attacked.connect(func(_id: String, damage: BigNumber) -> void: hits.append(damage.to_decimal_string()))

	# Act: one full interval
	_companions.tick(1.0)

	# Assert
	assert_array(hits).is_equal([A_200_AWAKENED])


func test_click_sees_the_awakened_power() -> void:
	# Arrange
	var before: String = _floors.click_damage().to_decimal_string()

	# Act
	_companions.awaken(A)

	# Assert
	assert_str(before).is_equal(CLICK_PLAIN)
	assert_str(_floors.click_damage().to_decimal_string()).is_equal(CLICK_AWAKENED)


func test_click_share_formula_sees_the_awakened_dps() -> void:
	# Arrange
	_build({A: FIRST_THRESHOLD}, BigNumber.from_int(AWAKEN_COST), DESIGN_BLOCK, null, "0.5")
	var before: String = _floors.click_damage().to_decimal_string()

	# Act
	_companions.awaken(A)

	# Assert
	assert_str(before).is_equal(CLICK_SHARE_PLAIN)
	assert_str(_floors.click_damage().to_decimal_string()).is_equal(CLICK_SHARE_AWAKENED)


func test_burst_sees_the_awakened_power() -> void:
	# Arrange
	var data: Dictionary = {
		"schema_version": SkillManager.SUPPORTED_SCHEMA,
		"skills": [
			{"id": "big_hit", "name": "Gros coup", "effect": "burst", "dps_seconds": "6", "cooldown_seconds": 60},
			{"id": "damage_buff", "name": "Frénésie", "effect": "damage_multiplier", "multiplier": "1.5", "duration_seconds": 15, "cooldown_seconds": 90},
			{"id": "gold_bonus", "name": "Bonus d'or", "effect": "gold_multiplier", "multiplier": "1.5", "duration_seconds": 20, "cooldown_seconds": 120},
		],
	}
	var skills: SkillManager = SkillManager.from_data(data, _state, _combat, _floors)
	assert_str(skills.get_error()).is_empty()
	var burst: Skill = skills.skill("big_hit")
	var before: String = skills.burst_damage(burst).to_decimal_string()

	# Act
	_companions.awaken(A)

	# Assert
	assert_str(before).is_equal(BURST_PLAIN)
	assert_str(skills.burst_damage(burst).to_decimal_string()).is_equal(BURST_AWAKENED)


func test_boss_estimate_sees_the_awakened_power() -> void:
	# Arrange: farming before the boss of stage 10. Boss HP 2 x 100000, 30 s: 6000 dps falls short
	# (180000), the awakened 42840 dps covers it (1285200).
	var boss: BossFight = BossFight.from_data({"schema_version": BossFight.SUPPORTED_SCHEMA, "boss_every_stages": 10, "timer_seconds": 30, "boss_hp_multiplier": "2", "boss_gold_base": "1", "boss_gold_growth": "1", "auto_challenge_margin": "1"})
	assert_str(boss.get_error()).is_empty()
	_build({A: FIRST_THRESHOLD}, BigNumber.from_int(AWAKEN_COST))
	_state.stage = 9
	_state.farming = true
	_floors = FloorManager.new(_state, _combat, boss)
	_companions = CompanionManager.new(_state, _combat, _floors)
	var before: bool = _floors.can_beat_next_boss()

	# Act
	_companions.awaken(A)

	# Assert
	assert_bool(before).is_false()
	assert_bool(_floors.can_beat_next_boss()).is_true()


func test_offline_gold_sees_the_awakened_power() -> void:
	# Arrange
	var offline: OfflineIncome = OfflineIncome.from_data(_curves, _combat)
	assert_str(offline.get_error()).is_empty()
	var before: String = offline.gold_for(OFFLINE_SECONDS, 1, _state.companion_levels, _state.companion_awakenings).to_decimal_string()

	# Act
	_companions.awaken(A)
	_state.gold = BigNumber.new()
	_state.last_saved_unix = NOW - OFFLINE_SECONDS
	var granted: Dictionary = offline.grant(_state, NOW)

	# Assert
	assert_str(before).is_equal(OFFLINE_PLAIN)
	assert_str(offline.gold_for(OFFLINE_SECONDS, 1, _state.companion_levels, {A: 1}).to_decimal_string()).is_equal(OFFLINE_AWAKENED)
	assert_str((granted["gold"] as BigNumber).to_decimal_string()).is_equal(OFFLINE_AWAKENED)


func test_a_count_above_the_thresholds_is_cut_to_their_number() -> void:
	# Arrange
	_build({A: LAST_THRESHOLD}, BigNumber.new())
	_state.companion_awakenings = {A: THRESHOLD_COUNT + 5, B: -2}

	# Act
	var own: int = _companions.awakenings(A)
	var other: int = _companions.awakenings(B)

	# Assert
	assert_int(own).is_equal(THRESHOLD_COUNT)
	assert_int(other).is_equal(0)
	assert_int(_companions.squad_awakenings()).is_equal(5)


func test_negative_level_on_a_fresh_companion_gives_zero_dps_not_null() -> void:
	# Arrange: a companion whose memos were never filled
	var companion: Companion = _combat.companion(B)

	# Act
	var dps: BigNumber = companion.damage_per_second_at_level(-1, 0, 0)
	var damage: BigNumber = companion.damage_at_level(-1, 0, 0)

	# Assert
	assert_object(dps).is_not_null()
	assert_str(dps.to_decimal_string()).is_equal("0")
	assert_str(damage.to_decimal_string()).is_equal("0")


# --- Data ---

func test_roster_without_block_keeps_levels_free_and_has_no_awakening() -> void:
	# Arrange
	_build({A: 500}, _rich(), null)

	# Act
	var bought: bool = _companions.buy_or_upgrade(A)

	# Assert
	assert_bool(_combat.awakening_rules().is_enabled()).is_false()
	assert_bool(bought).is_true()
	assert_dict(_companions.next_awakening(A)).is_empty()
	assert_bool(_companions.awaken(A)).is_false()
	assert_int(_companions.buyable_levels_cap(A)).is_equal(CompanionManager.NO_CAP)


func test_design_block_is_read() -> void:
	# Arrange / Act
	var rules: AwakeningRules = _combat.awakening_rules()

	# Assert
	assert_bool(rules.is_enabled()).is_true()
	assert_int(rules.threshold_count()).is_equal(THRESHOLD_COUNT)
	assert_int(rules.squad_threshold_count()).is_equal(5)
	var fraction: Array = rules.multiplier_fraction(1, 1)
	assert_str((fraction[0] as BigNumber).to_decimal_string()).is_equal("7140")
	assert_int(fraction[1]).is_equal(3)


func test_thresholds_not_strictly_increasing_are_refused() -> void:
	assert_str(_error_of(_block_with("thresholds", [300, 200]))).contains("strictly increasing")
	assert_str(_error_of(_block_with("thresholds", [200, 200]))).contains("strictly increasing")


func test_thresholds_that_are_not_whole_numbers_are_refused() -> void:
	assert_str(_error_of(_block_with("thresholds", [200.5]))).contains("thresholds must be integers")
	assert_str(_error_of(_block_with("thresholds", []))).contains("thresholds must be a non-empty array")
	assert_str(_error_of(_block_with("thresholds", "200"))).contains("thresholds must be a non-empty array")


func test_invalid_multipliers_are_refused() -> void:
	assert_str(_error_of(_block_with("self_multiplier", "3,4"))).contains("self_multiplier")
	assert_str(_error_of(_block_with("squad_multiplier", "0"))).contains("squad_multiplier")
	assert_str(_error_of(_block_with("cost_level_multiplier", 10))).contains("cost_level_multiplier")
	assert_str(_error_of(_block_with("squad_until_threshold", -1))).contains("squad_until_threshold")


func test_invalid_block_leaves_no_threshold() -> void:
	# Arrange: valid thresholds, then an invalid multiplier read after them
	var block: Dictionary = _block_with("self_multiplier", "abc")

	# Act
	var rules: AwakeningRules = AwakeningRules.from_block(block)

	# Assert
	assert_bool(rules.is_valid()).is_false()
	assert_bool(rules.is_enabled()).is_false()
	assert_int(rules.threshold_count()).is_equal(0)


func test_malformed_block_is_refused() -> void:
	# Arrange
	var missing: Dictionary = DESIGN_BLOCK.duplicate(true)
	missing.erase("self_multiplier")

	# Act / Assert
	assert_str(_error_of("yes")).contains("'awakening' must be an object")
	assert_str(_error_of(missing)).contains("self_multiplier")
	assert_bool(Combat.from_data(_curves_data(), _roster(missing)).is_valid()).is_false()
