extends GdUnitTestSuite
## Unit tests for the choices kept in [DisplaySettings] by story 010: "never set" for the effects,
## so that prefers-reduced-motion can decide the first run, and the x1 / x10 / Max / Palier choice.
## Stories: production/epics/idle-titans/story-010-adaptive-layout.md, story-013-companion-touch-ups.md.

const SETTINGS_PATH: String = "user://display_choices_test.cfg"


func before_test() -> void:
	DirAccess.remove_absolute(SETTINGS_PATH)


func after_test() -> void:
	DirAccess.remove_absolute(SETTINGS_PATH)


func _write(value_text: String, key: String) -> void:
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	file.store_string("[%s]\n%s=%s\n" % [DisplaySettings.SECTION, key, value_text])
	file.close()


func test_effects_never_set_has_no_choice() -> void:
	assert_bool(DisplaySettings.new(SETTINGS_PATH).has_visual_effects_choice()).is_false()


func test_effects_never_set_follows_the_argument() -> void:
	var settings: DisplaySettings = DisplaySettings.new(SETTINGS_PATH)
	assert_bool(settings.visual_effects(false)).is_false()
	assert_bool(settings.visual_effects(true)).is_true()


func test_effects_explicit_choice_wins_over_the_argument() -> void:
	DisplaySettings.new(SETTINGS_PATH).set_visual_effects(true)
	var reloaded: DisplaySettings = DisplaySettings.new(SETTINGS_PATH)
	assert_bool(reloaded.has_visual_effects_choice()).is_true()
	assert_bool(reloaded.visual_effects(false)).is_true()


func test_effects_explicit_off_wins_too() -> void:
	DisplaySettings.new(SETTINGS_PATH).set_visual_effects(false)
	assert_bool(DisplaySettings.new(SETTINGS_PATH).visual_effects(true)).is_false()


func test_effects_malformed_value_is_not_a_choice() -> void:
	_write("\"no\"", DisplaySettings.KEY_VISUAL_EFFECTS)
	var settings: DisplaySettings = DisplaySettings.new(SETTINGS_PATH)
	assert_bool(settings.has_visual_effects_choice()).is_false()
	assert_bool(settings.visual_effects(false)).is_false()


func test_buy_mode_defaults_to_x1() -> void:
	assert_int(DisplaySettings.new(SETTINGS_PATH).buy_mode()).is_equal(BuyQuote.Mode.ONE)


func test_buy_mode_survives_a_reload() -> void:
	DisplaySettings.new(SETTINGS_PATH).set_buy_mode(BuyQuote.Mode.MAX)
	assert_int(DisplaySettings.new(SETTINGS_PATH).buy_mode()).is_equal(BuyQuote.Mode.MAX)


func test_buy_mode_tier_survives_a_reload() -> void:
	DisplaySettings.new(SETTINGS_PATH).set_buy_mode(BuyQuote.Mode.TIER)
	assert_int(DisplaySettings.new(SETTINGS_PATH).buy_mode()).is_equal(BuyQuote.Mode.TIER)


func test_buy_mode_stored_before_the_tier_segment_stays_valid() -> void:
	_write("2", DisplaySettings.KEY_BUY_MODE)
	assert_int(DisplaySettings.new(SETTINGS_PATH).buy_mode()).is_equal(BuyQuote.Mode.MAX)


func test_buy_mode_out_of_range_is_the_default() -> void:
	_write("4", DisplaySettings.KEY_BUY_MODE)
	assert_int(DisplaySettings.new(SETTINGS_PATH).buy_mode()).is_equal(BuyQuote.Mode.ONE)


func test_buy_mode_of_the_wrong_type_is_the_default() -> void:
	_write("\"max\"", DisplaySettings.KEY_BUY_MODE)
	assert_int(DisplaySettings.new(SETTINGS_PATH).buy_mode()).is_equal(BuyQuote.Mode.ONE)


func test_buy_mode_count_matches_the_selector() -> void:
	assert_int(DisplaySettings.BUY_MODE_COUNT).is_equal(BuyQuote.MODE_COUNT)


func test_saving_the_buy_mode_keeps_the_effects_choice() -> void:
	var settings: DisplaySettings = DisplaySettings.new(SETTINGS_PATH)
	settings.set_visual_effects(false)
	settings.set_buy_mode(BuyQuote.Mode.TEN)
	assert_bool(DisplaySettings.new(SETTINGS_PATH).visual_effects()).is_false()
