class_name SkillOrb
extends Button
## One skill of the skill row (story 019b): a round of 56 u that draws its state itself, with no text
## on it. [enum Look] READY has a full ring and a halo; ACTIVE and COOLDOWN an arc and a badge of
## seconds; LOCKED a padlock; PASSIVE a grey icon with no ring. The name is never drawn: it is in the
## hint bubble and in [member Control.accessibility_name], which [SkillBar] keeps up to date.
##
## The touch zone is a disc around the round, up to [constant TOUCH_RADIUS_MAX], never the corners of
## its cell: a finger that leaves the disc before lifting cancels the press, and a press only acts on
## the release (the default of [BaseButton], kept on purpose).
##
## Redrawn only when what it shows changes: the arc moves by steps of 1/[constant ARC_STEPS] of a
## turn, so a cooldown of 90 s redraws less than twice a second.
##
## Usage:
## [codeblock]
## var orb: SkillOrb = SkillOrb.new()
## orb.icon_kind = UiIcon.Kind.BOLT
## orb.show_state(SkillOrb.Look.COOLDOWN, 42, 0.53)   # true: it will redraw
## [/codeblock]

## What the round shows.
enum Look { READY, ACTIVE, COOLDOWN, LOCKED, PASSIVE }

## Size of the drawn round (spec, display setting).
const DISK_SIZE: float = 56.0
## The touch zone: a disc of this radius at most, 64 u, over the 50 u of a touch target; smaller in
## a narrow cell, down to half the cell (display settings).
const TOUCH_RADIUS_MAX: float = 32.0
## Ring, halo and focus ring widths (display settings).
const RING_WIDTH: float = 4.0
const HALO_WIDTH: float = 6.0
const FOCUS_WIDTH: float = 2.0
const FOCUS_GAP: float = 2.0
## Share of the round the icon takes (display setting).
const ICON_RATIO: float = 0.42
## Steps of the arc in one turn (display setting).
const ARC_STEPS: int = 120
## Badge of seconds: 14 u digits in a pill, at the lower right of the round (spec, display settings).
const BADGE_FONT_SIZE: int = 14
const BADGE_HEIGHT: float = 20.0
const BADGE_PADDING: float = 5.0
const BADGE_BORDER: int = 1
const ARC_POINTS: int = 48
const HALO_ALPHA: float = 0.28

## The icon of the skill, drawn by [method UiIcon.draw_kind].
var icon_kind: UiIcon.Kind = UiIcon.Kind.STAR:
	set(value):
		icon_kind = value
		queue_redraw()

var _look: Look = Look.READY
var _seconds: int = 0
var _step: int = ARC_STEPS
var _badge_style: StyleBoxFlat = StyleBoxFlat.new()


func _init() -> void:
	text = ""
	custom_minimum_size = Vector2(DISK_SIZE, DISK_SIZE)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		add_theme_stylebox_override(state, empty)
	_badge_style.set_corner_radius_all(int(BADGE_HEIGHT / 2.0))
	_badge_style.set_border_width_all(BADGE_BORDER)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Shows [param look], with [param seconds] in the badge (ACTIVE and COOLDOWN) and [param fraction]
## of the ring drawn (0 to 1). True when that changed what is drawn, so a redraw is coming.
func show_state(look: Look, seconds: int, fraction: float) -> bool:
	var step: int = roundi(clampf(fraction, 0.0, 1.0) * ARC_STEPS)
	if look == _look and seconds == _seconds and step == _step:
		return false
	_look = look
	_seconds = seconds
	_step = step
	queue_redraw()
	return true


## What the round shows now.
func look() -> Look:
	return _look


## The arc drawn now, in steps of [constant ARC_STEPS].
func arc_step() -> int:
	return _step


## The radius of the touch zone in a cell of this size.
func touch_radius() -> float:
	return minf(TOUCH_RADIUS_MAX, minf(size.x, size.y) / 2.0)


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size / 2.0) <= touch_radius()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(DISK_SIZE, minf(size.x, size.y)) / 2.0
	var lit: bool = get_draw_mode() in [DRAW_HOVER, DRAW_PRESSED, DRAW_HOVER_PRESSED]
	if _look == Look.READY:
		draw_circle(center, radius + HALO_WIDTH / 2.0, Color(UiPalette.YELLOW, HALO_ALPHA))
	draw_circle(center, radius - RING_WIDTH / 2.0, UiPalette.ROW_HOVER if lit else UiPalette.ROW)
	var ring_radius: float = radius - RING_WIDTH / 2.0
	match _look:
		Look.READY:
			draw_arc(center, ring_radius, 0.0, TAU, ARC_POINTS, UiPalette.YELLOW, RING_WIDTH, true)
		Look.ACTIVE, Look.COOLDOWN:
			draw_arc(center, ring_radius, 0.0, TAU, ARC_POINTS, UiPalette.BUTTON, RING_WIDTH, true)
			var arc: Color = UiPalette.YELLOW if _look == Look.ACTIVE else UiPalette.TEXT_MUTED
			if _step > 0:
				var sweep: float = TAU * float(_step) / float(ARC_STEPS)
				draw_arc(center, ring_radius, -PI / 2.0, -PI / 2.0 + sweep, ARC_POINTS, arc, RING_WIDTH, true)
		Look.LOCKED:
			draw_arc(center, ring_radius, 0.0, TAU, ARC_POINTS, UiPalette.BUTTON, RING_WIDTH, true)
	var kind: UiIcon.Kind = UiIcon.Kind.LOCK if _look == Look.LOCKED else icon_kind
	UiIcon.draw_kind(self, kind, center, radius * ICON_RATIO, _icon_color())
	if _look == Look.ACTIVE or _look == Look.COOLDOWN:
		_draw_badge(center, radius)
	if has_focus(true):
		var focus_radius: float = radius + FOCUS_GAP + FOCUS_WIDTH / 2.0
		draw_arc(center, focus_radius + FOCUS_WIDTH, 0.0, TAU, ARC_POINTS, UiPalette.BACKGROUND, FOCUS_WIDTH, true)
		draw_arc(center, focus_radius, 0.0, TAU, ARC_POINTS, Color.WHITE, FOCUS_WIDTH, true)


func _icon_color() -> Color:
	match _look:
		Look.READY, Look.ACTIVE:
			return Color.WHITE
		Look.LOCKED:
			return UiPalette.TEXT_MUTED
	return UiPalette.TEXT_DISABLED


# The seconds left, in a pill over the lower right of the ring: yellow while the skill runs, dark
# while it recharges, so the two read apart by more than the arc.
func _draw_badge(center: Vector2, radius: float) -> void:
	var font: Font = get_theme_font(&"font")
	var digits: String = str(_seconds)
	var text_width: float = font.get_string_size(digits, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_FONT_SIZE).x
	var badge: Vector2 = Vector2(maxf(text_width + BADGE_PADDING * 2.0, BADGE_HEIGHT), BADGE_HEIGHT)
	var corner: Vector2 = center + Vector2(radius, radius) * 0.62
	var rect: Rect2 = Rect2(corner - badge / 2.0, badge)
	var running: bool = _look == Look.ACTIVE
	_badge_style.bg_color = UiPalette.YELLOW if running else UiPalette.BACKGROUND
	_badge_style.border_color = UiPalette.YELLOW_EDGE if running else UiPalette.TEXT_MUTED
	draw_style_box(_badge_style, rect)
	var baseline: float = rect.position.y + (BADGE_HEIGHT + font.get_ascent(BADGE_FONT_SIZE) - font.get_descent(BADGE_FONT_SIZE)) / 2.0
	draw_string(font, Vector2(rect.position.x, baseline), digits, HORIZONTAL_ALIGNMENT_CENTER, badge.x,
			BADGE_FONT_SIZE, UiPalette.ON_YELLOW if running else Color.WHITE)
