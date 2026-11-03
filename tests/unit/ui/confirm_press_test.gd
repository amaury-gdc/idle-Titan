extends GdUnitTestSuite
## Unit tests for the press that must be repeated: "Abandonner" asks "Confirmer ?" and only a
## second press within 3 s ends the fight. The time is given, never read from a clock.
## Story: production/epics/idle-titans/story-019b-mobile-ui-refonte.md

## A time far from 0, as Time.get_ticks_msec gives after a while.
const START: float = 120.0
const WINDOW: float = ConfirmPress.WINDOW_SECONDS


func test_first_press_only_arms() -> void:
	# Arrange
	var confirm: ConfirmPress = ConfirmPress.new()
	# Act
	var confirmed: bool = confirm.press(START)
	# Assert
	assert_bool(confirmed).is_false()
	assert_bool(confirm.is_armed(START)).is_true()


func test_second_press_within_the_window_confirms() -> void:
	var confirm: ConfirmPress = ConfirmPress.new()
	confirm.press(START)
	assert_bool(confirm.press(START + WINDOW)).is_true()
	# Confirmed: the next press starts over.
	assert_bool(confirm.is_armed(START + WINDOW)).is_false()


func test_second_press_after_the_window_arms_again() -> void:
	var confirm: ConfirmPress = ConfirmPress.new()
	confirm.press(START)
	assert_bool(confirm.press(START + WINDOW + 0.01)).is_false()
	assert_bool(confirm.is_armed(START + WINDOW + 0.01)).is_true()


func test_armed_press_expires_by_itself() -> void:
	var confirm: ConfirmPress = ConfirmPress.new()
	confirm.press(START)
	assert_bool(confirm.is_armed(START + WINDOW + 0.01)).is_false()


func test_cancel_forgets_the_first_press() -> void:
	var confirm: ConfirmPress = ConfirmPress.new()
	confirm.press(START)
	confirm.cancel()
	assert_bool(confirm.is_armed(START)).is_false()
	assert_bool(confirm.press(START + 1.0)).is_false()


func test_new_press_is_not_armed() -> void:
	assert_bool(ConfirmPress.new().is_armed(START)).is_false()
