extends GdUnitTestSuite
## Unit tests for the shared message place (story 017, engine review): the sentence of the first
## awakening, shown once in a game's life, must not be replaced by a loot arriving right after it.
## Story: production/epics/idle-titans/story-017-awakening-ui.md.

var _shown: Array[String] = []
var _slot: MessageSlot


func before_test() -> void:
	_shown = []
	_slot = MessageSlot.new()


func _show(text: String) -> void:
	_shown.append(text)


func test_loot_right_after_the_pinned_sentence_does_not_replace_it() -> void:
	# Arrange: the sentence holds the place
	_slot.pin()
	_show("sentence")

	# Act: a loot comes a moment later
	_slot.offer(_show.bind("loot"))

	# Assert: the sentence is still the last thing shown
	assert_array(_shown).contains_exactly(["sentence"])


func test_waiting_loot_shows_once_the_sentence_is_released() -> void:
	_slot.pin()
	_slot.offer(_show.bind("loot"))
	_slot.release()
	assert_array(_shown).contains_exactly(["loot"])
	assert_bool(_slot.is_pinned()).is_false()


func test_only_the_latest_waiting_loot_shows() -> void:
	_slot.pin()
	_slot.offer(_show.bind("first"))
	_slot.offer(_show.bind("second"))
	_slot.release()
	assert_array(_shown).contains_exactly(["second"])


func test_loot_without_a_pinned_message_shows_at_once() -> void:
	_slot.offer(_show.bind("loot"))
	assert_array(_shown).contains_exactly(["loot"])


func test_release_without_anything_waiting_shows_nothing() -> void:
	_slot.pin()
	_slot.release()
	_slot.release()
	assert_array(_shown).is_empty()
