class_name EnemyView
extends Control
## Draws the enemy as simple original shapes (no external art) and reports clicks
## that land on its body. Pure presentation: knows nothing about HP or gold.
##
## A boss (story 004) is drawn bigger, dark red with a gold outline, a gold crown
## and red pupils, so it can never be mistaken for a normal enemy.
##
## The node fills the slot the layout gives it. The drawing lives in a square box, the biggest one
## in that slot, capped by [constant MAX_BOX] and by [method set_box_limit]: all drawing and the hit
## radius follow [method box_scale] through [method CanvasItem.draw_set_transform]. The [member
## Control.scale] property stays reserved to [method play_hit].
##
## Stable contract, which the future cat art must keep: [signal clicked], [method set_stage],
## [method play_hit], [method anchor_global] (where effects aim) and [method hit_radius].
##
## Each finger on the body counts as one click (D6): a touch arrives as its own event, and the
## mouse press Godot emulates for the first finger is ignored, or that finger would count twice.
## There is no global attack key: the enemy takes the keyboard focus, and Space or Enter attacks
## while it has it, once per key press (no repeat when held).
##
## Transition between monsters (story 012, display only): each [method set_stage] after the first
## one shows the previous enemy as a "ghost" that fades and shrinks while the new one fades in and
## grows, all drawn in [method _draw] with [method CanvasItem.draw_set_transform]: neither
## [member Control.scale] nor the rectangle change, so [method anchor_global] never moves. The game
## never waits for it: [signal clicked], the click zone and [method hit_radius] belong to the new
## enemy at once, and a ghost takes no click. There is one ghost at most: a [method set_stage] during
## a transition replaces it. Past a kill rate, measured on the steps of [method _process], the
## transition shortens, then shrinks to a flash with no ghost: see [method effective_durations]. The
## values come from monster_transition.json through [method configure_transition]. With
## [method set_transition_enabled] off (the "Effets visuels" setting) or under [method set_paused]
## the change is instant; both cut a running transition short and nothing replays afterwards.
##
## Usage: place in a scene, connect [signal clicked], call [method set_stage]
## when the stage changes (with [code]is_boss = true[/code] on a boss stage) and
## [method play_hit] on each hit.

## The body was clicked (left button / touch-emulated press).
signal clicked

## Size of the box the shapes below are drawn in (display setting, not a gameplay value).
const DRAW_UNITS: float = 300.0
## Biggest box, in logical units (display setting, not a gameplay value).
const MAX_BOX: float = 640.0
const BODY_RADIUS: float = 120.0
## Bigger body of a boss. Its horns and crown keep the same height as a normal
## enemy's, so the boss banner above the enemy is never covered.
const BOSS_BODY_RADIUS: float = 140.0
const COLOR_BOSS_BODY: Color = Color(0.36, 0.05, 0.1)
const COLOR_BOSS_OUTLINE: Color = Color(1.0, 0.8, 0.2)
const COLOR_BOSS_PUPIL: Color = Color(0.95, 0.1, 0.1)
## The keyboard focus ring, in drawing units: light with a dark edge, as on the buttons.
const FOCUS_RING_GAP: float = 4.0
const FOCUS_RING_WIDTH: float = 5.0
const FOCUS_RING_EDGE_WIDTH: float = 9.0
const FOCUS_RING_POINTS: int = 64
const COLOR_FOCUS_RING: Color = Color(1.0, 1.0, 1.0)
const COLOR_FOCUS_EDGE: Color = Color(0.04, 0.05, 0.09)
## Longest step the transition clock takes in one frame (display setting, not a gameplay value).
const MAX_FRAME_SECONDS: float = 0.1
## Most kills remembered for the rate: past this count in the window, the rate stops rising.
const KILL_MEMORY: int = 64
## The only [code]schema_version[/code] of monster_transition.json this code reads.
const TRANSITION_SCHEMA_VERSION: int = 1
## The values of monster_transition.json when a key is missing or invalid: hypotheses to tune in
## that file (presentation only). Seconds, scales (1 = full size), an alpha and kills per second.
const TRANSITION_DEFAULTS: Dictionary = {
	"out_seconds": 0.15,
	"out_end_scale": 0.85,
	"in_seconds": 0.2,
	"in_start_scale": 0.85,
	"boss_in_seconds": 0.45,
	"boss_in_start_scale": 0.5,
	"boss_flash_alpha": 0.6,
	"crowded_kills_per_second": 3.0,
	"flash_kills_per_second": 6.0,
	"rate_window_seconds": 1.0,
	"flash_seconds": 0.05,
}
## Accepted [min, max] of each key above; a value outside it takes its default.
const TRANSITION_RANGES: Dictionary = {
	"out_seconds": [0.0, 2.0],
	"out_end_scale": [0.05, 1.0],
	"in_seconds": [0.0, 2.0],
	"in_start_scale": [0.05, 1.0],
	"boss_in_seconds": [0.0, 3.0],
	"boss_in_start_scale": [0.05, 1.0],
	"boss_flash_alpha": [0.0, 1.0],
	"crowded_kills_per_second": [0.1, 100.0],
	"flash_kills_per_second": [0.1, 200.0],
	"rate_window_seconds": [0.25, 2.0],
	"flash_seconds": [0.0, 0.5],
}

var _body_color: Color = Color(0.8, 0.4, 0.4)
var _is_boss: bool = false
var _tween: Tween
var _box_limit: float = MAX_BOX
var _settings: Dictionary = transition_settings(null)
var _transition_enabled: bool = true
var _paused: bool = false
# False until the first set_stage: the enemy there at the start does not fade in.
var _has_stage: bool = false
# The ghost, drawn while _out_left > 0. It may have died while fading in: it starts from the alpha
# and the scale it had then.
var _ghost_color: Color = Color.WHITE
var _ghost_boss: bool = false
var _ghost_alpha: float = 1.0
var _ghost_scale: float = 1.0
var _out_total: float = 0.0
var _out_left: float = 0.0
# The entry of the current enemy, while _in_left > 0.
var _in_total: float = 0.0
var _in_left: float = 0.0
var _in_start_scale: float = 1.0
var _in_flash: float = 0.0
# Ring buffer of the last kills, as values of _clock, oldest at _kill_head.
var _kill_times: PackedFloat64Array = PackedFloat64Array()
var _kill_head: int = 0
var _kill_count: int = 0
# Sum of the steps of _process while it runs; back to 0 when it stops.
var _clock: float = 0.0


func _init() -> void:
	_kill_times.resize(KILL_MEMORY)


func _ready() -> void:
	set_process(false)
	resized.connect(_on_resized)
	_on_resized()


func _process(delta: float) -> void:
	var step: float = clampf(delta, 0.0, MAX_FRAME_SECONDS)
	_clock += step
	if _is_animating():
		_out_left = maxf(_out_left - step, 0.0)
		_in_left = maxf(_in_left - step, 0.0)
		queue_redraw()
	_forget_old_kills()
	if _kill_count == 0 and not _is_animating():
		_clock = 0.0
		set_process(false)


## The body colour of [param stage] (visual variety only, not gameplay data).
static func stage_color(stage: int) -> Color:
	return Color.from_hsv(fposmod(float(stage) * 0.17, 1.0), 0.55, 0.85)


## The values of monster_transition.json read from [param data], complete and safe whatever
## [param data] holds: all of [constant TRANSITION_DEFAULTS] unless it is a [Dictionary] of the
## right [code]schema_version[/code], and the default of any key that is missing, not a number or
## outside [constant TRANSITION_RANGES]. A flash rate that is not above the crowded rate becomes
## twice that rate.
static func transition_settings(data: Variant) -> Dictionary:
	var settings: Dictionary = TRANSITION_DEFAULTS.duplicate()
	if not data is Dictionary:
		return settings
	var values: Dictionary = data
	var version: Variant = values.get("schema_version")
	if not (version is int or version is float) or float(version) != float(TRANSITION_SCHEMA_VERSION):
		return settings
	for key: String in TRANSITION_DEFAULTS:
		var value: Variant = values.get(key)
		if not (value is int or value is float):
			continue
		var number: float = float(value)
		var limits: Array = TRANSITION_RANGES[key]
		if is_finite(number) and number >= float(limits[0]) and number <= float(limits[1]):
			settings[key] = number
	var crowded: float = settings["crowded_kills_per_second"]
	if float(settings["flash_kills_per_second"]) <= crowded:
		settings["flash_kills_per_second"] = crowded * 2.0
	return settings


## The durations a transition really takes, in seconds: x for the ghost (0: no ghost), y for the
## entry. Up to [param crowded_rate] kills per second they are [param out_seconds] and
## [param in_seconds]; above it both shrink with the rate, so that they keep fitting between two
## kills; from [param flash_rate] on, there is no ghost and the entry takes [param flash_seconds],
## never more than [param in_seconds].
## [codeblock]
## EnemyView.effective_durations(0.15, 0.2, 4.0, 3.0, 6.0, 0.05) # (0.1125, 0.15)
## [/codeblock]
static func effective_durations(out_seconds: float, in_seconds: float, kills_per_second: float,
		crowded_rate: float, flash_rate: float, flash_seconds: float) -> Vector2:
	if kills_per_second <= crowded_rate:
		return Vector2(out_seconds, in_seconds)
	if kills_per_second >= flash_rate:
		return Vector2(0.0, minf(flash_seconds, in_seconds))
	var factor: float = crowded_rate / kills_per_second
	return Vector2(out_seconds * factor, in_seconds * factor)


## Sets the values of the transition from the parsed content of monster_transition.json. Anything
## invalid gives the safe values of [method transition_settings].
func configure_transition(data: Variant) -> void:
	_settings = transition_settings(data)


## Turns the transition on or off. Off, a running one ends at once and [method set_stage] is
## instant. Made for the "Effets visuels" setting.
func set_transition_enabled(enabled: bool) -> void:
	_transition_enabled = enabled
	if not _can_animate():
		_stop_transition()


## Hidden tab or modal screen: true ends a running transition at once and makes
## [method set_stage] instant until false. Nothing replays on the way back.
func set_paused(paused: bool) -> void:
	_paused = paused
	if not _can_animate():
		_stop_transition()


## Recolors the enemy for [param stage] (visual variety only, not gameplay data).
## With [param is_boss] it is drawn as the boss instead. Everything that counts for the game holds
## at once; only the drawing goes through the transition. Each call after the first counts as one
## kill for the rate of the transition.
func set_stage(stage: int, is_boss: bool = false) -> void:
	var previous_color: Color = _body_color
	var previous_boss: bool = _is_boss
	var previous_alpha: float = _entry_progress()
	var previous_scale: float = lerpf(_in_start_scale, 1.0, previous_alpha)
	var had_stage: bool = _has_stage
	_has_stage = true
	_is_boss = is_boss
	_body_color = COLOR_BOSS_BODY if is_boss else stage_color(stage)
	if had_stage and _can_animate():
		_ghost_color = previous_color
		_ghost_boss = previous_boss
		_ghost_alpha = previous_alpha
		_ghost_scale = previous_scale
		_start_transition()
	queue_redraw()


## Short squash animation on a hit.
func play_hit() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	scale = Vector2(0.92, 0.92)
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.1)


## Caps the box at [param limit] units, on top of [constant MAX_BOX] and of the slot.
func set_box_limit(limit: float) -> void:
	_box_limit = limit
	queue_redraw()


## Side of the box the enemy is drawn in, in logical units.
func box_size() -> float:
	return minf(minf(size.x, size.y), minf(MAX_BOX, _box_limit))


## Factor from the drawing units to this node's units.
func box_scale() -> float:
	return box_size() / DRAW_UNITS


## The center of the enemy in global coordinates, from the unscaled rectangle: a squash in
## progress does not move it. Convert it to a layer's local space before using it there.
func anchor_global() -> Vector2:
	var center: Vector2 = position + size / 2.0
	var parent: Control = get_parent_control()
	return parent.get_global_transform() * center if parent != null else center


## Radius of the clickable body around the anchor, in this node's units.
func hit_radius() -> float:
	return _radius() * box_scale()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept", false, true):
		clicked.emit()
		accept_event()
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and touch.position.distance_to(_center()) <= hit_radius():
			clicked.emit()
			accept_event()
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	# Never device == 0: the emulation has its own id, a real mouse may have any other.
	if button.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if button.position.distance_to(_center()) <= hit_radius():
		clicked.emit()
		accept_event()


func _draw() -> void:
	if _out_left > 0.0:
		var gone: float = 1.0 - _out_left / _out_total
		var end_scale: float = _ghost_scale * float(_settings["out_end_scale"])
		_draw_monster(_ghost_color, _ghost_boss, lerpf(_ghost_scale, end_scale, gone), _ghost_alpha * (1.0 - gone))
	var progress: float = _entry_progress()
	_draw_monster(_body_color, _is_boss, lerpf(_in_start_scale, 1.0, progress), progress)
	if _in_left > 0.0 and _in_flash > 0.0:
		draw_circle(Vector2.ZERO, BOSS_BODY_RADIUS, Color(1.0, 1.0, 1.0, _in_flash * (1.0 - progress)))
	# has_focus(true): the focus a click gives is hidden, only the keyboard draws the ring. It belongs
	# to the slot, not to the entry: it neither fades nor grows.
	if has_focus(true):
		var factor: float = box_scale()
		draw_set_transform(_center(), 0.0, Vector2(factor, factor))
		var ring: float = BOSS_BODY_RADIUS + FOCUS_RING_GAP
		draw_arc(Vector2.ZERO, ring, 0.0, TAU, FOCUS_RING_POINTS, COLOR_FOCUS_EDGE, FOCUS_RING_EDGE_WIDTH)
		draw_arc(Vector2.ZERO, ring, 0.0, TAU, FOCUS_RING_POINTS, COLOR_FOCUS_RING, FOCUS_RING_WIDTH)


# One monster around the center, [param size_factor] times its size, every shape at [param alpha].
# It leaves the transform in place, for what is drawn over this monster.
func _draw_monster(body_color: Color, boss: bool, size_factor: float, alpha: float) -> void:
	var factor: float = box_scale() * size_factor
	draw_set_transform(_center(), 0.0, Vector2(factor, factor))
	var c: Vector2 = Vector2.ZERO
	var tint: Color = Color(1.0, 1.0, 1.0, alpha)
	var radius: float = BOSS_BODY_RADIUS if boss else BODY_RADIUS
	var dark: Color = body_color.darkened(0.45) * tint
	var outline: Color = COLOR_BOSS_OUTLINE * tint
	# Horns.
	draw_colored_polygon(PackedVector2Array([c + Vector2(-100, -60), c + Vector2(-70, -150), c + Vector2(-40, -100)]), dark)
	draw_colored_polygon(PackedVector2Array([c + Vector2(100, -60), c + Vector2(70, -150), c + Vector2(40, -100)]), dark)
	# Body, outline first.
	draw_circle(c, radius + (9.0 if boss else 5.0), outline if boss else dark)
	draw_circle(c, radius, body_color * tint)
	if boss:
		draw_colored_polygon(PackedVector2Array([
				c + Vector2(-45, -128), c + Vector2(-45, -148), c + Vector2(-22, -136),
				c + Vector2(0, -150), c + Vector2(22, -136), c + Vector2(45, -148),
				c + Vector2(45, -128)]), outline)
	# Eyes.
	draw_circle(c + Vector2(-42, -20), 24.0, Color.WHITE * tint)
	draw_circle(c + Vector2(42, -20), 24.0, Color.WHITE * tint)
	var pupil: Color = (COLOR_BOSS_PUPIL if boss else Color.BLACK) * tint
	draw_circle(c + Vector2(-38, -16), 11.0, pupil)
	draw_circle(c + Vector2(38, -16), 11.0, pupil)
	# Mouth.
	draw_rect(Rect2(c + Vector2(-50, 42), Vector2(100, 14)), dark)


# Replaces whatever is running: there is one ghost and one entry at most, and the process stops by
# itself once they are over and the kills have left the window.
func _start_transition() -> void:
	_remember_kill()
	set_process(true)
	var rate: float = float(_kill_count) / float(_settings["rate_window_seconds"])
	var flash_rate: float = _settings["flash_kills_per_second"]
	var durations: Vector2 = effective_durations(float(_settings["out_seconds"]),
			float(_settings["boss_in_seconds" if _is_boss else "in_seconds"]), rate,
			float(_settings["crowded_kills_per_second"]), flash_rate, float(_settings["flash_seconds"]))
	_out_total = durations.x
	_out_left = durations.x
	_in_total = durations.y
	_in_left = durations.y
	# The flash is a bare fade: no growth, and no light on a boss.
	var flashing: bool = rate >= flash_rate
	_in_start_scale = 1.0
	_in_flash = 0.0
	if not flashing:
		_in_start_scale = float(_settings["boss_in_start_scale" if _is_boss else "in_start_scale"])
		_in_flash = float(_settings["boss_flash_alpha"]) if _is_boss else 0.0


func _stop_transition() -> void:
	_out_left = 0.0
	_in_left = 0.0
	_kill_head = 0
	_kill_count = 0
	_clock = 0.0
	set_process(false)
	queue_redraw()


func _can_animate() -> bool:
	return _transition_enabled and not _paused


func _is_animating() -> bool:
	return _out_left > 0.0 or _in_left > 0.0


# From 0 to 1 along the entry, slowing down at the end; 1 when no entry runs.
func _entry_progress() -> float:
	if _in_left <= 0.0:
		return 1.0
	var left: float = _in_left / _in_total
	return 1.0 - left * left


func _remember_kill() -> void:
	_forget_old_kills()
	if _kill_count == KILL_MEMORY:
		_kill_head = (_kill_head + 1) % KILL_MEMORY
		_kill_count -= 1
	_kill_times[(_kill_head + _kill_count) % KILL_MEMORY] = _clock
	_kill_count += 1


func _forget_old_kills() -> void:
	var oldest_kept: float = _clock - float(_settings["rate_window_seconds"])
	while _kill_count > 0 and _kill_times[_kill_head] <= oldest_kept:
		_kill_head = (_kill_head + 1) % KILL_MEMORY
		_kill_count -= 1


func _on_resized() -> void:
	pivot_offset = _center()
	queue_redraw()


func _radius() -> float:
	return BOSS_BODY_RADIUS if _is_boss else BODY_RADIUS


func _center() -> Vector2:
	return size / 2.0
