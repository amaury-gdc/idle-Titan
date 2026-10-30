class_name CompanionPanel
extends PanelContainer
## Readable list of the companions (story 003): name, level, damage per second, and
## a button showing the cost of the next level, disabled when gold is short.
## Companions not bought yet are listed at level 0 with the cost of level 1.
## Pure presentation: reads a [CompanionManager], never changes it; a press is
## reported through [signal buy_requested] and the composition root forwards it.
##
## Usage:
## [codeblock]
## panel.buy_requested.connect(func(id: String) -> void: companions.buy_or_upgrade(id))
## panel.setup(companions)   # builds one row per companion
## panel.refresh()           # after any change of gold or level
## [/codeblock]

## The player pressed the buy/upgrade button of companion [param id].
signal buy_requested(id: String)

const FONT_SIZE_NAME: int = 22
const FONT_SIZE_DAMAGE: int = 20
const FONT_SIZE_BUTTON: int = 22
const BUTTON_MIN_SIZE: Vector2 = Vector2(235, 54)
const COLOR_BUY: Color = Color(0.13, 0.5, 0.25)
const COLOR_BUY_HOVER: Color = Color(0.18, 0.62, 0.32)
const COLOR_BUY_PRESSED: Color = Color(0.09, 0.38, 0.19)
const COLOR_DISABLED: Color = Color(0.17, 0.17, 0.2)
const COLOR_DISABLED_TEXT: Color = Color(0.5, 0.5, 0.52)
const COLOR_DAMAGE: Color = Color(1, 0.62, 0.45)

var _companions: CompanionManager
## One row per companion: {"id": String, "title": Label, "damage": Label, "button": Button}.
var _rows: Array[Dictionary] = []

@onready var _rows_box: VBoxContainer = %Rows


## Builds the rows from [param companions] and draws them. Call once.
func setup(companions: CompanionManager) -> void:
	_companions = companions
	for companion: Companion in companions.companions():
		_add_row(companion.id)
	refresh()


## Redraws every row from the current levels and gold.
func refresh() -> void:
	for row: Dictionary in _rows:
		var id: String = row["id"]
		var level: int = _companions.level(id)
		var cost: String = _companions.next_cost(id).format()
		var title: Label = row["title"]
		var damage: Label = row["damage"]
		var button: Button = row["button"]
		title.text = tr("%s - Niv. %d") % [_companions.display_name(id), level]
		damage.text = tr("DPS : %s") % _companions.damage_per_second(id).format()
		button.text = (tr("Acheter : %s") if level == 0 else tr("Améliorer : %s")) % cost
		button.disabled = not _companions.can_buy(id)


func _add_row(id: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", FONT_SIZE_NAME)
	var damage: Label = Label.new()
	damage.add_theme_font_size_override("font_size", FONT_SIZE_DAMAGE)
	damage.add_theme_color_override("font_color", COLOR_DAMAGE)
	texts.add_child(title)
	texts.add_child(damage)
	var button: Button = Button.new()
	button.custom_minimum_size = BUTTON_MIN_SIZE
	button.add_theme_font_size_override("font_size", FONT_SIZE_BUTTON)
	button.add_theme_color_override("font_disabled_color", COLOR_DISABLED_TEXT)
	button.add_theme_stylebox_override("normal", _flat_box(COLOR_BUY))
	button.add_theme_stylebox_override("hover", _flat_box(COLOR_BUY_HOVER))
	button.add_theme_stylebox_override("pressed", _flat_box(COLOR_BUY_PRESSED))
	button.add_theme_stylebox_override("disabled", _flat_box(COLOR_DISABLED))
	button.pressed.connect(func() -> void: buy_requested.emit(id))
	row.add_child(texts)
	row.add_child(button)
	_rows_box.add_child(row)
	_rows.append({"id": id, "title": title, "damage": damage, "button": button})


func _flat_box(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(6)
	return box
