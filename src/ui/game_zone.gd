class_name GameZone
extends Container
## The combat zone of the main screen (story 010): it places its child blocks in rows in portrait
## and in three columns in landscape, and paints the backdrop under them.
##
## Portrait (story 019b): a scene and, under it, the skill row. In the scene the monster is centered,
## the HP bar lies at the bottom with the boss timer as a thin band just above it, and "Défier" or
## "Abandonner" sits in the top right corner, over the scene: none of them ever moves another.
##
## A custom container and not nested boxes because the two shapes do not share an order ("Défier"
## sits in a corner of the scene in portrait and in the right column in landscape), and moving a node
## to another parent would lose its focus. Here the blocks are direct children for good: only their
## rectangles change.
##
## The backdrop is drawn here in a few flat shapes, no asset and no node: the zone colour, a
## spotlight tinted with the stage hue, a floor band across the whole width. It only redraws when
## the stage or the layout changes.
##
## Usage:
## [codeblock]
## zone.set_layout(AdaptiveLayout.Shape.PORTRAIT, AdaptiveLayout.portrait_scene(height))
## zone.set_stage_tint(EnemyView.stage_color(stage))
## orbs.set_slots(zone.orb_slots(), GameZone.orb_radius(enemy.box_size()))
## [/codeblock]

## The monster box takes at most this share of the zone width (display setting).
const BOX_ZONE_RATIO: float = 0.55
## Landscape side columns: this share of the zone width, within these bounds (display setting).
const COLUMN_RATIO: float = 0.24
const COLUMN_MIN_WIDTH: float = 170.0
const COLUMN_MAX_WIDTH: float = 230.0
## Inner margin of the zone and space between landscape blocks (display setting).
const PADDING: float = 8.0
## Heights and widths of the blocks (display setting, not a gameplay value).
const BUTTON_HEIGHT: float = 50.0
const LANDSCAPE_HP_HEIGHT: float = 32.0
## The corner of the portrait scene ("Défier" / "Abandonner" / "Confirmer ?"), as tall as a touch
## target (story 019b; its drawn height of 44 u comes with its style, story 019b lot 3). 104 u
## wide: "Abandonner" fits at 16 u, and the corner stays clear of the monster box at 363 u.
const CORNER_WIDTH: float = 104.0
const CORNER_HEIGHT: float = 50.0
## The portrait HP bar (30 u, a 16 u outlined text) and the thin timer band above it.
const PORTRAIT_HP_HEIGHT: float = 30.0
const PORTRAIT_TIMER_HEIGHT: float = 22.0
## The boss hint takes 2 lines from the first width, 3 from the second, 4 under (at 16 u).
const HINT_TWO_LINES_WIDTH: float = 340.0
const HINT_THREE_LINES_WIDTH: float = 260.0
const HINT_LINE_HEIGHT: float = 26.0
const HINT_PADDING: float = 4.0
## Sphere radius and pitch at a monster box of [constant EnemyView.DRAW_UNITS], and their upper
## bounds; under that box they stay at the small value (display setting).
const ORB_RADIUS_MIN: float = 14.0
const ORB_RADIUS_MAX: float = 28.0
const ORB_PITCH_MIN: float = 36.0
const ORB_PITCH_MAX: float = 72.0
## The mice of the portrait scene (story 019b): 38 u wide when the band under the corner holds two
## rows of them, smaller when it is short, never under the minimum; the gap keeps two silhouettes
## apart (display setting).
const MOUSE_MAX_SIZE: float = 38.0
const MOUSE_MIN_SIZE: float = 20.0
const MOUSE_GAP: float = 2.0
const MOUSE_SIZE_STEP: float = 0.5
## How much of the stage hue goes into the spotlight, about 15 % (display setting).
const SPOT_TINT: float = 0.15
## Spotlight radius and floor band, as a share of the monster box (display setting).
const SPOT_BOX_RATIO: float = 0.75
const FLOOR_TOP_BOX_RATIO: float = 0.38
const FLOOR_HEIGHT_BOX_RATIO: float = 0.14
const COLOR_ZONE: Color = UiPalette.PANEL

var _shape: AdaptiveLayout.Shape = AdaptiveLayout.Shape.LANDSCAPE
var _scene: float = AdaptiveLayout.SCENE_MAX
var _tint: Color = COLOR_ZONE
var _spot_center: Vector2 = Vector2.ZERO
var _box: float = 0.0

@onready var _enemy: EnemyView = $Enemy
@onready var _hp_bar: Control = $HpBar
@onready var _hint: Control = $BossHintLabel
@onready var _timer: Control = $BossTimer
@onready var _abandon: Control = $AbandonButton
@onready var _challenge: Control = $ChallengeButton
@onready var _skills: Control = $SkillBar


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN and is_node_ready():
		_place_blocks()


func _get_minimum_size() -> Vector2:
	if _shape == AdaptiveLayout.Shape.PORTRAIT:
		return Vector2(0.0, AdaptiveLayout.portrait_game_height(_scene))
	return Vector2.ZERO


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_ZONE)
	draw_circle(_spot_center, _box * SPOT_BOX_RATIO, COLOR_ZONE.lerp(_tint, SPOT_TINT * 0.5))
	draw_circle(_spot_center, _box * SPOT_BOX_RATIO * 0.7, COLOR_ZONE.lerp(_tint, SPOT_TINT))
	var floor_top: float = _spot_center.y + _box * FLOOR_TOP_BOX_RATIO
	draw_rect(Rect2(0.0, floor_top, size.x, _box * FLOOR_HEIGHT_BOX_RATIO), COLOR_ZONE.lerp(_tint, SPOT_TINT))


## The shape in use and, in portrait, the height of the scene (see
## [method AdaptiveLayout.portrait_scene]).
func set_layout(shape: AdaptiveLayout.Shape, scene: float) -> void:
	if shape == _shape and is_equal_approx(scene, _scene):
		return
	_shape = shape
	_scene = scene
	update_minimum_size()
	queue_sort()


## The hue of the stage, shown in the spotlight and on the floor.
func set_stage_tint(color: Color) -> void:
	_tint = color
	queue_redraw()


## The 8 sphere slots of the current layout, in this node's coordinates: 2 by 2 on each side of the
## monster in portrait, under the corner of the scene, and 2 columns of 4 in the right column in
## landscape.
func orb_slots() -> PackedVector2Array:
	var box: float = _enemy.box_size()
	if _shape == AdaptiveLayout.Shape.PORTRAIT:
		return portrait_mouse_centers(size, _scene, box)
	var slots: PackedVector2Array = PackedVector2Array()
	var pitch: float = orb_pitch(box)
	_append_grid(slots, (blocks(_shape, size, _scene)["orbs"] as Rect2).get_center(), Vector2.ONE * pitch, 2, 4)
	return slots


## Half the width of a companion of the current layout, for [method CompanionOrbs.set_slots]: a
## mouse of [method portrait_mouse_size] in portrait, the landscape rule otherwise.
func orb_slot_radius() -> float:
	if _shape == AdaptiveLayout.Shape.PORTRAIT:
		return portrait_mouse_size(size, _scene) / 2.0
	return orb_radius(_enemy.box_size())


## The monster box of the portrait scene: as tall as its room, at most [constant BOX_ZONE_RATIO] of
## the width, and never so wide that two columns of mice stop fitting on each side. With the panel
## open the height decides; a collapsed panel makes the scene tall, and the mice decide (story 019b).
static func portrait_box(zone: Vector2, scene: float) -> float:
	var enemy: Rect2 = (_portrait_blocks(zone, scene)["enemy"] as Rect2)
	var half: Vector2 = MouseFace.half_extent(portrait_mouse_size(zone, scene))
	# Each flank holds two mice side by side, their gap, and a gap to the monster.
	var flank: float = half.x * 4.0 + MOUSE_GAP * 2.0
	var by_mice: float = enemy.size.x - flank * 2.0
	return minf(minf(enemy.size.y, zone.x * BOX_ZONE_RATIO), by_mice)


## The width of the portrait mice: the largest, up to [constant MOUSE_MAX_SIZE], whose two rows fit
## the band under the corner, and never under [constant MOUSE_MIN_SIZE].
static func portrait_mouse_size(zone: Vector2, scene: float) -> float:
	var band: float = (_portrait_blocks(zone, scene)["orbs"] as Rect2).size.y
	var mouse: float = MOUSE_MAX_SIZE
	while mouse > MOUSE_MIN_SIZE and portrait_mouse_pitch(mouse).y * 2.0 > band:
		mouse -= MOUSE_SIZE_STEP
	return maxf(mouse, MOUSE_MIN_SIZE)


## Distance between two mice of [param mouse] units, in a row (x) and in a column (y): their
## silhouettes and [constant MOUSE_GAP].
static func portrait_mouse_pitch(mouse: float) -> Vector2:
	return MouseFace.half_extent(mouse) * 2.0 + Vector2.ONE * MOUSE_GAP


## The 8 portrait mice: a 2 by 2 grid on each side of a monster box of [param box], centered in the
## band under the corner, each grid halfway between the edge of the zone and the box.
static func portrait_mouse_centers(zone: Vector2, scene: float, box: float) -> PackedVector2Array:
	var rects: Dictionary = _portrait_blocks(zone, scene)
	var enemy: Rect2 = rects["enemy"]
	var pitch: Vector2 = portrait_mouse_pitch(portrait_mouse_size(zone, scene))
	var left: float = _flank_x(enemy, box)
	var row_y: float = (rects["orbs"] as Rect2).get_center().y
	var slots: PackedVector2Array = PackedVector2Array()
	for side_x: float in [left, enemy.get_center().x * 2.0 - left]:
		_append_grid(slots, Vector2(side_x, row_y), pitch, 2, 2)
	return slots


## True when nothing stands in the band the loot message prefers: the corner of the portrait scene,
## or the landscape timer ("Défier" being in the right column there).
func band_free() -> bool:
	if _shape == AdaptiveLayout.Shape.PORTRAIT:
		return not _challenge.visible and not _abandon.visible
	return not _timer.visible


## Where the loot message of the current layout may go: see [method loot_slot_for].
func loot_slot(band_is_free: bool) -> Rect2:
	return loot_slot_for(_shape, size, _scene, _enemy.box_size(), band_is_free)


## The room of the loot message, in this node's coordinates. It never reaches a sphere or a
## control: in landscape it stays in the center column, from the top of the band when the band is
## free and under it otherwise. In portrait, a free band gives the whole width of the top of the
## scene, down to the first row of spheres; an occupied one gives the gap between the spheres, under
## the corner, and the message covers the monster for its few seconds. It takes no click, so the
## monster stays usable.
static func loot_slot_for(shape: AdaptiveLayout.Shape, zone: Vector2, scene: float, box: float, band_is_free: bool) -> Rect2:
	var rects: Dictionary = blocks(shape, zone, scene)
	var enemy: Rect2 = rects["enemy"]
	if shape != AdaptiveLayout.Shape.PORTRAIT:
		var top: float = PADDING if band_is_free else enemy.position.y
		return Rect2(enemy.position.x, top, enemy.size.x, enemy.end.y - top)
	var orbs: Rect2 = rects["orbs"]
	var mouse: float = portrait_mouse_size(zone, scene)
	var reach: Vector2 = portrait_mouse_pitch(mouse) / 2.0 + MouseFace.half_extent(mouse)
	if band_is_free:
		# A gap above the first mice, so that the message never even touches them.
		return Rect2(PADDING, PADDING, enemy.size.x, orbs.get_center().y - reach.y - PADDING - MOUSE_GAP)
	var side: float = _flank_x(enemy, box) + reach.x + MOUSE_GAP
	return Rect2(side, orbs.position.y, zone.x - side * 2.0, enemy.end.y - orbs.position.y)


## Sphere radius for a monster box of [param box] units.
static func orb_radius(box: float) -> float:
	return clampf(ORB_RADIUS_MIN * box / EnemyView.DRAW_UNITS, ORB_RADIUS_MIN, ORB_RADIUS_MAX)


## Distance between two sphere slots for a monster box of [param box] units.
static func orb_pitch(box: float) -> float:
	return clampf(ORB_PITCH_MIN * box / EnemyView.DRAW_UNITS, ORB_PITCH_MIN, ORB_PITCH_MAX)


## The rectangle of each block in a zone of [param zone] units, [param scene] being the height of
## the portrait scene. Keys: "timer", "abandon", "challenge", "enemy", "hint", "hp", "skills" and
## "orbs" (the band the companions stand in). Pure, so the layout can be read without a scene.
static func blocks(shape: AdaptiveLayout.Shape, zone: Vector2, scene: float) -> Dictionary:
	if shape == AdaptiveLayout.Shape.PORTRAIT:
		return _portrait_blocks(zone, scene)
	return _landscape_blocks(zone)


# The scene from the bottom up: HP bar, timer band, then the monster; the corner sits over the top
# right of the monster's room, beside the monster box, and the companions stand under the corner.
static func _portrait_blocks(zone: Vector2, scene: float) -> Dictionary:
	var gap: float = AdaptiveLayout.ROW_GAP
	var inner: float = zone.x - PADDING * 2.0
	var rects: Dictionary = {}
	var hp_y: float = scene - PADDING - PORTRAIT_HP_HEIGHT
	rects["hp"] = Rect2(PADDING, hp_y, inner, PORTRAIT_HP_HEIGHT)
	var timer_y: float = hp_y - gap - PORTRAIT_TIMER_HEIGHT
	rects["timer"] = Rect2(PADDING, timer_y, inner, PORTRAIT_TIMER_HEIGHT)
	var enemy: Rect2 = Rect2(PADDING, PADDING, inner, timer_y - gap - PADDING)
	rects["enemy"] = enemy
	var hint_h: float = _hint_height(inner)
	rects["hint"] = Rect2(PADDING, enemy.end.y - hint_h, inner, hint_h)
	var corner: Rect2 = Rect2(zone.x - PADDING - CORNER_WIDTH, PADDING, CORNER_WIDTH, CORNER_HEIGHT)
	rects["challenge"] = corner
	rects["abandon"] = corner
	var orbs_y: float = corner.end.y + gap
	rects["orbs"] = Rect2(PADDING, orbs_y, inner, enemy.end.y - orbs_y)
	rects["skills"] = Rect2(PADDING, scene, inner, AdaptiveLayout.SKILL_ROW_HEIGHT)
	return rects


static func _landscape_blocks(zone: Vector2) -> Dictionary:
	var side: float = clampf(zone.x * COLUMN_RATIO, COLUMN_MIN_WIDTH, COLUMN_MAX_WIDTH)
	var center_x: float = PADDING * 2.0 + side
	var center_w: float = zone.x - (PADDING * 2.0 + side) * 2.0
	var right_x: float = zone.x - PADDING - side
	var bottom: float = zone.y - PADDING
	var rects: Dictionary = {}
	rects["skills"] = Rect2(PADDING, PADDING, side, bottom - PADDING)
	rects["timer"] = Rect2(center_x, PADDING, center_w, BUTTON_HEIGHT)
	var hp_y: float = bottom - LANDSCAPE_HP_HEIGHT
	rects["hp"] = Rect2(center_x, hp_y, center_w, LANDSCAPE_HP_HEIGHT)
	var enemy_y: float = PADDING * 2.0 + BUTTON_HEIGHT
	var enemy_h: float = hp_y - PADDING - enemy_y
	rects["enemy"] = Rect2(center_x, enemy_y, center_w, enemy_h)
	var hint_h: float = _hint_height(center_w)
	rects["hint"] = Rect2(center_x, enemy_y + enemy_h - hint_h, center_w, hint_h)
	var action_y: float = bottom - BUTTON_HEIGHT
	rects["abandon"] = Rect2(right_x, action_y, side, BUTTON_HEIGHT)
	rects["challenge"] = Rect2(right_x, action_y, side, BUTTON_HEIGHT)
	rects["orbs"] = Rect2(right_x, PADDING, side, action_y - PADDING * 2.0)
	return rects


# Center of the left flank of spheres in portrait: halfway between the slot edge and the box.
static func _flank_x(slot: Rect2, box: float) -> float:
	return (slot.position.x + slot.get_center().x - box / 2.0) / 2.0


static func _hint_height(width: float) -> float:
	var lines: int = 2 if width >= HINT_TWO_LINES_WIDTH else (3 if width >= HINT_THREE_LINES_WIDTH else 4)
	return float(lines) * HINT_LINE_HEIGHT + HINT_PADDING


static func _append_grid(slots: PackedVector2Array, center: Vector2, pitch: Vector2, columns: int, rows: int) -> void:
	for row in rows:
		for column in columns:
			var cell: Vector2 = Vector2(float(column) - float(columns - 1) / 2.0, float(row) - float(rows - 1) / 2.0)
			slots.append(center + cell * pitch)


func _place_blocks() -> void:
	var rects: Dictionary = blocks(_shape, size, _scene)
	var box_limit: float = size.x * BOX_ZONE_RATIO
	if _shape == AdaptiveLayout.Shape.PORTRAIT:
		box_limit = portrait_box(size, _scene)
	_enemy.set_box_limit(box_limit)
	fit_child_in_rect(_enemy, rects["enemy"])
	fit_child_in_rect(_hp_bar, rects["hp"])
	fit_child_in_rect(_hint, rects["hint"])
	fit_child_in_rect(_timer, rects["timer"])
	fit_child_in_rect(_abandon, rects["abandon"])
	fit_child_in_rect(_challenge, rects["challenge"])
	fit_child_in_rect(_skills, rects["skills"])
	var enemy_rect: Rect2 = rects["enemy"]
	_spot_center = enemy_rect.get_center()
	_box = _enemy.box_size()
	queue_redraw()
