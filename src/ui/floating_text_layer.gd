class_name FloatingTextLayer
extends Control
## The one floating text system of the main screen (story 009): the damage numbers of the
## player's hits and the "+gold" of a kill. Pure display: it reads the core signals through the
## main screen and never changes the game.
## Implements production/epics/idle-titans/story-009-visual-feedback.md ("Dégâts", "Or",
## "Système commun").
##
## A fixed pool of [constant POOL_SIZE] labels is built once, in [method _init], and reused:
## nothing is created or freed while playing. When all of them are busy the OLDEST text is
## taken over. Every label has a dark outline and ignores the mouse, as does the layer, so the
## enemy and the buttons stay clickable through the texts. The animation is the layer's own
## [method _process] (no tween), on parallel arrays, and it only runs while a text is alive.
##
## What is shown: a click, a critical hit (bigger, ends with "!") and the skill burst (very
## big); a companion attack shows nothing. A kill shows its gold, golden, rising to the right and
## fading, bigger for a boss. The small sideways offset of the hit texts comes from a counter, not
## from a random generator: the dice of the game are never touched.
##
## Two switches stop everything: [method set_enabled] (the "Effets visuels" setting) and
## [method set_paused] (hidden tab, modal screen). Either one clears the running texts, so that
## nothing replays when it ends, and makes the layer ignore new events.
##
## Usage:
## [codeblock]
## var texts: FloatingTextLayer = FloatingTextLayer.new()
## add_child(texts)
## texts.set_target_point(enemy_center)
## floors.hit_landed.connect(texts.show_hit)
## floors.kill_rewarded.connect(texts.show_gold)
## [/codeblock]

## Number of labels, which is the most texts shown at once (display setting, not a gameplay value).
const POOL_SIZE: int = 12
## Longest frame the animation honors, in seconds: a long frame (hidden tab, debugger pause) cannot
## jump the texts (display setting, not a gameplay value).
const MAX_FRAME_SECONDS: float = 0.1
## Size of every label; the text is centered in it (display setting, not a gameplay value).
const LABEL_SIZE: Vector2 = Vector2(480.0, 110.0)
## Dark outline of every text (display setting, not a gameplay value).
const OUTLINE_SIZE: int = 8
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)
## Font sizes (display setting, not a gameplay value).
const FONT_SIZE_HIT: int = 30
const FONT_SIZE_CRITICAL: int = 46
const FONT_SIZE_BURST: int = 66
const FONT_SIZE_GOLD: int = 30
const FONT_SIZE_GOLD_BOSS: int = 48
## Colors (display setting, not a gameplay value).
const COLOR_HIT: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_CRITICAL: Color = Color(1.0, 0.62, 0.45, 1.0)
const COLOR_BURST: Color = Color(0.55, 0.85, 1.0, 1.0)
const COLOR_GOLD: Color = Color(1.0, 0.84, 0.25, 1.0)
## Seconds a text lives, and the fraction of that time before it starts to fade (display setting).
const HIT_SECONDS: float = 0.8
const GOLD_SECONDS: float = 1.3
const FADE_START: float = 0.6
## Where a text starts relative to the anchor, and how far it travels (display setting).
## A hit rises straight up; the gold rises diagonally to the RIGHT.
const HIT_START_OFFSET: Vector2 = Vector2(0.0, -40.0)
const HIT_TRAVEL: Vector2 = Vector2(0.0, -110.0)
const GOLD_START_OFFSET: Vector2 = Vector2(30.0, -90.0)
const GOLD_TRAVEL: Vector2 = Vector2(130.0, -130.0)
## Sideways offsets of the hit texts, taken in turn by a counter so that quick clicks do not
## pile up on one spot (display setting, not a gameplay value).
const HIT_JITTER_X: PackedFloat32Array = [-40.0, 25.0, -15.0, 45.0, -55.0, 10.0, 35.0, -30.0]

var _labels: Array[Label] = []
var _busy: PackedByteArray = PackedByteArray()
var _age: PackedFloat32Array = PackedFloat32Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _origin: PackedVector2Array = PackedVector2Array()
var _travel: PackedVector2Array = PackedVector2Array()
## Start order of each text; the smallest number of the busy ones is the oldest.
var _order: PackedInt64Array = PackedInt64Array()
var _busy_count: int = 0
var _counter: int = 0
var _anchor: Vector2 = Vector2.ZERO
var _enabled: bool = true
var _paused: bool = false


## Builds the pool: [constant POOL_SIZE] hidden labels, the only ones this layer will ever have.
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy.resize(POOL_SIZE)
	_age.resize(POOL_SIZE)
	_life.resize(POOL_SIZE)
	_origin.resize(POOL_SIZE)
	_travel.resize(POOL_SIZE)
	_order.resize(POOL_SIZE)
	for i in POOL_SIZE:
		var label: Label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size = LABEL_SIZE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
		label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
		label.visible = false
		add_child(label)
		_labels.append(label)
	set_process(false)


func _process(delta: float) -> void:
	var step: float = clampf(delta, 0.0, MAX_FRAME_SECONDS)
	for i in POOL_SIZE:
		if _busy[i] == 0:
			continue
		_age[i] += step
		var t: float = _age[i] / _life[i]
		if t >= 1.0:
			_release(i)
			continue
		var eased: float = 1.0 - (1.0 - t) * (1.0 - t)
		var label: Label = _labels[i]
		label.position = _origin[i] - LABEL_SIZE / 2.0 + _travel[i] * eased
		label.modulate.a = 1.0 if t < FADE_START else (1.0 - t) / (1.0 - FADE_START)
	if _busy_count == 0:
		set_process(false)


## Where the texts start: the center of the monster, in this layer's coordinates.
func set_target_point(point: Vector2) -> void:
	_anchor = point


## The "Effets visuels" setting: off clears every text and ignores new events.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _is_active():
		clear()


## Hidden tab or modal screen: true clears every text and ignores new events until false.
func set_paused(paused: bool) -> void:
	_paused = paused
	if not _is_active():
		clear()


## Hides every running text at once. Nothing is created or freed.
func clear() -> void:
	for i in POOL_SIZE:
		_release(i)
	set_process(false)


## How many texts are alive right now (never more than [constant POOL_SIZE]).
func busy_count() -> int:
	return _busy_count


## Shows the damage of one hit. Made to be connected to [signal FloorManager.hit_landed]:
## [param damage] is the final damage, [param source] a [enum FloorManager.HitSource].
## A companion attack ([constant FloorManager.HitSource.AUTO]) shows nothing.
func show_hit(damage: BigNumber, source: int) -> void:
	if not _is_active():
		return
	var text: String = damage.format()
	var font_size: int = FONT_SIZE_HIT
	var color: Color = COLOR_HIT
	match source:
		FloorManager.HitSource.CRITICAL:
			text = tr("%s !") % text
			font_size = FONT_SIZE_CRITICAL
			color = COLOR_CRITICAL
		FloorManager.HitSource.BURST:
			font_size = FONT_SIZE_BURST
			color = COLOR_BURST
		FloorManager.HitSource.CLICK:
			pass
		_:
			return
	var jitter: Vector2 = Vector2(HIT_JITTER_X[_counter % HIT_JITTER_X.size()], 0.0)
	_start(text, font_size, color, _anchor + HIT_START_OFFSET + jitter, HIT_TRAVEL, HIT_SECONDS)


## Shows the gold of a kill. Made to be connected to [signal FloorManager.kill_rewarded]:
## [param gold] is the reward really granted, [param was_boss] makes the text bigger.
func show_gold(_stage: int, gold: BigNumber, was_boss: bool) -> void:
	if not _is_active():
		return
	var font_size: int = FONT_SIZE_GOLD_BOSS if was_boss else FONT_SIZE_GOLD
	_start(tr("+%s or") % gold.format(), font_size, COLOR_GOLD, _anchor + GOLD_START_OFFSET, GOLD_TRAVEL, GOLD_SECONDS)


func _is_active() -> bool:
	return _enabled and not _paused


# Puts a text in the first free label, else takes over the oldest one.
func _start(text: String, font_size: int, color: Color, origin: Vector2, travel: Vector2, life: float) -> void:
	var slot: int = -1
	var oldest: int = 0
	for i in POOL_SIZE:
		if _busy[i] == 0:
			slot = i
			break
		if _order[i] < _order[oldest]:
			oldest = i
	if slot < 0:
		slot = oldest
	if _busy[slot] == 0:
		_busy[slot] = 1
		_busy_count += 1
	_counter += 1
	_order[slot] = _counter
	_age[slot] = 0.0
	_life[slot] = life
	_origin[slot] = origin
	_travel[slot] = travel
	var label: Label = _labels[slot]
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.modulate = Color.WHITE
	label.position = origin - LABEL_SIZE / 2.0
	label.visible = true
	set_process(true)


func _release(i: int) -> void:
	if _busy[i] == 0:
		return
	_busy[i] = 0
	_busy_count -= 1
	_labels[i].visible = false
