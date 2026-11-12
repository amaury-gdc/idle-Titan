extends GdUnitTestSuite
## Unit tests for the landscape screen (story 019b, lot 9) on the real scene without its script, as
## in panel_shell_test.gd: the scene on the left (about 540 u) and the panel on the right (about
## 720 u); in the scene the skills lie in a row of 68 u at the bottom, and the mice are the ones of
## the portrait rule, so that what is drawn and where the balls leave from are the same points;
## the talents show the full tree.
## Story: production/epics/idle-titans/story-019b-mobile-ui-refonte.md

const SCENE: String = "res://src/ui/main_screen.tscn"
const LANDSCAPE: AdaptiveLayout.Shape = AdaptiveLayout.Shape.LANDSCAPE
const SCREEN: Vector2 = Vector2(1280.0, 720.0)
## The split of the spec, 540 / 720 of the width, and how far the 3:4 ratio may stray from it.
const SCENE_SHARE: float = 3.0 / 7.0
const WIDTH_TOLERANCE: float = 1.0
const STAGES_PER_POINT: int = 5

var _root: Control
var _zone: GameZone
var _management: Control
var _tabs: ManagementTabs
var _talents: TalentScreen


func before_test() -> void:
	_root = auto_free((load(SCENE) as PackedScene).instantiate())
	_root.set_script(null)
	add_child(_root)
	# Sized by hand: the full-rect anchors of the scene would override the size.
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.size = SCREEN
	(_root.find_child("Split", true, false) as BoxContainer).vertical = false
	_zone = _root.find_child("GameZone", true, false)
	_zone.set_layout(LANDSCAPE, AdaptiveLayout.SCENE_MAX)
	_management = _root.find_child("ManagementZone", true, false)
	_tabs = _root.find_child("ManagementTabs", true, false)
	_tabs.set_handle_enabled(false)
	_talents = _root.find_child("TalentScreen", true, false)
	_talents.setup(_three_branches())


func _three_branches() -> TalentTree:
	var state: GameState = GameState.new()
	state.max_stage_reached = STAGES_PER_POINT
	var branches: Array = []
	var nodes: Array = []
	for id: String in ["one", "two", "three"]:
		branches.append({"id": id, "name": "Branche " + id})
		nodes.append({"id": "n_" + id, "branch": id, "name": "Nom " + id, "cost": 1, "requires": [],
				"effect": {"stat": TalentTree.STAT_CLICK_DAMAGE, "percent": 10}})
	return TalentTree.from_data({
		"schema_version": TalentTree.SUPPORTED_SCHEMA,
		"stages_per_point": STAGES_PER_POINT,
		"branches": branches,
		"nodes": nodes,
	}, PermanentState.new(), state)


func _laid_out() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_scene_takes_three_sevenths_and_the_panel_the_rest() -> void:
	# Act
	await _laid_out()

	# Assert: about 549 and 731 u at 1280 of width
	assert_float(_zone.size.x).is_equal_approx(SCREEN.x * SCENE_SHARE, WIDTH_TOLERANCE)
	assert_float(_management.size.x).is_equal_approx(SCREEN.x * (1.0 - SCENE_SHARE), WIDTH_TOLERANCE)


func test_skills_lie_in_a_row_at_the_bottom_of_the_scene() -> void:
	# Act
	await _laid_out()
	var skills: Control = _zone.find_child("SkillBar", false, false)

	# Assert
	assert_float(skills.size.y).is_equal(AdaptiveLayout.SKILL_ROW_HEIGHT)
	assert_float(skills.position.y + skills.size.y).is_equal_approx(_zone.size.y, 1.0)
	var hp: Control = _zone.find_child("HpBar", false, false)
	assert_float(hp.position.y + hp.size.y).is_less_equal(skills.position.y)


func test_balls_leave_from_the_drawn_mice() -> void:
	# Arrange
	await _laid_out()
	var scene: float = GameZone.scene_height(LANDSCAPE, _zone.size, 0.0)
	var box: float = GameZone.portrait_box(_zone.size, scene)

	# Act
	var slots: PackedVector2Array = _zone.orb_slots()

	# Assert: the slots and the width of the mice are those of the drawn rule, 38 u at 1280x720
	assert_array(Array(slots)).is_equal(Array(GameZone.portrait_mouse_centers(_zone.size, scene, box)))
	assert_float(_zone.orb_slot_radius() * 2.0).is_equal(GameZone.MOUSE_MAX_SIZE)


func test_landscape_mice_touch_nothing() -> void:
	# Arrange
	await _laid_out()
	var scene: float = GameZone.scene_height(LANDSCAPE, _zone.size, 0.0)
	var rects: Dictionary = GameZone.blocks(LANDSCAPE, _zone.size, 0.0)
	var box: float = GameZone.portrait_box(_zone.size, scene)
	var enemy: Rect2 = rects["enemy"]
	var monster: Rect2 = Rect2(enemy.get_center() - Vector2.ONE * box / 2.0, Vector2.ONE * box)
	var half: Vector2 = MouseFace.half_extent(GameZone.portrait_mouse_size(_zone.size, scene))

	# Act
	var mice: Array[Rect2] = []
	for center: Vector2 in _zone.orb_slots():
		mice.append(Rect2(center - half, half * 2.0))

	# Assert
	for i in mice.size():
		for key: String in ["challenge", "timer", "hp", "skills"]:
			assert_bool(mice[i].intersects(rects[key])).override_failure_message("mouse %d, %s" % [i, key]).is_false()
		assert_bool(mice[i].intersects(monster)).override_failure_message("mouse %d, monster" % i).is_false()
		for j in range(i + 1, mice.size()):
			assert_bool(mice[i].intersects(mice[j])).override_failure_message("mouse %d, %d" % [i, j]).is_false()


func test_talents_show_the_full_tree() -> void:
	# Act
	_tabs.select(ManagementTabs.Tab.TALENTS)
	await _laid_out()

	# Assert
	assert_bool(_talents.is_wide()).is_true()
