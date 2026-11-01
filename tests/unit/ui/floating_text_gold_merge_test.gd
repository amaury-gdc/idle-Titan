extends GdUnitTestSuite
## Unit tests for the merging of the gold texts: one label for the kills of a short window, its sum,
## the boss size, the bounds, and a new text after the window. Time goes through _process steps,
## never through real time.
## Story: production/epics/idle-titans/story-011-management-tabs.md.

const BOUNDS: Rect2 = Rect2(100.0, 100.0, 300.0, 170.0)
## Short of the window, then past it, in steps the layer honors whole.
const STEP: float = 0.1
const STEPS_INSIDE: int = 2
const STEPS_PAST: int = 4
const KILL_GOLD: int = 10
const HUGE_GOLD: int = 123_456_789

var _layer: FloatingTextLayer


func before_test() -> void:
	_layer = auto_free(FloatingTextLayer.new())
	add_child(_layer)
	_layer.set_target_point(BOUNDS.get_center())


func _kill(gold: int = KILL_GOLD, boss: bool = false) -> void:
	_layer.show_gold(1, BigNumber.from_int(gold), boss)


func _advance(steps: int) -> void:
	for i in steps:
		_layer._process(STEP)


func _shown() -> Array[Label]:
	var labels: Array[Label] = []
	for child: Node in _layer.get_children():
		if child is Label and (child as Label).visible:
			labels.append(child)
	return labels


func test_first_kill_shows_its_gold_at_once() -> void:
	_kill()
	assert_int(_layer.busy_count()).is_equal(1)
	assert_str(_shown()[0].text).is_equal("+10 or")


func test_kills_inside_the_window_update_the_same_label_with_the_sum() -> void:
	_kill()
	_advance(STEPS_INSIDE)
	_kill()
	_kill()
	assert_int(_layer.busy_count()).is_equal(1)
	assert_str(_shown()[0].text).is_equal("+30 or")


func test_kill_after_the_window_opens_a_new_text() -> void:
	_kill()
	_advance(STEPS_PAST)
	_kill()
	assert_int(_layer.busy_count()).is_equal(2)


func test_later_kills_do_not_stretch_the_window() -> void:
	_kill()
	_advance(STEPS_INSIDE)
	_kill()
	_advance(STEPS_INSIDE)
	_kill()
	assert_int(_layer.busy_count()).is_equal(2)


func test_boss_in_the_sum_gives_the_boss_size() -> void:
	_kill()
	_kill(KILL_GOLD, true)
	_kill()
	assert_int(_shown()[0].get_theme_font_size("font_size")).is_equal(FloatingTextLayer.FONT_SIZE_GOLD_BOSS)


func test_no_boss_keeps_the_gold_size() -> void:
	_kill()
	_kill()
	assert_int(_shown()[0].get_theme_font_size("font_size")).is_equal(FloatingTextLayer.FONT_SIZE_GOLD)


func test_growing_sum_stays_inside_the_bounds() -> void:
	_layer.set_bounds(BOUNDS)
	_kill(1)
	_advance(STEPS_INSIDE)
	_kill(HUGE_GOLD, true)
	var label: Label = _shown()[0]
	var half: Vector2 = _layer._half_size(label.text, label.get_theme_font_size("font_size"))
	var inner: Rect2 = BOUNDS.grow_individual(-half.x, -half.y, -half.x, -half.y)
	for i in FloatingTextLayer.POOL_SIZE:
		_layer._process(STEP)
		if _layer.busy_count() == 0:
			break
		assert_bool(inner.grow(0.01).has_point(label.position + label.size / 2.0)).is_true()


func test_merging_leaves_the_reward_itself_alone() -> void:
	# Arrange: the same object the game credits
	var reward: BigNumber = BigNumber.from_int(KILL_GOLD)
	_layer.show_gold(1, reward, false)

	# Act
	_layer.show_gold(1, BigNumber.from_int(KILL_GOLD), false)

	# Assert
	assert_str(reward.format()).is_equal(str(KILL_GOLD))


func test_merge_of_the_same_size_leaves_the_font_override_alone() -> void:
	# Arrange
	_kill()
	var label: Label = _shown()[0]
	var changes: Array = []
	label.theme_changed.connect(func() -> void: changes.append(true))

	# Act
	_kill()
	await await_idle_frame()

	# Assert
	assert_array(changes).is_empty()


func test_boss_joining_the_merge_still_changes_the_size() -> void:
	_kill()
	var label: Label = _shown()[0]
	_kill(KILL_GOLD, true)
	assert_int(label.get_theme_font_size("font_size")).is_equal(FloatingTextLayer.FONT_SIZE_GOLD_BOSS)


func test_clear_resets_the_merge() -> void:
	_kill()
	_layer.clear()
	_kill()
	assert_str(_shown()[0].text).is_equal("+10 or")


func test_label_taken_over_by_hits_stops_the_merge() -> void:
	_kill()
	for i in FloatingTextLayer.POOL_SIZE:
		_layer.show_hit(BigNumber.from_int(1), FloorManager.HitSource.CLICK)
	_kill()
	var golds: int = 0
	for label: Label in _shown():
		golds += 1 if label.text == "+10 or" else 0
	assert_int(golds).is_equal(1)
