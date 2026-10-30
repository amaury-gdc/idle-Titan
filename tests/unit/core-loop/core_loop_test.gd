extends GdUnitTestSuite
## Unit tests for max_stage_reached tracking in FloorManager and GameState.
## Story: production/epics/idle-titans/story-002-core-loop.md


func _make_combat() -> Combat:
	# One click kills: enemies have 1 HP at every stage.
	var curves: Dictionary = {
		"schema_version": 2,
		"enemy_hp_base": "1",
		"enemy_hp_growth": "1",
		"gold_per_kill_base": "1",
		"gold_per_kill_growth": "1",
		"click_damage_base": "1",
		"click_companion_power_factor": "0",
	}
	var roster: Dictionary = {"schema_version": 1, "companions": []}
	return Combat.from_data(curves, roster)


func test_kill_at_highest_stage_raises_max_stage_reached() -> void:
	# Arrange
	var state: GameState = GameState.new()
	var floors: FloorManager = FloorManager.new(state, _make_combat())

	# Act
	floors.click()
	floors.click()

	# Assert
	assert_int(state.stage).is_equal(3)
	assert_int(state.max_stage_reached).is_equal(3)


func test_kill_below_highest_stage_keeps_max_stage_reached() -> void:
	# Arrange: the player is back at stage 3 after reaching stage 10
	var state: GameState = GameState.new()
	state.stage = 3
	state.max_stage_reached = 10
	var floors: FloorManager = FloorManager.new(state, _make_combat())

	# Act
	floors.click()

	# Assert
	assert_int(state.stage).is_equal(4)
	assert_int(state.max_stage_reached).is_equal(10)


func test_reset_returns_max_stage_reached_to_one() -> void:
	# Arrange
	var state: GameState = GameState.new()
	state.stage = 8
	state.max_stage_reached = 12

	# Act
	state.reset()

	# Assert
	assert_int(state.max_stage_reached).is_equal(1)
