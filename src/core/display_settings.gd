class_name DisplaySettings
extends RefCounted
## Display preferences of the player, kept in a small file of their own (story 009), apart from
## the game saves: it is NOT part of [GameState], [PermanentState] or the text of "Copier ma
## sauvegarde", and "Réinitialiser ma sauvegarde" does not touch it. It holds "Effets visuels"
## (floating numbers, companion spheres and balls, monster squash), on by default, and the x1 /
## x10 / Max / Palier choice of the companion list (stories 010, 013), x1 by default, and whether
## the sentence of the first awakening was already shown (story 017), not by default.
## An absent, unreadable or malformed file means the default. The path can be injected for tests.
## Single-thread only.
##
## "Never set" is a state of its own: an explicit choice is the only thing written, so
## [method has_visual_effects_choice] can tell it from a default, and the first run can follow the
## browser's prefers-reduced-motion through the argument of [method visual_effects].
##
## Usage:
## [codeblock]
## var settings: DisplaySettings = DisplaySettings.new()   # reads user://settings.cfg
## if settings.visual_effects():
##     print("effects on")
## settings.set_visual_effects(false)                      # written at once
## settings.set_buy_mode(2)                                # BuyQuote.Mode.MAX, written at once
## [/codeblock]

## Default location of the file (browser storage on the web, like the saves).
const DEFAULT_PATH: String = "user://settings.cfg"
const SECTION: String = "display"
const KEY_VISUAL_EFFECTS: String = "visual_effects"
const KEY_BUY_MODE: String = "buy_mode"
const KEY_AWAKENING_INTRO_SEEN: String = "awakening_intro_seen"
## Stored values of the buy mode go from 0 to this, excluded: a [enum BuyQuote.Mode], kept as a
## number here so that this file depends on nothing in the interface.
const BUY_MODE_COUNT: int = 4

var _path: String
var _config: ConfigFile = ConfigFile.new()


## Reads [param path]; any problem leaves the defaults.
func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	if _config.load(path) != OK:
		_config.clear()


## True when the visual effects are on. [param when_never_set] is the answer while the player has
## made no choice, or when the stored value is malformed.
func visual_effects(when_never_set: bool = true) -> bool:
	var value: Variant = _config.get_value(SECTION, KEY_VISUAL_EFFECTS, when_never_set)
	return value if value is bool else when_never_set


## True when the player chose the visual effects, on or off, at some point.
func has_visual_effects_choice() -> bool:
	# get_value with a null default reports an engine error on a missing key.
	return _config.has_section_key(SECTION, KEY_VISUAL_EFFECTS) and _config.get_value(SECTION, KEY_VISUAL_EFFECTS) is bool


## The chosen buy mode, a [enum BuyQuote.Mode] value (default 0, x1). A value out of range counts
## as the default.
func buy_mode() -> int:
	var value: Variant = _config.get_value(SECTION, KEY_BUY_MODE, 0)
	return value if value is int and value >= 0 and value < BUY_MODE_COUNT else 0


## Keeps [param mode] and writes the file at once. Returns false when the file could not be
## written; the new value still counts until the game closes.
func set_buy_mode(mode: int) -> bool:
	_config.set_value(SECTION, KEY_BUY_MODE, mode)
	return _config.save(_path) == OK


## True once the sentence of the first awakening has been shown (story 017): it is shown once per
## player, so this flag outlives a reload and a reset of the save. A malformed value counts as not
## seen.
## [codeblock]
## if not settings.awakening_intro_seen():
##     settings.mark_awakening_intro_seen()
##     show_sentence()
## [/codeblock]
func awakening_intro_seen() -> bool:
	var value: Variant = _config.get_value(SECTION, KEY_AWAKENING_INTRO_SEEN, false)
	return value is bool and value


## Keeps that the sentence of the first awakening was shown and writes the file at once. Returns
## false when the file could not be written; the flag still counts until the game closes.
func mark_awakening_intro_seen() -> bool:
	_config.set_value(SECTION, KEY_AWAKENING_INTRO_SEEN, true)
	return _config.save(_path) == OK


## Turns the visual effects on or off and writes the file at once. Returns false when the file
## could not be written; the new value still counts until the game closes.
func set_visual_effects(enabled: bool) -> bool:
	_config.set_value(SECTION, KEY_VISUAL_EFFECTS, enabled)
	return _config.save(_path) == OK
