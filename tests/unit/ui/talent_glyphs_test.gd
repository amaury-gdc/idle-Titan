extends GdUnitTestSuite
## Guard test for story 019: every character the Talents tab, its cards, tier headers, reset refusals
## and the skill bar can show exists in the font the game draws with (the theme has none of its own,
## so it is the default font). A missing glyph shows as a box in the export ("→" did).
## Story: production/epics/idle-titans/story-019-talent-tree-content.md

const SCENE: String = "res://src/ui/talent_screen.tscn"
const SKILL_BAR_SCENE: String = "res://src/ui/skill_bar.tscn"
const THEME: String = "res://src/ui/main_theme.tres"
const NOW: int = 1_000_000
## Saves that put the nodes of the real tree in every state, and the skills in every kind.
const SAVES: Array[Dictionary] = [
	{},
	{"click_grip": 1, "click_crit": 1, "click_ally": 1, "frenzy_unlock": 1, "frenzy_long": 1, "gold_unlock": 1},
	{"eco_purse": 1, "gold_unlock": 1, "economy_offline": 1, "eco_flair": 1, "eco_haggle": 1, "gold_cd": 1, "eco_top_rentier": 1,
			"frenzy_unlock": 1, "comp_top_instinct": 1, "click_rhythm": 1, "click_top_timer": 1, "eco_vigil": 1, "comp_top_champion": 1},
]

var _font: Font


func before_test() -> void:
	var theme: Theme = load(THEME)
	_font = theme.default_font if theme.default_font != null else ThemeDB.fallback_font


# Every character of [param texts] the font lacks, as "U+XXXX 'c' in: text".
func _missing(texts: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for text: String in texts:
		for i in text.length():
			var code: int = text.unicode_at(i)
			if code == 10:
				continue
			if not _font.has_char(code):
				var entry: String = "U+%04X '%s' in: %s" % [code, char(code), text]
				if not found.has(entry):
					found.append(entry)
	return found


func _texts_of(talents: Dictionary, stage: int, seen: int) -> PackedStringArray:
	var curves: Variant = DataLoader.load_json("res://assets/data/core_curves.json")
	var combat: Combat = Combat.from_data(curves, DataLoader.load_json("res://assets/data/companions_roster.json"))
	var state: GameState = GameState.new()
	state.max_stage_reached = stage
	var permanent: PermanentState = PermanentState.new()
	permanent.talent_tree_seen = seen
	permanent.talents = talents.duplicate()
	permanent.talent_reset_unix = NOW - 5
	var floors: FloorManager = FloorManager.new(state, combat)
	var tree: TalentTree = TalentTree.from_data(DataLoader.load_json("res://assets/data/talents.json"), permanent, state)
	var hub: ModifierHub = ModifierHub.new(floors, OfflineIncome.from_data(curves, combat), tree, null)
	var skills: SkillManager = SkillManager.from_data(DataLoader.load_json("res://assets/data/skills.json"), state, combat, floors, hub)
	var screen: TalentScreen = auto_free((load(SCENE) as PackedScene).instantiate())
	screen.visible = true
	add_child(screen)
	screen.set_context(skills, 12.0, func() -> int: return NOW, func() -> bool: return false)
	screen.size = Vector2(348, 600)
	screen.setup(tree)
	var texts: PackedStringArray = PackedStringArray()
	for button: Node in screen.find_children("*", "Button", true, false):
		texts.append((button as Button).text)
	for label: Node in screen.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	for def: TalentTree.TalentDef in tree.nodes():
		texts.append("\n".join(screen._text.card_lines(def)))
	for boss: bool in [true, false]:
		texts.append(TalentCardText.reset_refusal_text(tree, NOW, boss))
	screen._on_reset_pressed()
	texts.append_array([screen._detail_title.text, screen._detail_status.text, screen._action_button.text])
	var bar: SkillBar = auto_free((load(SKILL_BAR_SCENE) as PackedScene).instantiate())
	add_child(bar)
	bar.setup(skills)
	for skill: Skill in skills.skills():
		texts.append(bar.button_of(skill.id).accessibility_name)
		texts.append(bar.hint_text(skill.id))
	return texts


func test_every_text_of_the_talents_and_skills_has_its_glyphs_in_the_font() -> void:
	# Arrange: every save, with points to spare and none, the version message due or read
	var texts: PackedStringArray = PackedStringArray()
	for talents: Dictionary in SAVES:
		texts.append_array(_texts_of(talents, 200, 1))
		texts.append_array(_texts_of(talents, 5, 1))
	texts.append_array(_texts_of({}, 50, 0))

	# Act
	var missing: PackedStringArray = _missing(texts)

	# Assert
	assert_array(missing).override_failure_message("\n".join(missing)).is_empty()
