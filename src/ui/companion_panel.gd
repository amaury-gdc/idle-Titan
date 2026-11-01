class_name CompanionPanel
extends PanelContainer
## Readable list of the companions (story 003): name, level, damage per second, and a button
## showing what a press buys under the x1 / x10 / Max selector (story 010, D3), disabled with
## "manque X" when gold is short. Companions not bought yet are listed at level 0.
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

## Width of the list from which the rows use the bigger sizes (display setting).
const WIDE_WIDTH: float = 470.0
const FONT_SIZE_WIDE: int = 20
const FONT_SIZE_COMPACT: int = 16
const BUTTON_WIDTH_WIDE: float = 250.0
const BUTTON_WIDTH_COMPACT: float = 170.0
## Height of a row: two lines of 16 u at least. Rows share the spare height of the list up to the
## maximum, past which they would stop reading as a list (display setting).
const ROW_MIN_HEIGHT: float = 54.0
const ROW_MAX_HEIGHT: float = 96.0
## Widest content of the list: on a very wide pane the name and its button stay within one look
## (display setting).
const CONTENT_MAX_WIDTH: float = 560.0
const COLOR_DAMAGE: Color = Color(1, 0.62, 0.45)
## Side margins of the panel style of the theme, ListPanel.
const PANEL_SIDE_MARGINS: float = 16.0
const NO_BREAK_SPACE: String = " "
## Longest cost a compact button must hold on one line (spec, Localization), and a little room so
## that rounding never wraps it (display settings).
const LONGEST_COST: String = "999,9 Qa"
const BUTTON_TEXT_ROOM: float = 4.0

var _companions: CompanionManager
var _gold: Callable
var _mode: BuyQuote.Mode = BuyQuote.Mode.ONE
## One row per companion: {"id": String, "title": Label, "damage": Label, "button": Button,
## "count": int}. "count" is what the row displays, so what a press buys.
var _rows: Array[Dictionary] = []
var _wide: bool = false

@onready var _rows_box: VBoxContainer = %Rows
@onready var _frame: MarginContainer = %Frame
@onready var _scroll: ScrollContainer = %Scroll
@onready var _segments: Array[Button] = [%OneSegment, %TenSegment, %MaxSegment]


func _ready() -> void:
	var group: ButtonGroup = ButtonGroup.new()
	for i in _segments.size():
		var segment: Button = _segments[i]
		segment.button_group = group
		segment.pressed.connect(_on_segment_pressed.bind(i))
	_segments[0].text = tr("x1")
	_segments[1].text = tr("x10")
	_segments[2].text = tr("Max")
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
		var quote: BuyQuote = BuyQuote.of(_companions, id, _mode, gold)
		var title: Label = row["title"]
		var damage: Label = row["damage"]
		var button: Button = row["button"]
		title.text = tr("%s Niv. %d") % [_companions.display_name(id), level]
		damage.text = tr("DPS : %s") % _companions.damage_per_second(id).format()
		row["count"] = quote.count
		button.text = _button_text(level, quote)
		button.disabled = not quote.affordable


## [param text] with its spaces made non-breaking: "960,3 B" stays whole on one line.
static func keep_together(text: String) -> String:
	return text.replace(" ", NO_BREAK_SPACE)


func _button_text(level: int, quote: BuyQuote) -> String:
	var cost: String = keep_together(quote.cost.format())
	var verb: String = tr("Acheter") if level == 0 else tr("Améliorer")
	var text: String
	if _mode == BuyQuote.Mode.ONE:
		text = tr("%s : %s") % [verb, cost]
	elif quote.count == 0:
		text = tr("%s Max : %s") % [verb, cost]
	else:
		text = tr("%s x%d : %s") % [verb, quote.count, cost]
	# The colon stays with its word, so the only break left in the first line is before the cost.
	text = text.replace(" :", NO_BREAK_SPACE + ":")
	if quote.affordable:
		return text
	return "%s\n%s" % [text, tr("manque %s") % keep_together(quote.missing.format())]


func _add_row(id: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	# Both wrap: the longest name and the longest cost do not fit side by side at 320 wide, and a
	# row a line taller is better than a list wider than the screen.
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
	row.add_child(texts)
	row.add_child(button)
	_rows_box.add_child(row)
	var entry: Dictionary = {"id": id, "title": title, "damage": damage, "button": button, "count": 0}
	button.pressed.connect(_on_buy_pressed.bind(entry))
	_rows.append(entry)
	_size_row(entry)


func _on_buy_pressed(row: Dictionary) -> void:
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
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, ROW_MIN_HEIGHT)


# Wide enough for the longest cost on one line, measured: the name wraps, the cost must not.
func _compact_button_width(button: Button) -> float:
	var verb: String = tr("Améliorer")
	var text: String = "%s x%d : %s" % [verb, BuyQuote.TEN_COUNT, keep_together(LONGEST_COST)]
	var font: Font = button.get_theme_font("font")
	var box: StyleBox = button.get_theme_stylebox("normal")
	var margins: float = box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT)
	var measured: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_COMPACT).x
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
		button.custom_minimum_size.y = height
