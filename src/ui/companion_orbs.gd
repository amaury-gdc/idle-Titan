class_name CompanionOrbs
extends Control
## Draws the companions beside the monster (story 009): one coloured sphere per companion the
## player owns, and a small ball thrown from the sphere to the monster each time that companion
## attacks. Pure display: the damage falls when the companion attacks, the ball only shows it, and a
## ball that is not thrown changes nothing in the game.
## Implements production/epics/idle-titans/story-009-visual-feedback.md ("Compagnons").
##
## ONE canvas item draws every sphere and every ball in [method _draw]: no node per ball. The
## balls live in a fixed pool of [constant BALL_POOL_SIZE] slots on parallel arrays, so nothing is
## allocated while playing. A ball is thrown only if the companion has not thrown one for
## [constant BALL_MIN_INTERVAL_SECONDS] of display time (accumulated from [method _process]) and a slot
## is free; otherwise the attack is simply not shown. The layer ignores the mouse.
##
## The sphere colours come from the "color" field of companions_roster.json (see
## assets/data/data_schema.md); a missing or invalid one gives [constant DEFAULT_COLOR]. Each
## companion has a fixed slot in a grid, in roster order, so a sphere never moves when another
## companion is bought. The main screen replaces the default grid with the slots of its layout
## through [method set_slots], at each change of size or shape; the rest of the API is the same.
##
## Two switches stop the animation: [method set_enabled] (the "Effets visuels" setting, off draws
## nothing at all) and [method set_paused] (hidden tab, modal screen: the balls are cleared and
## nothing runs, the spheres stay).
##
## Usage:
## [codeblock]
## var orbs: CompanionOrbs = CompanionOrbs.new()
## add_child(orbs)
## orbs.setup(DataLoader.load_json("res://assets/data/companions_roster.json"))
## orbs.set_target_point(enemy_center)
## orbs.set_level("scout", 3)
## companions.companion_attacked.connect(orbs.on_companion_attacked)
## [/codeblock]

## Balls that can fly at once (display setting, not a gameplay value).
const BALL_POOL_SIZE: int = 24
## Display time a companion waits between two balls (display setting, not a gameplay value).
const BALL_MIN_INTERVAL_SECONDS: float = 0.25
## Time a ball takes to reach the monster (display setting, not a gameplay value).
const BALL_FLIGHT_SECONDS: float = 0.3
## Longest frame the animation honors, in seconds (display setting, not a gameplay value).
const MAX_FRAME_SECONDS: float = 0.1
## Sizes in pixels (display setting, not a gameplay value).
const ORB_RADIUS: float = 18.0
const BALL_RADIUS: float = 6.0
## Where the spheres stand: the grid of the free column between the monster (x 235 to 485) and
## the companion panel (x from 680), in the 1280x720 screen: low enough for a loot message of
## several lines (it starts at y 234 and grows down) and above the HP bar (y 510). Three rows of
## three hold the 8 companions (display setting, not a gameplay value).
const ORB_GRID_ORIGIN: Vector2 = Vector2(545.0, 395.0)
const ORB_GRID_SPACING: Vector2 = Vector2(52.0, 45.0)
const ORB_GRID_COLUMNS: int = 3
## Colour of a companion without a valid "color" in the roster.
const DEFAULT_COLOR: Color = Color(0.7, 0.7, 0.75, 1.0)
const OUTLINE_COLOR: Color = Color(0.04, 0.05, 0.09, 1.0)
const OUTLINE_WIDTH: float = 3.0
const HIGHLIGHT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.45)

var _index: Dictionary = {}
var _colors: PackedColorArray = PackedColorArray()
var _owned: PackedByteArray = PackedByteArray()
## Display time since the last ball of each companion, capped at the minimum interval.
var _since_ball: PackedFloat32Array = PackedFloat32Array()
var _ball_busy: PackedByteArray = PackedByteArray()
var _ball_age: PackedFloat32Array = PackedFloat32Array()
var _ball_from: PackedVector2Array = PackedVector2Array()
var _ball_color: PackedColorArray = PackedColorArray()
var _ball_count: int = 0
var _anchor: Vector2 = Vector2.ZERO
var _enabled: bool = true
var _paused: bool = false
## Positions set by [method set_slots]; empty means the default grid.
var _slots: PackedVector2Array = PackedVector2Array()
var _orb_radius: float = ORB_RADIUS


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ball_busy.resize(BALL_POOL_SIZE)
	_ball_age.resize(BALL_POOL_SIZE)
	_ball_from.resize(BALL_POOL_SIZE)
	_ball_color.resize(BALL_POOL_SIZE)
	set_process(false)


func _process(delta: float) -> void:
	var step: float = clampf(delta, 0.0, MAX_FRAME_SECONDS)
	var was_flying: bool = _ball_count > 0
	var waiting: bool = false
	for i in _since_ball.size():
		_since_ball[i] = minf(_since_ball[i] + step, BALL_MIN_INTERVAL_SECONDS)
		waiting = waiting or _since_ball[i] < BALL_MIN_INTERVAL_SECONDS
	for i in BALL_POOL_SIZE:
		if _ball_busy[i] == 0:
			continue
		_ball_age[i] += step
		if _ball_age[i] >= BALL_FLIGHT_SECONDS:
			_ball_busy[i] = 0
			_ball_count -= 1
	if was_flying:
		queue_redraw()
	if _ball_count == 0 and not waiting:
		set_process(false)


func _draw() -> void:
	if not _enabled:
		return
	for i in _colors.size():
		if _owned[i] == 0:
			continue
		var center: Vector2 = _orb_position(i)
		draw_circle(center, _orb_radius + OUTLINE_WIDTH, OUTLINE_COLOR)
		draw_circle(center, _orb_radius, _colors[i])
		draw_circle(center + Vector2(-_orb_radius, -_orb_radius) * 0.35, _orb_radius * 0.35, HIGHLIGHT_COLOR)
	var ball_radius: float = BALL_RADIUS * _orb_radius / ORB_RADIUS
	for i in BALL_POOL_SIZE:
		if _ball_busy[i] == 0:
			continue
		var position_now: Vector2 = _ball_from[i].lerp(_anchor, _ball_age[i] / BALL_FLIGHT_SECONDS)
		draw_circle(position_now, ball_radius + OUTLINE_WIDTH * 0.5, OUTLINE_COLOR)
		draw_circle(position_now, ball_radius, _ball_color[i])


## Reads the companions of the roster data (the Variant [method DataLoader.load_json] returns): the
## "id" of each entry and its "color" (a hex string such as "#4fc3f7"). Entries without a valid id
## are skipped; a missing or invalid colour gives [constant DEFAULT_COLOR]. No companion is owned
## afterwards: call [method set_level]. Replaces any earlier setup.
func setup(roster: Variant) -> void:
	_index.clear()
	_colors.clear()
	_owned.clear()
	_since_ball.clear()
	clear()
	var entries: Variant = (roster as Dictionary).get("companions") if roster is Dictionary else null
	if entries is Array:
		for entry: Variant in entries:
			var data: Dictionary = entry if entry is Dictionary else {}
			var id: Variant = data.get("id")
			if not id is String or _index.has(id):
				continue
			var hex: Variant = data.get("color")
			_index[id] = _colors.size()
			_colors.append(Color.html(hex) if hex is String and Color.html_is_valid(hex) else DEFAULT_COLOR)
			_owned.append(0)
			_since_ball.append(BALL_MIN_INTERVAL_SECONDS)
	queue_redraw()


## Where the balls fly to: the center of the monster, in this node's coordinates.
func set_target_point(point: Vector2) -> void:
	_anchor = point


## Where the spheres stand, in this node's coordinates, and their radius: one fixed slot per
## companion in roster order. An empty [param slots] goes back to the default grid.
func set_slots(slots: PackedVector2Array, radius: float = ORB_RADIUS) -> void:
	_slots = slots
	_orb_radius = radius
	queue_redraw()


## Shows the sphere of [param id] when [param level] is 1 or more, hides it otherwise. An unknown id
## is ignored. Made to follow [signal CompanionManager.companion_leveled_up] and to read the real
## levels after a load.
func set_level(id: String, level: int) -> void:
	var i: int = _index.get(id, -1)
	if i < 0:
		return
	_owned[i] = 1 if level >= 1 else 0
	queue_redraw()


## The "Effets visuels" setting: off draws nothing, runs nothing and ignores new attacks.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _is_active():
		clear()
	queue_redraw()


## Hidden tab or modal screen: true clears the balls and stops the animation until false. The
## spheres stay drawn.
func set_paused(paused: bool) -> void:
	_paused = paused
	if not _is_active():
		clear()


## Removes every ball in flight at once and stops the animation.
func clear() -> void:
	_ball_busy.fill(0)
	_ball_count = 0
	# The intervals only advance in _process, stopped here: a waiting one would never run out.
	_since_ball.fill(BALL_MIN_INTERVAL_SECONDS)
	set_process(false)
	queue_redraw()


## How many balls are flying right now (never more than [constant BALL_POOL_SIZE]).
func active_ball_count() -> int:
	return _ball_count


## Throws a ball from the sphere of [param id] to the anchor, unless the companion threw one less
## than [constant BALL_MIN_INTERVAL_SECONDS] ago, all the slots are busy, the companion is not owned or
## the effects are stopped. Made to be connected to [signal CompanionManager.companion_attacked];
## the damage is not used, and nothing here ever feeds back into the game.
func on_companion_attacked(id: String, _damage: BigNumber) -> void:
	if not _is_active():
		return
	var i: int = _index.get(id, -1)
	if i < 0 or _owned[i] == 0 or _since_ball[i] < BALL_MIN_INTERVAL_SECONDS:
		return
	for slot in BALL_POOL_SIZE:
		if _ball_busy[slot] != 0:
			continue
		_ball_busy[slot] = 1
		_ball_age[slot] = 0.0
		_ball_from[slot] = _orb_position(i)
		_ball_color[slot] = _colors[i]
		_ball_count += 1
		_since_ball[i] = 0.0
		set_process(true)
		queue_redraw()
		return


func _is_active() -> bool:
	return _enabled and not _paused


@warning_ignore("integer_division")
func _orb_position(i: int) -> Vector2:
	if not _slots.is_empty():
		return _slots[i % _slots.size()]
	return ORB_GRID_ORIGIN + Vector2(float(i % ORB_GRID_COLUMNS), float(i / ORB_GRID_COLUMNS)) * ORB_GRID_SPACING
