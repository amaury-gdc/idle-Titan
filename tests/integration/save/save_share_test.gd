extends GdUnitTestSuite
## Integration tests for the player's save tools: the reset, the text export and the confirmation
## of the save screen. Writes real files under user:// with test-only names and removes them.

const GAME_PATH: String = "user://test_share_game.json"
const PERMANENT_PATH: String = "user://test_share_permanent.json"
const TEST_FILES: PackedStringArray = [
	"test_share_game.json",
	"test_share_game.json.bak",
	"test_share_permanent.json",
	"test_share_permanent.json.bak",
]
const VERSION: String = "1.2.3"
const OLD_STAGE: int = 42

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


# Saves an advanced game twice, so that the ".bak" files hold it too.
func _save_old_game() -> void:
	var game: GameState = GameState.new()
	game.stage = OLD_STAGE
	var permanent: PermanentState = PermanentState.new()
	permanent.talents = {"click_1": 1}
	assert_bool(_saves.save(game, permanent)).is_true()
	assert_bool(_saves.save(game, permanent)).is_true()


func _make_screen() -> SaveScreen:
	var screen: SaveScreen = auto_free((load("res://src/ui/save_screen.tscn") as PackedScene).instantiate())
	add_child(screen)
	screen.setup(VERSION)
	screen.open()
	return screen


func _button(screen: SaveScreen, node_name: String) -> Button:
	return screen.find_child(node_name, true, false)


# Reset

func test_reset_gives_fresh_saves() -> void:
	# Arrange
	_save_old_game()

	# Act
	var done: bool = _saves.reset()

	# Assert
	assert_bool(done).is_true()
	assert_int(_saves.load_game().stage).is_equal(GameState.new().stage)
	assert_int(_saves.load_permanent().talents.size()).is_equal(0)


func test_reset_leaves_no_old_save_in_the_backups() -> void:
	# Arrange
	_save_old_game()

	# Act: with the main files broken, the load falls back on the ".bak" files
	_saves.reset()
	_write_raw(GAME_PATH, "not json")
	_write_raw(PERMANENT_PATH, "not json")

	# Assert
	assert_int(_saves.load_game().stage).is_equal(GameState.new().stage)
	assert_int(_saves.load_permanent().talents.size()).is_equal(0)


# Export

func test_export_holds_the_version_and_both_saves() -> void:
	# Arrange
	_save_old_game()

	# Act
	var parsed: Variant = JSON.parse_string(_saves.export_text(VERSION))

	# Assert
	assert_str(parsed["game_version"]).is_equal(VERSION)
	assert_int(int(parsed["game"]["stage"])).is_equal(OLD_STAGE)
	assert_bool((parsed["permanent"]["talents"] as Dictionary).has("click_1")).is_true()


func test_export_keeps_the_saved_text_exact() -> void:
	# Arrange: a number that a JSON parse would round
	_write_raw(GAME_PATH, '{"big":12345678901234567}')
	_write_raw(PERMANENT_PATH, '{"version":5}')

	# Act
	var text: String = _saves.export_text(VERSION)

	# Assert
	assert_str(text).is_equal('{"game_version":"1.2.3","game":{"big":12345678901234567},"permanent":{"version":5}}')


func test_export_without_saves_gives_empty_objects() -> void:
	# Arrange: before_test removed every test file

	# Act
	var parsed: Variant = JSON.parse_string(_saves.export_text(VERSION))

	# Assert
	assert_int((parsed["game"] as Dictionary).size()).is_equal(0)
	assert_int((parsed["permanent"] as Dictionary).size()).is_equal(0)


func test_export_uses_the_backup_of_a_corrupt_save() -> void:
	# Arrange
	_save_old_game()
	_write_raw(GAME_PATH, "not json")

	# Act
	var parsed: Variant = JSON.parse_string(_saves.export_text(VERSION))

	# Assert
	assert_int(int(parsed["game"]["stage"])).is_equal(OLD_STAGE)


func test_export_escapes_the_version() -> void:
	# Arrange
	var version: String = 'a"b'

	# Act
	var parsed: Variant = JSON.parse_string(_saves.export_text(version))

	# Assert
	assert_str(parsed["game_version"]).is_equal(version)


# Save screen

func test_reset_button_alone_erases_nothing() -> void:
	# Arrange
	var screen: SaveScreen = _make_screen()
	var confirmed: Array[bool] = []
	screen.reset_confirmed.connect(func() -> void: confirmed.append(true))

	# Act
	_button(screen, "ResetButton").pressed.emit()

	# Assert
	assert_int(confirmed.size()).is_equal(0)
	assert_bool(_button(screen, "ConfirmButton").is_visible_in_tree()).is_true()


func test_confirmation_starts_on_the_safe_answer() -> void:
	# Arrange
	var screen: SaveScreen = _make_screen()

	# Act
	_button(screen, "ResetButton").pressed.emit()

	# Assert
	assert_object(get_viewport().gui_get_focus_owner()).is_same(_button(screen, "CancelButton"))


func test_confirm_button_asks_for_the_reset() -> void:
	# Arrange
	var screen: SaveScreen = _make_screen()
	var confirmed: Array[bool] = []
	screen.reset_confirmed.connect(func() -> void: confirmed.append(true))
	_button(screen, "ResetButton").pressed.emit()

	# Act
	_button(screen, "ConfirmButton").pressed.emit()

	# Assert
	assert_int(confirmed.size()).is_equal(1)


func test_cancel_goes_back_without_a_reset() -> void:
	# Arrange
	var screen: SaveScreen = _make_screen()
	var confirmed: Array[bool] = []
	screen.reset_confirmed.connect(func() -> void: confirmed.append(true))
	_button(screen, "ResetButton").pressed.emit()

	# Act
	_button(screen, "CancelButton").pressed.emit()

	# Assert
	assert_int(confirmed.size()).is_equal(0)
	assert_bool(_button(screen, "ConfirmButton").is_visible_in_tree()).is_false()
	assert_bool(_button(screen, "ResetButton").is_visible_in_tree()).is_true()


func test_reopening_forgets_the_confirmation_and_the_text() -> void:
	# Arrange
	var screen: SaveScreen = _make_screen()
	_button(screen, "ResetButton").pressed.emit()
	screen.show_copied("texte")
	screen.close()

	# Act
	screen.open()

	# Assert
	assert_bool(_button(screen, "ConfirmButton").is_visible_in_tree()).is_false()
	assert_str((screen.find_child("SaveText", true, false) as TextEdit).text).is_empty()
