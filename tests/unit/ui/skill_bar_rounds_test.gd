extends GdUnitTestSuite
## Unit tests for the skill rounds (story 019b, lot 4): what each round shows, its accessible name,
## its touch zone, the room for five rounds at 320 u, and the press: on the release only, cancelled
## when the finger leaves the round, and never after a long press. The presses go through the real
## viewport, so the rules of [BaseButton] and of [HintBubble] are the ones under test.
## The locked and passive rounds of the real talents: talent_screen_v2_test.gd.
## Story: production/epics/idle-titans/story-019b-mobile-ui-refonte.md

const BAR_SCENE: String = "res://src/ui/skill_bar.tscn"
const VIEW: Vector2 = Vector2(390.0, 844.0)
## The skill row of the portrait game zone: the zone padding on each side, 68 u high.
const ROW: Vector2 = Vector2(390.0 - GameZone.PADDING * 2.0, AdaptiveLayout.SKILL_ROW_HEIGHT)
const NARROWEST_ROW_WIDTH: float = 320.0 - GameZone.PADDING * 2.0
const HOLD: float = LongPress.HOLD_SECONDS + 0.01
const BUFF_SECONDS: int = 15
const BURST_COOLDOWN: int = 60
## Less than one step of the arc of a 15 s buff (15 / 120 = 0.125 s), and more than one.
const LESS_THAN_A_STEP: float = 0.05
const MORE_THAN_A_STEP: float = 0.3
## Far enough out of a round of 64 u to be off it, still inside its cell.
const OFF_THE_ROUND: Vector2 = Vector2(0.0, 33.0)

var _state: GameState
var _skills: SkillManager
var _root: Control
var _bar: SkillBar
var _bubble: HintBubble
var _activations: Array = []


func before_test() -> void:
	var curves: Dictionary = {
		"schema_version": Combat.SUPPORTED_CURVES_SCHEMA,
		"enemy_hp_base": "1000",
		"enemy_hp_growth": "1",
		"gold_per_kill_base": "1",
		"gold_per_kill_growth": "1",
		"click_damage_base": "1",
		"click_companion_power_factor": "0",
		"cost_growth": "1.08",
		"offline_efficiency": "0.5",
		"offline_max_hours": 12,
		"offline_min_seconds": 60,
	}
	var roster: Dictionary = {"schema_version": 2, "companions": [{
		"id": "scout", "name": "Scout", "base_cost": "10", "base_damage": "1", "cost_growth": "1.08",
		"attack_interval_seconds": 1.0, "tiers": [],
	}]}
	var combat: Combat = Combat.from_data(curves, roster)
	_state = GameState.new()
	_skills = SkillManager.from_data({"schema_version": SkillManager.SUPPORTED_SCHEMA, "skills": [
		{"id": "big_hit", "name": "Gros coup", "effect": "burst", "dps_seconds": "6", "cooldown_seconds": BURST_COOLDOWN},
		{"id": "damage_buff", "name": "Frénésie", "effect": "damage_multiplier", "multiplier": "1.5",
				"duration_seconds": BUFF_SECONDS, "cooldown_seconds": 90},
		{"id": "gold_bonus", "name": "Bonus d'or", "effect": "gold_multiplier", "multiplier": "1.5",
				"duration_seconds": 20, "cooldown_seconds": 120},
	]}, _state, combat, FloorManager.new(_state, combat))
	assert_str(_skills.get_error()).is_empty()
	_root = auto_free(Control.new())
	_root.size = VIEW
	add_child(_root)
	_bubble = HintBubble.new()
	var label: Label = Label.new()
	label.name = "Label"
	_bubble.add_child(label)
	_bubble.visible = false
	_bar = (load(BAR_SCENE) as PackedScene).instantiate()
	_bar.position = Vector2(GameZone.PADDING, 200.0)
	_bar.size = ROW
	_root.add_child(_bar)
	# After the bar: the bubble is drawn, and takes the dismissing taps, above it.
	_root.add_child(_bubble)
	_bar.set_compact(true)
	_bar.setup(_skills)
	_bar.watch_with(_bubble)
	_activations = []
	_bar.activate_requested.connect(func(id: String) -> void: _activations.append(id))


func _orb(id: String) -> SkillOrb:
	return _bar.button_of(id) as SkillOrb


func _center(id: String) -> Vector2:
	return _orb(id).get_global_rect().get_center()


func _push_button(at: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	if pressed:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event, true)


func _push_motion(at: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event, true)


func _laid_out() -> void:
	await get_tree().process_frame


# What each round shows

func test_ready_skill_shows_a_full_ring_and_says_disponible() -> void:
	assert_int(_orb("big_hit").look()).is_equal(SkillOrb.Look.READY)
	assert_int(_orb("big_hit").arc_step()).is_equal(SkillOrb.ARC_STEPS)
	assert_str(_orb("big_hit").accessibility_name).is_equal("Gros coup, Disponible")
	assert_bool(_orb("big_hit").disabled).is_false()


func test_running_buff_shows_its_time_left_and_its_seconds() -> void:
	# Act
	_skills.activate("damage_buff")
	_bar.refresh()

	# Assert
	var orb: SkillOrb = _orb("damage_buff")
	assert_int(orb.look()).is_equal(SkillOrb.Look.ACTIVE)
	assert_int(orb.arc_step()).is_equal(SkillOrb.ARC_STEPS)
	assert_str(orb.accessibility_name).is_equal("Frénésie, En cours : %d s" % BUFF_SECONDS)
	assert_bool(orb.disabled).is_true()


func test_recharging_skill_fills_its_ring_as_the_cooldown_runs() -> void:
	# Arrange: a burst goes straight to its cooldown
	_skills.activate("big_hit")
	_bar.refresh()
	var at_start: int = _orb("big_hit").arc_step()

	# Act: half the cooldown, in steps a tick honours
	var left: float = BURST_COOLDOWN / 2.0
	while left > 0.0:
		_skills.tick(minf(left, SkillManager.MAX_TICK_SECONDS))
		left -= SkillManager.MAX_TICK_SECONDS
	_bar.refresh()

	# Assert
	assert_int(_orb("big_hit").look()).is_equal(SkillOrb.Look.COOLDOWN)
	assert_int(at_start).is_equal(0)
	assert_int(_orb("big_hit").arc_step()).is_equal(SkillOrb.ARC_STEPS / 2)
	assert_str(_orb("big_hit").accessibility_name).is_equal("Gros coup, Dans %d s" % (BURST_COOLDOWN / 2))


func test_round_redraws_only_when_its_arc_moves_a_step() -> void:
	# Arrange
	_skills.activate("damage_buff")
	_bar.refresh()
	var orb: SkillOrb = _orb("damage_buff")
	var step: int = orb.arc_step()

	# Act / Assert: under a step nothing changes, past it the arc moves
	_skills.tick(LESS_THAN_A_STEP)
	_bar.refresh()
	assert_int(orb.arc_step()).is_equal(step)
	assert_bool(orb.show_state(orb.look(), BUFF_SECONDS, float(step) / SkillOrb.ARC_STEPS)).is_false()
	_skills.tick(MORE_THAN_A_STEP)
	_bar.refresh()
	assert_int(orb.arc_step()).is_less(step)


func test_each_effect_has_its_icon() -> void:
	assert_int(_orb("big_hit").icon_kind).is_equal(UiIcon.Kind.STAR)
	assert_int(_orb("damage_buff").icon_kind).is_equal(UiIcon.Kind.BOLT)
	assert_int(_orb("gold_bonus").icon_kind).is_equal(UiIcon.Kind.COIN)


func test_round_shows_no_text_and_the_bubble_names_the_skill() -> void:
	assert_str(_orb("damage_buff").text).is_empty()
	assert_str(_bar.hint_text("damage_buff")).starts_with("Frénésie\n")


# Touch zone and room

func test_touch_zone_is_a_disc_of_at_least_a_touch_target() -> void:
	await _laid_out()
	var orb: SkillOrb = _orb("damage_buff")
	assert_float(orb.touch_radius() * 2.0).is_greater_equal(GameZone.BUTTON_HEIGHT)
	assert_bool(orb._has_point(orb.size / 2.0)).is_true()
	assert_bool(orb._has_point(Vector2.ZERO)).is_false()


func test_row_holds_five_rounds_at_320_wide() -> void:
	# Arrange: the narrowest portrait row, with the five rounds the row is laid out for
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", SkillBar.SEPARATION_COMPACT)
	box.size = Vector2(NARROWEST_ROW_WIDTH, AdaptiveLayout.SKILL_ROW_HEIGHT)
	_root.add_child(box)
	for i in SkillBar.DESIGNED_SLOTS:
		box.add_child(SkillOrb.new())

	# Act
	await _laid_out()

	# Assert
	assert_float(box.size.x).is_equal(NARROWEST_ROW_WIDTH)
	for orb: Node in box.get_children():
		assert_float((orb as SkillOrb).size.x).is_greater_equal(SkillOrb.DISK_SIZE)
		assert_float((orb as SkillOrb).touch_radius() * 2.0).is_greater_equal(GameZone.BUTTON_HEIGHT)


# The press

func test_release_on_the_round_activates_it() -> void:
	await _laid_out()
	_push_button(_center("damage_buff"), true)
	_push_button(_center("damage_buff"), false)
	assert_array(_activations).contains_exactly(["damage_buff"])


func test_press_does_not_activate_before_the_release() -> void:
	await _laid_out()
	_push_button(_center("damage_buff"), true)
	assert_array(_activations).is_empty()
	_push_button(_center("damage_buff"), false)


func test_finger_leaving_the_round_cancels_the_press() -> void:
	# Arrange
	await _laid_out()
	var center: Vector2 = _center("damage_buff")
	_push_button(center, true)

	# Act: out of the round, still in its cell, then released there
	_push_motion(center + OFF_THE_ROUND)
	_push_button(center + OFF_THE_ROUND, false)

	# Assert
	assert_bool(_orb("damage_buff").get_global_rect().has_point(center + OFF_THE_ROUND)).is_true()
	assert_array(_activations).is_empty()


func test_long_press_shows_the_name_and_the_release_activates_nothing() -> void:
	# Arrange
	await _laid_out()
	var center: Vector2 = _center("damage_buff")
	_push_button(center, true)

	# Act: held to the end of the hold, then released on the round
	_bubble._process(HOLD)
	_push_button(center, false)

	# Assert
	assert_bool(_bubble.is_showing_for(_orb("damage_buff"))).is_true()
	assert_str((_bubble.get_node("Label") as Label).text).starts_with("Frénésie\n")
	assert_array(_activations).is_empty()
