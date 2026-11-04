extends GdUnitTestSuite
## Unit tests for the blocks of the game zone after the mobile redesign: in portrait a scene and the
## skill row under it; "Boss" / "Abandonner" in the top right corner, over the scene, never on the HP
## bar, the timer band or the monster box; the version and "Défi auto" gone to "Réglages".
## Story: production/epics/idle-titans/story-019b-mobile-ui-refonte.md

const PORTRAIT: AdaptiveLayout.Shape = AdaptiveLayout.Shape.PORTRAIT
const LANDSCAPE: AdaptiveLayout.Shape = AdaptiveLayout.Shape.LANDSCAPE
## Widths of the portrait zone: 320 CSS px at the floor, and the base.
const WIDTHS: Array[float] = [363.0, 390.0]
## Scene heights: the smallest, the one of a 320x568 phone, the tallest with the panel open, then
## the scenes of a collapsed panel (story 019b, lot 5) at 320x568, 390x742 and 412x915.
const SCENES: Array[float] = [160.0, 178.0, 208.0, 419.0, 516.0, 640.0]
## Logical heights of those three phones, and their collapsed scenes.
const COLLAPSED: Dictionary = {645.0: 419.0, 742.0: 516.0, 866.0: 640.0}
## Touch target of the spec: 44 CSS px at the floor of 0.88 CSS px per unit.
const TOUCH_TARGET: float = 50.0
const LANDSCAPE_ZONE: Vector2 = Vector2(768.0, 664.0)


func _zone(width: float, scene: float) -> Vector2:
	return Vector2(width, AdaptiveLayout.portrait_game_height(scene))


func test_portrait_scene_and_skill_row_fill_the_zone() -> void:
	for width: float in WIDTHS:
		for scene: float in SCENES:
			var zone: Vector2 = _zone(width, scene)
			var skills: Rect2 = GameZone.blocks(PORTRAIT, zone, scene)["skills"]
			assert_float(skills.position.y).is_equal(scene)
			assert_float(skills.size.y).is_equal(AdaptiveLayout.SKILL_ROW_HEIGHT)
			assert_float(skills.end.y).is_equal(zone.y)


func test_portrait_blocks_stay_inside_the_scene() -> void:
	for width: float in WIDTHS:
		for scene: float in SCENES:
			var rects: Dictionary = GameZone.blocks(PORTRAIT, _zone(width, scene), scene)
			var room: Rect2 = Rect2(0.0, 0.0, width, scene)
			for key: String in ["enemy", "hp", "timer", "challenge", "abandon", "hint", "orbs"]:
				assert_bool(room.encloses(rects[key])).override_failure_message("%s at %s x %s" % [key, width, scene]).is_true()


func test_portrait_corner_never_touches_the_hp_bar_or_the_timer() -> void:
	for width: float in WIDTHS:
		for scene: float in SCENES:
			var rects: Dictionary = GameZone.blocks(PORTRAIT, _zone(width, scene), scene)
			for corner: String in ["challenge", "abandon"]:
				assert_bool((rects[corner] as Rect2).intersects(rects["hp"])).is_false()
				assert_bool((rects[corner] as Rect2).intersects(rects["timer"])).is_false()
			assert_float((rects["timer"] as Rect2).end.y).is_less_equal((rects["hp"] as Rect2).position.y)


func test_portrait_corner_stays_beside_the_monster_box() -> void:
	for width: float in WIDTHS:
		for scene: float in SCENES:
			var rects: Dictionary = GameZone.blocks(PORTRAIT, _zone(width, scene), scene)
			var enemy: Rect2 = rects["enemy"]
			var box: float = GameZone.portrait_box(_zone(width, scene), scene)
			var monster: Rect2 = Rect2(enemy.get_center() - Vector2.ONE * box / 2.0, Vector2.ONE * box)
			assert_bool((rects["challenge"] as Rect2).intersects(monster)).override_failure_message("at %s x %s" % [width, scene]).is_false()


func test_portrait_corner_is_a_touch_target() -> void:
	var corner: Rect2 = GameZone.blocks(PORTRAIT, _zone(390.0, 208.0), 208.0)["challenge"]
	assert_float(corner.size.y).is_greater_equal(TOUCH_TARGET)
	assert_float(corner.size.x).is_greater_equal(TOUCH_TARGET)


func test_portrait_boss_and_abandon_share_the_corner() -> void:
	var rects: Dictionary = GameZone.blocks(PORTRAIT, _zone(390.0, 208.0), 208.0)
	assert_bool(rects["challenge"] == rects["abandon"]).is_true()


func test_portrait_companions_stand_under_the_corner() -> void:
	for width: float in WIDTHS:
		for scene: float in SCENES:
			var rects: Dictionary = GameZone.blocks(PORTRAIT, _zone(width, scene), scene)
			assert_float((rects["orbs"] as Rect2).position.y).is_greater((rects["challenge"] as Rect2).end.y)


## Scenes the mice must fit without touching anything: from a 320x568 phone (178 u) to the top, and
## the scenes of a collapsed panel.
const MOUSE_SCENES: Array[float] = [178.0, 190.0, 205.0, 208.0, 419.0, 516.0, 640.0]


func test_collapsed_scenes_are_the_ones_of_the_phones() -> void:
	for height: float in COLLAPSED:
		assert_float(AdaptiveLayout.portrait_scene_collapsed(height)).is_equal(COLLAPSED[height])


func test_open_panel_keeps_the_monster_box_of_its_height() -> void:
	# The rule of the mice only bites in a tall scene: with the panel open, the height decides.
	for width: float in WIDTHS:
		for scene: float in [178.0, 208.0]:
			var enemy: Rect2 = GameZone.blocks(PORTRAIT, _zone(width, scene), scene)["enemy"]
			assert_float(GameZone.portrait_box(_zone(width, scene), scene)).is_equal(enemy.size.y)


func test_collapsed_scene_gives_a_bigger_monster() -> void:
	assert_float(GameZone.portrait_box(_zone(390.0, 516.0), 516.0)).is_greater(GameZone.portrait_box(_zone(390.0, 208.0), 208.0))


func _mouse_rects(zone: Vector2, scene: float) -> Array[Rect2]:
	var box: float = GameZone.portrait_box(zone, scene)
	var half: Vector2 = MouseFace.half_extent(GameZone.portrait_mouse_size(zone, scene))
	var mice: Array[Rect2] = []
	for center: Vector2 in GameZone.portrait_mouse_centers(zone, scene, box):
		mice.append(Rect2(center - half, half * 2.0))
	return mice


func test_portrait_has_eight_mice() -> void:
	assert_int(GameZone.portrait_mouse_centers(_zone(390.0, 208.0), 208.0, 132.0).size()).is_equal(8)


func test_portrait_mice_are_38_units_in_a_full_scene() -> void:
	assert_float(GameZone.portrait_mouse_size(_zone(390.0, 208.0), 208.0)).is_equal(GameZone.MOUSE_MAX_SIZE)


func test_portrait_mice_never_go_under_their_minimum() -> void:
	for scene: float in [AdaptiveLayout.SCENE_MIN, 178.0]:
		assert_float(GameZone.portrait_mouse_size(_zone(363.0, scene), scene)).is_greater_equal(GameZone.MOUSE_MIN_SIZE)


func test_portrait_mice_touch_nothing() -> void:
	for width: float in WIDTHS:
		for scene: float in MOUSE_SCENES:
			var zone: Vector2 = _zone(width, scene)
			var rects: Dictionary = GameZone.blocks(PORTRAIT, zone, scene)
			var enemy: Rect2 = rects["enemy"]
			var box: float = GameZone.portrait_box(zone, scene)
			var monster: Rect2 = Rect2(enemy.get_center() - Vector2.ONE * box / 2.0, Vector2.ONE * box)
			var room: Rect2 = Rect2(0.0, 0.0, width, scene)
			var mice: Array[Rect2] = _mouse_rects(zone, scene)
			for i in mice.size():
				var mouse: Rect2 = mice[i]
				var where: String = "mouse %d at %s x %s" % [i, width, scene]
				assert_bool(room.encloses(mouse)).override_failure_message(where).is_true()
				for key: String in ["challenge", "timer", "hp"]:
					assert_bool(mouse.intersects(rects[key])).override_failure_message("%s, %s" % [where, key]).is_false()
				assert_bool(mouse.intersects(monster)).override_failure_message(where + ", monster").is_false()
				for j in range(i + 1, mice.size()):
					assert_bool(mouse.intersects(mice[j])).override_failure_message("%s, mouse %d" % [where, j]).is_false()


func test_version_and_auto_challenge_left_the_game_zone() -> void:
	var portrait: Dictionary = GameZone.blocks(PORTRAIT, _zone(390.0, 208.0), 208.0)
	var landscape: Dictionary = GameZone.blocks(LANDSCAPE, LANDSCAPE_ZONE, 0.0)
	for rects: Dictionary in [portrait, landscape]:
		assert_bool(rects.has("version")).is_false()
		assert_bool(rects.has("auto")).is_false()


func test_landscape_skills_take_the_whole_left_column() -> void:
	var skills: Rect2 = GameZone.blocks(LANDSCAPE, LANDSCAPE_ZONE, 0.0)["skills"]
	assert_float(skills.position.y).is_equal(GameZone.PADDING)
	assert_float(skills.end.y).is_equal(LANDSCAPE_ZONE.y - GameZone.PADDING)
