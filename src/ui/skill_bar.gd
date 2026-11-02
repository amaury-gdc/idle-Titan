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
## Talents (story 019): the three buttons always stay in place, so that the keys 1/2/3 never move.
## A skill the talents lock reads "À débloquer"; its button stays usable and reports
## [signal unlock_requested], to open the card of the node that unlocks it. A passive skill
## ("Instinct de meute") reads "Passif" and cannot be pressed. Durations and cooldowns are the
## values the talents give ([method SkillManager.effective_duration] and the like).
##
## Usage:
## [codeblock]
## bar.activate_requested.connect(func(id: String) -> void: skills.activate(id))
## bar.unlock_requested.connect(func(id: String) -> void: open_talent_card_of(id))
## bar.setup(skills)     # builds one button per skill
## bar.refresh()         # every frame, and right after an activation
## [/codeblock]

## The player pressed the button of skill [param id].
signal activate_requested(id: String)
## The player touched the button of the locked skill [param id].
signal unlock_requested(id: String)

## Keys of the drawn state of a locked and of a passive skill, past every [enum Skill.State].
const KEY_LOCKED: int = 100_000_000
const KEY_PASSIVE: int = 200_000_000

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
## [method SkillManager.talent_version] the hints were last built for.
var _drawn_talent_version: int = -1

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
	var talents_moved: bool = _skills.talent_version() != _drawn_talent_version
	_drawn_talent_version = _skills.talent_version()
	for row: Dictionary in _rows:
		var skill: Skill = row["skill"]
		var state: Skill.State = skill.state()
		var seconds: int = _seconds_shown(skill, state)
		var key: int = int(state) * 1_000_000 + seconds
		if not _skills.is_unlocked(skill.id):
			key = KEY_LOCKED
		elif _skills.is_passive(skill.id):
			key = KEY_PASSIVE
		# The hint only changes with the kind of button or the talents, not with the seconds.
		var kind: int = key if key >= KEY_LOCKED else 0
		if talents_moved or kind != row["kind"]:
			row["kind"] = kind
			(row["button"] as Button).tooltip_text = _effect_text(skill)
		if key == row["key"]:
			continue
		changed = true
		row["key"] = key
		match key:
			KEY_LOCKED:
				_draw_locked(row["button"], skill)
			KEY_PASSIVE:
				_draw_passive(row["button"], skill)
			_:
				_draw_button(row["button"], skill, state, seconds)
	if changed:
		_draw_buffs()


## The button of the skill [param id], null for an unknown id.
func button_of(id: String) -> Button:
	for row: Dictionary in _rows:
		if (row["skill"] as Skill).id == id:
			return row["button"]
	return null


## What the hint bubble says for the skill [param id]: its effect, and for a locked one where to
## unlock it.
func hint_text(id: String) -> String:
	for row: Dictionary in _rows:
		if (row["skill"] as Skill).id == id:
			return _effect_text(row["skill"])
	return ""


func _add_row(skill: Skill) -> void:
	var button: Button = Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_size_button(button)
	button.pressed.connect(_on_button_pressed.bind(skill.id))
	_buttons_box.add_child(button)
	_rows.append({"skill": skill, "button": button, "key": -1, "kind": -1})


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


# Stays enabled: a touch opens the card of the node that unlocks it.
func _draw_locked(button: Button, skill: Skill) -> void:
	button.disabled = false
	button.theme_type_variation = &""
	button.text = "%s\n%s" % [skill.display_name, tr("À débloquer")]


func _draw_passive(button: Button, skill: Skill) -> void:
	button.disabled = true
	button.theme_type_variation = &"SkillActive"
	button.text = "%s\n%s" % [skill.display_name, tr("Passif")]


func _on_button_pressed(id: String) -> void:
	if not _skills.is_unlocked(id):
		unlock_requested.emit(id)
	else:
		activate_requested.emit(id)


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
	var text: String = ""
	var cooldown: int = int(_skills.effective_cooldown(skill))
	if skill.effect == Skill.Effect.BURST:
		text = tr("Dégâts immédiats : %s secondes de dégâts (compagnons + un clic).\nRecharge : %d s") % [_amount_shown(skill), cooldown]
	else:
		var what: String = tr("Dégâts") if skill.effect == Skill.Effect.DAMAGE_MULTIPLIER else tr("Or gagné")
		if _skills.is_passive(skill.id):
			text = tr("%s ×%s en permanence : passif, rien à appuyer.") % [what, _amount_shown(skill)]
		else:
			text = tr("%s ×%s pendant %d s.\nRecharge : %d s") % [what, _amount_shown(skill), int(_skills.effective_duration(skill)), cooldown]
	if not _skills.is_unlocked(skill.id):
		text += "\n" + tr("À débloquer dans l'onglet Talents.")
	return text


# The data holds decimal strings such as "1.5"; the player reads a French comma.
func _amount_shown(skill: Skill) -> String:
	return _skills.effective_amount(skill).replace(".", ",")
