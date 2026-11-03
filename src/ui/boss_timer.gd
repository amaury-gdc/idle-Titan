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
## Font sizes of the banner and of the thin portrait band (story 019b).
const FONT_SIZE: int = 24
const COMPACT_FONT_SIZE: int = 16
## Colours of the bar (story 019b): the texts are white with a black outline over both.
const COLOR_FILL: Color = UiPalette.YELLOW
const COLOR_FILL_LOW: Color = UiPalette.RED

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


## Fits the texts to the thin band of the portrait scene ([param compact]) or to the landscape
## banner. The seconds stay in figures in both.
func set_compact(compact: bool) -> void:
	for label: Label in [_marking, _countdown]:
		label.add_theme_font_size_override("font_size", COMPACT_FONT_SIZE if compact else FONT_SIZE)
