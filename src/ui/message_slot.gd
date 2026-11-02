class_name MessageSlot
extends RefCounted
## The one place of the screen where a short message shows (the loot message), shared by the loot
## and the sentence of the first awakening (story 017). A pinned message keeps the place for its
## whole duration: a message offered meanwhile waits, the latest one only, and shows when the pinned
## one is released. Pure: it shows nothing itself, it calls what it is given.
##
## Usage:
## [codeblock]
## slot.pin()                                  # then show the sentence and start its timer
## slot.offer(show_loot.bind(item))            # waits while pinned, shows at once otherwise
## # when the timer of the pinned message ends:
## slot.release()                              # shows the waiting loot, if any
## [/codeblock]

var _pinned: bool = false
var _waiting: Callable = Callable()


## True while a pinned message holds the place.
func is_pinned() -> bool:
	return _pinned


## The next message shown keeps the place until [method release].
func pin() -> void:
	_pinned = true


## Calls [param show] now, or keeps it for [method release] while a message is pinned (a newer
## offer replaces an older one: only the latest loot is worth showing).
func offer(show: Callable) -> void:
	if _pinned:
		_waiting = show
		return
	show.call()


## Ends the pinned message and calls the message that waited, if any. Without a pinned message it
## does nothing.
func release() -> void:
	if not _pinned:
		return
	_pinned = false
	var waiting: Callable = _waiting
	_waiting = Callable()
	if waiting.is_valid():
		waiting.call()
