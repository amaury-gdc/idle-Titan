class_name HeaderButton
extends Button
## A button of a tab header (story 019b): drawn 44 u tall in the 46 u header, touched over 50 u. The
## touch zone grows upwards only, into the bottom of the handle band above it, which is empty there;
## under the header the list starts, and must keep its own touches.
##
## Usage (in a scene: a Button with this script, inside a [PaneHeader]):
## [codeblock]
## button.pressed.connect(_on_pressed)    # a touch up to TOUCH_GROW_UP above the header counts
## [/codeblock]

## Units of touch zone above the button: 46 + 4 = 50 u, a touch target (display setting).
const TOUCH_GROW_UP: float = 4.0
## Units the drawn frame leaves above and below, so that it is 44 u in the 46 u header.
const DRAWN_INSET: float = 1.0


func _has_point(point: Vector2) -> bool:
	return Rect2(0.0, -TOUCH_GROW_UP, size.x, size.y + TOUCH_GROW_UP).has_point(point)


## The touch zone in the button's coordinates, for tests and for the handle that must not cover it.
func touch_rect() -> Rect2:
	return Rect2(0.0, -TOUCH_GROW_UP, size.x, size.y + TOUCH_GROW_UP)
