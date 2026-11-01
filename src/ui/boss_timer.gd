class_name BossTimer
extends Control
## Boss banner (story 004): a "BOSS" marking, the seconds left in large text and a
## bar that empties with the countdown. In the last quarter the bar turns red AND the marking
## reads "Vite !", so that the end of the time is not told by colour alone (story 010).
## Hidden outside a boss fight. Pure presentation: it is told the time, it never
## reads or changes the fight.
##
## Usage:
## [codeblock]
## # every frame
## if floors.is_boss_fight():
##     boss_timer.show_fight(floors.boss_time_left(), floors.boss_timer_seconds())
## else:
##     boss_timer.hide_fight()
## [/codeblock]

## Below this share of the time left the bar turns red (display setting, not balance).
const LOW_TIME_RATIO: float = 0.25
const COLOR_FILL: Color = Color(0.85, 0.45, 0.1)
const COLOR_FILL_LOW: Color = Color(0.9, 0.12, 0.12)

@onready var _fill: ColorRect = %Fill
@onready var _countdown: Label = %CountdownLabel
@onready var _marking: Label = %BossLabel


## Shows the banner for [param time_left] seconds left out of [param total].
func show_fight(time_left: float, total: float) -> void:
	visible = true
	var ratio: float = clampf(time_left / total, 0.0, 1.0) if total > 0.0 else 0.0
	# keep_offset: the bar must follow the anchor, not stay where it was.
	_fill.set_anchor(SIDE_RIGHT, ratio, true)
	var low: bool = ratio <= LOW_TIME_RATIO
	_fill.color = COLOR_FILL_LOW if low else COLOR_FILL
	_marking.text = tr("Vite !") if low else tr("BOSS")
	_countdown.text = tr("%d s") % int(ceil(time_left))


## Hides the banner.
func hide_fight() -> void:
	visible = false
