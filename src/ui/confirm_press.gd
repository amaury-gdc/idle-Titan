class_name ConfirmPress
extends RefCounted
## A press that only counts when it is repeated within [constant WINDOW_SECONDS] (story 019b): the
## first one arms it, the second one confirms. Used by "Abandonner", which a stray touch near the
## monster must not trigger. Pure: the caller gives the time, so a test needs no clock.
##
## Usage:
## [codeblock]
## var confirm: ConfirmPress = ConfirmPress.new()
## if confirm.press(now):
##     floors.abandon_boss()
## button.text = tr("Confirmer ?") if confirm.is_armed(now) else tr("Abandonner")
## [/codeblock]

## Time the first press waits for the second one (display setting, not a gameplay value).
const WINDOW_SECONDS: float = 3.0

var _armed_until: float = -INF


## Presses at [param now] seconds. True when it confirms an armed press; otherwise it arms one.
func press(now: float) -> bool:
	if is_armed(now):
		cancel()
		return true
	_armed_until = now + WINDOW_SECONDS
	return false


## True when a first press at most [constant WINDOW_SECONDS] old waits for its second.
func is_armed(now: float) -> bool:
	return now <= _armed_until


## Forgets a first press.
func cancel() -> void:
	_armed_until = -INF
