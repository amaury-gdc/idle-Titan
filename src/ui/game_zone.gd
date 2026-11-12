class_name GameZone
extends Container
## The combat zone of the main screen (story 010): a scene and, under it, the skill row, in both
## shapes, and the backdrop under them.
##
## The scene (story 019b): the monster is centered, the HP bar lies at the bottom with the boss timer
## as a thin band just above it, and "Défier" or "Abandonner" sits in the top right corner, over the
## scene: none of them ever moves another. Two grids of 2 by 2 mice stand on each side of the monster.
## In portrait the scene height comes from [method AdaptiveLayout.portrait_scene]; in landscape the
## zone is the left column of the screen and the scene takes all of it but the skill row (lot 9).
##
## A custom container and not nested boxes: the corner lies over the scene, and moving a node to
## another parent would lose its focus. Here the blocks are direct children for good: only their
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
## orbs.set_slots(zone.orb_slots(), zone.orb_slot_radius())
## [/codeblock]

## The monster box takes at most this share of the zone width (display setting).
const BOX_ZONE_RATIO: float = 0.55
## Inner margin of the zone (display setting).
const PADDING: float = 8.0
## Height of a touch target (display setting, not a gameplay value).
const BUTTON_HEIGHT: float = 50.0
## The corner of the scene ("Défier" / "Abandonner" / "Confirmer ?"), as tall as a touch
## target (story 019b; its drawn height of 44 u comes with its style, story 019b lot 3). 104 u
## wide: "Abandonner" fits at 16 u, and the corner stays clear of the monster box at 363 u.
const CORNER_WIDTH: float = 104.0
const CORNER_HEIGHT: float = 50.0
## The HP bar (30 u, a 16 u outlined text) and the thin timer band above it.
const PORTRAIT_HP_HEIGHT: float = 30.0
const PORTRAIT_TIMER_HEIGHT: float = 22.0
## The boss hint takes 2 lines from the first width, 3 from the second, 4 under (at 16 u).
const HINT_TWO_LINES_WIDTH: float = 340.0
const HINT_THREE_LINES_WIDTH: float = 260.0
const HINT_LINE_HEIGHT: float = 26.0
const HINT_PADDING: float = 4.0
## The mice of the scene (story 019b): 38 u wide when the band under the corner holds two
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
## [method AdaptiveLayout.portrait_scene]); landscape ignores [param scene] (see [method scene_height]).
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


## The height of the scene in a zone of [param zone] units: [param scene] in portrait; in landscape
## the whole zone but the skill row, never under [constant AdaptiveLayout.SCENE_MIN].
static func scene_height(shape: AdaptiveLayout.Shape, zone: Vector2, scene: float) -> float:
	if shape == AdaptiveLayout.Shape.PORTRAIT:
		return scene
	return maxf(floorf(zone.y - AdaptiveLayout.SKILL_ROW_HEIGHT), AdaptiveLayout.SCENE_MIN)


## The 8 mouse slots of the current layout, in this node's coordinates: 2 by 2 on each side of the
## monster, under the corner of the scene, in both shapes.
func orb_slots() -> PackedVector2Array:
	return portrait_mouse_centers(size, _scene_now(), _enemy.box_size())


## Half the width of a mouse of the current layout, for [method CompanionOrbs.set_slots]: a mouse of
## [method portrait_mouse_size], in both shapes, so that the balls leave from the drawn mice.
func orb_slot_radius() -> float:
	return portrait_mouse_size(size, _scene_now()) / 2.0


## The monster box of the scene: as tall as its room, at most [constant BOX_ZONE_RATIO] of
## the width, and never so wide that two columns of mice stop fitting on each side. With the panel
## open the height decides; a collapsed panel makes the scene tall, and the mice decide (story 019b).
## Nor does the box reach the corner: it stays left of it or under it, whichever lets it be larger;
## only a short and wide scene feels it (the landscape of an 844x390 phone, lot 9).
## [param scene] is the scene height ([method scene_height]).
static func portrait_box(zone: Vector2, scene: float) -> float:
	var rects: Dictionary = _scene_blocks(zone, scene)
	var enemy: Rect2 = rects["enemy"]
	var corner: Rect2 = rects["challenge"]
	var half: Vector2 = MouseFace.half_extent(portrait_mouse_size(zone, scene))
	# Each flank holds two mice side by side, their gap, and a gap to the monster.
	var flank: float = half.x * 4.0 + MOUSE_GAP * 2.0
	var by_mice: float = enemy.size.x - flank * 2.0
	var center: Vector2 = enemy.get_center()
	var by_corner: float = maxf(corner.position.x - center.x, center.y - corner.end.y) * 2.0
	return minf(minf(minf(enemy.size.y, zone.x * BOX_ZONE_RATIO), by_mice), by_corner)


## The width of the mice: the largest, up to [constant MOUSE_MAX_SIZE], whose two rows fit
## the band under the corner, and never under [constant MOUSE_MIN_SIZE].
static func portrait_mouse_size(zone: Vector2, scene: float) -> float:
	var band: float = (_scene_blocks(zone, scene)["orbs"] as Rect2).size.y
	var mouse: float = MOUSE_MAX_SIZE
	while mouse > MOUSE_MIN_SIZE and portrait_mouse_pitch(mouse).y * 2.0 > band:
		mouse -= MOUSE_SIZE_STEP
	return maxf(mouse, MOUSE_MIN_SIZE)


## Distance between two mice of [param mouse] units, in a row (x) and in a column (y): their
## silhouettes and [constant MOUSE_GAP].
static func portrait_mouse_pitch(mouse: float) -> Vector2:
	return MouseFace.half_extent(mouse) * 2.0 + Vector2.ONE * MOUSE_GAP


## The 8 mice: a 2 by 2 grid on each side of a monster box of [param box], centered in the
## band under the corner, each grid halfway between the edge of the zone and the box.
static func portrait_mouse_centers(zone: Vector2, scene: float, box: float) -> PackedVector2Array:
	var rects: Dictionary = _scene_blocks(zone, scene)
	var enemy: Rect2 = rects["enemy"]
	var pitch: Vector2 = portrait_mouse_pitch(portrait_mouse_size(zone, scene))
	var left: float = _flank_x(enemy, box)
	var row_y: float = (rects["orbs"] as Rect2).get_center().y
	var slots: PackedVector2Array = PackedVector2Array()
	for side_x: float in [left, enemy.get_center().x * 2.0 - left]:
		_append_grid(slots, Vector2(side_x, row_y), pitch, 2, 2)
	return slots


## True when nothing stands in the band the loot message prefers: the corner of the scene.
func band_free() -> bool:
	return not _challenge.visible and not _abandon.visible


## Where the loot message of the current layout may go: see [method loot_slot_for].
func loot_slot(band_is_free: bool) -> Rect2:
	return loot_slot_for(_shape, size, _scene, _enemy.box_size(), band_is_free)


## The room of the loot message, in this node's coordinates. It never reaches a mouse or a
## control. A free band gives the whole width of the top of the scene, down to the first row of
## mice; an occupied one gives the gap between the mice, under the corner, and the message covers
## the monster for its few seconds. It takes no click, so the monster stays usable.
static func loot_slot_for(shape: AdaptiveLayout.Shape, zone: Vector2, scene: float, box: float, band_is_free: bool) -> Rect2:
	var height: float = scene_height(shape, zone, scene)
	var rects: Dictionary = _scene_blocks(zone, height)
	var enemy: Rect2 = rects["enemy"]
	var orbs: Rect2 = rects["orbs"]
	var mouse: float = portrait_mouse_size(zone, height)
	var reach: Vector2 = portrait_mouse_pitch(mouse) / 2.0 + MouseFace.half_extent(mouse)
	if band_is_free:
		# A gap above the first mice, so that the message never even touches them.
		return Rect2(PADDING, PADDING, enemy.size.x, orbs.get_center().y - reach.y - PADDING - MOUSE_GAP)
	var side: float = _flank_x(enemy, box) + reach.x + MOUSE_GAP
	return Rect2(side, orbs.position.y, zone.x - side * 2.0, enemy.end.y - orbs.position.y)


## The rectangle of each block in a zone of [param zone] units, [param scene] being the height of
## the portrait scene (ignored in landscape, see [method scene_height]). Keys: "timer", "abandon",
## "challenge", "enemy", "hint", "hp", "skills" and "orbs" (the band the mice stand in). Pure, so
## the layout can be read without a scene.
static func blocks(shape: AdaptiveLayout.Shape, zone: Vector2, scene: float) -> Dictionary:
	return _scene_blocks(zone, scene_height(shape, zone, scene))


func _scene_now() -> float:
	return scene_height(_shape, size, _scene)


# The scene from the bottom up: HP bar, timer band, then the monster; the corner sits over the top
# right of the monster's room, beside the monster box, and the mice stand under the corner. The
# skill row lies under the scene.
static func _scene_blocks(zone: Vector2, scene: float) -> Dictionary:
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


# Center of the left flank of mice: halfway between the slot edge and the box.
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
	var scene: float = _scene_now()
	var rects: Dictionary = _scene_blocks(size, scene)
	_enemy.set_box_limit(portrait_box(size, scene))
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
