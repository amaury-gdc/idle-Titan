class_name ClickDpsMeter
extends RefCounted
## Rolling measure of the player's click damage per second, for display: total
## click damage of the last [constant WINDOW_SECONDS] seconds divided by the time
## since the oldest of those clicks, at least [constant MIN_SPAN_SECONDS]. A lone
## click reads as its full damage, the rate rises while the player clicks and
## falls back to 0 once they stop.
## No Node and no timer: time is fed through [method tick]. Single-thread only.
##
## Usage:
## [codeblock]
## var meter := ClickDpsMeter.new()
## meter.record(floors.click())
## # every frame:
## meter.tick(delta)
## print(meter.rate().format())
## [/codeblock]

## Length of the measure, in seconds (display setting, not a gameplay value).
const WINDOW_SECONDS: int = 3
## Shortest duration a rate is computed over, so clicks a few frames apart do not
## read as a huge rate (display setting, not a gameplay value).
const MIN_SPAN_SECONDS: float = 1.0

var _now: float = 0.0
## Time and damage of each click still inside the window, oldest first.
var _times: Array[float] = []
var _damages: Array[BigNumber] = []


## Counts one click dealing [param damage], now.
func record(damage: BigNumber) -> void:
	_times.append(_now)
	_damages.append(damage)


## Advances time by [param delta] seconds and forgets the clicks that left the window.
func tick(delta: float) -> void:
	_now += delta
	while not _times.is_empty() and _now - _times[0] >= float(WINDOW_SECONDS):
		_times.pop_front()
		_damages.pop_front()


## Click damage per second over the window (floored); 0 with no click in it.
func rate() -> BigNumber:
	var total: BigNumber = BigNumber.new()
	if _times.is_empty():
		return total
	for damage: BigNumber in _damages:
		total = total.add(damage)
	var span_ms: int = roundi(maxf(_now - _times[0], MIN_SPAN_SECONDS) * 1000.0)
	return total.multiply(BigNumber.from_int(1000)).divide(BigNumber.from_int(span_ms))
