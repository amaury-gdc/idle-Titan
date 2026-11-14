extends GdUnitTestSuite
## Unit tests for the balance message in the main screen (story 020): its title and text, the
## acknowledgment on Continuer, and its place after the return message and the talent tree message.
## The main screen script runs without its scene: only the parts these handlers read are given.
## Story: production/epics/idle-titans/story-020-economy-calibration.md

const MAIN_SCRIPT: String = "res://src/ui/main_screen.gd"
const SAVE_SCENE: String = "res://src/ui/save_screen.tscn"
const CURVES: Dictionary = {"balance_version": 1, "balance_notice_min_stage": 150}
const RECORD_ABOVE: int = 215
const TREE_VERSION: int = 1

var _permanent: PermanentState
var _state: GameState
var _tree: TalentTree
var _notice: BalanceNotice
var _main: Control
var _root: Control
var _title: Label
var _message: Label
var _panel: PanelContainer
var _tabs: FakeTabs


## The tabs without their scene: only the focus the main screen hands back on close is recorded.
class FakeTabs extends ManagementTabs:
	var focus_given: bool = false

	func focus_active(_hidden: bool) -> void:
		focus_given = true


func before_test() -> void:
	_permanent = PermanentState.new()
	_permanent.talent_tree_seen = TREE_VERSION
	_state = GameState.new()
	_state.max_stage_reached = RECORD_ABOVE
	_tree = TalentTree.from_data(DataLoader.load_json("res://assets/data/talents.json"), _permanent, _state)
	assert_str(_tree.get_error()).is_empty()
	_notice = BalanceNotice.from_data(CURVES, _permanent)
	# Out of the tree: its _ready would build the whole game. Its parts live under _root.
	_main = auto_free((load(MAIN_SCRIPT) as GDScript).new())
	_root = auto_free(Control.new())
	_root.size = Vector2(400, 800)
	_main.size = Vector2(400, 800)
	add_child(_root)
	# The window as main_screen.tscn builds it: panel > scroll > column of title, message, Continuer.
	_panel = PanelContainer.new()
	_panel.visible = false
	_root.add_child(_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	_panel.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	scroll.add_child(column)
	_title = Label.new()
	_message = Label.new()
	var close: Button = Button.new()
	for part: Control in [_title, _message, close]:
		column.add_child(part)
	var blocker: ColorRect = ColorRect.new()
	_root.add_child(blocker)
	var bubble: HintBubble = HintBubble.new()
	var label: Label = Label.new()
	label.name = "Label"
	bubble.add_child(label)
	bubble.visible = false
	_root.add_child(bubble)
	var save_screen: Control = (load(SAVE_SCENE) as PackedScene).instantiate()
	save_screen.visible = false
	_root.add_child(save_screen)
	# Never in the tree: its _ready would look for its scene.
	_tabs = auto_free(FakeTabs.new())
	_main.set("_tabs", _tabs)
	_main.set("_talents", _tree)
	_main.set("_balance_notice", _notice)
	_main.set("_bubble", bubble)
	_main.set("_save_screen", save_screen)
	_main.set("_offline_panel", _panel)
	_main.set("_offline_blocker", blocker)
	_main.set("_offline_title", _title)
	_main.set("_offline_message", _message)
	_main.set("_offline_close_button", close)


func test_balance_message_opens_with_its_title_and_text() -> void:
	# Arrange: what _ready does after the load
	assert_bool(_notice.apply(_tree.best_stage())).is_true()

	# Act
	_main.call("_show_balance_notice")

	# Assert: a non-breaking space before the colon
	assert_bool(_panel.visible).is_true()
	assert_str(_title.text).is_equal("Équilibrage mis à jour")
	assert_str(_message.text).is_equal("L'équilibrage a changé : les monstres des étages élevés sont plus résistants. Tu ne perds rien.")
	assert_int(_permanent.balance_seen).is_equal(0)


func test_closing_the_balance_message_records_it_and_closes_the_window() -> void:
	# Arrange
	_notice.apply(_tree.best_stage())
	_main.call("_show_balance_notice")

	# Act: Continuer
	_main.call("_on_offline_closed")

	# Assert
	assert_int(_permanent.balance_seen).is_equal(1)
	assert_bool(_notice.is_due()).is_false()
	assert_bool(_panel.visible).is_false()
	assert_bool(_tabs.focus_given).is_true()


func test_closing_the_return_message_brings_the_balance_message_next() -> void:
	# Arrange: the return message is open, the balance message is due
	_notice.apply(_tree.best_stage())
	_panel.visible = true
	_title.text = "Bon retour !"

	# Act: Continuer on the return message
	_main.call("_on_offline_closed")

	# Assert: the window stays, with the balance message, not yet recorded
	assert_bool(_panel.visible).is_true()
	assert_str(_title.text).is_equal("Équilibrage mis à jour")
	assert_int(_permanent.balance_seen).is_equal(0)


func test_talent_tree_message_comes_before_the_balance_message() -> void:
	# Arrange: both due, the return message open
	_permanent.talent_tree_seen = 0
	_permanent.talents = {"click_grip": 1}
	_tree.apply_tree_version()
	_notice.apply(_tree.best_stage())
	_panel.visible = true

	# Act and assert: Continuer three times
	_main.call("_on_offline_closed")
	assert_str(_title.text).is_equal("Nouvel arbre de talents")
	_main.call("_on_offline_closed")
	assert_str(_title.text).is_equal("Équilibrage mis à jour")
	assert_bool(_tree.version_notice_due()).is_false()
	_main.call("_on_offline_closed")
	assert_bool(_panel.visible).is_false()
	assert_int(_permanent.balance_seen).is_equal(1)


func test_record_under_the_minimum_stage_shows_nothing_after_the_return_message() -> void:
	# Arrange: a record of 150 is not concerned
	_notice.apply(150)
	_panel.visible = true

	# Act
	_main.call("_on_offline_closed")

	# Assert
	assert_bool(_panel.visible).is_false()
	assert_int(_permanent.balance_seen).is_equal(1)
