class_name GameZone
extends Container
## The combat zone of the main screen (story 010): it places its child blocks in rows in portrait
## and in three columns in landscape, and paints the backdrop under them.
##
## A custom container and not nested boxes because the two shapes do not share an order (the timer
## sits above the monster in both, but "Défier" sits above it in portrait and in the right column
## in landscape), and moving a node to another parent would lose its focus. Here the blocks are
## direct children for good: only their rectangles change.
##
## The backdrop is drawn here in a few flat shapes, no asset and no node: the zone colour, a
## spotlight tinted with the stage hue, a floor band across the whole width. It only redraws when
## the stage or the layout changes.
##
## Usage:
## [codeblock]
## zone.set_layout(AdaptiveLayout.Shape.PORTRAIT, monster_row)
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
const ABANDON_WIDTH: float = 110.0
const VERSION_WIDTH: float = 60.0
const VERSION_HEIGHT: float = 24.0
const AUTO_WIDTH: float = 140.0
const LANDSCAPE_HP_HEIGHT: float = 32.0
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
## How much of the stage hue goes into the spotlight, about 15 % (display setting).
const SPOT_TINT: float = 0.15
## Spotlight radius and floor band, as a share of the monster box (display setting).
const SPOT_BOX_RATIO: float = 0.75
const FLOOR_TOP_BOX_RATIO: float = 0.38
const FLOOR_HEIGHT_BOX_RATIO: float = 0.14
const COLOR_ZONE: Color = Color("#171A29")

var _shape: AdaptiveLayout.Shape = AdaptiveLayout.Shape.LANDSCAPE
var _monster_row: float = AdaptiveLayout.MONSTER_ROW_MAX
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
@onready var _version: Control = $VersionLabel
@onready var _auto: Control = $AutoChallengeToggle


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN and is_node_ready():
		_place_blocks()


func _get_minimum_size() -> Vector2:
	if _shape == AdaptiveLayout.Shape.PORTRAIT:
		return Vector2(0.0, AdaptiveLayout.portrait_game_height(_monster_row))
	return Vector2.ZERO


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_ZONE)
	draw_circle(_spot_center, _box * SPOT_BOX_RATIO, COLOR_ZONE.lerp(_tint, SPOT_TINT * 0.5))
	draw_circle(_spot_center, _box * SPOT_BOX_RATIO * 0.7, COLOR_ZONE.lerp(_tint, SPOT_TINT))
	var floor_top: float = _spot_center.y + _box * FLOOR_TOP_BOX_RATIO
	draw_rect(Rect2(0.0, floor_top, size.x, _box * FLOOR_HEIGHT_BOX_RATIO), COLOR_ZONE.lerp(_tint, SPOT_TINT))


## The shape in use and, in portrait, the height of the monster row (see
## [method AdaptiveLayout.portrait_monster_row]).
func set_layout(shape: AdaptiveLayout.Shape, monster_row: float) -> void:
	if shape == _shape and is_equal_approx(monster_row, _monster_row):
		return
	_shape = shape
	_monster_row = monster_row
	update_minimum_size()
	queue_sort()


## The hue of the stage, shown in the spotlight and on the floor.
func set_stage_tint(color: Color) -> void:
	_tint = color
	queue_redraw()


## The 8 sphere slots of the current layout, in this node's coordinates: 2 by 2 on each side of the
## monster in portrait, 2 columns of 4 in the right column in landscape.
func orb_slots() -> PackedVector2Array:
	var rects: Dictionary = blocks(_shape, size, _monster_row)
	var box: float = _enemy.box_size()
	var pitch: float = orb_pitch(box)
	var slots: PackedVector2Array = PackedVector2Array()
	if _shape == AdaptiveLayout.Shape.PORTRAIT:
		var slot: Rect2 = rects["enemy"]
		var center: Vector2 = slot.get_center()
		var left: float = _flank_x(slot, box)
		for side_x: float in [left, center.x * 2.0 - left]:
			_append_grid(slots, Vector2(side_x, center.y), pitch, 2, 2)
	else:
		_append_grid(slots, (rects["orbs"] as Rect2).get_center(), pitch, 2, 4)
	return slots


## True when nothing stands in the action band: the loot message can sit in it. In landscape only
## the timer is there, "Défier" being in the right column.
func band_free() -> bool:
	if _timer.visible:
		return false
	return _shape != AdaptiveLayout.Shape.PORTRAIT or not _challenge.visible


## Where the loot message of the current layout may go: see [method loot_slot_for].
func loot_slot(band_is_free: bool) -> Rect2:
	return loot_slot_for(_shape, size, _monster_row, _enemy.box_size(), band_is_free)


## The room of the loot message, in this node's coordinates. It never reaches a sphere or a
## control: in landscape it stays in the center column, from the top of the band when the band is
## free and under it otherwise. In portrait, a free band gives the whole width down to the first
## row of spheres; an occupied one gives the gap between the spheres, in the monster row, and the
## message covers the monster for its few seconds. It takes no click, so the monster stays usable.
static func loot_slot_for(shape: AdaptiveLayout.Shape, zone: Vector2, monster_row: float, box: float, band_is_free: bool) -> Rect2:
	var enemy: Rect2 = blocks(shape, zone, monster_row)["enemy"]
	if shape != AdaptiveLayout.Shape.PORTRAIT:
		var top: float = PADDING if band_is_free else enemy.position.y
		return Rect2(enemy.position.x, top, enemy.size.x, enemy.end.y - top)
	var reach: float = orb_pitch(box) / 2.0 + orb_radius(box) + CompanionOrbs.OUTLINE_WIDTH
	if band_is_free:
		var band_top: float = AdaptiveLayout.ROW_GAP
		return Rect2(PADDING, band_top, enemy.size.x, enemy.get_center().y - reach - band_top)
	var side: float = _flank_x(enemy, box) + reach
	return Rect2(side, enemy.position.y, zone.x - side * 2.0, enemy.size.y)


## Sphere radius for a monster box of [param box] units.
static func orb_radius(box: float) -> float:
	return clampf(ORB_RADIUS_MIN * box / EnemyView.DRAW_UNITS, ORB_RADIUS_MIN, ORB_RADIUS_MAX)


## Distance between two sphere slots for a monster box of [param box] units.
static func orb_pitch(box: float) -> float:
	return clampf(ORB_PITCH_MIN * box / EnemyView.DRAW_UNITS, ORB_PITCH_MIN, ORB_PITCH_MAX)


## The rectangle of each block in a zone of [param zone] units. Keys: "timer", "abandon",
## "challenge", "enemy", "hint", "hp", "skills", "version", "auto", and "orbs" in landscape. Pure, so the layout can be read without a scene.
static func blocks(shape: AdaptiveLayout.Shape, zone: Vector2, monster_row: float) -> Dictionary:
	if shape == AdaptiveLayout.Shape.PORTRAIT:
		return _portrait_blocks(zone, monster_row)
	return _landscape_blocks(zone)


static func _portrait_blocks(zone: Vector2, monster_row: float) -> Dictionary:
	var gap: float = AdaptiveLayout.ROW_GAP
	var inner: float = zone.x - PADDING * 2.0
	var rects: Dictionary = {}
	var y: float = gap
	var row: float = AdaptiveLayout.ACTION_ROW_HEIGHT
	rects["abandon"] = Rect2(PADDING, y, ABANDON_WIDTH, row)
	rects["timer"] = Rect2(PADDING + ABANDON_WIDTH + gap, y, inner - ABANDON_WIDTH - gap, row)
	rects["challenge"] = Rect2(PADDING, y, inner, row)
	y += row + gap
	rects["enemy"] = Rect2(PADDING, y, inner, monster_row)
	var hint_h: float = _hint_height(inner)
	rects["hint"] = Rect2(PADDING, y + monster_row - hint_h, inner, hint_h)
	y += monster_row + gap
	rects["hp"] = Rect2(PADDING, y, inner, AdaptiveLayout.HP_ROW_HEIGHT)
	y += AdaptiveLayout.HP_ROW_HEIGHT + gap
	rects["skills"] = Rect2(PADDING, y, inner, AdaptiveLayout.SKILL_ROW_HEIGHT)
	y += AdaptiveLayout.SKILL_ROW_HEIGHT + gap
	row = AdaptiveLayout.FOOT_ROW_HEIGHT
	rects["version"] = Rect2(PADDING, y, VERSION_WIDTH, row)
	rects["auto"] = Rect2(zone.x - PADDING - AUTO_WIDTH, y, AUTO_WIDTH, row)
	return rects


static func _landscape_blocks(zone: Vector2) -> Dictionary:
	var side: float = clampf(zone.x * COLUMN_RATIO, COLUMN_MIN_WIDTH, COLUMN_MAX_WIDTH)
	var center_x: float = PADDING * 2.0 + side
	var center_w: float = zone.x - (PADDING * 2.0 + side) * 2.0
	var right_x: float = zone.x - PADDING - side
	var bottom: float = zone.y - PADDING
	var rects: Dictionary = {}
	rects["skills"] = Rect2(PADDING, PADDING, side, bottom - VERSION_HEIGHT - PADDING * 2.0)
	rects["version"] = Rect2(PADDING, bottom - VERSION_HEIGHT, side, VERSION_HEIGHT)
	rects["timer"] = Rect2(center_x, PADDING, center_w, BUTTON_HEIGHT)
	var hp_y: float = bottom - LANDSCAPE_HP_HEIGHT
	rects["hp"] = Rect2(center_x, hp_y, center_w, LANDSCAPE_HP_HEIGHT)
	var enemy_y: float = PADDING * 2.0 + BUTTON_HEIGHT
	var enemy_h: float = hp_y - PADDING - enemy_y
	rects["enemy"] = Rect2(center_x, enemy_y, center_w, enemy_h)
	var hint_h: float = _hint_height(center_w)
	rects["hint"] = Rect2(center_x, enemy_y + enemy_h - hint_h, center_w, hint_h)
	rects["auto"] = Rect2(right_x, bottom - BUTTON_HEIGHT, side, BUTTON_HEIGHT)
	var action_y: float = bottom - BUTTON_HEIGHT * 2.0 - PADDING
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


static func _append_grid(slots: PackedVector2Array, center: Vector2, pitch: float, columns: int, rows: int) -> void:
	for row in rows:
		for column in columns:
			var cell: Vector2 = Vector2(float(column) - float(columns - 1) / 2.0, float(row) - float(rows - 1) / 2.0)
			slots.append(center + cell * pitch)


func _place_blocks() -> void:
	var rects: Dictionary = blocks(_shape, size, _monster_row)
	_enemy.set_box_limit(size.x * BOX_ZONE_RATIO)
	fit_child_in_rect(_enemy, rects["enemy"])
	fit_child_in_rect(_hp_bar, rects["hp"])
	fit_child_in_rect(_hint, rects["hint"])
	fit_child_in_rect(_timer, rects["timer"])
	fit_child_in_rect(_abandon, rects["abandon"])
	fit_child_in_rect(_challenge, rects["challenge"])
	fit_child_in_rect(_skills, rects["skills"])
	fit_child_in_rect(_version, rects["version"])
	fit_child_in_rect(_auto, rects["auto"])
	var enemy_rect: Rect2 = rects["enemy"]
	_spot_center = enemy_rect.get_center()
	_box = _enemy.box_size()
	queue_redraw()
