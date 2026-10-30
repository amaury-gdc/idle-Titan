extends GdUnitTestSuite
## Unit tests for the gain, cap and minimum of OfflineIncome.
## Story: production/epics/idle-titans/story-004b-offline.md

const NOW: int = 1_000_000
const MAX_HOURS: int = 12
const MAX_SECONDS: int = MAX_HOURS * 3600
const MIN_SECONDS: int = 60
const STARTING_GOLD: int = 7


func _make_offline(min_seconds: int = MIN_SECONDS) -> OfflineIncome:
	# 1 HP and 1 gold at every stage, one companion dealing 1 damage per second, so
	# the gold earned is seconds * efficiency.
	var curves: Dictionary = {
		"schema_version": Combat.SUPPORTED_CURVES_SCHEMA,
		"enemy_hp_base": "1",
		"enemy_hp_growth": "1",
		"gold_per_kill_base": "1",
		"gold_per_kill_growth": "1",
		"click_damage_base": "1",
		"click_companion_power_factor": "0",
		"cost_growth": "1.08",
		"offline_efficiency": "0.5",
		"offline_max_hours": MAX_HOURS,
		"offline_min_seconds": min_seconds,
	}
	var roster: Dictionary = {
		"schema_version": 2,
		"companions": [{
			"id": "scout",
			"name": "Scout",
			"base_cost": "10",
			"base_damage": "1",
			"cost_growth": "1.08",
			"attack_interval_seconds": 1.0,
			"tiers": [],
		}],
	}
	var offline: OfflineIncome = OfflineIncome.from_data(curves, Combat.from_data(curves, roster))
	assert_str(offline.get_error()).is_empty()
	return offline


func _make_state(last_saved_unix: int) -> GameState:
	var state: GameState = GameState.new()
	state.gold = BigNumber.from_int(STARTING_GOLD)
	state.companion_levels = {"scout": 1}
	state.last_saved_unix = last_saved_unix
	return state


func _assert_nothing_granted(gain: Dictionary, state: GameState) -> void:
	assert_bool(gain.is_empty()).is_true()
	assert_str(state.gold.to_decimal_string()).is_equal(str(STARTING_GOLD))


func test_grant_with_zero_elapsed_time_gives_nothing() -> void:
	# Arrange: no minimum, or the minimum would hide the rule under test
	var state: GameState = _make_state(NOW)

	# Act
	var gain: Dictionary = _make_offline(0).grant(state, NOW)

	# Assert
	_assert_nothing_granted(gain, state)


func test_grant_with_clock_moved_back_gives_nothing() -> void:
	# Arrange: no minimum, or the minimum would hide the rule under test
	var state: GameState = _make_state(NOW + MAX_SECONDS)
	var offline: OfflineIncome = _make_offline(0)

	# Act
	var seconds: int = offline.counted_seconds(state.last_saved_unix, NOW)
	var gain: Dictionary = offline.grant(state, NOW)

	# Assert
	assert_int(seconds).is_equal(0)
	_assert_nothing_granted(gain, state)


func test_grant_without_saved_time_gives_nothing() -> void:
	# Arrange: a save from before story 004b loads with last_saved_unix at 0
	var state: GameState = _make_state(0)

	# Act
	var gain: Dictionary = _make_offline().grant(state, NOW)

	# Assert
	_assert_nothing_granted(gain, state)


func test_grant_beyond_twelve_hours_is_capped() -> void:
	# Arrange
	var state: GameState = _make_state(NOW - MAX_SECONDS * 2)

	# Act
	var gain: Dictionary = _make_offline().grant(state, NOW)

	# Assert
	assert_int(gain["seconds"]).is_equal(MAX_SECONDS)
	assert_bool(gain["capped"]).is_true()
	assert_str((gain["gold"] as BigNumber).to_decimal_string()).is_equal(str(MAX_SECONDS / 2))
	assert_str(state.gold.to_decimal_string()).is_equal(str(STARTING_GOLD + MAX_SECONDS / 2))


func test_grant_at_exactly_twelve_hours_is_not_capped() -> void:
	# Arrange
	var state: GameState = _make_state(NOW - MAX_SECONDS)

	# Act
	var gain: Dictionary = _make_offline().grant(state, NOW)

	# Assert
	assert_int(gain["seconds"]).is_equal(MAX_SECONDS)
	assert_bool(gain["capped"]).is_false()


func test_grant_just_below_minimum_gives_nothing() -> void:
	# Arrange
	var state: GameState = _make_state(NOW - (MIN_SECONDS - 1))

	# Act
	var gain: Dictionary = _make_offline().grant(state, NOW)

	# Assert
	_assert_nothing_granted(gain, state)


func test_grant_at_exactly_minimum_gives_gold() -> void:
	# Arrange
	var state: GameState = _make_state(NOW - MIN_SECONDS)

	# Act
	var gain: Dictionary = _make_offline().grant(state, NOW)

	# Assert
	assert_int(gain["seconds"]).is_equal(MIN_SECONDS)
	assert_bool(gain["capped"]).is_false()
	assert_str((gain["gold"] as BigNumber).to_decimal_string()).is_equal(str(MIN_SECONDS / 2))


func test_second_grant_at_same_time_gives_nothing() -> void:
	# Arrange: the tab comes back twice, the absence must be paid once
	var state: GameState = _make_state(NOW - MIN_SECONDS)
	var offline: OfflineIncome = _make_offline()
	offline.grant(state, NOW)
	var gold_after_first: String = state.gold.to_decimal_string()

	# Act
	var gain: Dictionary = offline.grant(state, NOW)

	# Assert
	assert_bool(gain.is_empty()).is_true()
	assert_str(state.gold.to_decimal_string()).is_equal(gold_after_first)


func test_grant_keeps_the_stage() -> void:
	# Arrange
	var state: GameState = _make_state(NOW - MIN_SECONDS)
	state.stage = 42

	# Act
	_make_offline().grant(state, NOW)

	# Assert
	assert_int(state.stage).is_equal(42)
