class_name LongPress
extends RefCounted
## The state machine of one long press, with no node and no clock (story 010, Interaction Map of
## design/ux/main-screen-adaptive.md): time comes through [method tick], so every rule can be
## tested. [HintBubble] feeds it the real input. A long press never activates anything: it only
## reports that the hold is over, and [method release] says the release that follows it must not
## count as a press.
##
## Usage:
## [codeblock]
## press.begin(position)
## press.move(new_position, css_per_unit)   # past 10 CSS px: cancelled
## if press.tick(delta):
##     show_the_bubble()
## var swallow: bool = press.release()
## [/codeblock]

## Where a press is in its life.
enum State { IDLE, HELD, FIRED }

## Time the press must be held (spec, display setting).
const HOLD_SECONDS: float = 0.5
## Movement that cancels the press, in CSS pixels (spec, display setting).
const MAX_MOVE_CSS: float = 10.0
## Space kept between a bubble and the target or the screen edge, in logical units.
const BUBBLE_MARGIN: float = 8.0

var _state: State = State.IDLE
var _held_for: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _fingers: Dictionary = {}


## Where a bubble of [param bubble] units goes for a target at [param target] in a view of
## [param view] units: centered above the target, below it when there is no room, and always whole
## on screen.
static func bubble_position(bubble: Vector2, target: Rect2, view: Vector2) -> Vector2:
	var x: float = target.get_center().x - bubble.x / 2.0
	var y: float = target.position.y - bubble.y - BUBBLE_MARGIN
	if y < BUBBLE_MARGIN:
		y = target.end.y + BUBBLE_MARGIN
	return Vector2(
			clampf(x, BUBBLE_MARGIN, maxf(view.x - bubble.x - BUBBLE_MARGIN, BUBBLE_MARGIN)),
			clampf(y, BUBBLE_MARGIN, maxf(view.y - bubble.y - BUBBLE_MARGIN, BUBBLE_MARGIN)))


## The current [enum State].
func state() -> State:
	return _state


## A press started at [param position].
func begin(position: Vector2) -> void:
	_state = State.HELD
	_held_for = 0.0
	_origin = position


## Advances the hold by [param delta] seconds. True once, on the frame the hold completes.
func tick(delta: float) -> bool:
	if _state != State.HELD:
		return false
	_held_for += delta
	if _held_for < HOLD_SECONDS:
		return false
	_state = State.FIRED
	return true


## The pointer moved to [param position]; [param css_per_unit] converts units to CSS pixels. Only a
## press still held can be cancelled: once the hold is over, a slip of the finger changes nothing.
func move(position: Vector2, css_per_unit: float) -> void:
	if _state == State.HELD and position.distance_to(_origin) * css_per_unit > MAX_MOVE_CSS:
		cancel()


## A finger [param index] went down or up. A second finger cancels the press.
func touch(index: int, pressed: bool) -> void:
	if pressed:
		_fingers[index] = true
	else:
		_fingers.erase(index)
	if _fingers.size() >= 2 and _state == State.HELD:
		cancel()


## Gives up the press, whatever caused it (tab, shape, hidden page).
func cancel() -> void:
	_state = State.IDLE
	_held_for = 0.0


## Forgets every finger and the press, for when the page hides and the releases will never come.
func reset() -> void:
	_fingers.clear()
	cancel()


## The press ended. True when the hold had completed: this release must not act as a press.
func release() -> bool:
	var fired: bool = _state == State.FIRED
	cancel()
	return fired
