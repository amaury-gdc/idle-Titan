class_name SkillBar
extends VBoxContainer
## The three skill buttons (story 005): name, state (prêt / actif / en recharge) with the
## seconds left, and under them one line per running buff with its remaining time.
## Pure presentation: it reads the [Skill] states of a [SkillManager], never changes them;
## a press is reported through [signal activate_requested] and the composition root
## forwards it.
##
## Usage:
## [codeblock]
## bar.activate_requested.connect(func(id: String) -> void: skills.activate(id))
## bar.setup(skills)     # builds one button per skill
## bar.refresh()         # every frame, and right after an activation
## [/codeblock]

## The player pressed the button of skill [param id].
signal activate_requested(id: String)

const FONT_SIZE_BUTTON: int = 20
const BUTTON_MIN_SIZE: Vector2 = Vector2(190, 62)
const COLOR_READY: Color = Color(0.13, 0.5, 0.25)
const COLOR_READY_HOVER: Color = Color(0.18, 0.62, 0.32)
const COLOR_READY_PRESSED: Color = Color(0.09, 0.38, 0.19)
const COLOR_ACTIVE: Color = Color(0.55, 0.42, 0.05)
const COLOR_COOLDOWN: Color = Color(0.17, 0.17, 0.2)
const COLOR_TEXT_ACTIVE: Color = Color(1, 0.92, 0.5)
const COLOR_TEXT_COOLDOWN: Color = Color(0.55, 0.55, 0.58)

var _skills: SkillManager
## One entry per skill: {"skill": Skill, "button": Button, "key": int}. "key" is the last
## drawn (state, whole seconds shown), so unchanged buttons are not redrawn.
var _rows: Array[Dictionary] = []

@onready var _buttons_box: VBoxContainer = %Buttons
@onready var _buff_label: Label = %BuffLabel


## Builds the buttons from [param skills] and draws them. Call once.
func setup(skills: SkillManager) -> void:
	_skills = skills
	for skill: Skill in skills.skills():
		_add_row(skill)
	refresh()


## Redraws what changed since the last call: the buttons whose state or displayed
## seconds changed, and the list of running buffs.
func refresh() -> void:
	var changed: bool = false
	for row: Dictionary in _rows:
		var skill: Skill = row["skill"]
		var state: Skill.State = skill.state()
		var seconds: int = _seconds_shown(skill, state)
		var key: int = int(state) * 1_000_000 + seconds
		if key == row["key"]:
			continue
		changed = true
		row["key"] = key
		_draw_button(row["button"], skill, state, seconds)
	if changed:
		_draw_buffs()


func _add_row(skill: Skill) -> void:
	var button: Button = Button.new()
	button.custom_minimum_size = BUTTON_MIN_SIZE
	button.add_theme_font_size_override("font_size", FONT_SIZE_BUTTON)
	button.add_theme_stylebox_override("normal", _flat_box(COLOR_READY))
	button.add_theme_stylebox_override("hover", _flat_box(COLOR_READY_HOVER))
	button.add_theme_stylebox_override("pressed", _flat_box(COLOR_READY_PRESSED))
	button.tooltip_text = _effect_text(skill)
	button.pressed.connect(func() -> void: activate_requested.emit(skill.id))
	_buttons_box.add_child(button)
	_rows.append({"skill": skill, "button": button, "key": -1})


func _draw_button(button: Button, skill: Skill, state: Skill.State, seconds: int) -> void:
	match state:
		Skill.State.READY:
			button.disabled = false
			button.text = "%s\n%s" % [skill.display_name, tr("Prêt")]
		Skill.State.ACTIVE:
			button.disabled = true
			button.add_theme_stylebox_override("disabled", _flat_box(COLOR_ACTIVE))
			button.add_theme_color_override("font_disabled_color", COLOR_TEXT_ACTIVE)
			button.text = "%s\n%s" % [skill.display_name, tr("Actif : %d s") % seconds]
		Skill.State.COOLDOWN:
			button.disabled = true
			button.add_theme_stylebox_override("disabled", _flat_box(COLOR_COOLDOWN))
			button.add_theme_color_override("font_disabled_color", COLOR_TEXT_COOLDOWN)
			button.text = "%s\n%s" % [skill.display_name, tr("Recharge : %d s") % seconds]


func _draw_buffs() -> void:
	var lines: PackedStringArray = PackedStringArray()
	for row: Dictionary in _rows:
		var skill: Skill = row["skill"]
		if skill.state() == Skill.State.ACTIVE:
			lines.append(tr("%s ×%s : %d s") % [skill.display_name, _amount_shown(skill), _seconds_shown(skill, Skill.State.ACTIVE)])
	_buff_label.text = "\n".join(lines)
	_buff_label.visible = not lines.is_empty()


# Whole seconds the player reads, rounded up so a timer never shows 0 before the end.
func _seconds_shown(skill: Skill, state: Skill.State) -> int:
	match state:
		Skill.State.ACTIVE:
			return ceili(skill.active_left())
		Skill.State.COOLDOWN:
			return ceili(skill.cooldown_left())
	return 0


func _effect_text(skill: Skill) -> String:
	if skill.effect == Skill.Effect.BURST:
		return tr("Dégâts immédiats : %s secondes de dégâts (compagnons + un clic).\nRecharge : %d s") % [_amount_shown(skill), int(skill.cooldown_seconds)]
	var what: String = tr("Dégâts") if skill.effect == Skill.Effect.DAMAGE_MULTIPLIER else tr("Or gagné")
	return tr("%s ×%s pendant %d s.\nRecharge : %d s") % [what, _amount_shown(skill), int(skill.duration_seconds), int(skill.cooldown_seconds)]


# The data holds decimal strings such as "1.5"; the player reads a French comma.
func _amount_shown(skill: Skill) -> String:
	return skill.amount.replace(".", ",")


func _flat_box(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(6)
	return box
