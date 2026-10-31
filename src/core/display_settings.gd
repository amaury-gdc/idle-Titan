class_name DisplaySettings
extends RefCounted
## Display preferences of the player, kept in a small file of their own (story 009), apart from
## the game saves: it is NOT part of [GameState], [PermanentState] or the text of "Copier ma
## sauvegarde", and "Réinitialiser ma sauvegarde" does not touch it. Today it holds one
## boolean, "Effets visuels" (floating numbers, companion spheres and balls), on by default.
## An absent, unreadable or malformed file means the default. The path can be injected for tests.
## Single-thread only.
##
## Usage:
## [codeblock]
## var settings: DisplaySettings = DisplaySettings.new()   # reads user://settings.cfg
## if settings.visual_effects():
##     print("effects on")
## settings.set_visual_effects(false)                      # written at once
## [/codeblock]

## Default location of the file (browser storage on the web, like the saves).
const DEFAULT_PATH: String = "user://settings.cfg"
const SECTION: String = "display"
const KEY_VISUAL_EFFECTS: String = "visual_effects"

var _path: String
var _config: ConfigFile = ConfigFile.new()


## Reads [param path]; any problem leaves the defaults.
func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	if _config.load(path) != OK:
		_config.clear()


## True when the visual effects are on (default true).
func visual_effects() -> bool:
	var value: Variant = _config.get_value(SECTION, KEY_VISUAL_EFFECTS, true)
	return value if value is bool else true


## Turns the visual effects on or off and writes the file at once. Returns false when the file
## could not be written; the new value still counts until the game closes.
func set_visual_effects(enabled: bool) -> bool:
	_config.set_value(SECTION, KEY_VISUAL_EFFECTS, enabled)
	return _config.save(_path) == OK
