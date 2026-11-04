class_name PanelHandle
extends Button
## The handle on top of the portrait management panel (story 019b): a band with a short bar, which
## collapses and unfolds the panel on a touch, and on Enter or Space when it has the focus. The band
## is 22 u over the header of the open tab, whose free part ([PaneHeader]) is a second touch zone; with
## the panel collapsed the header is gone, so the band alone grows to a touch target of 50 u. Its
## accessible name says what a press does. It only reports the press: [ManagementTabs] holds the state.
##
## Usage:
## [codeblock]
## handle.pressed.connect(tabs.toggle_collapsed)
## handle.show_collapsed(true)   # 50 u, "Déployer le panneau"
## [/codeblock]

## The drawn bar (display settings).
const BAR_SIZE: Vector2 = Vector2(40.0, 5.0)

var _collapsed: bool = false
var _bar_style: StyleBoxFlat = StyleBoxFlat.new()


func _init() -> void:
	_bar_style.set_corner_radius_all(int(BAR_SIZE.y / 2.0) + 1)
	text = ""
	focus_mode = Control.FOCUS_ALL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		add_theme_stylebox_override(state, empty)
	show_collapsed(false)


## Shows the band for a panel [param collapsed] or not: its height and its accessible name.
func show_collapsed(collapsed: bool) -> void:
	_collapsed = collapsed
	custom_minimum_size.y = AdaptiveLayout.HANDLE_COLLAPSED_HEIGHT if collapsed else AdaptiveLayout.HANDLE_HEIGHT
	accessibility_name = tr("Déployer le panneau") if collapsed else tr("Replier le panneau")
	tooltip_text = accessibility_name
	queue_redraw()


## True when the band is drawn for a collapsed panel.
func is_collapsed() -> bool:
	return _collapsed


func _draw() -> void:
	var lit: bool = get_draw_mode() in [DRAW_HOVER, DRAW_PRESSED, DRAW_HOVER_PRESSED]
	var bar: Rect2 = Rect2((size - BAR_SIZE) / 2.0, BAR_SIZE)
	_bar_style.bg_color = UiPalette.TEXT_SOFT if lit else UiPalette.TEXT_MUTED
	draw_style_box(_bar_style, bar)
