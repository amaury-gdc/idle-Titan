extends GdUnitTestSuite
## Unit tests for ClickDpsMeter, the rolling click damage per second.
## Story: production/epics/idle-titans/story-003-companions.md


func test_rate_counts_a_single_click_in_full() -> void:
	# Arrange
	var meter: ClickDpsMeter = ClickDpsMeter.new()

	# Act: a 5-damage click must read 5, not 5 spread over the whole window
	meter.record(BigNumber.from_int(5))

	# Assert
	assert_str(meter.rate().to_decimal_string()).is_equal("5")


func test_rate_divides_by_the_time_since_the_oldest_click() -> void:
	# Arrange
	var meter: ClickDpsMeter = ClickDpsMeter.new()
	meter.record(BigNumber.from_int(5))
	meter.tick(2.0)

	# Act
	meter.record(BigNumber.from_int(5))

	# Assert: 10 damage over 2 seconds
	assert_str(meter.rate().to_decimal_string()).is_equal("5")


func test_rate_falls_to_zero_once_clicks_leave_the_window() -> void:
	# Arrange
	var meter: ClickDpsMeter = ClickDpsMeter.new()
	meter.record(BigNumber.from_int(5))

	# Act
	meter.tick(float(ClickDpsMeter.WINDOW_SECONDS))

	# Assert
	assert_bool(meter.rate().is_zero()).is_true()
