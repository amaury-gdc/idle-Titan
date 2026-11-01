extends GdUnitTestSuite
## Unit tests for the rules of the notification dots: on event and not on state, cleared on visit,
## never on the open tab, and a baseline after a load.
## Story: production/epics/idle-titans/story-010-adaptive-layout.md, D4 of
## design/ux/main-screen-adaptive.md.

const COMPANIONS: int = ManagementTabs.Tab.COMPANIONS
const INVENTORY: int = ManagementTabs.Tab.INVENTORY
const TALENTS: int = ManagementTabs.Tab.TALENTS
const TIERS: Array = [10, 25]

var _dots: NotificationDots


func before_test() -> void:
	_dots = NotificationDots.new()
	_dots.observe_companions({})
	_dots.observe_talents(PackedStringArray())


func test_next_goal_not_bought_is_level_one() -> void:
	assert_int(NotificationDots.next_goal(0, TIERS)).is_equal(1)


func test_next_goal_is_the_first_tier_above_the_level() -> void:
	assert_int(NotificationDots.next_goal(1, TIERS)).is_equal(10)
	assert_int(NotificationDots.next_goal(10, TIERS)).is_equal(25)


func test_next_goal_after_the_last_tier_is_none() -> void:
	assert_int(NotificationDots.next_goal(25, TIERS)).is_equal(0)


func test_kept_item_lights_inventory_when_not_open() -> void:
	_dots.note_item_kept()
	assert_bool(_dots.is_lit(INVENTORY)).is_true()


func test_event_on_the_open_tab_lights_nothing() -> void:
	_dots.set_open_tab(INVENTORY)
	_dots.note_item_kept()
	assert_bool(_dots.is_lit(INVENTORY)).is_false()


func test_visit_clears_the_dot() -> void:
	_dots.note_item_kept()
	_dots.visit(INVENTORY)
	assert_bool(_dots.is_lit(INVENTORY)).is_false()


func test_opening_a_tab_clears_its_dot() -> void:
	_dots.note_item_kept()
	_dots.set_open_tab(INVENTORY)
	assert_bool(_dots.is_lit(INVENTORY)).is_false()


func test_new_buyable_talent_lights_nothing_with_its_tab_open() -> void:
	_dots.set_open_tab(TALENTS)
	_dots.observe_talents(PackedStringArray(["a"]))
	assert_bool(_dots.is_lit(TALENTS)).is_false()


func test_talent_seen_with_the_tab_open_stays_quiet_after_leaving_it() -> void:
	_dots.set_open_tab(TALENTS)
	_dots.observe_talents(PackedStringArray(["a"]))
	_dots.set_open_tab(COMPANIONS)
	_dots.observe_talents(PackedStringArray(["a"]))
	assert_bool(_dots.is_lit(TALENTS)).is_false()


func test_leaving_the_tab_lets_new_talents_light_again() -> void:
	_dots.set_open_tab(TALENTS)
	_dots.set_open_tab(COMPANIONS)
	_dots.observe_talents(PackedStringArray(["b"]))
	assert_bool(_dots.is_lit(TALENTS)).is_true()


func test_companion_goal_lights_compagnons_while_another_tab_is_open() -> void:
	_dots.set_open_tab(INVENTORY)
	_dots.observe_companions({"scout": 1})
	assert_bool(_dots.is_lit(COMPANIONS)).is_true()


func test_new_buyable_talent_lights_talents() -> void:
	_dots.observe_talents(PackedStringArray(["a"]))
	assert_bool(_dots.is_lit(TALENTS)).is_true()


func test_same_buyable_talent_does_not_light_again_after_a_visit() -> void:
	_dots.observe_talents(PackedStringArray(["a"]))
	_dots.visit(TALENTS)
	_dots.observe_talents(PackedStringArray(["a"]))
	assert_bool(_dots.is_lit(TALENTS)).is_false()


func test_talent_buyable_again_stays_quiet() -> void:
	_dots.observe_talents(PackedStringArray(["a"]))
	_dots.visit(TALENTS)
	_dots.observe_talents(PackedStringArray())
	_dots.observe_talents(PackedStringArray(["a"]))
	assert_bool(_dots.is_lit(TALENTS)).is_false()


func test_first_look_at_talents_is_a_silent_baseline() -> void:
	var fresh: NotificationDots = NotificationDots.new()
	fresh.observe_talents(PackedStringArray(["a"]))
	assert_bool(fresh.is_lit(TALENTS)).is_false()
	fresh.observe_talents(PackedStringArray(["a", "b"]))
	assert_bool(fresh.is_lit(TALENTS)).is_true()


func test_first_look_at_companions_is_a_silent_baseline() -> void:
	var fresh: NotificationDots = NotificationDots.new()
	fresh.set_open_tab(TALENTS)
	fresh.observe_companions({"scout": 1})
	assert_bool(fresh.is_lit(COMPANIONS)).is_false()


func test_goal_becoming_affordable_lights_companions_when_not_open() -> void:
	_dots.set_open_tab(TALENTS)
	_dots.observe_companions({"scout": 1})
	assert_bool(_dots.is_lit(COMPANIONS)).is_true()


func test_gold_going_up_and_down_does_not_relight_the_same_goal() -> void:
	_dots.set_open_tab(TALENTS)
	_dots.observe_companions({"scout": 1})
	_dots.visit(COMPANIONS)
	_dots.observe_companions({"scout": 0})
	_dots.observe_companions({"scout": 1})
	assert_bool(_dots.is_lit(COMPANIONS)).is_false()


func test_next_tier_lights_again() -> void:
	_dots.set_open_tab(TALENTS)
	_dots.observe_companions({"scout": 1})
	_dots.visit(COMPANIONS)
	_dots.observe_companions({"scout": 10})
	assert_bool(_dots.is_lit(COMPANIONS)).is_true()
