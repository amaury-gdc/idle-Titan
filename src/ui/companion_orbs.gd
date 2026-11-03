class_name CompanionOrbs
extends Control
## Draws the companions beside the monster (story 009): one coloured mouse per companion the player
## owns (a [MouseFace], story 019b; spheres before it, hence the names here), and a small ball
## thrown from it to the monster each time that companion attacks. Pure display: the damage falls when the companion attacks, the ball only shows it, and a
## ball that is not thrown changes nothing in the game.
## Implements production/epics/idle-titans/story-009-visual-feedback.md ("Compagnons").
##
## ONE canvas item draws every ball in [method _draw]: no node per ball. The mice sit on a second
## canvas item behind it, redrawn only when they change (slots, levels, setting), never while the
## balls fly. They are textures: a mouse is 11 circles, and 8 of them drawn as circles cost the
## main thread about 1.5 points with the processor slowed 4 times, at every frame even when not
## redrawn (story 019b, measured in the export). So each companion's mouse is painted once with
## [method MouseFace.draw] into an atlas (a [SubViewport] rendered once, at [constant BAKE_OVERSAMPLE]
## times the screen pixels so that the linear filter smooths the edges), painted again only when the
## size of the mice or of the screen pixels changes. Two atlases take turns: the old one stays on
## screen, stretched, until the new one is rendered, so a resize never blinks. The
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
## Atlas pixels per screen pixel (display setting, not a gameplay value).
const BAKE_OVERSAMPLE: float = 2.0
## Mice per row of the atlas.
const ATLAS_COLUMNS: int = 4
## Free room around a mouse in its cell, in units: the linear filter never reaches the next cell.
const ATLAS_PADDING: float = 2.0

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
## The canvas item of the mice, behind the balls, at this node's origin so that it shares its
## coordinates.
var _mice: Control = Control.new()
## The two atlases, and what each was (or is being) painted at: pixels per unit, mouse width in
## units, cell side in pixels.
var _bakers: Array[SubViewport] = []
var _bake_scales: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _bake_sizes: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _bake_cells: PackedInt32Array = PackedInt32Array([0, 0])
## The atlas on screen; none until the first one is rendered.
var _front: int = 0
var _has_front: bool = false
## The atlas being painted, shown at the end of the frame that renders it; -1 for none.
var _pending: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mice.show_behind_parent = true
	_mice.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# The atlas was painted on a transparent background: its colours are premultiplied.
	var blend: CanvasItemMaterial = CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_mice.material = blend
	_mice.draw.connect(_draw_mice)
	add_child(_mice)
	for i in 2:
		var baker: SubViewport = SubViewport.new()
		baker.transparent_bg = true
		baker.disable_3d = true
		baker.gui_disable_input = true
		baker.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var painter: Control = Control.new()
		painter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		painter.draw.connect(_paint_atlas.bind(painter, i))
		baker.add_child(painter)
		add_child(baker)
		_bakers.append(baker)
	_ball_busy.resize(BALL_POOL_SIZE)
	_ball_age.resize(BALL_POOL_SIZE)
	_ball_from.resize(BALL_POOL_SIZE)
	_ball_color.resize(BALL_POOL_SIZE)
	set_process(false)


func _notification(what: int) -> void:
	# The screen pixels per unit change with the window, even when the layout keeps its slots.
	if what == NOTIFICATION_ENTER_TREE:
		get_viewport().size_changed.connect(_bake)
		_bake.call_deferred()
	elif what == NOTIFICATION_EXIT_TREE:
		get_viewport().size_changed.disconnect(_bake)


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
	var ball_radius: float = BALL_RADIUS * _orb_radius / ORB_RADIUS
	for i in BALL_POOL_SIZE:
		if _ball_busy[i] == 0:
			continue
		var position_now: Vector2 = _ball_from[i].lerp(_anchor, _ball_age[i] / BALL_FLIGHT_SECONDS)
		draw_circle(position_now, ball_radius + OUTLINE_WIDTH * 0.5, OUTLINE_COLOR)
		draw_circle(position_now, ball_radius, _ball_color[i])


func _draw_mice() -> void:
	if not _enabled or not _has_front:
		return
	var texture: ViewportTexture = _bakers[_front].get_texture()
	var cell: int = _bake_cells[_front]
	# A mouse as wide as the sphere was (story 019b): the radius is half its width. Until the new
	# atlas is rendered, the old one is stretched to the new size.
	var side: float = float(cell) / _bake_scales[_front] * (_orb_radius * 2.0 / _bake_sizes[_front])
	for i in _colors.size():
		if _owned[i] == 0:
			continue
		var source: Rect2 = Rect2(atlas_origin(i, cell), Vector2(cell, cell))
		_mice.draw_texture_rect_region(texture, Rect2(_orb_position(i) - Vector2(side, side) / 2.0, Vector2(side, side)), source)


# Paints every companion's mouse, each in the center of its cell, on atlas [param index].
func _paint_atlas(painter: Control, index: int) -> void:
	var scale_now: float = _bake_scales[index]
	var cell: int = _bake_cells[index]
	if cell == 0:
		return
	painter.draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_now, scale_now))
	for i in _colors.size():
		var center: Vector2 = (atlas_origin(i, cell) + Vector2(cell, cell) / 2.0) / scale_now
		MouseFace.draw(painter, center, _bake_sizes[index], _colors[i])


# Paints the atlas that is not on screen for the current mouse width and screen pixels, and shows
# it once rendered. Nothing outside the tree: no screen, no pixels.
func _bake() -> void:
	if not is_inside_tree() or _colors.is_empty():
		return
	var scale_now: float = _screen_scale() * BAKE_OVERSAMPLE
	var mouse: float = _orb_radius * 2.0
	if _has_front and is_equal_approx(_bake_scales[_front], scale_now) and is_equal_approx(_bake_sizes[_front], mouse):
		_pending = -1 # An atlas painted for another size is no longer wanted.
		return
	var back: int = 1 - _front if _has_front else _front
	var cell: int = atlas_cell_pixels(mouse, scale_now)
	_bake_scales[back] = scale_now
	_bake_sizes[back] = mouse
	_bake_cells[back] = cell
	_bakers[back].size = atlas_pixels(_colors.size(), cell)
	_bakers[back].render_target_update_mode = SubViewport.UPDATE_ONCE
	(_bakers[back].get_child(0) as Control).queue_redraw()
	_pending = back
	if not RenderingServer.frame_post_draw.is_connected(_show_atlas):
		RenderingServer.frame_post_draw.connect(_show_atlas, CONNECT_ONE_SHOT)


func _show_atlas() -> void:
	if _pending < 0:
		return
	_front = _pending
	_has_front = true
	_pending = -1
	_mice.queue_redraw()


# Screen pixels per unit where the mice are drawn: the window stretch and the transforms above.
func _screen_scale() -> float:
	return absf(get_viewport().get_final_transform().get_scale().x * _mice.get_global_transform_with_canvas().get_scale().x)


# The mice and the balls: everything that changes what stands, not what flies.
func _redraw_all() -> void:
	queue_redraw()
	_mice.queue_redraw()


## Side in pixels of an atlas cell that holds a mouse [param mouse] units wide, outline and
## [constant ATLAS_PADDING] included, painted at [param pixels_per_unit].
static func atlas_cell_pixels(mouse: float, pixels_per_unit: float) -> int:
	var extent: Vector2 = MouseFace.half_extent(mouse)
	return ceili((maxf(extent.x, extent.y) + ATLAS_PADDING) * 2.0 * pixels_per_unit)


## Top left corner, in pixels, of the cell of companion [param i] in an atlas of [param cell] pixel
## cells.
@warning_ignore("integer_division")
static func atlas_origin(i: int, cell: int) -> Vector2:
	return Vector2(float(i % ATLAS_COLUMNS * cell), float(i / ATLAS_COLUMNS * cell))


## Size in pixels of an atlas of [param count] mice in [param cell] pixel cells.
static func atlas_pixels(count: int, cell: int) -> Vector2i:
	var rows: int = ceili(float(maxi(count, 1)) / ATLAS_COLUMNS)
	return Vector2i(mini(maxi(count, 1), ATLAS_COLUMNS) * cell, rows * cell)


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
	# Other colours: the atlas on screen no longer holds these mice.
	_has_front = false
	_bake()
	_redraw_all()


## Where the balls fly to: the center of the monster, in this node's coordinates.
func set_target_point(point: Vector2) -> void:
	_anchor = point


## Where the spheres stand, in this node's coordinates, and their radius (half the width of a
## mouse): one fixed slot per companion in roster order. An empty [param slots] goes back to the
## default grid.
func set_slots(slots: PackedVector2Array, radius: float = ORB_RADIUS) -> void:
	_slots = slots
	_orb_radius = radius
	_bake()
	_redraw_all()


## Shows the sphere of [param id] when [param level] is 1 or more, hides it otherwise. An unknown id
## is ignored. Made to follow [signal CompanionManager.companion_leveled_up] and to read the real
## levels after a load.
func set_level(id: String, level: int) -> void:
	var i: int = _index.get(id, -1)
	if i < 0:
		return
	_owned[i] = 1 if level >= 1 else 0
	_mice.queue_redraw()


## The "Effets visuels" setting: off draws nothing, runs nothing and ignores new attacks.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _is_active():
		clear()
	_redraw_all()


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
