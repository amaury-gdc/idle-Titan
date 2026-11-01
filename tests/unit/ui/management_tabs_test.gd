extends GdUnitTestSuite
## Unit tests for what a press on a tab does to the open content. The real scene without its script:
## the composition root would load saves, and only the tabs and their contents are under test.
## Story: production/epics/idle-titans/story-011-management-tabs.md.

const SCENE: String = "res://src/ui/main_screen.tscn"
const STAGES_PER_POINT: int = 5

var _tabs: ManagementTabs
var _talents: TalentScreen


func before_test() -> void:
	var root: Control = auto_free((load(SCENE) as PackedScene).instantiate())
	root.set_script(null)
	add_child(root)
	_tabs = root.find_child("ManagementTabs", true, false)
	_talents = root.find_child("TalentScreen", true, false)
	var state: GameState = GameState.new()
	state.stage = STAGES_PER_POINT
	state.max_stage_reached = STAGES_PER_POINT
	var tree: TalentTree = TalentTree.from_data({
		"schema_version": TalentTree.SUPPORTED_SCHEMA,
		"stages_per_point": STAGES_PER_POINT,
		"branches": [{"id": "one", "name": "Branche"}],
		"nodes": [{"id": "a", "branch": "one", "name": "Nom", "cost": 1, "requires": [],
				"effect": {"stat": TalentTree.STAT_CLICK_DAMAGE, "percent": 10}}],
	}, PermanentState.new(), state)
	tree.sync_best_stage()
	tree.buy("a")
	_talents.setup(tree)


func test_leaving_talents_closes_the_reset_confirmation() -> void:
	_tabs.select(ManagementTabs.Tab.TALENTS)
	_talents._reset_button.pressed.emit()
	_tabs._companions_button.pressed.emit()
	assert_bool(_talents.is_detail_open()).is_false()


func test_leaving_talents_keeps_a_node_detail_open() -> void:
	_tabs.select(ManagementTabs.Tab.TALENTS)
	_talents._button_of("a").pressed.emit()
	_tabs._inventory_button.pressed.emit()
	assert_int(_talents.detail()).is_equal(TalentScreen.Detail.NODE)


func test_touching_the_open_tab_goes_back_to_its_list() -> void:
	_tabs.select(ManagementTabs.Tab.TALENTS)
	_talents._button_of("a").pressed.emit()
	_tabs._talents_button.pressed.emit()
	assert_bool(_talents.is_detail_open()).is_false()
	assert_int(_tabs.selected()).is_equal(ManagementTabs.Tab.TALENTS)


func test_coming_back_to_a_tab_keeps_its_node_detail() -> void:
	_tabs.select(ManagementTabs.Tab.TALENTS)
	_talents._button_of("a").pressed.emit()
	_tabs._companions_button.pressed.emit()
	_tabs._talents_button.pressed.emit()
	assert_int(_talents.detail()).is_equal(TalentScreen.Detail.NODE)
