extends GdUnitTestSuite
## Unit tests for the toggles that came to "Réglages" with the mobile redesign: "Défi auto" (it left
## the main screen) and "Plein écran" (shown only where the browser allows it, its label following
## the real state, including a full screen left with the back gesture or Escape).
## Story: production/epics/idle-titans/story-019b-mobile-ui-refonte.md

const SCREEN_PATH: String = "res://src/ui/save_screen.tscn"

var _emitted: Array = []


func _make_screen() -> SaveScreen:
	var screen: SaveScreen = auto_free((load(SCREEN_PATH) as PackedScene).instantiate())
	add_child(screen)
	screen.setup("0.0.0")
	screen.open()
	return screen


func _button(screen: SaveScreen, node_name: String) -> Button:
	return screen.find_child(node_name, true, false)


func _record(value: bool) -> void:
	_emitted.append(value)


func before_test() -> void:
	_emitted = []


func test_auto_challenge_press_reports_and_reads_oui() -> void:
	# Arrange
	var screen: SaveScreen = _make_screen()
	screen.set_auto_challenge(false)
	screen.auto_challenge_toggled.connect(_record)
	var toggle: Button = _button(screen, "AutoChallengeToggle")
	# Act
	toggle.button_pressed = true
	# Assert
	assert_array(_emitted).is_equal([true])
	assert_str(toggle.text).is_equal("Défi auto : OUI")


func test_auto_challenge_state_is_shown_without_being_reported() -> void:
	var screen: SaveScreen = _make_screen()
	screen.auto_challenge_toggled.connect(_record)
	screen.set_auto_challenge(true)
	var toggle: Button = _button(screen, "AutoChallengeToggle")
	assert_bool(toggle.button_pressed).is_true()
	assert_str(toggle.text).is_equal("Défi auto : OUI")
	assert_array(_emitted).is_empty()


func test_fullscreen_is_hidden_where_it_is_not_available() -> void:
	var screen: SaveScreen = _make_screen()
	screen.set_fullscreen(false, false)
	assert_bool(_button(screen, "FullscreenToggle").visible).is_false()


func test_fullscreen_label_goes_back_to_non_when_full_screen_is_left() -> void:
	# Arrange: full screen is on, as the root reports after the window grew.
	var screen: SaveScreen = _make_screen()
	screen.fullscreen_toggled.connect(_record)
	screen.set_fullscreen(true, true)
	var toggle: Button = _button(screen, "FullscreenToggle")
	assert_str(toggle.text).is_equal("Plein écran : OUI")
	# Act: the player left it with the back gesture; the root tells the new state on the resize.
	screen.set_fullscreen(true, false)
	# Assert
	assert_bool(toggle.visible).is_true()
	assert_bool(toggle.button_pressed).is_false()
	assert_str(toggle.text).is_equal("Plein écran : NON")
	assert_array(_emitted).is_empty()


func test_fullscreen_press_reports_and_waits_for_the_real_state() -> void:
	# The browser may refuse: the label only changes when the root tells the new state.
	var screen: SaveScreen = _make_screen()
	screen.set_fullscreen(true, false)
	screen.fullscreen_toggled.connect(_record)
	var toggle: Button = _button(screen, "FullscreenToggle")
	toggle.button_pressed = true
	assert_array(_emitted).is_equal([true])
	assert_str(toggle.text).is_equal("Plein écran : NON")
