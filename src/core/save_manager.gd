class_name SaveManager
extends RefCounted
## Writes/reads [GameState] and [PermanentState] as two separate JSON files in
## user://, each with a ".bak" copy of the last valid save.
## Not an autoload; construct with paths for dependency injection.
## Single-thread only.
##
## Web assumption (UNVERIFIED): on a Web export user:// is browser-backed
## storage (IndexedDB). That it persists across page reloads, and when pending
## writes are flushed (closing the tab right after a save may lose it), has not
## been tested in a browser.
##
## Each game save stamps [member GameState.last_saved_unix] with the real time (story
## 004b), read back by [OfflineIncome]. The clock can be injected for tests.
##
## Usage:
## [codeblock]
## var saves := SaveManager.new()
## saves.save(game_state, permanent_state)
## var game: GameState = saves.load_game()        # fresh state if missing/corrupt
## var perm: PermanentState = saves.load_permanent()
## [/codeblock]

var _game_path: String
var _permanent_path: String
var _clock: Callable


## [param clock] returns the current Unix time in whole seconds; left empty, the
## system clock is used.
func _init(game_path: String = "user://save_game.json", permanent_path: String = "user://save_permanent.json", clock: Callable = Callable()) -> void:
	_game_path = game_path
	_permanent_path = permanent_path
	_clock = clock


## Writes both states (always attempts both). Returns true only if both succeeded.
func save(game: GameState, permanent: PermanentState) -> bool:
	var game_ok: bool = save_game(game)
	var permanent_ok: bool = save_permanent(permanent)
	return game_ok and permanent_ok


## Stamps the real time on [param game], then writes only the game state, keeping the
## previous valid save as ".bak".
func save_game(game: GameState) -> bool:
	game.last_saved_unix = _now_unix()
	return _write(_game_path, game.to_dict())


## Writes only the permanent state, keeping the previous valid save as ".bak".
func save_permanent(permanent: PermanentState) -> bool:
	return _write(_permanent_path, permanent.to_dict())


## Loads the game state; main file, else ".bak", else a fresh state.
func load_game() -> GameState:
	return GameState.from_dict(_read_with_backup(_game_path))


## Loads the permanent state; main file, else ".bak", else a fresh state.
func load_permanent() -> PermanentState:
	return PermanentState.from_dict(_read_with_backup(_permanent_path))


func _now_unix() -> int:
	if _clock.is_valid():
		return int(_clock.call())
	return int(Time.get_unix_time_from_system())


func _write(path: String, payload: Dictionary) -> bool:
	# Keep the current file as .bak, but only if it is itself a valid save.
	var current_text: String = _read_text(path)
	if not current_text.is_empty() and not _parse_object(current_text).is_empty():
		_write_text(path + ".bak", current_text)
	return _write_text(path, JSON.stringify(payload))


func _write_text(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: cannot open '%s' for writing (error %d)" % [path, FileAccess.get_open_error()])
		return false
	var stored: bool = file.store_string(text)
	file.close()
	return stored


# Returns "" when the file is absent or cannot be opened.
func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: cannot open '%s' for reading (error %d)" % [path, FileAccess.get_open_error()])
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


# Returns {} when the text is invalid JSON or not an object.
# JSON.new().parse() returns an Error silently; parse_string() logs an engine error.
func _parse_object(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


func _read_with_backup(path: String) -> Dictionary:
	var data: Dictionary = _parse_object(_read_text(path))
	if data.is_empty():
		data = _parse_object(_read_text(path + ".bak"))
	return data
