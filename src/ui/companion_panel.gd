class_name CompanionPanel
extends PanelContainer
## Readable list of the companions (story 003), one card of 70 u per companion (story 019b, lot 6): a
## portrait in the companion's colour, its name in bold and "Niv. N" in blue, "DPS · part %" (its share
## of the damage of all the companions), its progress line (tier or awakening, a thin bar, the framed
## rank), and one buy button of 112 x 56 u with two lines: the cost, then "+X DPS", what the press adds.
## Companions not bought yet are listed at level 0, and their button reads "Acheter" over the cost.
## The bar takes no input and tells nothing the text does not. One list only: it adapts to its own
## width, not to the shape of the screen.
## Pure presentation: reads a [CompanionManager], never changes it; a press is reported through
## [signal buy_requested] with the amount the row displays, and the composition root forwards it.
## The mode's choice is kept by the composition root ([DisplaySettings]), never in the save.
##
## The button under the buy mode (stories 010, 013, D3): yellow when it can be paid, grey when the
## gold is short; violet "Éveil II" over the cost at an awakening threshold (story 017), the card edged
## in violet and its line saying "Niveau bloqué : éveil requis"; "Max", outlined and disabled, in the
## Palier mode once the last tier is passed. Blocked at a threshold, the rank badge gives way: the
## button names the rank to reach. The button does not repeat "x10" (the header says
## "Achat ×10"); it shows "×N · " before the gain when the real count differs from the mode: Max,
## Palier, or x10 and x100 cut by a threshold. Its accessible name says it all in one sentence.
##
## "+X DPS" (story 019b) is [method CompanionManager.damage_per_second_at] at the level the press
## reaches minus the damage per second now: the companion talents and "Cadence" are in it. A purchase
## that changes the strongest companion ("Champion") or crosses the level of "Synergie" moves other
## companions too, which this reading does not foresee.
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
## panel.set_colors(roster)  # the "color" of each companion of companions_roster.json
## panel.setup(companions, func() -> BigNumber: return game.gold)   # builds one row per companion
## panel.set_mode(BuyQuote.Mode.TEN)
## panel.set_squad_dps("19,4 Qa")
## panel.refresh()           # after a change of gold or level
## panel.row_lines(0)        # ["2,9 Qa", "+339 M DPS"]
## [/codeblock]

## The player pressed the buy button of companion [param id]: buy [param count] levels.
signal buy_requested(id: String, count: int)
## The player chose [param mode] (a [enum BuyQuote.Mode]) with the "Achat ×N" button.
signal mode_changed(mode: int)
## The player touched "DPS des souris" in the header: show the detail of the damage.
signal squad_dps_pressed
## The player pressed the "Éveil" button of companion [param id], shown only at an awakening
## threshold (story 017): awaken it.
signal awaken_requested(id: String)

## Width of the list from which a pane counts as wide (display setting): [ManagementTabs] reads it.
const WIDE_WIDTH: float = 470.0
## Sizes of the card (story 019b, display settings): 70 u high, a portrait of 52 u holding a mouse of
## 40 u, a button of 112 x 56 u, and the room between them.
const ROW_HEIGHT: float = 70.0
const PORTRAIT_SIZE: float = 52.0
const PORTRAIT_MOUSE: float = 40.0
const BUTTON_SIZE: Vector2 = Vector2(112.0, 56.0)
const ROW_GAP: int = 8
const ROW_PADDING: float = 6.0
## Above and below: 70 u hold a line of 16 u and two of 14 u (23 + 20 + 20) with this room.
const ROW_PADDING_Y: float = 3.0
const ROW_CORNER: int = 10
## Inside the button: the gap between the cost and the gain, and the spacing of a gain on two lines
## (display settings): 23 + 37 - 4 = 56 u at most.
const BUTTON_LINES_GAP: int = -4
const BUTTON_LINE_SPACING: int = -3
const ROW_EDGE: int = 2
## Text sizes (spec): name, level and cost at 16 u, the rest at 14 u, the secondary of the spec.
const FONT_SIZE_MAIN: int = 16
const FONT_SIZE_SECONDARY: int = 14
## Weight added to the font of the name and of the cost: bold (display setting).
const BOLD_EMBOLDEN: float = 0.6
## Height of a line of 14 u and the measures of the progress line (display settings).
const TIER_LINE_HEIGHT: float = 20.0
const TIER_BAR_HEIGHT: float = 6.0
const TIER_LINE_GAP: int = 6
## Widest content of the list: on a very wide pane the name and its button stay within one look
## (display setting).
const CONTENT_MAX_WIDTH: float = 560.0
const COLOR_DAMAGE: Color = Color(1, 0.62, 0.45)
## Side margins of the panel style of the theme, CompanionListPanel.
const PANEL_SIDE_MARGINS: float = 8.0
## U+00A0. It looks like a plain space: companion_cost_text_test.gd checks its code, so that a copy
## of the file cannot turn it into one unseen (it happened once, story 019b).
const NO_BREAK_SPACE: String = " "
## Longest cost and longest count the button must hold (spec, Localization). The cost is the widest
## text [method BigNumber.format] gives up to stage 300 and the awakening costs of level 1000 (about
## 1e46): a scientific notation with two exponent digits, measured wider than every suffix from K to
## Dc (story 017, companion_panel_awakening_test.gd). The count is the most levels one press buys
## before the last awakening: x200, a first Max from level 0 to the first threshold.
const LONGEST_COST: String = "999,9e99"
const LONGEST_COUNT: int = 200
## Rank badge of an awakened companion ("Éveil II"), at the end of its progress line: a frame drawn
## around the text, so that the rank reads by its shape and its words, never by a colour alone. No
## vertical margin: the frame sits in the line without making the row taller (display settings).
const RANK_BORDER: int = 1
const RANK_MARGIN_X: float = 4.0
const RANK_MARGIN_Y: float = 0.0
const RANK_CORNER: int = 4
const COLOR_RANK: Color = Color(1, 0.84, 0.25)
## The colour of a companion without a valid "color" in the roster.
const DEFAULT_PORTRAIT_COLOR: Color = Color("#A9B1CC")
## The "Achat ×N" button: 16 u text, room on the right for its rotation icon, a blue edge (display
## settings).
const MODE_FONT_SIZE: int = 16
const MODE_TEXT_MARGIN: float = 12.0
const MODE_ICON_ROOM: float = 38.0
const MODE_EDGE: int = 2
const MODE_CORNER: int = 8
const BUTTON_TEXT_ROOM: float = 2.0
## The "DPS des souris" button: room for the longest value of the spec, and its side margins (the
## offsets of SquadDpsCell in the scene).
const LONGEST_SQUAD_DPS: String = "999,9 Qa"
const SQUAD_MARGIN: float = 8.0
## Levels of one press of each mode whose count is fixed: the button names the count only when the
## real one differs (Max and Palier have none).
const NOMINAL_COUNTS: Dictionary = {BuyQuote.Mode.ONE: 1, BuyQuote.Mode.TEN: 10, BuyQuote.Mode.HUNDRED: 100}

var _companions: CompanionManager
var _gold: Callable
var _mode: BuyQuote.Mode = BuyQuote.Mode.ONE
## One row per companion: {"id", "card": PanelContainer, "portrait": MousePortrait, "title" (the name),
## "level", "damage", "tier", "bar", "rank": Label or ProgressBar, "button": Button, "cost" and "gain":
## the two Labels of the button, "count": int, "awaken": bool, "dps": BigNumber}. "count" is what the
## row displays, so what a press buys.
var _rows: Array[Dictionary] = []
var _colors: Dictionary = {}
var _bold: FontVariation
var _card_style: StyleBoxFlat
var _card_awakening_style: StyleBoxFlat
var _max_style: StyleBoxFlat

@onready var _rows_box: VBoxContainer = %Rows
@onready var _frame: MarginContainer = %Frame
@onready var _scroll: ScrollContainer = %Scroll
@onready var _header: PaneHeader = %Header
@onready var _squad_button: Button = %SquadDpsButton
@onready var _squad_value: Label = %SquadDpsValue
@onready var _mode_button: Button = %BuyModeButton


func _ready() -> void:
	_bold = FontVariation.new()
	_bold.base_font = get_theme_font("font")
	_bold.variation_embolden = BOLD_EMBOLDEN
	_card_style = _new_card_style(UiPalette.ROW, 0)
	_card_awakening_style = _new_card_style(UiPalette.ROW, ROW_EDGE)
	_max_style = StyleBoxFlat.new()
	_max_style.bg_color = UiPalette.PANEL
	_max_style.set_border_width_all(ROW_EDGE)
	_max_style.border_color = UiPalette.TEXT_DISABLED
	_max_style.set_corner_radius_all(MODE_CORNER)
	_style_header_buttons()
	_mode_button.add_theme_font_size_override("font_size", MODE_FONT_SIZE)
	_mode_button.pressed.connect(_on_mode_pressed)
	_squad_button.pressed.connect(squad_dps_pressed.emit)
	_squad_button.custom_minimum_size.x = _squad_width()
	_mode_button.custom_minimum_size.x = _mode_width()
	set_squad_dps("0")
	_draw_mode()
	resized.connect(_on_resized)
	_on_resized()


## Reads the colour of each companion from [param roster] (companions_roster.json as loaded): the
## "color" of each entry, a hex string. A missing or invalid one gives
## [constant DEFAULT_PORTRAIT_COLOR]. Before or after [method setup].
func set_colors(roster: Variant) -> void:
	_colors.clear()
	var entries: Variant = (roster as Dictionary).get("companions", []) if roster is Dictionary else []
	for entry: Variant in entries if entries is Array else []:
		if entry is Dictionary and (entry as Dictionary).get("id") is String:
			var hex: Variant = (entry as Dictionary).get("color")
			_colors[entry["id"]] = Color.html(hex) if hex is String and Color.html_is_valid(hex) else DEFAULT_PORTRAIT_COLOR
	for row: Dictionary in _rows:
		(row["portrait"] as MousePortrait).color = color_of(row["id"])


## The portrait colour of [param id].
func color_of(id: String) -> Color:
	return _colors.get(id, DEFAULT_PORTRAIT_COLOR)


## Builds the rows from [param companions] and draws them. [param gold] is a Callable returning
## the gold on hand as a [BigNumber]. Call once.
func setup(companions: CompanionManager, gold: Callable) -> void:
	_companions = companions
	_gold = gold
	for companion: Companion in companions.companions():
		_add_row(companion.id)
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


## The "DPS des souris" button of the header, where the detail bubble goes.
func squad_dps_button() -> Button:
	return _squad_button


## The mode shown now, a [enum BuyQuote.Mode].
func buy_mode() -> BuyQuote.Mode:
	return _mode


## Shows [param mode] (a [enum BuyQuote.Mode]) as chosen, without reporting it back.
func set_mode(mode: int) -> void:
	_mode = mode as BuyQuote.Mode
	_draw_mode()
	if _companions != null:
		refresh()


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


## The two lines the buy button of row [param index] shows now: [top, bottom].
func row_lines(index: int) -> PackedStringArray:
	var row: Dictionary = _rows[index]
	return PackedStringArray([(row["cost"] as Label).text, (row["gain"] as Label).text])


## Redraws every row from the current levels and gold.
func refresh() -> void:
	var gold: BigNumber = _gold.call()
	var squad: BigNumber = _companions.total_power()
	for row: Dictionary in _rows:
		var id: String = row["id"]
		var level: int = _companions.level(id)
		# Read once per row and passed down: a cost of an awakening is a power on big numbers.
		var next: Dictionary = _companions.next_awakening(id)
		var quote: BuyQuote = BuyQuote.of(_companions, id, _mode, gold, next)
		var line: TierLine = TierLine.of(_companions, id, next)
		var rank: int = _companions.awakenings(id)
		(row["title"] as Label).text = _companions.display_name(id)
		(row["level"] as Label).text = tr("Niv. %d") % level
		# Most redraws follow the gold alone: the damage text is only rebuilt when the damage moved.
		var dps: BigNumber = _companions.damage_per_second(id)
		var drawn: BigNumber = row["dps"]
		if drawn == null or drawn.compare(dps) != 0 or row["squad"] == null or (row["squad"] as BigNumber).compare(squad) != 0:
			row["dps"] = dps
			row["squad"] = squad
			(row["damage"] as Label).text = damage_text(dps, squad)
		var tier_label: Label = row["tier"]
		tier_label.text = tier_text(line)
		tier_label.tooltip_text = full_tier_text(line)
		var bar: ProgressBar = row["bar"]
		bar.value = line.progress
		# With no goal ahead the words say it all: no bar, and they take the room, wrapping if they must.
		var goal: bool = line.kind == TierLine.Kind.TIER or line.kind == TierLine.Kind.AWAKENING_AHEAD
		if goal != bar.visible or not row["drawn"]:
			bar.visible = goal
			tier_label.autowrap_mode = TextServer.AUTOWRAP_OFF if goal else TextServer.AUTOWRAP_WORD_SMART
			tier_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if goal else Control.SIZE_EXPAND_FILL
		var rank_label: Label = row["rank"]
		# Blocked at a threshold, the button names the rank to reach: the badge gives the line its room.
		rank_label.visible = rank > 0 and line.kind != TierLine.Kind.AWAKENING_READY
		if rank > 0:
			rank_label.text = rank_text(rank)
		row["count"] = quote.count
		# A style or colour set again reapplies the theme of the control: only when the state changes.
		if quote.awakening != row["awaken"] or not row["drawn"]:
			(row["card"] as PanelContainer).add_theme_stylebox_override("panel", _card_awakening_style if quote.awakening else _card_style)
			tier_label.add_theme_color_override("font_color", UiPalette.VIOLET_EDGE if quote.awakening else UiPalette.TEXT_MUTED)
		row["awaken"] = quote.awakening
		# The texts of the button follow the level, the count, the rank and the squad, not the gold:
		# a redraw at the pace of the gold only changes whether it can be paid. The squad power is a
		# cached object that changes on every purchase and talent, so its identity says enough.
		var key: Array = [quote.awakening, level, quote.count, rank, squad, _mode]
		if key != row["key"]:
			row["key"] = key
			_draw_button(row, id, level, quote)
		_draw_affordable(row, quote)
		row["drawn"] = true


## [param text] with its spaces made non-breaking: "960,3 B" stays whole on one line.
static func keep_together(text: String) -> String:
	return text.replace(" ", NO_BREAK_SPACE)


## Filling of the tier bar: see [method TierLine.tier_progress].
static func tier_progress(level: int, tier: Dictionary) -> float:
	return TierLine.tier_progress(level, tier)


## "339,9 M DPS · 2 %": the damage per second [param dps] and its share of [param squad], the damage
## of all the companions, rounded to the nearest percent.
static func damage_text(dps: BigNumber, squad: BigNumber) -> String:
	var share: int = 0
	if not squad.is_zero():
		var tenths: int = int(dps.multiply(BigNumber.from_int(1000)).divide(squad).to_decimal_string())
		share = (tenths + 5) / 10
	return keep_together("%s DPS · %d %%" % [dps.format(), share])


## The short words of the progress line [param line] beside its bar (story 019b: "barre + Éveil N",
## so that the line holds with the rank badge at 320 wide): "Palier 200", "Éveil 1000", or the
## state in full when there is no goal ahead. The state is always in the text, the bar only repeats
## it; the multiplier is in [method full_tier_text].
func tier_text(line: TierLine) -> String:
	match line.kind:
		TierLine.Kind.TIER:
			return keep_together(tr("Palier %d") % line.level)
		TierLine.Kind.AWAKENING_AHEAD:
			return keep_together(tr("Éveil %d") % line.level)
	return full_tier_text(line)


## The whole sentence of the progress line [param line], one per state of [enum TierLine.Kind], the
## multiplier included: the tooltip of the line, and what a screen reader can ask for.
func full_tier_text(line: TierLine) -> String:
	match line.kind:
		TierLine.Kind.TIER:
			return keep_together(tr("Palier niv. %d : ×%s") % [line.level, line.multiplier])
		TierLine.Kind.AWAKENING_AHEAD:
			return keep_together(tr("Éveil niv. %d : ×%s") % [line.level, line.multiplier])
		TierLine.Kind.AWAKENING_READY:
			return tr("Niveau bloqué : éveil requis")
		TierLine.Kind.ALL_AWAKENED:
			return tr("Tous les éveils faits")
	return tr("Tous les paliers atteints")


## The rank badge of [param rank] awakenings: "Éveil II", on one line.
func rank_text(rank: int) -> String:
	return keep_together(tr("Éveil %s") % AwakeningText.roman(rank))


## The two lines of a buy button for a companion at [param level], under the current mode, for the
## quote [param quote] (not an awakening) and the gain [param gain] it brings: [top, bottom]. Level 0
## reads "Acheter" over the cost; otherwise the cost over "+X DPS"; "×N · " starts the bottom line
## when the count differs from the mode's; the Palier mode with no tier left reads "Max".
func button_lines(level: int, quote: BuyQuote, gain: BigNumber) -> PackedStringArray:
	if _mode == BuyQuote.Mode.TIER and quote.count == 0:
		return PackedStringArray([tr("Max"), ""])
	var cost: String = keep_together(quote.cost.format())
	var prefix: String = count_prefix(quote.count)
	if level == 0:
		return PackedStringArray([tr("Acheter"), prefix + cost])
	return PackedStringArray([cost, prefix + gain_text(gain)])


## "×3 · " when a press buys [param count] levels and the mode does not say how many (Max, Palier),
## or says another number (x10 and x100 cut by a threshold); "" otherwise.
func count_prefix(count: int) -> String:
	if count <= 0 or count == NOMINAL_COUNTS.get(_mode, -1):
		return ""
	# A plain space after "·": the one place a long gain line may break.
	return keep_together(tr("×%d ·") % count) + " "


## "+339 M DPS": what a purchase adds.
static func gain_text(gain: BigNumber) -> String:
	return keep_together("+%s DPS" % gain.format())


## The two lines of the button at an awakening threshold, the companion having [param rank]
## awakenings: the next rank ("Éveil II"), then its [param cost].
func awakening_lines(rank: int, cost: BigNumber) -> PackedStringArray:
	return PackedStringArray([rank_text(rank + 1), keep_together(cost.format())])


func _draw_button(row: Dictionary, id: String, level: int, quote: BuyQuote) -> void:
	var button: Button = row["button"]
	var lines: PackedStringArray
	var said: String
	var is_max: bool = false
	if quote.awakening:
		lines = awakening_lines(_companions.awakenings(id), quote.cost)
		button.theme_type_variation = &"AwakenButton"
		said = tr("Éveiller %s : %s. %s") % [_companions.display_name(id), lines[1], _awakening_gain_line(_companions.next_awakening_counts_for_squad(id))]
	else:
		var reached: int = level + maxi(quote.count, 1)
		var gain: BigNumber = _companions.damage_per_second_at(id, reached).subtract(_companions.damage_per_second(id))
		lines = button_lines(level, quote, gain)
		is_max = _mode == BuyQuote.Mode.TIER and quote.count == 0
		button.theme_type_variation = &"BuyButton"
		said = _accessible_text(id, level, quote, gain)
	if is_max != row["max"] or not row["drawn"]:
		if is_max:
			button.add_theme_stylebox_override("disabled", _max_style)
		else:
			button.remove_theme_stylebox_override("disabled")
		row["max"] = is_max
	(row["cost"] as Label).text = lines[0]
	(row["gain"] as Label).text = lines[1]
	(row["gain"] as Label).visible = not lines[1].is_empty()
	button.accessibility_name = said
	button.tooltip_text = said


# What the gold alone changes: enabled or not, and the colour of the two lines.
func _draw_affordable(row: Dictionary, quote: BuyQuote) -> void:
	(row["button"] as Button).disabled = not quote.affordable
	var ink: Color = _ink(quote)
	if ink != row["ink"]:
		(row["cost"] as Label).add_theme_color_override("font_color", ink)
		(row["gain"] as Label).add_theme_color_override("font_color", ink)
		row["ink"] = ink


# The text of the labels in the button, which a Button does not colour for them: dark on yellow,
# white on violet, the grey of a disabled control otherwise.
func _ink(quote: BuyQuote) -> Color:
	if not quote.affordable:
		return UiPalette.TEXT_DISABLED
	return Color.WHITE if quote.awakening else UiPalette.ON_YELLOW


# The whole button in one sentence, for a screen reader and the tooltip: what a press does.
func _accessible_text(id: String, level: int, quote: BuyQuote, gain: BigNumber) -> String:
	var who: String = _companions.display_name(id)
	if _mode == BuyQuote.Mode.TIER and quote.count == 0:
		return tr("%s : Max, dernier palier atteint") % who
	var verb: String = tr("Acheter") if level == 0 else tr("Améliorer")
	var cost: String = quote.cost.format()
	if quote.count <= 0:
		return tr("%s %s Max : %s, %s") % [verb, who, cost, gain_text(gain)]
	return tr("%s %s ×%d : %s, %s") % [verb, who, quote.count, cost, gain_text(gain)]


func _awakening_gain_line(squad: bool) -> String:
	if squad:
		return keep_together(tr("Escouade ×%s") % _companions.awakening_squad_text())
	return keep_together(tr("Ce compagnon ×%s") % _companions.awakening_self_text())


func _add_row(id: String) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size.y = ROW_HEIGHT
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", _card_style)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", ROW_GAP)
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	var portrait: MousePortrait = MousePortrait.new()
	portrait.custom_minimum_size = Vector2.ONE * PORTRAIT_SIZE
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_size = PORTRAIT_MOUSE
	portrait.color = color_of(id)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_PASS
	# The name and its level flow: "Niv. 1000" goes under a long name rather than past the screen, and
	# neither word is ever cut.
	var title_line: HFlowContainer = HFlowContainer.new()
	title_line.add_theme_constant_override("h_separation", 6)
	title_line.add_theme_constant_override("v_separation", 0)
	title_line.mouse_filter = Control.MOUSE_FILTER_PASS
	var title: Label = _new_label(FONT_SIZE_MAIN, Color.WHITE, true)
	var level_label: Label = _new_label(FONT_SIZE_MAIN, UiPalette.BLUE, true)
	title_line.add_child(title)
	title_line.add_child(level_label)
	var damage: Label = _new_label(FONT_SIZE_SECONDARY, UiPalette.TEXT_MUTED, false)
	var tier_line: HBoxContainer = HBoxContainer.new()
	tier_line.add_theme_constant_override("separation", TIER_LINE_GAP)
	tier_line.mouse_filter = Control.MOUSE_FILTER_PASS
	# Short beside its bar; without a goal, "Niveau bloqué : éveil requis" is longer than the line at
	# 320 wide: it wraps there, and the row grows (see refresh).
	var tier: Label = _new_label(FONT_SIZE_SECONDARY, UiPalette.TEXT_MUTED, false)
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
	texts.add_child(title_line)
	texts.add_child(damage)
	texts.add_child(tier_line)
	var button: Button = Button.new()
	button.theme_type_variation = &"BuyButton"
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var inside: VBoxContainer = VBoxContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.alignment = BoxContainer.ALIGNMENT_CENTER
	inside.add_theme_constant_override("separation", BUTTON_LINES_GAP)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cost: Label = _new_label(FONT_SIZE_MAIN, UiPalette.ON_YELLOW, true)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gain: Label = _new_label(FONT_SIZE_SECONDARY, UiPalette.ON_YELLOW, false)
	gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# A count with a long gain may take two lines; the spaces that stay are those after "·". Tight
	# lines, so that the cost and two gain lines hold in the 56 u of the button.
	gain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gain.add_theme_constant_override("line_spacing", BUTTON_LINE_SPACING)
	inside.add_child(cost)
	inside.add_child(gain)
	button.add_child(inside)
	line.add_child(portrait)
	line.add_child(texts)
	line.add_child(button)
	card.add_child(line)
	_rows_box.add_child(card)
	var entry: Dictionary = {"id": id, "card": card, "portrait": portrait, "title": title, "level": level_label,
			"damage": damage, "tier": tier, "bar": bar, "rank": rank, "button": button, "cost": cost, "gain": gain,
			"count": 0, "awaken": false, "dps": null, "squad": null, "drawn": false, "max": false,
			"ink": UiPalette.ON_YELLOW, "key": []}
	button.pressed.connect(_on_buy_pressed.bind(entry))
	_rows.append(entry)


func _new_label(font_size: int, color: Color, bold: bool) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", _bold)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _new_card_style(fill: Color, edge: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(ROW_CORNER)
	box.content_margin_left = ROW_PADDING
	box.content_margin_right = ROW_PADDING
	box.content_margin_top = ROW_PADDING_Y
	box.content_margin_bottom = ROW_PADDING_Y
	if edge > 0:
		box.set_border_width_all(edge)
		box.border_color = UiPalette.VIOLET_EDGE
	return box


# The framed "Éveil II" at the end of the progress line, hidden until the first awakening.
func _new_rank_badge() -> Label:
	var badge: Label = _new_label(FONT_SIZE_SECONDARY, COLOR_RANK, false)
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
