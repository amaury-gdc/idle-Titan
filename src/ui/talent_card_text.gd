class_name TalentCardText
extends RefCounted
## The French texts of the talent tree (story 019, design/talent-tree-v2.md "Interface"): the short
## effect of a tile, the lines of a node card (effect, total before → after, "Exclut X", what a
## passive cancels), the state of a node in words, the tier headers and the refusal of a reset. Pure
## text: reads a [TalentTree] and, when given, a [SkillManager] for the names and current values of
## the skills; changes nothing. Every state is a word, so color is never the only signal.
##
## Usage:
## [codeblock]
## var text: TalentCardText = TalentCardText.new(tree, skills, 12.0)
## label.text = text.effect_short(tree.node("click_grip"))      # "Clic +8 %"
## card.text = "\n".join(text.card_lines(tree.node("click_grip")))
## [/codeblock]

## Rarity ids of items.json and their names, for the loot weight effect.
const RARITY_NAMES: Dictionary = {"common": "Commun", "rare": "Rare", "legendary": "Légendaire"}

var _tree: TalentTree
var _skills: SkillManager
var _offline_base_hours: float


## [param skills] may be null (the skill ids are then shown); [param offline_base_hours] is the offline
## cap of the data without talents, the "before" of "Longue veille".
func _init(tree: TalentTree, skills: SkillManager = null, offline_base_hours: float = 0.0) -> void:
	_tree = tree
	_skills = skills
	_offline_base_hours = offline_base_hours


## The effects of [param def] in a few words, one per line, for its tile.
func effect_short(def: TalentTree.TalentDef) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for effect: Dictionary in def.effects:
		lines.append(_effect_line(effect))
	return "\n".join(lines)


## The lines of the card of [param def]: its effects, each total before → after, "Exclut X" for a node
## of an exclusive group, what a passive cancels, then its state.
func card_lines(def: TalentTree.TalentDef) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for effect: Dictionary in def.effects:
		lines.append(_effect_line(effect))
		var change: String = _before_after(effect, def)
		if not change.is_empty():
			lines.append(change)
		if effect["type"] == TalentTree.EFFECT_SKILL_PASSIVE:
			var cancelled: String = _cancelled_text(effect["skill"])
			if not cancelled.is_empty():
				lines.append(cancelled)
		if effect["type"] == TalentTree.EFFECT_RHYTHM:
			lines.append(tr("%s s au moins entre deux.") % _number(float(effect["min_gap_seconds"])))
	var excludes: String = excludes_text(def)
	if not excludes.is_empty():
		lines.append(excludes)
	lines.append(state_text(def, true))
	# The card always gives the cost; these two states do not say it.
	var state: TalentTree.NodeState = _tree.state_of(def.id)
	if state == TalentTree.NodeState.TIER_CLOSED or state == TalentTree.NodeState.EXCLUDED:
		lines.append(cost_text(def.cost))
	if _tree.version_notice_due():
		lines.append(tr("Ferme d'abord le message du nouvel arbre pour acheter."))
	return lines


## "Exclut X" (and "et Y") for a node of an exclusive group, "" otherwise.
func excludes_text(def: TalentTree.TalentDef) -> String:
	if def.exclusive_group.is_empty():
		return ""
	var names: PackedStringArray = PackedStringArray()
	for other: TalentTree.TalentDef in _tree.nodes():
		if other.exclusive_group == def.exclusive_group and other.id != def.id:
			names.append(tr(other.display_name))
	return tr("Exclut %s") % _and_list(names)


## The state of [param def] in words: Acheté, Coût, Manque, Palier fermé, Requiert, Exclu. The card
## ([param long]) says more than the tile.
func state_text(def: TalentTree.TalentDef, long: bool = false) -> String:
	match _tree.state_of(def.id):
		TalentTree.NodeState.OWNED:
			return tr("Acheté")
		TalentTree.NodeState.BUYABLE:
			return cost_text(def.cost)
		TalentTree.NodeState.UNAFFORDABLE:
			return tr("%s, manque %s") % [cost_text(def.cost), points_text(def.cost - _tree.available_points())]
		TalentTree.NodeState.LOCKED:
			return "%s\n%s" % [requires_text(def), cost_text(def.cost)] if long else requires_text(def)
		TalentTree.NodeState.TIER_CLOSED:
			if not long:
				return tr("Palier fermé")
			var missing: int = _tree.tier_thresholds()[def.tier - 1] - _tree.spent_in_branch(def.branch)
			return tr("Palier fermé : dépense encore %s dans cette branche.") % points_text(missing)
		TalentTree.NodeState.EXCLUDED:
			return tr("Exclu : %s est acheté") % _owned_rival(def) if long else tr("Exclu")
	return ""


## "Coût : 1 pt" or "Coût : 3 pts".
func cost_text(cost: int) -> String:
	return tr("Coût : %s") % points_text(cost)


## "1 pt" or "3 pts".
func points_text(points: int) -> String:
	return tr("%d pt") % points if points == 1 else tr("%d pts") % points


## What [param def] requires; all of them, hence "et".
func requires_text(def: TalentTree.TalentDef) -> String:
	var names: PackedStringArray = PackedStringArray()
	for id: String in def.requires:
		names.append(tr(_tree.node(id).display_name))
	return tr("Requiert : %s") % _and_list(names)


## "Palier 3 : 4 / 8 points" while the tier is closed, "Palier 3 : Ouvert" once it is open.
func tier_header(branch_id: String, tier: int) -> String:
	if _tree.tier_open(branch_id, tier):
		return tr("Palier %d : Ouvert") % tier
	var spent: int = _tree.spent_in_branch(branch_id)
	var threshold: int = _tree.tier_thresholds()[tier - 1]
	var word: String = tr("point") if threshold < 2 else tr("points")
	return tr("Palier %d : %d / %d %s") % [tier, spent, threshold, word]


## "Palier 3", the left part of a tier header.
func tier_name(tier: int) -> String:
	return tr("Palier %d") % tier


## "Ouvert" once the tier is open, else "4 / 8 points", the points spent in the branch against its
## threshold: the right part of a tier header (story 019b).
func tier_progress(branch_id: String, tier: int) -> String:
	if _tree.tier_open(branch_id, tier):
		return tr("Ouvert")
	var threshold: int = _tree.tier_thresholds()[tier - 1]
	var word: String = tr("point") if threshold < 2 else tr("points")
	return tr("%d / %d %s") % [_tree.spent_in_branch(branch_id), threshold, word]


## The state line of the tile of [param def]: [method state_text], with the real cost after it when
## the state does not say it (a closed tier, a missing prerequisite). An excluded node is never
## bought, so it shows none.
func tile_state_text(def: TalentTree.TalentDef) -> String:
	var state: String = state_text(def)
	match _tree.state_of(def.id):
		TalentTree.NodeState.LOCKED, TalentTree.NodeState.TIER_CLOSED:
			return "%s · %s" % [state, points_text(def.cost)]
	return state


## Why [method TalentTree.try_reset] refuses at Unix time [param now_unix], in French; "" when it would not.
static func reset_refusal_text(tree: TalentTree, now_unix: int, in_boss_fight: bool) -> String:
	if tree.version_notice_due():
		return TranslationServer.translate("Ferme d'abord le message du nouvel arbre.")
	match tree.reset_block(now_unix, in_boss_fight):
		TalentTree.ResetBlock.BOSS:
			return TranslationServer.translate("Impossible pendant un combat de boss : réessaie après le combat.")
		TalentTree.ResetBlock.COOLDOWN:
			return TranslationServer.translate("Prochaine réinitialisation possible dans %s.") % clock_text(tree.reset_seconds_left(now_unix))
	if tree.spent_points() <= 0:
		return TranslationServer.translate("Aucun talent à réinitialiser.")
	return ""


## [param seconds] as minutes:seconds, "59:05" (one hour is "60:00").
static func clock_text(seconds: int) -> String:
	@warning_ignore("integer_division")
	return "%02d:%02d" % [seconds / 60, seconds % 60]


func _effect_line(effect: Dictionary) -> String:
	match effect["type"]:
		TalentTree.EFFECT_STAT:
			return _stat_line(effect["stat"], int(effect["percent"]))
		TalentTree.EFFECT_SKILL_UNLOCK:
			return tr("Débloque %s") % _skill_name(effect["skill"])
		TalentTree.EFFECT_SKILL_MOD:
			return "%s : %s" % [_skill_name(effect["skill"]), _skill_value(effect["skill"], effect["field"], effect["value"])]
		TalentTree.EFFECT_SKILL_PASSIVE:
			return tr("%s passive ×%s, bouton « Passif »") % [_skill_name(effect["skill"]), _decimal(effect["multiplier"])]
		TalentTree.EFFECT_RHYTHM:
			return tr("Tous les %d clics, %s gratuit de %s s") % [int(effect["clicks"]), _skill_name("big_hit"), _decimal(effect["dps_seconds"])]
		TalentTree.EFFECT_BOSS_TIMER:
			return tr("Chrono de boss +%s s") % _number(float(effect["seconds"]))
		TalentTree.EFFECT_OFFLINE_CAP:
			return tr("Plafond hors-ligne : %s h") % _number(float(effect["hours"]))
		TalentTree.EFFECT_SYNERGY:
			return tr("+%d %% par compagnon au niveau %d, %d %% au plus") % [int(effect["percent_per_companion"]), int(effect["level"]), int(effect["max_percent"])]
		TalentTree.EFFECT_CHAMPION:
			return tr("Compagnon le plus puissant +%d %%") % int(effect["percent"])
		TalentTree.EFFECT_LOOT_SHIFT:
			return tr("%d points de poids passent de %s à %s") % [int(effect["weight"]), _rarity(effect["from"]), _rarity(effect["to"])]
	return ""


func _stat_line(stat: String, value: int) -> String:
	match stat:
		TalentTree.STAT_CLICK_DAMAGE:
			return tr("Clic +%d %%") % value
		TalentTree.STAT_COMPANION_DAMAGE:
			return tr("Compagnons +%d %%") % value
		TalentTree.STAT_OFFLINE_GOLD:
			return tr("Or hors-ligne +%d %%") % value
		TalentTree.STAT_BOSS_DAMAGE:
			return tr("Dégâts sur boss +%d %%") % value
		TalentTree.STAT_CRIT_CHANCE:
			return tr("%d %% de critique sur clic") % value
		TalentTree.STAT_CLICK_SHARE:
			return tr("Part des compagnons dans le clic ×%s") % _decimal(TalentTree.factor_from_percent(value).rstrip("0").rstrip("."))
		TalentTree.STAT_ATTACK_SPEED:
			return tr("Vitesse d'attaque +%d %%") % value
		TalentTree.STAT_COST_DISCOUNT:
			return tr("Coûts de niveau -%d %%, éveil exclu") % value
		TalentTree.STAT_FARM_GOLD:
			return tr("Or en mode farm +%d %%") % value
	return tr("Or +%d %%") % value


# "Total des talents : de +8 % à +23 %" and the like (no arrow: the font has no glyph for it); "" when there is nothing to compare.
func _before_after(effect: Dictionary, def: TalentTree.TalentDef) -> String:
	var owned: bool = _tree.is_owned(def.id)
	match effect["type"]:
		TalentTree.EFFECT_STAT:
			var now: int = _tree.percent(effect["stat"])
			var before: int = now - int(effect["percent"]) if owned else now
			return tr("Total des talents : de +%d %% à +%d %%") % [before, before + int(effect["percent"])]
		TalentTree.EFFECT_SKILL_UNLOCK:
			return tr("%s : devient disponible") % _skill_name(effect["skill"])
		TalentTree.EFFECT_SKILL_MOD:
			var skill: Skill = _skill(effect["skill"])
			if skill == null or owned:
				return ""
			var current: Variant = _current_skill_value(skill, effect["field"])
			return tr("Avant : %s. Après : %s.") % [_skill_value(skill.id, effect["field"], current), _skill_value(skill.id, effect["field"], effect["value"])]
		TalentTree.EFFECT_SKILL_PASSIVE:
			var skill: Skill = _skill(effect["skill"])
			if skill == null or owned:
				return ""
			return tr("Avant : ×%s pendant %d s. Après : ×%s en permanence.") % [
					_decimal(_skills.effective_amount(skill)), int(_skills.effective_duration(skill)), _decimal(effect["multiplier"])]
		TalentTree.EFFECT_RHYTHM:
			var rhythm: Dictionary = _tree.rhythm()
			var before_text: String = tr("aucun rythme") if rhythm.is_empty() or owned else tr("tous les %d clics") % int(rhythm["clicks"])
			return tr("Avant : %s. Après : tous les %d clics.") % [before_text, int(effect["clicks"])]
		TalentTree.EFFECT_BOSS_TIMER:
			var seconds: float = _tree.boss_timer_bonus_seconds() - (float(effect["seconds"]) if owned else 0.0)
			return tr("Chrono de boss : de +%s s à +%s s") % [_number(seconds), _number(seconds + float(effect["seconds"]))]
		TalentTree.EFFECT_OFFLINE_CAP:
			if _offline_base_hours <= 0.0 or owned:
				return ""
			var hours: float = maxf(_offline_base_hours, _tree.offline_cap_hours())
			return tr("Plafond hors-ligne : de %s h à %s h") % [_number(hours), _number(maxf(hours, float(effect["hours"])))]
		TalentTree.EFFECT_CHAMPION:
			var percent: int = _tree.champion_percent() - (int(effect["percent"]) if owned else 0)
			return tr("Compagnon le plus puissant : de +%d %% à +%d %%") % [percent, percent + int(effect["percent"])]
	return ""


# "Annule Frénésie durable et Frénésie ardente." for a passive: the skill_mod of its skill stop counting.
func _cancelled_text(skill_id: String) -> String:
	var names: PackedStringArray = PackedStringArray()
	for other: TalentTree.TalentDef in _tree.nodes():
		for effect: Dictionary in other.effects:
			if effect["type"] == TalentTree.EFFECT_SKILL_MOD and effect["skill"] == skill_id and not names.has(tr(other.display_name)):
				names.append(tr(other.display_name))
	if names.is_empty():
		return ""
	return tr("Annule %s.") % _and_list(names)


func _owned_rival(def: TalentTree.TalentDef) -> String:
	for other: TalentTree.TalentDef in _tree.nodes():
		if other.exclusive_group == def.exclusive_group and other.id != def.id and _tree.is_owned(other.id):
			return tr(other.display_name)
	return ""


func _skill(skill_id: String) -> Skill:
	return null if _skills == null else _skills.skill(skill_id)


func _skill_name(skill_id: String) -> String:
	var skill: Skill = _skill(skill_id)
	return skill_id if skill == null else tr(skill.display_name)


func _current_skill_value(skill: Skill, field: String) -> Variant:
	match field:
		TalentTree.SKILL_AMOUNT:
			return _skills.effective_amount(skill)
		TalentTree.SKILL_DURATION:
			return _skills.effective_duration(skill)
	return _skills.effective_cooldown(skill)


# A value of a skill field in words: "8 s de dégâts" or "×1,75" for the amount, "20 s", "recharge 40 s".
func _skill_value(skill_id: String, field: String, value: Variant) -> String:
	match field:
		TalentTree.SKILL_AMOUNT:
			var skill: Skill = _skill(skill_id)
			if skill != null and skill.effect == Skill.Effect.BURST:
				return tr("%s s de dégâts") % _decimal(String(value))
			return "×%s" % _decimal(String(value))
		TalentTree.SKILL_DURATION:
			return tr("%s s") % _number(float(value))
	return tr("recharge %s s") % _number(float(value))


func _rarity(id: String) -> String:
	return tr(RARITY_NAMES.get(id, id))


# "X", "X et Y", "X, Y et Z".
func _and_list(names: PackedStringArray) -> String:
	if names.size() < 2:
		return ", ".join(names)
	return tr("%s et %s") % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


# The data holds decimal strings such as "1.5"; the player reads a French comma.
func _decimal(value: String) -> String:
	return value.replace(".", ",")


# 5.0 reads "5", 1.5 reads "1,5".
func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return _decimal(str(snappedf(value, 0.01)))
