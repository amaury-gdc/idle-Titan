extends GdUnitTestSuite
## Unit tests for the wiring of the talents in the main screen (story 019): the reset goes through
## TalentTree.try_reset with the boss fight of the FloorManager, never the old reset(); a key on a
## locked or passive skill shows the hint bubble and leaves the tabs alone. The main screen script
## runs without its scene: only the parts these handlers read are given to it.
## Story: production/epics/idle-titans/story-019-talent-tree-content.md

const MAIN_SCRIPT: String = "res://src/ui/main_screen.gd"
const TALENT_SCENE: String = "res://src/ui/talent_screen.tscn"
const SKILL_BAR_SCENE: String = "res://src/ui/skill_bar.tscn"
const SAVE_SCENE: String = "res://src/ui/save_screen.tscn"
const STAGE_WITH_POINTS: int = 50
const TREE_VERSION: int = 1
## A phone of 320x568 CSS px, in units.
const PHONE_VIEW: Vector2 = Vector2(363, 645)

var _state: GameState
var _permanent: PermanentState
var _floors: FloorManager
var _tree: TalentTree
var _skills: SkillManager
var _main: Control
var _root: Control
var _talent_screen: TalentScreen
var _skill_bar: SkillBar
var _bubble: HintBubble


func before_test() -> void:
	var curves: Variant = DataLoader.load_json("res://assets/data/core_curves.json")
	var combat: Combat = Combat.from_data(curves, DataLoader.load_json("res://assets/data/companions_roster.json"))
	var boss: BossFight = BossFight.from_data(DataLoader.load_json("res://assets/data/boss_curves.json"))
	_state = GameState.new()
	_permanent = PermanentState.new()
	_permanent.talent_tree_seen = TREE_VERSION
	# The stage before the first boss, in farm mode: challenge_boss starts the fight.
	var stage: int = 1
	while not boss.is_boss_stage(stage + 1):
		stage += 1
	_state.stage = stage
	_state.max_stage_reached = STAGE_WITH_POINTS
	_state.farming = true
	_floors = FloorManager.new(_state, combat, boss, _permanent)
	_tree = TalentTree.from_data(DataLoader.load_json("res://assets/data/talents.json"), _permanent, _state)
	assert_str(_tree.get_error()).is_empty()
	var hub: ModifierHub = ModifierHub.new(_floors, OfflineIncome.from_data(curves, combat), _tree, null)
	_skills = SkillManager.from_data(DataLoader.load_json("res://assets/data/skills.json"), _state, combat, _floors, hub)
	assert_str(_skills.get_error()).is_empty()
	# Out of the tree: its _ready would build the whole game. Its parts live under _root.
	_main = auto_free((load(MAIN_SCRIPT) as GDScript).new())
	_root = auto_free(Control.new())
	_root.size = Vector2(400, 800)
	add_child(_root)
	_talent_screen = (load(TALENT_SCENE) as PackedScene).instantiate()
	_talent_screen.visible = true
	_talent_screen.size = Vector2(348, 600)
	_root.add_child(_talent_screen)
	_talent_screen.setup(_tree)
	_main.set("_talents", _tree)
	_main.set("_floors", _floors)
	_main.set("_skills", _skills)
	_main.set("_talent_screen", _talent_screen)


func _give_bar_and_bubble() -> void:
	_skill_bar = (load(SKILL_BAR_SCENE) as PackedScene).instantiate()
	_root.add_child(_skill_bar)
	_skill_bar.setup(_skills)
	_bubble = HintBubble.new()
	var label: Label = Label.new()
	label.name = "Label"
	_bubble.add_child(label)
	_bubble.visible = false
	_root.add_child(_bubble)
	var offline_panel: PanelContainer = PanelContainer.new()
	offline_panel.visible = false
	_root.add_child(offline_panel)
	var save_screen: Control = (load(SAVE_SCENE) as PackedScene).instantiate()
	save_screen.visible = false
	_root.add_child(save_screen)
	_main.set("_skill_bar", _skill_bar)
	_main.set("_bubble", _bubble)
	_main.set("_offline_panel", offline_panel)
	_main.set("_save_screen", save_screen)


# Version message (criterion: "le message de version")

# The window as main_screen.tscn builds it: panel > scroll (follows the focus) > column of title,
# message and Continuer, with the same sizes. The view is a phone of 320x568 CSS px (363x645 units).
func _give_message_window() -> Dictionary:
	_give_bar_and_bubble()
	_root.size = PHONE_VIEW
	_main.size = PHONE_VIEW
	var panel: PanelContainer = _main.get("_offline_panel")
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)
	var parts: Dictionary = {"blocker": ColorRect.new(), "title": Label.new(), "message": Label.new(), "close": Button.new(), "scroll": scroll}
	_root.add_child(parts["blocker"])
	(parts["title"] as Label).add_theme_font_size_override("font_size", 32)
	(parts["message"] as Label).add_theme_font_size_override("font_size", 20)
	for label: Label in [parts["title"], parts["message"]]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	var close: Button = parts["close"]
	close.custom_minimum_size = Vector2(220, 52)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 24)
	close.text = "Continuer"
	column.add_child(close)
	_main.call("_fit_overlays")
	_main.set("_offline_blocker", parts["blocker"])
	_main.set("_offline_title", parts["title"])
	_main.set("_offline_message", parts["message"])
	_main.set("_offline_close_button", parts["close"])
	return parts


func test_version_message_opens_with_the_refund_and_blocks_purchases() -> void:
	# Arrange: a save of the old tree with a node bought
	_permanent.talent_tree_seen = 0
	_permanent.talents = {"click_grip": 1}
	var parts: Dictionary = _give_message_window()

	# Act: what _ready does after the offline grant
	assert_bool(_tree.apply_tree_version()).is_true()
	_main.call("_show_version_notice")

	# Assert
	assert_bool((_main.get("_offline_panel") as Control).visible).is_true()
	assert_str((parts["title"] as Label).text).is_equal("Nouvel arbre de talents")
	assert_str((parts["message"] as Label).text).is_equal("L'arbre de talents a changé : tous tes points te sont rendus. Les bonus de tes anciens talents sont retirés jusqu'à tes prochains achats.")
	assert_dict(_permanent.talents).is_empty()
	assert_bool(_tree.can_buy("click_grip")).is_false()


func test_version_window_opens_at_its_title_with_continuer_whole_on_a_phone() -> void:
	# Arrange
	_permanent.talent_tree_seen = 0
	_permanent.talents = {"click_grip": 1}
	var parts: Dictionary = _give_message_window()
	_tree.apply_tree_version()

	# Act
	_main.call("_show_version_notice")
	for i in 4:
		await await_idle_frame()

	# Assert: the title and the whole button inside the panel, nothing scrolled, focus on Continuer
	var panel: Rect2 = (_main.get("_offline_panel") as Control).get_global_rect()
	var view: Rect2 = Rect2(_root.global_position, PHONE_VIEW)
	assert_int((parts["scroll"] as ScrollContainer).scroll_vertical).is_equal(0)
	assert_bool(panel.encloses((parts["title"] as Control).get_global_rect())).is_true()
	assert_bool(panel.encloses((parts["close"] as Control).get_global_rect())).is_true()
	assert_bool(view.encloses(panel)).is_true()
	assert_bool((parts["close"] as Control).has_focus()).is_true()


func test_closing_the_version_message_acknowledges_it_and_allows_purchases() -> void:
	# Arrange
	_permanent.talent_tree_seen = 0
	_permanent.talents = {"click_grip": 1}
	_give_message_window()
	_tree.apply_tree_version()
	_main.call("_show_version_notice")

	# Act
	var show_again: bool = _main.call("_close_talent_notice")

	# Assert
	assert_bool(show_again).is_false()
	assert_bool(_tree.version_notice_due()).is_false()
	assert_bool(_tree.can_buy("click_grip")).is_true()


func test_closing_the_return_message_brings_the_version_message_next() -> void:
	# Arrange: a refunded save whose version message was not shown yet (the return message came first)
	_permanent.talent_tree_seen = 0
	_permanent.talents = {"click_grip": 1}
	_tree.apply_tree_version()

	# Act
	var show_next: bool = _main.call("_close_talent_notice")

	# Assert: still due, nothing acknowledged
	assert_bool(show_next).is_true()
	assert_bool(_tree.version_notice_due()).is_true()


# Reset through the screen (criterion: "test qui échoue si l'écran rappelle l'ancien reset")

func test_reset_through_the_screen_during_a_boss_fight_keeps_the_talents() -> void:
	# Arrange: a bought node, then a boss fight
	assert_bool(_tree.buy("click_grip")).is_true()
	assert_bool(_floors.challenge_boss()).is_true()
	assert_bool(_floors.is_boss_fight()).is_true()

	# Act
	_main.call("_on_talent_reset_requested")

	# Assert: the old reset() would have removed it
	assert_bool(_tree.is_owned("click_grip")).is_true()
	assert_int(_talent_screen.detail()).is_equal(TalentScreen.Detail.RESET)
	assert_str(_talent_screen._detail_status.text).is_equal("Impossible pendant un combat de boss : réessaie après le combat.")
	assert_bool(_talent_screen._action_button.visible).is_false()


func test_reset_through_the_screen_in_the_wait_keeps_the_talents_and_says_mm_ss() -> void:
	# Arrange: a reset a few seconds ago, then a new purchase
	_permanent.talent_reset_unix = int(Time.get_unix_time_from_system()) - 5
	assert_bool(_tree.buy("click_grip")).is_true()

	# Act
	_main.call("_on_talent_reset_requested")

	# Assert
	assert_bool(_tree.is_owned("click_grip")).is_true()
	assert_str(_talent_screen._detail_status.text).starts_with("Prochaine réinitialisation possible dans 59:")


func test_reset_through_the_screen_outside_a_fight_removes_the_talents_and_starts_the_wait() -> void:
	# Arrange
	assert_bool(_tree.buy("click_grip")).is_true()

	# Act
	_main.call("_on_talent_reset_requested")

	# Assert: try_reset stamps the time, the old reset() did not
	assert_bool(_tree.is_owned("click_grip")).is_false()
	assert_int(_permanent.talent_reset_unix).is_greater(0)


# Keys 1/2/3 on a locked or passive skill (criterion: "la touche affiche une bulle")

func test_key_on_a_locked_skill_shows_the_bubble_and_activates_nothing() -> void:
	# Arrange: Frénésie (damage_buff) is locked until "frenzy_unlock" is bought
	_give_bar_and_bubble()
	assert_bool(_skills.is_unlocked("damage_buff")).is_false()

	# Act: no _tabs is given: a handler that changed the tab would fail here
	_main.call("_on_skill_key", "damage_buff")

	# Assert
	assert_bool(_bubble.is_showing_for(_skill_bar.button_of("damage_buff"))).is_true()
	assert_int(_skills.skill("damage_buff").state()).is_equal(Skill.State.READY)
	assert_str(_bubble.get_node("Label").text).contains("À débloquer dans l'onglet Talents.")


func test_key_on_an_unlocked_skill_activates_it_without_a_bubble() -> void:
	# Arrange
	_give_bar_and_bubble()

	# Act: Gros coup is acquired from the start
	_main.call("_on_skill_key", "big_hit")

	# Assert
	assert_bool(_bubble.visible).is_false()
	assert_int(_skills.skill("big_hit").state()).is_not_equal(Skill.State.READY)
