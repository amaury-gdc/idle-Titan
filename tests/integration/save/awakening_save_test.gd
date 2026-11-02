extends GdUnitTestSuite
## Integration tests of the saved awakenings (GameState.companion_awakenings): round-trip, ".bak",
## reset of the run, a save without the key, out of bounds values, and a real 0.2.1 save whose
## levels already pass several thresholds. Writes test-only files under user:// and removes them.
## Story: production/epics/idle-titans/story-016-awakening.md.

const GAME_PATH: String = "user://test_awakening_game.json"
const PERMANENT_PATH: String = "user://test_awakening_permanent.json"
const TEST_FILES: PackedStringArray = [
	"test_awakening_game.json",
	"test_awakening_game.json.bak",
	"test_awakening_permanent.json",
	"test_awakening_permanent.json.bak",
]
## The block of design/economy-rework.md "Éveil", injected in memory into the real roster.
const DESIGN_BLOCK: Dictionary = {
	"thresholds": [200, 300, 400, 500, 600, 700, 800, 900, 1000],
	"self_multiplier": "3.4",
	"squad_multiplier": "2.10",
	"squad_until_threshold": 600,
	"cost_level_multiplier": "10",
}
const THRESHOLD_COUNT: int = 9
## A 0.2.1 save as the game wrote it, before the awakening existed.
const SAVE_0_2_1: String = '{"stage":231,"max_stage_reached":231,"farming":false,"gold":"1000000000000000000000000000000000000000","companion_levels":{"scout":409,"spearman":365,"archer":321,"guardian":276,"mage":232,"knight":188,"alchemist":144,"dragon":100},"last_saved_unix":1761000000,"skill_timers":{}}'
## Thresholds already passed by that save: scout 3 (200, 300, 400), spearman 2, archer 2, guardian 1,
## mage 1, the others none.
const ELIGIBLE_IN_SAVE_0_2_1: Dictionary = {"scout": 3, "spearman": 2, "archer": 2, "guardian": 1, "mage": 1, "knight": 0, "alchemist": 0, "dragon": 0}
const ELIGIBLE_TOTAL: int = 9

var _saves: SaveManager


func before_test() -> void:
	_remove_test_files()
	_saves = SaveManager.new(GAME_PATH, PERMANENT_PATH)


func after_test() -> void:
	_remove_test_files()


func _remove_test_files() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	for file_name: String in TEST_FILES:
		if dir.file_exists(file_name):
			dir.remove(file_name)


func _write_raw(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _game_with(awakenings: Dictionary) -> GameState:
	var game: GameState = GameState.new()
	game.companion_levels = {"scout": 420, "archer": 310}
	game.companion_awakenings = awakenings.duplicate()
	return game


func _real_combat() -> Combat:
	var roster: Dictionary = DataLoader.load_json("res://assets/data/companions_roster.json")
	roster["awakening"] = DESIGN_BLOCK.duplicate(true)
	var combat: Combat = Combat.from_data(DataLoader.load_json("res://assets/data/core_curves.json"), roster)
	assert_str(combat.get_error()).is_empty()
	return combat


func test_awakenings_survive_a_save_and_a_load() -> void:
	# Arrange
	_saves.save(_game_with({"scout": 3, "archer": 2}), PermanentState.new())

	# Act
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_dict(loaded.companion_awakenings).is_equal({"scout": 3, "archer": 2})
	assert_dict(loaded.companion_levels).is_equal({"scout": 420, "archer": 310})


func test_corrupt_save_falls_back_to_the_awakenings_of_the_bak() -> void:
	# Arrange: the first save becomes the .bak, then the main file is corrupted
	_saves.save(_game_with({"scout": 1}), PermanentState.new())
	_saves.save(_game_with({"scout": 2}), PermanentState.new())
	_write_raw(GAME_PATH, "{ not json")

	# Act
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_dict(loaded.companion_awakenings).is_equal({"scout": 1})


func test_reset_of_the_run_clears_the_awakenings() -> void:
	# Arrange
	var game: GameState = _game_with({"scout": 3})
	_saves.save(game, PermanentState.new())

	# Act
	game.reset()
	_saves.reset()

	# Assert
	assert_dict(game.companion_awakenings).is_empty()
	assert_dict(_saves.load_game().companion_awakenings).is_empty()


func test_save_without_the_key_has_no_awakening() -> void:
	# Arrange
	var payload: Dictionary = {"stage": 40, "gold": "5", "companion_levels": {"scout": 250}}

	# Act
	var loaded: GameState = GameState.from_dict(payload)

	# Assert
	assert_dict(loaded.companion_awakenings).is_empty()
	assert_dict(loaded.to_dict()["companion_awakenings"]).is_empty()


func test_out_of_bounds_values_are_kept_within_bounds() -> void:
	# Arrange: negative, huge, not a number, a string, a non-string key, a whole float
	var payload: Dictionary = {"companion_awakenings": {"scout": -3, "archer": 1e30, "mage": NAN, "knight": "2", 7: 1, "dragon": 2.0}}

	# Act
	var loaded: GameState = GameState.from_dict(payload)

	# Assert
	assert_dict(loaded.companion_awakenings).is_equal({"scout": 0, "archer": AwakeningRules.MAX_THRESHOLDS, "dragon": 2})


func test_a_saved_count_above_the_thresholds_of_the_data_counts_as_all_of_them() -> void:
	# Arrange
	var state: GameState = GameState.from_dict({"companion_levels": {"scout": 1200}, "companion_awakenings": {"scout": 50}})
	var combat: Combat = _real_combat()

	# Act
	var counted: int = combat.awakening_count(state.companion_awakenings, "scout")

	# Assert
	assert_int(state.companion_awakenings["scout"]).is_equal(50)
	assert_int(counted).is_equal(THRESHOLD_COUNT)


func test_real_0_2_1_save_keeps_its_levels_and_pays_its_nine_eligible_awakenings() -> void:
	# Arrange
	_write_raw(GAME_PATH, SAVE_0_2_1)
	var state: GameState = _saves.load_game()
	var combat: Combat = _real_combat()
	var companions: CompanionManager = CompanionManager.new(state, combat, FloorManager.new(state, combat))
	var levels_before: Dictionary = state.companion_levels.duplicate()
	var gold_before: BigNumber = state.gold
	var blocked: Array[String] = []
	for companion: Companion in companions.companions():
		if not companions.can_buy(companion.id):
			blocked.append(companion.id)

	# Act: the player pays every awakening they can, in order
	var paid: BigNumber = BigNumber.new()
	var count: int = 0
	var awoke: bool = true
	while awoke:
		awoke = false
		for companion: Companion in companions.companions():
			var next: Dictionary = companions.next_awakening(companion.id)
			if companions.awaken(companion.id):
				paid = paid.add(next["cost"])
				count += 1
				awoke = true

	# Assert: nothing offered, levels kept, nine paid awakenings, the others free to level
	assert_dict(levels_before).is_equal({"scout": 409, "spearman": 365, "archer": 321, "guardian": 276, "mage": 232, "knight": 188, "alchemist": 144, "dragon": 100})
	assert_array(blocked).is_equal(["scout", "spearman", "archer", "guardian", "mage"])
	assert_int(count).is_equal(ELIGIBLE_TOTAL)
	assert_dict(state.companion_levels).is_equal(levels_before)
	for id: String in ELIGIBLE_IN_SAVE_0_2_1:
		assert_int(companions.awakenings(id)).is_equal(ELIGIBLE_IN_SAVE_0_2_1[id])
		assert_bool(companions.can_buy(id)).is_true()
	assert_str(state.gold.to_decimal_string()).is_equal(gold_before.subtract(paid).to_decimal_string())
	assert_bool(paid.is_zero()).is_false()
	assert_int(companions.buyable_levels_cap("scout")).is_equal(500 - 409)
