class_name SkillBar
extends VBoxContainer
## The three skill buttons (story 005): name, state (prêt / actif / en recharge) with the
## seconds left. Stacked in landscape, side by side in portrait ([method set_compact]). The line of
## running buffs stays built but hidden: the buttons already show "En cours : 12 s" (story 010).
## Stacked, the buttons share the height of the bar.
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
const FONT_SIZE_COMPACT: int = 16
const BUTTON_MIN_SIZE: Vector2 = Vector2(0, 62)
const BUTTON_MIN_SIZE_COMPACT: Vector2 = Vector2(0, 52)
## Space between the buttons. Side by side at 320 wide, three "En cours : 15 s" need all the room.
const SEPARATION: int = 8
const SEPARATION_COMPACT: int = 4

var _skills: SkillManager
## One entry per skill: {"skill": Skill, "button": Button, "key": int}. "key" is the last
## drawn (state, whole seconds shown), so unchanged buttons are not redrawn.
var _rows: Array[Dictionary] = []
var _compact: bool = false

@onready var _buttons_box: BoxContainer = %Buttons
@onready var _buff_label: Label = %BuffLabel


## Builds the buttons from [param skills] and draws them. Call once.
func setup(skills: SkillManager) -> void:
	_skills = skills
	for skill: Skill in skills.skills():
		_add_row(skill)
	refresh()


## Gives each button to [param bubble], for the long press and the keyboard focus. Call after
## [method setup].
func watch_with(bubble: HintBubble) -> void:
	for row: Dictionary in _rows:
		var skill: Skill = row["skill"]
		bubble.watch(row["button"], _effect_text.bind(skill))


## Side by side with short state texts when [param compact] (portrait), stacked otherwise. Can be
## called before [method setup].
func set_compact(compact: bool) -> void:
	_compact = compact
	_buttons_box.vertical = not compact
	_buttons_box.add_theme_constant_override("separation", SEPARATION_COMPACT if compact else SEPARATION)
	for row: Dictionary in _rows:
		_size_button(row["button"])
		row["key"] = -1
	if _skills != null:
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
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_size_button(button)
	button.tooltip_text = _effect_text(skill)
	button.pressed.connect(func() -> void: activate_requested.emit(skill.id))
	_buttons_box.add_child(button)
	_rows.append({"skill": skill, "button": button, "key": -1})


func _size_button(button: Button) -> void:
	button.custom_minimum_size = BUTTON_MIN_SIZE_COMPACT if _compact else BUTTON_MIN_SIZE
	button.add_theme_font_size_override("font_size", FONT_SIZE_COMPACT if _compact else FONT_SIZE_BUTTON)


func _draw_button(button: Button, skill: Skill, state: Skill.State, seconds: int) -> void:
	match state:
		Skill.State.READY:
			button.disabled = false
			button.theme_type_variation = &"BuyButton"
			button.text = "%s\n%s" % [skill.display_name, tr("Disponible")]
		Skill.State.ACTIVE:
			button.disabled = true
			button.theme_type_variation = &"SkillActive"
			button.text = "%s\n%s" % [skill.display_name, tr("En cours : %d s") % seconds]
		Skill.State.COOLDOWN:
			button.disabled = true
			button.theme_type_variation = &""
			button.text = "%s\n%s" % [skill.display_name, tr("Dans %d s") % seconds]


func _draw_buffs() -> void:
	var lines: PackedStringArray = PackedStringArray()
	for row: Dictionary in _rows:
		var skill: Skill = row["skill"]
		if skill.state() == Skill.State.ACTIVE:
			lines.append(tr("%s ×%s : %d s") % [skill.display_name, _amount_shown(skill), _seconds_shown(skill, Skill.State.ACTIVE)])
	_buff_label.text = "\n".join(lines)


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
