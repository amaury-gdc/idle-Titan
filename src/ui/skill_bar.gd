class_name SkillBar
extends VBoxContainer
## The skill row (story 005, rounds since story 019b): one [SkillOrb] per skill, side by side in
## portrait ([method set_compact]), stacked in the landscape column. Each round shows ready, running,
## recharging, locked or passive; the name and the effect are in the hint bubble (long press, focus)
## and the name and the state in the accessible name. The row is laid out for five rounds at 320 u.
## The line of running buffs stays built but hidden: the rounds already show the seconds (story 010).
## Pure presentation: it reads the [Skill] states of a [SkillManager], never changes them;
## a press is reported through [signal activate_requested] and the composition root
## forwards it. A press acts on the release, and not when the finger left the round first, nor
## after a long press (the bubble cancels it).
##
## Talents (story 019): the three rounds always stay in place, so that the keys 1/2/3 never move.
## A skill the talents lock shows a padlock; its round stays usable and reports
## [signal unlock_requested], to open the card of the node that unlocks it. A passive skill
## ("Instinct de meute") is grey, says "Passif" and cannot be pressed. Durations and cooldowns are the
## values the talents give ([method SkillManager.effective_duration] and the like).
##
## Usage:
## [codeblock]
## bar.activate_requested.connect(func(id: String) -> void: skills.activate(id))
## bar.unlock_requested.connect(func(id: String) -> void: open_talent_card_of(id))
## bar.setup(skills)     # builds one round per skill
## bar.refresh()         # every frame, and right after an activation
## [/codeblock]

## The player pressed the round of skill [param id].
signal activate_requested(id: String)
## The player touched the round of the locked skill [param id].
signal unlock_requested(id: String)

## Rounds the row is laid out for (spec): three today, five without a redesign.
const DESIGNED_SLOTS: int = 5
## Space between the rounds (display setting).
const SEPARATION: int = 8
const SEPARATION_COMPACT: int = 4

var _skills: SkillManager
## One entry per skill: {"skill": Skill, "button": SkillOrb, "words": String}. "words" is the last
## accessible state, so that the name is only rebuilt when the seconds change.
var _rows: Array[Dictionary] = []
var _compact: bool = false
## [method SkillManager.talent_version] the hints were last built for.
var _drawn_talent_version: int = -1

@onready var _buttons_box: BoxContainer = %Buttons
@onready var _buff_label: Label = %BuffLabel


## Builds the rounds from [param skills] and draws them. Call once.
func setup(skills: SkillManager) -> void:
	_skills = skills
	for skill: Skill in skills.skills():
		_add_row(skill)
	refresh()


## Gives each round to [param bubble], for the long press and the keyboard focus. Call after
## [method setup].
func watch_with(bubble: HintBubble) -> void:
	for row: Dictionary in _rows:
		var skill: Skill = row["skill"]
		bubble.watch(row["button"], _effect_text.bind(skill))


## Side by side when [param compact] (portrait), stacked otherwise. Can be called before
## [method setup].
func set_compact(compact: bool) -> void:
	_compact = compact
	_buttons_box.vertical = not compact
	_buttons_box.add_theme_constant_override("separation", SEPARATION_COMPACT if compact else SEPARATION)


## Redraws what changed since the last call: the rounds whose state, seconds or arc changed, and
## the list of running buffs.
func refresh() -> void:
	var changed: bool = false
	var talents_moved: bool = _skills.talent_version() != _drawn_talent_version
	_drawn_talent_version = _skills.talent_version()
	for row: Dictionary in _rows:
		var skill: Skill = row["skill"]
		var orb: SkillOrb = row["button"]
		var look: SkillOrb.Look = _look_of(skill)
		var seconds: int = _seconds_shown(skill, skill.state())
		if talents_moved or look != orb.look():
			orb.tooltip_text = _effect_text(skill)
		if not orb.show_state(look, seconds, _fraction(skill, look)):
			continue
		var words: String = state_words(look, seconds)
		if words == row["words"]:
			continue
		changed = true
		row["words"] = words
		orb.disabled = look == SkillOrb.Look.ACTIVE or look == SkillOrb.Look.COOLDOWN or look == SkillOrb.Look.PASSIVE
		orb.accessibility_name = "%s, %s" % [skill.display_name, words]
	if changed:
		_draw_buffs()


## The round of the skill [param id], null for an unknown id.
func button_of(id: String) -> Button:
	for row: Dictionary in _rows:
		if (row["skill"] as Skill).id == id:
			return row["button"]
	return null


## What the hint bubble says for the skill [param id]: its name, its effect, and for a locked one
## where to unlock it.
func hint_text(id: String) -> String:
	for row: Dictionary in _rows:
		if (row["skill"] as Skill).id == id:
			return _effect_text(row["skill"])
	return ""


## The state of a round in words, for its accessible name: the round itself shows no text but its
## seconds.
func state_words(look: SkillOrb.Look, seconds: int) -> String:
	match look:
		SkillOrb.Look.ACTIVE:
			return tr("En cours : %d s") % seconds
		SkillOrb.Look.COOLDOWN:
			return tr("Dans %d s") % seconds
		SkillOrb.Look.LOCKED:
			return tr("À débloquer")
		SkillOrb.Look.PASSIVE:
			return tr("Passif")
	return tr("Disponible")


## The icon of a skill of [param effect].
static func icon_of(effect: Skill.Effect) -> UiIcon.Kind:
	match effect:
		Skill.Effect.DAMAGE_MULTIPLIER:
			return UiIcon.Kind.BOLT
		Skill.Effect.BURST:
			return UiIcon.Kind.STAR
	return UiIcon.Kind.COIN


func _add_row(skill: Skill) -> void:
	var orb: SkillOrb = SkillOrb.new()
	orb.icon_kind = icon_of(skill.effect)
	orb.pressed.connect(_on_button_pressed.bind(skill.id))
	_buttons_box.add_child(orb)
	# A first state the refresh always changes: the words of a new row are empty.
	_rows.append({"skill": skill, "button": orb, "words": ""})
	orb.show_state(SkillOrb.Look.PASSIVE, -1, 0.0)


func _look_of(skill: Skill) -> SkillOrb.Look:
	if not _skills.is_unlocked(skill.id):
		return SkillOrb.Look.LOCKED
	if _skills.is_passive(skill.id):
		return SkillOrb.Look.PASSIVE
	match skill.state():
		Skill.State.ACTIVE:
			return SkillOrb.Look.ACTIVE
		Skill.State.COOLDOWN:
			return SkillOrb.Look.COOLDOWN
	return SkillOrb.Look.READY


# The ring: the time left of a running skill, the part of the cooldown already done.
func _fraction(skill: Skill, look: SkillOrb.Look) -> float:
	match look:
		SkillOrb.Look.ACTIVE:
			var duration: float = _skills.effective_duration(skill)
			return skill.active_left() / duration if duration > 0.0 else 0.0
		SkillOrb.Look.COOLDOWN:
			var cooldown: float = _skills.effective_cooldown(skill)
			return 1.0 - skill.cooldown_left() / cooldown if cooldown > 0.0 else 1.0
		SkillOrb.Look.READY:
			return 1.0
	return 0.0


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
	var text: String = skill.display_name + "\n"
	var cooldown: int = int(_skills.effective_cooldown(skill))
	if skill.effect == Skill.Effect.BURST:
		text += tr("Dégâts immédiats : %s secondes de dégâts (compagnons + un clic).\nRecharge : %d s") % [_amount_shown(skill), cooldown]
	else:
		var what: String = tr("Dégâts") if skill.effect == Skill.Effect.DAMAGE_MULTIPLIER else tr("Or gagné")
		if _skills.is_passive(skill.id):
			text += tr("Passif : %s ×%s en permanence, rien à appuyer.") % [what, _amount_shown(skill)]
		else:
			text += tr("%s ×%s pendant %d s.\nRecharge : %d s") % [what, _amount_shown(skill), int(_skills.effective_duration(skill)), cooldown]
	if not _skills.is_unlocked(skill.id):
		text += "\n" + tr("À débloquer dans l'onglet Talents.")
	return text


# The data holds decimal strings such as "1.5"; the player reads a French comma.
func _amount_shown(skill: Skill) -> String:
	return _skills.effective_amount(skill).replace(".", ",")
