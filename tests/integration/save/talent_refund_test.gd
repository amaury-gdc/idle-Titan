extends GdUnitTestSuite
## Integration tests of the talent tree version through the saves (story 018): PermanentState v6
## fields, the refund of an old save written on disk, the version message that stays due across
## reloads and a ".bak", an old 0.2.1 tab writing over the save, and the real talents.json (schema 2
## since story 019) that refunds a 0.2.1 save. Writes test-only files under user:// and removes them.
## Story: production/epics/idle-titans/story-018-talent-tree-format.md

const GAME_PATH: String = "user://test_talent_refund_game.json"
const PERMANENT_PATH: String = "user://test_talent_refund_permanent.json"
const TEST_FILES: PackedStringArray = [
	"test_talent_refund_game.json",
	"test_talent_refund_game.json.bak",
	"test_talent_refund_permanent.json",
	"test_talent_refund_permanent.json.bak",
]
const TREE_VERSION: int = 1
const BEST_STAGE: int = 120
const NOW: int = 1_000_000
## A permanent save of 0.2.1 (version 5) as the game wrote it, with talents of the old tree.
const SAVE_0_2_1: String = '{"version":5,"talent_points":0,"talents":{"click_1":1,"click_2":1,"economy_offline":1},"best_stage_record":120,"artifacts":[],"auto_challenge":true,"boss_hint_shown":true,"inventory":[],"equipped":{}}'

var _saves: SaveManager
var _game: GameState
var _permanent: PermanentState


func before_test() -> void:
	_remove_test_files()
	_saves = SaveManager.new(GAME_PATH, PERMANENT_PATH)
	_game = GameState.new()
	_game.max_stage_reached = BEST_STAGE


func after_test() -> void:
	_remove_test_files()


func _remove_test_files() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	for file_name: String in TEST_FILES:
		if dir.file_exists(file_name):
			dir.remove(file_name)


func _write_raw(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## A versioned tree whose ids differ from the old one, except economy_offline.
func _tree(permanent: PermanentState) -> TalentTree:
	var data: Dictionary = {
		"schema_version": TalentTree.TIERED_SCHEMA,
		"tree_version": TREE_VERSION,
		"stage_point_bands": [{"up_to": 100, "stages_per_point": 5}, {"stages_per_point": 20}],
		"tier_thresholds": [0, 2],
		"branches": [{"id": "economy", "name": "Économie"}],
		"nodes": [
			{"id": "eco_purse", "branch": "economy", "name": "Bourse", "tier": 1, "cost": 1, "effects": [{"type": "stat", "stat": "gold", "percent": 3}]},
			{"id": "economy_offline", "branch": "economy", "name": "Rentes", "tier": 1, "cost": 2, "effects": [{"type": "stat", "stat": "offline_gold", "percent": 25}]},
		],
	}
	var tree: TalentTree = TalentTree.from_data(data, permanent, _game)
	assert_str(tree.get_error()).is_empty()
	return tree


# Loads as the main screen will: load, absence paid (nothing here), version applied. The loaded
# state is kept in _permanent for the saves that follow.
func _load_and_apply() -> TalentTree:
	_permanent = _saves.load_permanent()
	var tree: TalentTree = _tree(_permanent)
	tree.apply_tree_version()
	return tree


func test_v6_fields_survive_a_save_and_a_load() -> void:
	# Arrange
	var permanent: PermanentState = PermanentState.new()
	permanent.talent_tree_seen = TREE_VERSION
	permanent.talent_reset_unix = NOW
	_saves.save(_game, permanent)

	# Act
	var loaded: PermanentState = _saves.load_permanent()

	# Assert
	assert_int(loaded.talent_tree_seen).is_equal(TREE_VERSION)
	assert_int(loaded.talent_reset_unix).is_equal(NOW)
	# 7 since story 020 (balance_seen); the version 6 fields above are unchanged.
	assert_int(int(loaded.to_dict()["version"])).is_equal(7)


func test_absurd_v6_values_load_as_none() -> void:
	# Arrange: negative, not a number, a string, beyond 2^53
	var payloads: Array[Dictionary] = [
		{"talent_tree_seen": -2, "talent_reset_unix": -5},
		{"talent_tree_seen": NAN, "talent_reset_unix": INF},
		{"talent_tree_seen": "1", "talent_reset_unix": "1000"},
		{"talent_tree_seen": 1e30, "talent_reset_unix": 1e30},
	]

	# Act / Assert
	for payload: Dictionary in payloads:
		var loaded: PermanentState = PermanentState.from_dict(payload)
		assert_int(loaded.talent_tree_seen).is_equal(0)
		assert_int(loaded.talent_reset_unix).is_equal(0)


func test_0_2_1_save_is_refunded_once_and_keeps_its_other_fields() -> void:
	# Arrange
	_write_raw(PERMANENT_PATH, SAVE_0_2_1)

	# Act
	var tree: TalentTree = _load_and_apply()

	# Assert: every key gone, the old ids and the one the new tree knows
	assert_bool(tree.version_notice_due()).is_true()
	assert_dict(_permanent.talents).is_empty()
	assert_bool(_permanent.auto_challenge).is_true()
	assert_int(tree.spent_points()).is_equal(0)
	assert_int(tree.available_points()).is_equal(tree.earned_points())
	assert_int(tree.earned_points()).is_equal(21)


func test_version_message_stays_due_after_a_reload() -> void:
	# Arrange: refund, autosave, page reloaded before the message was read
	_write_raw(PERMANENT_PATH, SAVE_0_2_1)
	_load_and_apply()
	_saves.save(_game, _permanent)

	# Act
	var permanent: PermanentState = _saves.load_permanent()
	var tree: TalentTree = _tree(permanent)
	var due: bool = tree.apply_tree_version()

	# Assert
	assert_bool(due).is_true()
	assert_bool(tree.version_notice_due()).is_true()
	assert_dict(permanent.talents).is_empty()
	assert_bool(permanent.auto_challenge).is_true()


func test_version_message_stays_due_after_a_bak() -> void:
	# Arrange: two saves after the refund, then the main file is corrupted
	_write_raw(PERMANENT_PATH, SAVE_0_2_1)
	_load_and_apply()
	_saves.save(_game, _permanent)
	_saves.save(_game, _permanent)
	_write_raw(PERMANENT_PATH, "{ not json")

	# Act
	var tree: TalentTree = _load_and_apply()

	# Assert
	assert_bool(tree.version_notice_due()).is_true()
	assert_int(tree.spent_points()).is_equal(0)


func test_bak_from_before_the_refund_is_refunded_again() -> void:
	# Arrange: the .bak is still the 0.2.1 save
	_write_raw(PERMANENT_PATH, SAVE_0_2_1)
	_load_and_apply()
	_saves.save(_game, _permanent)
	_write_raw(PERMANENT_PATH, "{ not json")

	# Act
	var permanent: PermanentState = _saves.load_permanent()
	var tree: TalentTree = _tree(permanent)
	var owned_before: bool = tree.is_owned("economy_offline")
	var due: bool = tree.apply_tree_version()

	# Assert
	assert_bool(owned_before).is_true()
	assert_bool(due).is_true()
	assert_dict(permanent.talents).is_empty()


func test_acknowledged_message_is_not_due_after_a_reload() -> void:
	# Arrange
	_write_raw(PERMANENT_PATH, SAVE_0_2_1)
	var first: TalentTree = _load_and_apply()
	first.acknowledge_version()
	assert_bool(first.buy("eco_purse")).is_true()
	_saves.save(_game, _permanent)

	# Act
	var permanent: PermanentState = _saves.load_permanent()
	var tree: TalentTree = _tree(permanent)
	var due: bool = tree.apply_tree_version()

	# Assert: no second refund, the new purchase stays
	assert_bool(due).is_false()
	assert_bool(tree.is_owned("eco_purse")).is_true()


func test_old_tab_writing_over_the_save_brings_the_refund_back() -> void:
	# Arrange: acknowledged and saved, then a 0.2.1 tab still open writes its version 5 state
	_write_raw(PERMANENT_PATH, SAVE_0_2_1)
	var first: TalentTree = _load_and_apply()
	first.acknowledge_version()
	_saves.save(_game, _permanent)
	_write_raw(PERMANENT_PATH, SAVE_0_2_1)

	# Act
	var tree: TalentTree = _load_and_apply()

	# Assert: the old tree's ids never count in the new one
	assert_bool(tree.version_notice_due()).is_true()
	assert_int(tree.spent_points()).is_equal(0)


func test_real_talents_file_refunds_a_0_2_1_save_once() -> void:
	# Arrange: since story 019 the real file is the versioned tree of design/talent-tree-v2.md
	var permanent: PermanentState = PermanentState.from_dict(JSON.parse_string(SAVE_0_2_1))
	var tree: TalentTree = TalentTree.from_data(DataLoader.load_json("res://assets/data/talents.json"), permanent, _game)

	# Act
	var due: bool = tree.apply_tree_version()

	# Assert: every old point back, the new bands (20 points at 100, then 1 per 20), locked skills
	assert_str(tree.get_error()).is_empty()
	assert_int(tree.tree_version()).is_equal(TREE_VERSION)
	assert_bool(due).is_true()
	assert_bool(permanent.talents.is_empty()).is_true()
	assert_int(tree.earned_points()).is_equal(21)
	assert_bool(tree.skill_unlocked("big_hit")).is_true()
	assert_bool(tree.skill_unlocked("damage_buff")).is_false()
	assert_bool(tree.skill_unlocked("gold_bonus")).is_false()

