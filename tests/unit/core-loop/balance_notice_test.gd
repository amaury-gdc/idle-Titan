extends GdUnitTestSuite
## Unit tests for BalanceNotice (story 020): the one-time message of a rebalance is due only for a
## stage record above the stage of the data, once per balance version, and survives the save.
## Story: production/epics/idle-titans/story-020-economy-calibration.md

const VERSION: int = 1
const NEXT_VERSION: int = 2
const MIN_STAGE: int = 150
const RECORD_ABOVE: int = 151
const RECORD_FAR_ABOVE: int = 215


func _curves(version: Variant = VERSION, min_stage: Variant = MIN_STAGE) -> Dictionary:
	return {"balance_version": version, "balance_notice_min_stage": min_stage}


func test_record_above_the_minimum_stage_makes_the_message_due() -> void:
	# Arrange
	var permanent: PermanentState = PermanentState.new()
	var notice: BalanceNotice = BalanceNotice.from_data(_curves(), permanent)

	# Act
	var show: bool = notice.apply(RECORD_ABOVE)

	# Assert: due and not recorded until the player closes it
	assert_bool(notice.is_valid()).is_true()
	assert_bool(show).is_true()
	assert_bool(notice.is_due()).is_true()
	assert_int(permanent.balance_seen).is_equal(0)


func test_record_at_the_minimum_stage_is_recorded_without_a_message() -> void:
	# Arrange
	var permanent: PermanentState = PermanentState.new()
	var notice: BalanceNotice = BalanceNotice.from_data(_curves(), permanent)

	# Act
	var show: bool = notice.apply(MIN_STAGE)

	# Assert
	assert_bool(show).is_false()
	assert_bool(notice.is_due()).is_false()
	assert_int(permanent.balance_seen).is_equal(VERSION)


func test_player_who_passes_the_minimum_stage_later_gets_no_message() -> void:
	# Arrange: recorded in silence at stage 1
	var permanent: PermanentState = PermanentState.new()
	BalanceNotice.from_data(_curves(), permanent).apply(1)

	# Act: a later load with a high record
	var show: bool = BalanceNotice.from_data(_curves(), permanent).apply(RECORD_FAR_ABOVE)

	# Assert
	assert_bool(show).is_false()


func test_acknowledged_message_is_not_due_again_after_a_save_round_trip() -> void:
	# Arrange
	var permanent: PermanentState = PermanentState.new()
	var notice: BalanceNotice = BalanceNotice.from_data(_curves(), permanent)
	notice.apply(RECORD_FAR_ABOVE)

	# Act
	notice.acknowledge()
	var restored: PermanentState = PermanentState.from_dict(permanent.to_dict())
	var show_again: bool = BalanceNotice.from_data(_curves(), restored).apply(RECORD_FAR_ABOVE)

	# Assert
	assert_int(restored.balance_seen).is_equal(VERSION)
	assert_bool(show_again).is_false()


func test_message_not_closed_is_still_due_at_the_next_load() -> void:
	# Arrange: shown, the page reloaded before Continuer
	var permanent: PermanentState = PermanentState.new()
	BalanceNotice.from_data(_curves(), permanent).apply(RECORD_FAR_ABOVE)
	var restored: PermanentState = PermanentState.from_dict(permanent.to_dict())

	# Act
	var show: bool = BalanceNotice.from_data(_curves(), restored).apply(RECORD_FAR_ABOVE)

	# Assert
	assert_bool(show).is_true()


func test_next_balance_version_brings_the_message_back() -> void:
	# Arrange: version 1 seen
	var permanent: PermanentState = PermanentState.new()
	permanent.balance_seen = VERSION

	# Act
	var show: bool = BalanceNotice.from_data(_curves(NEXT_VERSION), permanent).apply(RECORD_FAR_ABOVE)

	# Assert
	assert_bool(show).is_true()


func test_save_of_an_older_format_has_seen_nothing() -> void:
	# Arrange: a version 6 payload has no balance_seen key
	var old_save: Dictionary = {"version": 6, "best_stage_record": RECORD_FAR_ABOVE, "talent_tree_seen": 1}

	# Act
	var permanent: PermanentState = PermanentState.from_dict(old_save)
	var show: bool = BalanceNotice.from_data(_curves(), permanent).apply(permanent.best_stage_record)

	# Assert
	assert_int(permanent.balance_seen).is_equal(0)
	assert_bool(show).is_true()


func test_invalid_saved_value_reads_as_nothing_seen() -> void:
	for bad: Variant in ["1", -1, null, 1e30]:
		assert_int(PermanentState.from_dict({"balance_seen": bad}).balance_seen).is_equal(0)


func test_data_without_a_balance_version_never_has_a_message() -> void:
	# Arrange
	var permanent: PermanentState = PermanentState.new()
	var notice: BalanceNotice = BalanceNotice.from_data({}, permanent)

	# Act
	var show: bool = notice.apply(RECORD_FAR_ABOVE)

	# Assert: valid, silent, and nothing written
	assert_bool(notice.is_valid()).is_true()
	assert_bool(show).is_false()
	assert_bool(notice.is_due()).is_false()
	assert_int(permanent.balance_seen).is_equal(0)


func test_non_integer_balance_version_is_refused() -> void:
	for bad: Variant in ["1", 1.5, -1, null]:
		var notice: BalanceNotice = BalanceNotice.from_data(_curves(bad), PermanentState.new())
		assert_bool(notice.is_valid()).is_false()
		assert_str(notice.get_error()).is_equal("core_curves.json: 'balance_version' must be an integer >= 0")
		assert_bool(notice.apply(RECORD_FAR_ABOVE)).is_false()


func test_non_integer_minimum_stage_is_refused() -> void:
	# Act
	var notice: BalanceNotice = BalanceNotice.from_data(_curves(VERSION, "150"), PermanentState.new())

	# Assert
	assert_bool(notice.is_valid()).is_false()
	assert_str(notice.get_error()).is_equal("core_curves.json: 'balance_notice_min_stage' must be an integer >= 0")


func test_curves_that_are_not_an_object_are_refused() -> void:
	# Act
	var notice: BalanceNotice = BalanceNotice.from_data(null, PermanentState.new())

	# Assert
	assert_bool(notice.is_valid()).is_false()
	assert_bool(notice.is_due()).is_false()
