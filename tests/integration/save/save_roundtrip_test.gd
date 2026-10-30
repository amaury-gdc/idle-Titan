extends GdUnitTestSuite
## Integration tests for SaveManager: round-trip, missing file, corrupt file,
## .bak fallback and state separation. Writes real files under user:// with
## test-only names and removes them after each test.
## Story: production/epics/idle-titans/story-001-data-state-save.md

const GAME_PATH: String = "user://test_save_game.json"
const PERMANENT_PATH: String = "user://test_save_permanent.json"
const TEST_FILES: PackedStringArray = [
	"test_save_game.json",
	"test_save_game.json.bak",
	"test_save_permanent.json",
	"test_save_permanent.json.bak",
]

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


func _make_game(stage: int, gold: String) -> GameState:
	var game: GameState = GameState.new()
	game.stage = stage
	game.gold = BigNumber.from_string(gold)
	game.companion_levels = {"archer": 4, "mage": 1}
	return game


func _make_permanent(points: int) -> PermanentState:
	var permanent: PermanentState = PermanentState.new()
	permanent.talent_points = points
	permanent.talents = {"click_power": 2}
	return permanent


# --- round-trip ------------------------------------------------------------

func test_save_returns_true_when_both_files_are_written() -> void:
	# Arrange
	var game: GameState = _make_game(10, "1500")
	var permanent: PermanentState = _make_permanent(3)

	# Act
	var ok: bool = _saves.save(game, permanent)

	# Assert
	assert_bool(ok).is_true()


func test_save_then_load_game_restores_identical_state() -> void:
	# Arrange: gold above int64 must survive exactly
	var game: GameState = _make_game(10, "123456789012345678901234567890")
	_saves.save(game, _make_permanent(3))

	# Act
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_int(loaded.stage).is_equal(10)
	assert_str(loaded.gold.to_decimal_string()).is_equal("123456789012345678901234567890")
	assert_int(loaded.companion_levels["archer"]).is_equal(4)
	assert_int(loaded.companion_levels["mage"]).is_equal(1)
	assert_int(loaded.companion_levels.size()).is_equal(2)


func test_save_then_load_game_keeps_max_stage_above_current_stage() -> void:
	# Arrange: the player fell back from stage 12 to stage 9
	var game: GameState = _make_game(9, "1500")
	game.max_stage_reached = 12
	_saves.save(game, _make_permanent(3))

	# Act
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_int(loaded.stage).is_equal(9)
	assert_int(loaded.max_stage_reached).is_equal(12)


func test_save_then_load_permanent_restores_identical_state() -> void:
	# Arrange
	_saves.save(_make_game(10, "1500"), _make_permanent(3))

	# Act
	var loaded: PermanentState = _saves.load_permanent()

	# Assert
	assert_int(loaded.talent_points).is_equal(3)
	assert_int(loaded.talents["click_power"]).is_equal(2)
	assert_int(loaded.talents.size()).is_equal(1)


func test_game_and_permanent_states_are_stored_in_separate_files() -> void:
	# Arrange / Act
	_saves.save(_make_game(10, "1500"), _make_permanent(3))

	# Assert
	assert_bool(FileAccess.file_exists(GAME_PATH)).is_true()
	assert_bool(FileAccess.file_exists(PERMANENT_PATH)).is_true()
	assert_str(FileAccess.get_file_as_string(GAME_PATH)).not_contains("talent_points")
	assert_str(FileAccess.get_file_as_string(PERMANENT_PATH)).not_contains("companion_levels")


func test_game_state_reset_after_load_leaves_permanent_state_untouched() -> void:
	# Arrange
	_saves.save(_make_game(10, "1500"), _make_permanent(7))
	var game: GameState = _saves.load_game()
	var permanent: PermanentState = _saves.load_permanent()

	# Act
	game.reset()

	# Assert
	assert_int(game.stage).is_equal(1)
	assert_bool(game.gold.is_zero()).is_true()
	assert_int(permanent.talent_points).is_equal(7)


func test_saving_again_overwrites_the_previous_values() -> void:
	# Arrange
	_saves.save(_make_game(10, "1500"), _make_permanent(3))

	# Act
	_saves.save(_make_game(25, "99"), _make_permanent(5))
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_int(loaded.stage).is_equal(25)
	assert_str(loaded.gold.to_decimal_string()).is_equal("99")


# --- missing file ----------------------------------------------------------

func test_load_game_returns_fresh_state_when_file_is_missing() -> void:
	# Arrange: before_test removed every test file

	# Act
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_int(loaded.stage).is_equal(1)
	assert_bool(loaded.gold.is_zero()).is_true()
	assert_int(loaded.companion_levels.size()).is_equal(0)


func test_load_permanent_returns_fresh_state_when_file_is_missing() -> void:
	# Arrange: before_test removed every test file

	# Act
	var loaded: PermanentState = _saves.load_permanent()

	# Assert
	assert_int(loaded.talent_points).is_equal(0)
	assert_int(loaded.talents.size()).is_equal(0)


func test_missing_game_file_does_not_affect_permanent_load() -> void:
	# Arrange: only the permanent state was ever saved
	_saves.save_permanent(_make_permanent(4))

	# Act
	var game: GameState = _saves.load_game()
	var permanent: PermanentState = _saves.load_permanent()

	# Assert
	assert_int(game.stage).is_equal(1)
	assert_int(permanent.talent_points).is_equal(4)


# --- corrupt file ----------------------------------------------------------

func test_load_game_returns_fresh_state_when_file_is_not_valid_json() -> void:
	# Arrange
	_write_raw(GAME_PATH, "{not json")

	# Act
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_int(loaded.stage).is_equal(1)
	assert_bool(loaded.gold.is_zero()).is_true()


func test_load_game_returns_fresh_state_when_json_is_not_an_object() -> void:
	# Arrange
	_write_raw(GAME_PATH, "[1, 2, 3]")

	# Act
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_int(loaded.stage).is_equal(1)


func test_load_game_returns_fresh_state_when_file_is_empty() -> void:
	# Arrange
	_write_raw(GAME_PATH, "")

	# Act
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_int(loaded.stage).is_equal(1)


func test_load_game_defaults_invalid_fields_inside_a_valid_object() -> void:
	# Arrange: valid JSON object with a bad stage, bad gold and bad levels
	_write_raw(GAME_PATH, '{"stage": "ten", "gold": "12x", "companion_levels": []}')

	# Act
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_int(loaded.stage).is_equal(1)
	assert_bool(loaded.gold.is_zero()).is_true()
	assert_int(loaded.companion_levels.size()).is_equal(0)


func test_load_game_defaults_max_stage_to_saved_stage_when_field_is_missing() -> void:
	# Arrange: a save written before max_stage_reached existed
	_write_raw(GAME_PATH, '{"stage": 14, "gold": "1500", "companion_levels": {}}')

	# Act
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_int(loaded.stage).is_equal(14)
	assert_int(loaded.max_stage_reached).is_equal(14)


func test_load_game_defaults_max_stage_to_saved_stage_when_field_is_invalid() -> void:
	# Arrange
	_write_raw(GAME_PATH, '{"stage": 14, "max_stage_reached": "high"}')

	# Act
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_int(loaded.max_stage_reached).is_equal(14)


func test_load_game_raises_max_stage_to_stage_when_saved_value_is_lower() -> void:
	# Arrange
	_write_raw(GAME_PATH, '{"stage": 14, "max_stage_reached": 3}')

	# Act
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_int(loaded.max_stage_reached).is_equal(14)


func test_load_permanent_returns_fresh_state_when_file_is_corrupt() -> void:
	# Arrange
	_write_raw(PERMANENT_PATH, "<<<corrupt>>>")

	# Act
	var loaded: PermanentState = _saves.load_permanent()

	# Assert
	assert_int(loaded.talent_points).is_equal(0)


# --- .bak fallback ---------------------------------------------------------

func test_first_save_creates_no_backup() -> void:
	# Arrange / Act
	_saves.save(_make_game(10, "1500"), _make_permanent(3))

	# Assert
	assert_bool(FileAccess.file_exists(GAME_PATH + ".bak")).is_false()
	assert_bool(FileAccess.file_exists(PERMANENT_PATH + ".bak")).is_false()


func test_second_save_keeps_previous_valid_save_as_backup() -> void:
	# Arrange
	_saves.save(_make_game(10, "1500"), _make_permanent(3))

	# Act
	_saves.save(_make_game(25, "99"), _make_permanent(5))

	# Assert
	assert_bool(FileAccess.file_exists(GAME_PATH + ".bak")).is_true()
	assert_bool(FileAccess.file_exists(PERMANENT_PATH + ".bak")).is_true()


func test_load_game_falls_back_to_backup_when_main_file_is_corrupt() -> void:
	# Arrange: two saves so a .bak holds stage 10, then the main file is corrupted
	_saves.save(_make_game(10, "1500"), _make_permanent(3))
	_saves.save(_make_game(25, "99"), _make_permanent(5))
	_write_raw(GAME_PATH, "{broken")

	# Act
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_int(loaded.stage).is_equal(10)
	assert_str(loaded.gold.to_decimal_string()).is_equal("1500")


func test_load_game_falls_back_to_backup_when_main_file_is_missing() -> void:
	# Arrange
	_saves.save(_make_game(10, "1500"), _make_permanent(3))
	_saves.save(_make_game(25, "99"), _make_permanent(5))
	var dir: DirAccess = DirAccess.open("user://")
	dir.remove("test_save_game.json")

	# Act
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_int(loaded.stage).is_equal(10)


func test_load_game_returns_fresh_state_when_main_and_backup_are_both_corrupt() -> void:
	# Arrange
	_write_raw(GAME_PATH, "{broken")
	_write_raw(GAME_PATH + ".bak", "also broken")

	# Act
	var loaded: GameState = _saves.load_game()

	# Assert
	assert_int(loaded.stage).is_equal(1)
	assert_bool(loaded.gold.is_zero()).is_true()


func test_saving_over_a_corrupt_main_file_keeps_the_last_valid_backup() -> void:
	# Arrange: two saves, so .bak holds stage 10; then the main file is corrupted
	_saves.save(_make_game(10, "1500"), _make_permanent(3))
	_saves.save(_make_game(25, "99"), _make_permanent(5))
	_write_raw(GAME_PATH, "{broken")

	# Act: saving over the corrupt main must not copy it over the good .bak,
	# then the new main is corrupted again so the load must use the .bak
	_saves.save(_make_game(40, "7"), _make_permanent(6))
	_write_raw(GAME_PATH, "{broken again")
	var loaded: GameState = _saves.load_game()

	# Assert: the .bak still holds stage 10 (the last valid save before the corruption)
	assert_int(loaded.stage).is_equal(10)


func test_save_writes_both_files_even_when_the_game_path_is_unwritable() -> void:
	# Arrange: a game path inside a directory that does not exist
	var saves: SaveManager = SaveManager.new("user://missing_dir_for_tests/game.json", PERMANENT_PATH)

	# Act
	var ok: bool = saves.save(_make_game(10, "1500"), _make_permanent(3))

	# Assert: the game write failed, the permanent write still happened
	assert_bool(ok).is_false()
	assert_bool(FileAccess.file_exists(PERMANENT_PATH)).is_true()
