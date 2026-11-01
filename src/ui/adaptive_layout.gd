class_name AdaptiveLayout
extends RefCounted
## The pure decisions of the adaptive main screen (story 010, design/ux/main-screen-adaptive.md):
## portrait or landscape, the logical size of the window, the height of the portrait monster row
## and the rectangle of a modal panel. Nothing here touches a node, so all of it is unit-testable;
## [code]main_screen.gd[/code] reads the window and applies the answers.
##
## The shape has a dead zone between [constant TO_PORTRAIT_BELOW] and [constant TO_LANDSCAPE_ABOVE]
## where the previous shape stays, so that a browser bar appearing cannot flip the layout.
##
## Sizes in CSS pixels are what the player sees: [code]window size / devicePixelRatio[/code].
## One logical unit ("u") never gets smaller than [constant MIN_CSS_PER_UNIT] CSS pixels, which is
## what makes a 50 u target 44 CSS px and a 16 u text 14 CSS px everywhere.
##
## Usage:
## [codeblock]
## var shape: AdaptiveLayout.Shape = AdaptiveLayout.decide_shape(css_size, previous_shape)
## get_window().content_scale_size = AdaptiveLayout.content_size(css_size, shape)
## [/codeblock]

## The form of the screen. [constant UNDECIDED] is the "previous shape" of a cold start.
enum Shape { UNDECIDED, PORTRAIT, LANDSCAPE }

## Width/height under which the screen turns portrait (display setting, not a gameplay value).
const TO_PORTRAIT_BELOW: float = 1.10
## Width/height over which the screen turns landscape (display setting, not a gameplay value).
const TO_LANDSCAPE_ABOVE: float = 1.20
## Width/height under which a cold start is portrait (display setting, not a gameplay value).
const COLD_START_THRESHOLD: float = 1.15
## Smallest size each shape is designed for, in logical units.
const BASE_PORTRAIT: Vector2i = Vector2i(390, 640)
const BASE_LANDSCAPE: Vector2i = Vector2i(1280, 720)
## Floor of the scale, in CSS pixels per logical unit: 44 CSS pixels for a 50 u target
## (display setting, not a gameplay value).
const MIN_CSS_PER_UNIT: float = 0.88
## Ceiling of the scale in portrait: past it a tablet gets more room, not a bigger phone screen
## (display setting, not a gameplay value).
const MAX_PORTRAIT_CSS_PER_UNIT: float = 1.28
## Height of the header, in both shapes.
const HEADER_HEIGHT: float = 56.0
## Rows of the portrait game zone. The monster row gives way before the list does.
const ACTION_ROW_HEIGHT: float = 50.0
const HP_ROW_HEIGHT: float = 24.0
const SKILL_ROW_HEIGHT: float = 52.0
const FOOT_ROW_HEIGHT: float = 50.0
const MONSTER_ROW_MAX: float = 170.0
const MONSTER_ROW_MIN: float = 120.0
## Space between two rows of the portrait game zone, and above the first and under the last.
const ROW_GAP: float = 4.0
## Number of gaps of the portrait game zone (5 rows, so 6 with both ends).
const ROW_GAPS: int = 6
## Height the management zone keeps before the monster row shrinks: 2,5 list rows of 56 u, the
## selector and its gap (56 u), the list margins (8 u) and the tabs (56 u).
const MANAGEMENT_MIN_HEIGHT: float = 260.0
## A modal panel is at most this wide, and leaves [constant MODAL_MARGIN] on each side.
const MODAL_MAX_WIDTH: float = 720.0
const MODAL_MARGIN: float = 16.0
## Floating point margin of a rounding up, in logical units.
const ROUNDING_MARGIN: float = 0.001


## Decides the shape for a window of [param css_size] CSS pixels. [param previous] is the shape in
## use; [constant Shape.UNDECIDED] is a cold start, which has no dead zone. An empty window (a
## minimized one reports 0) keeps [param previous].
static func decide_shape(css_size: Vector2, previous: Shape = Shape.UNDECIDED) -> Shape:
	if css_size.x <= 0.0 or css_size.y <= 0.0:
		return Shape.LANDSCAPE if previous == Shape.UNDECIDED else previous
	var ratio: float = css_size.x / css_size.y
	if previous == Shape.UNDECIDED:
		return Shape.PORTRAIT if ratio < COLD_START_THRESHOLD else Shape.LANDSCAPE
	if ratio < TO_PORTRAIT_BELOW:
		return Shape.PORTRAIT
	if ratio > TO_LANDSCAPE_ABOVE:
		return Shape.LANDSCAPE
	return previous


## The design size of [param shape].
static func base_size(shape: Shape) -> Vector2i:
	return BASE_PORTRAIT if shape == Shape.PORTRAIT else BASE_LANDSCAPE


## CSS pixels per logical unit for a window of [param css_size]: the base size fits the window,
## but the unit never goes under [constant MIN_CSS_PER_UNIT], nor over
## [constant MAX_PORTRAIT_CSS_PER_UNIT] in portrait.
static func css_per_unit(css_size: Vector2, shape: Shape) -> float:
	var base: Vector2 = Vector2(base_size(shape))
	var fit: float = maxf(minf(css_size.x / base.x, css_size.y / base.y), MIN_CSS_PER_UNIT)
	return minf(fit, MAX_PORTRAIT_CSS_PER_UNIT) if shape == Shape.PORTRAIT else fit


## The value of [member Window.content_scale_size]: the base size, or, when the floor or the
## portrait ceiling holds, the window measured at that scale. Rounded down at the floor and up at
## the ceiling, so that the unit never leaves the two bounds.
static func content_size(css_size: Vector2, shape: Shape) -> Vector2i:
	var base: Vector2i = base_size(shape)
	var fit: float = minf(css_size.x / float(base.x), css_size.y / float(base.y))
	if shape == Shape.PORTRAIT and fit > MAX_PORTRAIT_CSS_PER_UNIT:
		# The small margin: 768 / 1.28 is 600 and a hair in floating point.
		var capped: Vector2 = css_size / MAX_PORTRAIT_CSS_PER_UNIT - Vector2.ONE * ROUNDING_MARGIN
		return Vector2i(ceili(capped.x), ceili(capped.y))
	# Approximate: a window exactly at the floor can come out a hair under it in floating point.
	if fit >= MIN_CSS_PER_UNIT or is_equal_approx(fit, MIN_CSS_PER_UNIT):
		return base
	return Vector2i(
			maxi(floori(css_size.x / MIN_CSS_PER_UNIT), 1),
			maxi(floori(css_size.y / MIN_CSS_PER_UNIT), 1))


## The size of the screen in logical units once [method content_size] is applied.
static func logical_size(css_size: Vector2, shape: Shape) -> Vector2:
	return css_size / css_per_unit(css_size, shape)


## Height of the portrait monster row for a screen [param logical_height] units tall.
static func portrait_monster_row(logical_height: float) -> float:
	var free: float = logical_height - HEADER_HEIGHT - MANAGEMENT_MIN_HEIGHT - portrait_game_height(0.0)
	# Rounded down: the window has whole units, and the fraction must not come out of the list.
	return clampf(floorf(free), MONSTER_ROW_MIN, MONSTER_ROW_MAX)


## Height of the portrait game zone with a monster row of [param monster_row].
static func portrait_game_height(monster_row: float) -> float:
	return ACTION_ROW_HEIGHT + monster_row + HP_ROW_HEIGHT + SKILL_ROW_HEIGHT + FOOT_ROW_HEIGHT \
			+ ROW_GAP * ROW_GAPS


## Where a modal panel goes in a view of [param view] units: centered, as wide as the view allows
## up to [constant MODAL_MAX_WIDTH], and at most [param wanted_height] tall. A smaller height than
## wanted is why the content of a modal panel scrolls.
static func modal_rect(view: Vector2, wanted_height: float) -> Rect2:
	var panel: Vector2 = Vector2(
			minf(MODAL_MAX_WIDTH, view.x - MODAL_MARGIN * 2.0),
			minf(wanted_height, view.y - MODAL_MARGIN * 2.0))
	return Rect2((view - panel) / 2.0, panel)
