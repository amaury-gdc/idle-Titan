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
## fading, bigger for a boss. When enemies die very fast the golds merge (story 011): the first kill
## shows at once, and for [constant GOLD_MERGE_SECONDS] the next ones add to that same text, which
## takes the boss size if a boss is in the sum and stays inside the bounds as it grows. The small
## sideways offset of the hit texts comes from a counter, not from a random generator: the dice of
## the game are never touched.
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
const OUTLINE_SIZE: int = 6
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)
## Font sizes (display setting, not a gameplay value).
const FONT_SIZE_HIT: int = 24
const FONT_SIZE_CRITICAL: int = 32
const FONT_SIZE_BURST: int = 48
const FONT_SIZE_GOLD: int = 24
const FONT_SIZE_GOLD_BOSS: int = 32
## Colors (display setting, not a gameplay value).
const COLOR_HIT: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_CRITICAL: Color = Color(1.0, 0.62, 0.45, 1.0)
const COLOR_BURST: Color = Color(0.55, 0.85, 1.0, 1.0)
const COLOR_GOLD: Color = Color(1.0, 0.84, 0.25, 1.0)
## Seconds a text lives, and the fraction of that time before it starts to fade (display setting).
const HIT_SECONDS: float = 0.8
const GOLD_SECONDS: float = 1.3
const FADE_START: float = 0.6
## Seconds after a gold text opens during which the next kills add to it (display setting, not a
## gameplay value).
const GOLD_MERGE_SECONDS: float = 0.3
## [member _merge_slot] when no gold text is open to merging.
const NO_MERGE: int = -1
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
## Font size each label was last given: a text of the same size touches no theme override.
var _font_sizes: PackedInt32Array = PackedInt32Array()
var _busy_count: int = 0
var _counter: int = 0
var _anchor: Vector2 = Vector2.ZERO
var _box_scale: float = 1.0
var _bounds: Rect2 = Rect2()
var _enabled: bool = true
var _paused: bool = false
## The label of the gold text still merging, its time left, the sum so far, whether a boss is in
## it, and where it would go before the bounds: a longer sum is fitted again from there.
var _merge_slot: int = NO_MERGE
var _merge_left: float = 0.0
var _merge_total: BigNumber
var _merge_boss: bool = false
var _merge_origin: Vector2 = Vector2.ZERO
var _merge_travel: Vector2 = Vector2.ZERO


## Builds the pool: [constant POOL_SIZE] hidden labels, the only ones this layer will ever have.
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy.resize(POOL_SIZE)
	_age.resize(POOL_SIZE)
	_life.resize(POOL_SIZE)
	_origin.resize(POOL_SIZE)
	_travel.resize(POOL_SIZE)
	_order.resize(POOL_SIZE)
	_font_sizes.resize(POOL_SIZE)
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
	if _merge_slot != NO_MERGE:
		_merge_left -= step
		if _merge_left <= 0.0:
			_merge_slot = NO_MERGE
	for i in POOL_SIZE:
		if _busy[i] == 0:
			continue
		_age[i] += step
		if _age[i] >= _life[i]:
			_release(i)
			continue
		_place(i)
	if _busy_count == 0:
		set_process(false)


## Where the texts start: the center of the monster, in this layer's coordinates.
func set_target_point(point: Vector2) -> void:
	_anchor = point


## Keeps every next text whole inside [param bounds] (in this layer's coordinates), from its start
## to the end of its travel, so that it never covers the buttons around the monster. An empty
## rectangle means no limit, the default.
func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds


## [param point] moved as little as possible so that a text of half size [param half] centered on
## it stays whole inside [param bounds]; a text too big for an axis is centered on that axis.
static func keep_inside(point: Vector2, half: Vector2, bounds: Rect2) -> Vector2:
	var low: Vector2 = bounds.position + half
	var high: Vector2 = bounds.end - half
	var center: Vector2 = bounds.get_center()
	return Vector2(
			clampf(point.x, low.x, high.x) if low.x <= high.x else center.x,
			clampf(point.y, low.y, high.y) if low.y <= high.y else center.y)


## Size of the monster relative to its drawing units ([method EnemyView.box_scale]): the offsets and
## the travels of the next texts follow it. The font sizes do not.
func set_box_scale(factor: float) -> void:
	_box_scale = factor


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
	var origin: Vector2 = _anchor + (HIT_START_OFFSET + jitter) * _box_scale
	_start(text, font_size, color, origin, HIT_TRAVEL * _box_scale, HIT_SECONDS)


## Shows the gold of a kill, or adds it to the gold text still merging (see
## [constant GOLD_MERGE_SECONDS]). Made to be connected to [signal FloorManager.kill_rewarded]:
## [param gold] is the reward really granted, [param was_boss] makes the text bigger.
func show_gold(_stage: int, gold: BigNumber, was_boss: bool) -> void:
	if not _is_active():
		return
	if _merge_slot != NO_MERGE:
		_add_to_merge(gold, was_boss)
		return
	_merge_total = gold
	_merge_boss = was_boss
	_merge_origin = _anchor + GOLD_START_OFFSET * _box_scale
	_merge_travel = GOLD_TRAVEL * _box_scale
	_merge_slot = _start(_gold_text(), _gold_font_size(), COLOR_GOLD, _merge_origin, _merge_travel, GOLD_SECONDS)
	_merge_left = GOLD_MERGE_SECONDS


func _is_active() -> bool:
	return _enabled and not _paused


func _gold_text() -> String:
	return tr("+%s or") % _merge_total.format()


func _gold_font_size() -> int:
	return FONT_SIZE_GOLD_BOSS if _merge_boss else FONT_SIZE_GOLD


func _add_to_merge(gold: BigNumber, was_boss: bool) -> void:
	_merge_total = _merge_total.add(gold)
	_merge_boss = _merge_boss or was_boss
	var text: String = _gold_text()
	var font_size: int = _gold_font_size()
	var slot: int = _merge_slot
	_fit(slot, text, font_size, _merge_origin, _merge_travel)
	_labels[slot].text = text
	_set_font_size(slot, font_size)
	_place(slot)


# An override rebuilds the label's theme cache: this runs on every kill of a fast fight.
func _set_font_size(slot: int, font_size: int) -> void:
	if _font_sizes[slot] != font_size:
		_font_sizes[slot] = font_size
		_labels[slot].add_theme_font_size_override("font_size", font_size)


# Moves label [param i] along its path, by its age.
func _place(i: int) -> void:
	var t: float = _age[i] / _life[i]
	var eased: float = 1.0 - (1.0 - t) * (1.0 - t)
	var label: Label = _labels[i]
	label.position = _origin[i] - LABEL_SIZE / 2.0 + _travel[i] * eased
	label.modulate.a = 1.0 if t < FADE_START else (1.0 - t) / (1.0 - FADE_START)


# Sets the path of [param slot] so that the text stays whole inside the bounds all along it.
func _fit(slot: int, text: String, font_size: int, origin: Vector2, travel: Vector2) -> void:
	if _bounds.has_area():
		var half: Vector2 = _half_size(text, font_size)
		var end: Vector2 = keep_inside(origin + travel, half, _bounds)
		origin = keep_inside(origin, half, _bounds)
		travel = end - origin
	_origin[slot] = origin
	_travel[slot] = travel


# Half the size a text takes on screen, its outline included.
func _half_size(text: String, font_size: int) -> Vector2:
	var font: Font = _labels[0].get_theme_font("font")
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return text_size / 2.0 + Vector2.ONE * float(OUTLINE_SIZE)


# Puts a text in the first free label, else takes over the oldest one, and returns that label.
func _start(text: String, font_size: int, color: Color, origin: Vector2, travel: Vector2, life: float) -> int:
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
	if slot == _merge_slot:
		_merge_slot = NO_MERGE
	if _busy[slot] == 0:
		_busy[slot] = 1
		_busy_count += 1
	_counter += 1
	_order[slot] = _counter
	_age[slot] = 0.0
	_life[slot] = life
	_fit(slot, text, font_size, origin, travel)
	var label: Label = _labels[slot]
	label.text = text
	_set_font_size(slot, font_size)
	label.add_theme_color_override("font_color", color)
	label.modulate = Color.WHITE
	label.position = _origin[slot] - LABEL_SIZE / 2.0
	label.visible = true
	set_process(true)
	return slot


func _release(i: int) -> void:
	if i == _merge_slot:
		_merge_slot = NO_MERGE
	if _busy[i] == 0:
		return
	_busy[i] = 0
	_busy_count -= 1
	_labels[i].visible = false
