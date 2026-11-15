extends GdUnitTestSuite
## Unit tests for BalanceNotice (stories 020 and 023): the one-time message of a rebalance is due
## only for a stage record above the threshold of the current version, once per balance version,
## with the title and text of that version, and survives the save.
## Stories: production/epics/idle-titans/story-020-economy-calibration.md,
## production/epics/idle-titans/story-023-active-play-value.md

const VERSION: int = 1
const NEXT_VERSION: int = 2
const MIN_STAGE: int = 150
const NEXT_MIN_STAGE: int = 10
const RECORD_ABOVE: int = 151
const RECORD_FAR_ABOVE: int = 215
const TITLE: String = "Title one"
const TEXT: String = "Text one"
const NEXT_TITLE: String = "Title two"
const NEXT_TEXT: String = "Text two"


## Curves whose current version is [param version], with an entry for versions 1 and 2;
## [param min_stage] is the threshold of version 1.
func _curves(version: Variant = VERSION, min_stage: Variant = MIN_STAGE) -> Dictionary:
	return {"balance_version": version, "balance_notices": [
		{"version": VERSION, "min_stage": min_stage, "title": TITLE, "text": TEXT},
		{"version": NEXT_VERSION, "min_stage": NEXT_MIN_STAGE, "title": NEXT_TITLE, "text": NEXT_TEXT},
	]}


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
	assert_str(notice.get_error()).is_equal("core_curves.json: 'balance_notices' min_stage must be an integer >= 0")


func test_message_carries_the_title_and_text_of_the_current_version() -> void:
	# Act
	var first: BalanceNotice = BalanceNotice.from_data(_curves(VERSION), PermanentState.new())
	var second: BalanceNotice = BalanceNotice.from_data(_curves(NEXT_VERSION), PermanentState.new())

	# Assert
	assert_str(first.title()).is_equal(TITLE)
	assert_str(first.text()).is_equal(TEXT)
	assert_str(second.title()).is_equal(NEXT_TITLE)
	assert_str(second.text()).is_equal(NEXT_TEXT)


func test_each_version_uses_its_own_stage_threshold() -> void:
	# Arrange: a record above the threshold of version 2 (10) and under that of version 1 (150)
	var record: int = NEXT_MIN_STAGE + 1
	var under_first: PermanentState = PermanentState.new()
	var under_second: PermanentState = PermanentState.new()

	# Act
	var first_shown: bool = BalanceNotice.from_data(_curves(VERSION), under_first).apply(record)
	var second_shown: bool = BalanceNotice.from_data(_curves(NEXT_VERSION), under_second).apply(record)
	var at_second_limit: bool = BalanceNotice.from_data(_curves(NEXT_VERSION), PermanentState.new()).apply(NEXT_MIN_STAGE)

	# Assert
	assert_bool(first_shown).is_false()
	assert_bool(second_shown).is_true()
	assert_bool(at_second_limit).is_false()


func test_player_who_missed_a_version_reads_only_the_newest_message() -> void:
	# Arrange: nothing seen, the data already at version 2
	var permanent: PermanentState = PermanentState.new()
	var notice: BalanceNotice = BalanceNotice.from_data(_curves(NEXT_VERSION), permanent)

	# Act
	var shown: bool = notice.apply(RECORD_FAR_ABOVE)
	notice.acknowledge()

	# Assert: one message, of version 2, and nothing left due
	assert_bool(shown).is_true()
	assert_str(notice.text()).is_equal(NEXT_TEXT)
	assert_int(permanent.balance_seen).is_equal(NEXT_VERSION)
	assert_bool(BalanceNotice.from_data(_curves(NEXT_VERSION), permanent).apply(RECORD_FAR_ABOVE)).is_false()


func test_player_who_saw_the_former_version_under_the_new_threshold_gets_no_message() -> void:
	# Arrange: version 1 seen, a record under the first boss
	var permanent: PermanentState = PermanentState.new()
	permanent.balance_seen = VERSION

	# Act
	var shown: bool = BalanceNotice.from_data(_curves(NEXT_VERSION), permanent).apply(NEXT_MIN_STAGE - 2)

	# Assert: recorded in silence
	assert_bool(shown).is_false()
	assert_int(permanent.balance_seen).is_equal(NEXT_VERSION)


func test_fractional_saved_version_reads_as_its_whole_part() -> void:
	# Arrange: a hand-edited save
	var seen_one: PermanentState = PermanentState.from_dict({"balance_seen": 1.5})
	var seen_two: PermanentState = PermanentState.from_dict({"balance_seen": 2.5})

	# Act and assert: 1.5 is version 1 (message due under version 2), 2.5 is version 2 (nothing due)
	assert_bool(BalanceNotice.from_data(_curves(NEXT_VERSION), seen_one).apply(RECORD_FAR_ABOVE)).is_true()
	assert_bool(BalanceNotice.from_data(_curves(NEXT_VERSION), seen_two).apply(RECORD_FAR_ABOVE)).is_false()


func test_version_without_its_entry_is_refused() -> void:
	# Act: version 3 has no entry
	var notice: BalanceNotice = BalanceNotice.from_data(_curves(3), PermanentState.new())

	# Assert
	assert_bool(notice.is_valid()).is_false()
	assert_str(notice.get_error()).is_equal("core_curves.json: 'balance_notices' has no entry for 'balance_version' 3")
	assert_bool(notice.apply(RECORD_FAR_ABOVE)).is_false()


func test_entry_without_a_text_is_refused() -> void:
	for bad: Variant in ["", null, 3]:
		var curves: Dictionary = {"balance_version": 1, "balance_notices": [{"version": 1, "min_stage": 10, "title": TITLE, "text": bad}]}
		var notice: BalanceNotice = BalanceNotice.from_data(curves, PermanentState.new())
		assert_str(notice.get_error()).is_equal("core_curves.json: 'balance_notices' version 1 needs a 'title' and a 'text'")


func test_repeated_or_zero_entry_version_is_refused() -> void:
	# Arrange
	var entry: Dictionary = {"version": 1, "min_stage": 10, "title": TITLE, "text": TEXT}
	var zero: Dictionary = {"version": 0, "min_stage": 10, "title": TITLE, "text": TEXT}

	# Act
	var repeated: BalanceNotice = BalanceNotice.from_data({"balance_version": 1, "balance_notices": [entry, entry]}, PermanentState.new())
	var at_zero: BalanceNotice = BalanceNotice.from_data({"balance_version": 1, "balance_notices": [zero]}, PermanentState.new())

	# Assert
	assert_str(repeated.get_error()).is_equal("core_curves.json: 'balance_notices' versions must be distinct integers >= 1")
	assert_str(at_zero.get_error()).is_equal("core_curves.json: 'balance_notices' versions must be distinct integers >= 1")


func test_notices_that_are_not_an_array_of_objects_are_refused() -> void:
	for bad: Variant in ["x", {"version": 1}, [1]]:
		var notice: BalanceNotice = BalanceNotice.from_data({"balance_version": 1, "balance_notices": bad}, PermanentState.new())
		assert_str(notice.get_error()).is_equal("core_curves.json: 'balance_notices' must be an array of {version, min_stage, title, text}")


func test_curves_that_are_not_an_object_are_refused() -> void:
	# Act
	var notice: BalanceNotice = BalanceNotice.from_data(null, PermanentState.new())

	# Assert
	assert_bool(notice.is_valid()).is_false()
	assert_bool(notice.is_due()).is_false()
