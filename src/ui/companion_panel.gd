class_name CompanionPanel
extends PanelContainer
## Readable list of the companions (story 003): name, level, damage per second, the next tier with
## a thin bar, and a button showing what a press buys under the x1 / x10 / Max / Palier selector
## (stories 010 and 013, D3), showing the cost alone and disabled when gold is short. Companions not
## bought yet are listed at level 0. The bar takes no input and tells nothing the text does not.
## One list only: it adapts to its own width, not to the shape of the screen.
## Pure presentation: reads a [CompanionManager], never changes it; a press is reported through
## [signal buy_requested] with the amount the row displays, and the composition root forwards it.
## The selector's choice is kept by the composition root ([DisplaySettings]), never in the save.
##
## The buy buttons pass the mouse on: the [ScrollContainer] sees a drag and cancels the press, so a
## drag in the list never buys.
##
## Usage:
## [codeblock]
## panel.buy_requested.connect(func(id: String, count: int) -> void: companions.buy_levels(id, count))
## panel.setup(companions, func() -> BigNumber: return game.gold)   # builds one row per companion
## panel.set_mode(BuyQuote.Mode.TEN)
## panel.refresh()           # after a change of gold or level
## [/codeblock]

## The player pressed the buy button of companion [param id]: buy [param count] levels.
signal buy_requested(id: String, count: int)
## The player chose [param mode] (a [enum BuyQuote.Mode]) in the selector.
signal mode_changed(mode: int)
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
@onready var _segments: Array[Button] = [%OneSegment, %TenSegment, %MaxSegment, %TierSegment]


func _ready() -> void:
	var group: ButtonGroup = ButtonGroup.new()
	for i in _segments.size():
		var segment: Button = _segments[i]
		segment.button_group = group
		segment.pressed.connect(_on_segment_pressed.bind(i))
	_segments[0].text = tr("x1")
	_segments[1].text = tr("x10")
	_segments[2].text = tr("Max")
	_segments[3].text = tr("Palier")
	_segments[_mode].button_pressed = true
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
	return _segments[0]


## The last control of the panel for the Tab key. Call after [method setup].
func last_focus() -> Control:
	return _rows[-1]["button"] if not _rows.is_empty() else _segments[-1]


## Shows [param mode] (a [enum BuyQuote.Mode]) as chosen, without reporting it back.
func set_mode(mode: int) -> void:
	_mode = mode as BuyQuote.Mode
	_segments[_mode].button_pressed = true
	if _companions != null:
		refresh()


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


func _on_segment_pressed(mode: int) -> void:
	_mode = mode as BuyQuote.Mode
	mode_changed.emit(mode)
	refresh()


func _on_resized() -> void:
	var content: float = size.x - PANEL_SIDE_MARGINS
	var margin: int = ceili(maxf(content - CONTENT_MAX_WIDTH, 0.0) / 2.0)
	_frame.add_theme_constant_override("margin_left", margin)
	_frame.add_theme_constant_override("margin_right", margin)
	var wide: bool = size.x >= WIDE_WIDTH
	if wide == _wide:
		return
	_wide = wide
	for segment: Button in _segments:
		segment.add_theme_font_size_override("font_size", FONT_SIZE_WIDE if wide else FONT_SIZE_COMPACT)
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
