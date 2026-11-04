class_name CompanionPanel
extends PanelContainer
## Readable list of the companions (story 003): name, level, damage per second, the next tier with
## a thin bar, and a button showing what a press buys under the buy mode (stories 010 and 013, D3),
## showing the cost alone and disabled when gold is short. Companions not
## bought yet are listed at level 0. The bar takes no input and tells nothing the text does not.
## One list only: it adapts to its own width, not to the shape of the screen.
## Pure presentation: reads a [CompanionManager], never changes it; a press is reported through
## [signal buy_requested] with the amount the row displays, and the composition root forwards it.
## The mode's choice is kept by the composition root ([DisplaySettings]), never in the save.
##
## Header (story 019b, a [PaneHeader]): "DPS des souris" and its value, a button that reports
## [signal squad_dps_pressed] (the composition root opens the same detail as the screen header),
## and one "Achat ×N" button, whose press walks [constant BuyQuote.CYCLE].
##
## The buy buttons pass the mouse on: the [ScrollContainer] sees a drag and cancels the press, so a
## drag in the list never buys.
##
## Usage:
## [codeblock]
## panel.buy_requested.connect(func(id: String, count: int) -> void: companions.buy_levels(id, count))
## panel.setup(companions, func() -> BigNumber: return game.gold)   # builds one row per companion
## panel.set_mode(BuyQuote.Mode.TEN)
## panel.set_squad_dps("19,4 Qa")
## panel.refresh()           # after a change of gold or level
## [/codeblock]

## The player pressed the buy button of companion [param id]: buy [param count] levels.
signal buy_requested(id: String, count: int)
## The player chose [param mode] (a [enum BuyQuote.Mode]) with the "Achat ×N" button.
signal mode_changed(mode: int)
## The player touched "DPS des souris" in the header: show the detail of the damage.
signal squad_dps_pressed
## The player pressed the "Éveiller" button of companion [param id], shown only at an awakening
## threshold (story 017): awaken it.
signal awaken_requested(id: String)

## Width of the list from which the rows use the bigger sizes (display setting).
const WIDE_WIDTH: float = 470.0
const FONT_SIZE_WIDE: int = 20
const FONT_SIZE_COMPACT: int = 16
const BUTTON_WIDTH_WIDE: float = 250.0
const BUTTON_WIDTH_COMPACT: float = 170.0
## Height of a row: a button of 50 u over the tier line, whose bar stands beside the text so that
## 2 rows stay visible at 320x568. Rows share the spare height of the list up to the maximum, past
## which they would stop reading as a list (display settings).
const ROW_MIN_HEIGHT: float = 73.0
const ROW_MAX_HEIGHT: float = 96.0
## Height of a line of 16 u, and the measures of the tier line (display settings).
const TIER_LINE_HEIGHT: float = 23.0
const TIER_BAR_HEIGHT: float = 8.0
const TIER_LINE_GAP: int = 8
## Widest content of the list: on a very wide pane the name and its button stay within one look
## (display setting).
const CONTENT_MAX_WIDTH: float = 560.0
const COLOR_DAMAGE: Color = Color(1, 0.62, 0.45)
## Side margins of the panel style of the theme, CompanionListPanel.
const PANEL_SIDE_MARGINS: float = 8.0
const NO_BREAK_SPACE: String = " "
## Longest cost and longest count a compact button must hold on one line (spec, Localization), and
## a little room so that rounding never wraps it (display settings). The cost is the widest text
## [method BigNumber.format] gives up to stage 300 and the awakening costs of level 1000 (about
## 1e46): a scientific notation with two exponent digits, measured wider than every suffix from K to
## Dc (story 017, companion_panel_awakening_test.gd). The count is the most levels one press buys
## before the last awakening: x200, a first Max from level 0 to the first threshold. Past the last
## awakening a Max can count 4 digits ("x1000"): that text alone breaks before its cost, on the two
## lines the 50 u button holds, so that the name of a companion at level 1000 keeps its line.
const LONGEST_COST: String = "999,9e99"
const LONGEST_COUNT: int = 200
const BUTTON_TEXT_ROOM: float = 2.0
## Rank badge of an awakened companion ("Éveil II"), at the end of its progress line: a frame drawn
## around the text, so that the rank reads by its shape and its words, never by a colour alone. No
## vertical margin: a line of 16 u is already 23 u high with room above and below the letters, so
## the frame sits in it without making the row taller (display settings).
const RANK_BORDER: int = 1
const RANK_MARGIN_X: float = 4.0
const RANK_MARGIN_Y: float = 0.0
const RANK_CORNER: int = 4
const COLOR_RANK: Color = Color(1, 0.84, 0.25)
## The "Achat ×N" button: 16 u text, room on the right for its rotation icon, a blue edge (display
## settings).
const MODE_FONT_SIZE: int = 16
const MODE_TEXT_MARGIN: float = 12.0
const MODE_ICON_ROOM: float = 38.0
const MODE_EDGE: int = 2
const MODE_CORNER: int = 8
## The "DPS des souris" button: room for the longest value of the spec, and its side margins (the
## offsets of SquadDpsCell in the scene).
const LONGEST_SQUAD_DPS: String = "999,9 Qa"
const SQUAD_MARGIN: float = 8.0

var _companions: CompanionManager
var _gold: Callable
var _mode: BuyQuote.Mode = BuyQuote.Mode.ONE
## One row per companion: {"id": String, "title": Label, "damage": Label, "tier": Label,
## "bar": ProgressBar, "button": Button, "count": int}. "count" is what the row displays, so what a
## press buys.
var _rows: Array[Dictionary] = []
var _wide: bool = false

@onready var _rows_box: VBoxContainer = %Rows
@onready var _frame: MarginContainer = %Frame
@onready var _scroll: ScrollContainer = %Scroll
@onready var _header: PaneHeader = %Header
@onready var _squad_button: Button = %SquadDpsButton
@onready var _squad_value: Label = %SquadDpsValue
@onready var _mode_button: Button = %BuyModeButton


func _ready() -> void:
	_style_header_buttons()
	_mode_button.add_theme_font_size_override("font_size", MODE_FONT_SIZE)
	_mode_button.pressed.connect(_on_mode_pressed)
	_squad_button.pressed.connect(squad_dps_pressed.emit)
	_squad_button.custom_minimum_size.x = _squad_width()
	_mode_button.custom_minimum_size.x = _mode_width()
	set_squad_dps("0")
	_draw_mode()
	resized.connect(_on_resized)
	_scroll.resized.connect(_fit_rows)
	_on_resized()


## Builds the rows from [param companions] and draws them. [param gold] is a Callable returning
## the gold on hand as a [BigNumber]. Call once.
func setup(companions: CompanionManager, gold: Callable) -> void:
	_companions = companions
	_gold = gold
	for companion: Companion in companions.companions():
		_add_row(companion.id)
	_fit_rows()
	refresh()


## The first control of the panel for the Tab key.
func first_focus() -> Control:
	return _squad_button


## The last control of the panel for the Tab key. Call after [method setup].
func last_focus() -> Control:
	return _rows[-1]["button"] if not _rows.is_empty() else _mode_button


## The header of the tab, whose free part is a touch zone of the panel handle.
func pane_header() -> PaneHeader:
	return _header


## Shows [param mode] (a [enum BuyQuote.Mode]) as chosen, without reporting it back.
func set_mode(mode: int) -> void:
	_mode = mode as BuyQuote.Mode
	_draw_mode()
	if _companions != null:
		refresh()


## The "DPS des souris" button of the header, where the detail bubble goes.
func squad_dps_button() -> Button:
	return _squad_button


## The mode shown now, a [enum BuyQuote.Mode].
func buy_mode() -> BuyQuote.Mode:
	return _mode


## Shows [param value] (already formatted) as the damage per second of the companions.
func set_squad_dps(value: String) -> void:
	_squad_value.text = value
	_squad_button.accessibility_name = tr("DPS des souris : %s. Détail du DPS") % value


## The words of the "Achat ×N" button for [param mode] (a [enum BuyQuote.Mode]).
func mode_text(mode: int) -> String:
	match mode:
		BuyQuote.Mode.TEN:
			return tr("Achat ×10")
		BuyQuote.Mode.HUNDRED:
			return tr("Achat ×100")
		BuyQuote.Mode.MAX:
			return tr("Achat Max")
		BuyQuote.Mode.TIER:
			return tr("Achat Palier")
	return tr("Achat ×1")


## Redraws every row from the current levels and gold.
func refresh() -> void:
	var gold: BigNumber = _gold.call()
	for row: Dictionary in _rows:
		var id: String = row["id"]
		var level: int = _companions.level(id)
		# Read once per row and passed down: a cost of an awakening is a power on big numbers.
		var next: Dictionary = _companions.next_awakening(id)
		var quote: BuyQuote = BuyQuote.of(_companions, id, _mode, gold, next)
		var title: Label = row["title"]
		var damage: Label = row["damage"]
		var button: Button = row["button"]
		var line: TierLine = TierLine.of(_companions, id, next)
		var tier_label: Label = row["tier"]
		var bar: ProgressBar = row["bar"]
		var rank_label: Label = row["rank"]
		var rank: int = _companions.awakenings(id)
		title.text = tr("%s Niv. %d") % [_companions.display_name(id), level]
		# Most redraws follow the gold alone: the damage text is only rebuilt when the damage moved.
		var dps: BigNumber = _companions.damage_per_second(id)
		var drawn: BigNumber = row["dps"]
		if drawn == null or drawn.compare(dps) != 0:
			row["dps"] = dps
			damage.text = tr("DPS : %s") % dps.format()
		tier_label.text = tier_text(line)
		bar.value = line.progress
		rank_label.visible = rank > 0
		if rank > 0:
			rank_label.text = rank_text(rank)
		row["count"] = quote.count
		row["awaken"] = quote.awakening
		button.text = _awakening_button_text(id, quote) if quote.awakening else _button_text(level, quote)
		button.disabled = not quote.affordable


## [param text] with its spaces made non-breaking: "960,3 B" stays whole on one line.
static func keep_together(text: String) -> String:
	return text.replace(" ", NO_BREAK_SPACE)


## Filling of the tier bar: see [method TierLine.tier_progress].
static func tier_progress(level: int, tier: Dictionary) -> float:
	return TierLine.tier_progress(level, tier)


## The words of the progress line [param line], one per state of [enum TierLine.Kind]: the state
## is always in the text, the bar only repeats it.
func tier_text(line: TierLine) -> String:
	match line.kind:
		TierLine.Kind.TIER:
			return keep_together(tr("Palier niv. %d : ×%s") % [line.level, line.multiplier])
		TierLine.Kind.AWAKENING_AHEAD:
			return keep_together(tr("Éveil niv. %d : ×%s") % [line.level, line.multiplier])
		TierLine.Kind.AWAKENING_READY:
			return tr("Éveil disponible")
		TierLine.Kind.ALL_AWAKENED:
			return tr("Tous les éveils faits")
	return tr("Tous les paliers atteints")


## The rank badge of [param rank] awakenings: "Éveil II", on one line.
func rank_text(rank: int) -> String:
	return keep_together(tr("Éveil %s") % AwakeningText.roman(rank))


# "Éveiller : cost" and, on a second line, what the awakening multiplies: the whole squad when this
# threshold counts for it, the companion alone otherwise.
func _awakening_button_text(id: String, quote: BuyQuote) -> String:
	var squad: bool = _companions.next_awakening_counts_for_squad(id)
	return "%s\n%s" % [_awakening_cost_line(quote.cost.format()), _awakening_gain_line(squad)]


func _awakening_cost_line(cost: String) -> String:
	return (tr("Éveiller : %s") % keep_together(cost)).replace(" :", NO_BREAK_SPACE + ":")


func _awakening_gain_line(squad: bool) -> String:
	if squad:
		return keep_together(tr("Escouade ×%s") % _companions.awakening_squad_text())
	return keep_together(tr("Ce compagnon ×%s") % _companions.awakening_self_text())


func _button_text(level: int, quote: BuyQuote) -> String:
	if _mode == BuyQuote.Mode.TIER and quote.count == 0:
		return tr("Dernier palier")
	var cost: String = keep_together(quote.cost.format())
	var verb: String = tr("Acheter") if level == 0 else tr("Améliorer")
	var text: String
	if _mode == BuyQuote.Mode.ONE:
		text = tr("%s : %s") % [verb, cost]
	elif quote.count == 0:
		text = tr("%s Max : %s") % [verb, cost]
	else:
		text = tr("%s x%d : %s") % [verb, quote.count, cost]
	# The colon stays with its word, so that a text too long for the button breaks before the cost.
	return text.replace(" :", NO_BREAK_SPACE + ":")


func _add_row(id: String) -> void:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var top: HBoxContainer = HBoxContainer.new()
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	# Both wrap: the longest name at a level of 3 digits and the longest cost do not fit side by side
	# at 320 wide, and a row a line taller is better than a list wider than the screen.
	var title: Label = Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var damage: Label = Label.new()
	damage.add_theme_color_override("font_color", COLOR_DAMAGE)
	texts.add_child(title)
	texts.add_child(damage)
	var button: Button = Button.new()
	button.theme_type_variation = &"BuyButton"
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", FONT_SIZE_COMPACT)
	top.add_child(texts)
	top.add_child(button)
	var tier_line: HBoxContainer = HBoxContainer.new()
	tier_line.add_theme_constant_override("separation", TIER_LINE_GAP)
	var tier: Label = Label.new()
	tier.theme_type_variation = &"PaneText"
	var bar: ProgressBar = ProgressBar.new()
	bar.theme_type_variation = &"TierBar"
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.0
	bar.custom_minimum_size.y = TIER_BAR_HEIGHT
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier_line.add_child(tier)
	tier_line.add_child(bar)
	var rank: Label = _new_rank_badge()
	tier_line.add_child(rank)
	row.add_child(top)
	row.add_child(tier_line)
	_rows_box.add_child(row)
	var entry: Dictionary = {"id": id, "title": title, "damage": damage, "tier": tier, "bar": bar, "rank": rank, "button": button, "count": 0, "awaken": false, "dps": null}
	button.pressed.connect(_on_buy_pressed.bind(entry))
	_rows.append(entry)
	_size_row(entry)


# The framed "Éveil II" at the end of the progress line, hidden until the first awakening.
func _new_rank_badge() -> Label:
	var badge: Label = Label.new()
	badge.theme_type_variation = &"PaneText"
	badge.add_theme_color_override("font_color", COLOR_RANK)
	var frame: StyleBoxFlat = StyleBoxFlat.new()
	frame.draw_center = false
	frame.set_border_width_all(RANK_BORDER)
	frame.border_color = COLOR_RANK
	frame.set_corner_radius_all(RANK_CORNER)
	frame.content_margin_left = RANK_MARGIN_X
	frame.content_margin_right = RANK_MARGIN_X
	frame.content_margin_top = RANK_MARGIN_Y
	frame.content_margin_bottom = RANK_MARGIN_Y
	badge.add_theme_stylebox_override("normal", frame)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	return badge


func _on_buy_pressed(row: Dictionary) -> void:
	if row["awaken"]:
		awaken_requested.emit(row["id"])
		return
	var count: int = row["count"]
	if count > 0:
		buy_requested.emit(row["id"], count)


func _on_mode_pressed() -> void:
	_mode = BuyQuote.next_mode(_mode)
	mode_changed.emit(_mode)
	_draw_mode()
	if _companions != null:
		refresh()


func _draw_mode() -> void:
	_mode_button.text = mode_text(_mode)
	_mode_button.accessibility_name = tr("Mode d'achat : %s. Toucher pour changer") % mode_text(_mode)


# The "Achat ×N" button: a dark fill with a blue edge, drawn 44 u in the 46 u header. The DPS button
# has no fill: it reads as a value, and lights only under the pointer.
func _style_header_buttons() -> void:
	var states: Dictionary = {&"normal": UiPalette.BUTTON, &"hover": UiPalette.BUTTON_HOVER,
			&"pressed": UiPalette.ROW, &"hover_pressed": UiPalette.ROW}
	for state: StringName in states:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = states[state]
		box.set_border_width_all(MODE_EDGE)
		box.border_color = UiPalette.BLUE
		box.set_corner_radius_all(MODE_CORNER)
		box.content_margin_left = MODE_TEXT_MARGIN
		box.content_margin_right = MODE_ICON_ROOM
		box.expand_margin_top = -HeaderButton.DRAWN_INSET
		box.expand_margin_bottom = -HeaderButton.DRAWN_INSET
		_mode_button.add_theme_stylebox_override(state, box)
		var flat: StyleBoxFlat = StyleBoxFlat.new()
		flat.bg_color = UiPalette.ROW_HOVER if state != &"normal" else Color(UiPalette.ROW_HOVER, 0.0)
		flat.set_corner_radius_all(MODE_CORNER)
		_squad_button.add_theme_stylebox_override(state, flat)


# Wide enough for the longest of the five texts, measured: the button never changes width.
func _mode_width() -> float:
	var font: Font = _mode_button.get_theme_font("font")
	var widest: float = 0.0
	for each: int in BuyQuote.CYCLE:
		widest = maxf(widest, font.get_string_size(mode_text(each), HORIZONTAL_ALIGNMENT_LEFT, -1, MODE_FONT_SIZE).x)
	return ceilf(widest + MODE_TEXT_MARGIN + MODE_ICON_ROOM) + BUTTON_TEXT_ROOM


# Wide enough for its title and the longest value of the header (spec: "999,9 Qa").
func _squad_width() -> float:
	var title: Label = %SquadDpsTitle
	var title_width: float = title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			title.get_theme_font_size("font_size")).x
	var value_width: float = _squad_value.get_theme_font("font").get_string_size(LONGEST_SQUAD_DPS, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_squad_value.get_theme_font_size("font_size")).x
	return ceilf(maxf(title_width, value_width)) + SQUAD_MARGIN * 2.0


func _on_resized() -> void:
	var content: float = size.x - PANEL_SIDE_MARGINS
	var margin: int = ceili(maxf(content - CONTENT_MAX_WIDTH, 0.0) / 2.0)
	_frame.add_theme_constant_override("margin_left", margin)
	_frame.add_theme_constant_override("margin_right", margin)
	var wide: bool = size.x >= WIDE_WIDTH
	if wide == _wide:
		return
	_wide = wide
	for row: Dictionary in _rows:
		_size_row(row)


func _size_row(row: Dictionary) -> void:
	var title: Label = row["title"]
	var damage: Label = row["damage"]
	var button: Button = row["button"]
	title.add_theme_font_size_override("font_size", FONT_SIZE_WIDE if _wide else FONT_SIZE_COMPACT)
	damage.add_theme_font_size_override("font_size", FONT_SIZE_COMPACT)
	button.custom_minimum_size.x = BUTTON_WIDTH_WIDE if _wide else _compact_button_width(button)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, ROW_MIN_HEIGHT - TIER_LINE_HEIGHT)


# Wide enough for the longest cost on one line, measured: the name wraps, the cost must not. Each
# line of the awakening button holds on its own line too.
func _compact_button_width(button: Button) -> float:
	var verb: String = tr("Améliorer")
	var text: String = "%s x%d : %s" % [verb, LONGEST_COUNT, keep_together(LONGEST_COST)]
	var font: Font = button.get_theme_font("font")
	var box: StyleBox = button.get_theme_stylebox("normal")
	var margins: float = box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT)
	var lines: PackedStringArray = PackedStringArray([text, _awakening_cost_line(LONGEST_COST)])
	# The gain lines name factors of the data: known once setup gave the companions.
	if _companions != null:
		lines.append(_awakening_gain_line(true))
		lines.append(_awakening_gain_line(false))
	var measured: float = 0.0
	for line: String in lines:
		measured = maxf(measured, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_COMPACT).x)
	return maxf(BUTTON_WIDTH_COMPACT, ceilf(measured + margins) + BUTTON_TEXT_ROOM)


# Spare height goes to the rows, the whole list staying visible when it can.
func _fit_rows() -> void:
	if _rows.is_empty():
		return
	var gaps: float = float(_rows_box.get_theme_constant("separation") * (_rows.size() - 1))
	var share: float = floorf((_scroll.size.y - gaps) / float(_rows.size()))
	var height: float = clampf(share, ROW_MIN_HEIGHT, ROW_MAX_HEIGHT)
	for row: Dictionary in _rows:
		var button: Button = row["button"]
		button.custom_minimum_size.y = height - TIER_LINE_HEIGHT
