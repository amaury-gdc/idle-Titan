extends GdUnitTestSuite
## The real talents.json of story 019 (design/talent-tree-v2.md "Nœuds" and "Règles"): valid, the 30
## nodes of the spec, its point bands and tiers, one top choice per branch, and every tier reachable.
## Reads the shipped data file on purpose: it is the content under test.
## Story: production/epics/idle-titans/story-019-talent-tree-content.md

const TALENTS_PATH: String = "res://assets/data/talents.json"
const NODE_COUNT: int = 30
const TOP_TIER: int = 5
## Ids of the spec table, in its order.
const SPEC_IDS: PackedStringArray = [
	"click_grip", "click_crit", "click_ally", "bighit_power", "click_rhythm", "click_heavy", "boss_hunter",
	"bighit_cd", "click_top_timer", "click_top_rhythm",
	"frenzy_unlock", "comp_camaraderie", "comp_cadence", "frenzy_long", "comp_synergy", "comp_formation",
	"frenzy_power", "comp_legion", "comp_top_champion", "comp_top_instinct",
	"gold_unlock", "eco_purse", "economy_offline", "eco_flair", "eco_haggle", "gold_long", "gold_cd",
	"eco_vigil", "eco_top_rentier", "eco_top_harvest",
]
## A stage far past every point the tree can use.
const FAR_STAGE: int = 100000

var _permanent: PermanentState
var _tree: TalentTree


func before_test() -> void:
	_permanent = PermanentState.new()
	_tree = TalentTree.from_data(DataLoader.load_json(TALENTS_PATH), _permanent, GameState.new())
	_permanent.talent_tree_seen = _tree.tree_version()


func test_real_file_is_valid_and_versioned() -> void:
	assert_str(_tree.get_error()).is_empty()
	assert_int(_tree.tree_version()).is_equal(1)


func test_real_file_has_the_thirty_nodes_of_the_spec() -> void:
	# Act
	var ids: PackedStringArray = PackedStringArray()
	for def: TalentTree.TalentDef in _tree.nodes():
		ids.append(def.id)

	# Assert
	assert_int(ids.size()).is_equal(NODE_COUNT)
	assert_array(Array(ids)).is_equal(Array(SPEC_IDS))


func test_real_file_points_follow_the_bands() -> void:
	assert_int(_tree.points_at_stage(4)).is_equal(0)
	assert_int(_tree.points_at_stage(100)).is_equal(20)
	assert_int(_tree.points_at_stage(119)).is_equal(20)
	assert_int(_tree.points_at_stage(120)).is_equal(21)
	assert_int(_tree.points_at_stage(200)).is_equal(25)
	assert_array(Array(_tree.tier_thresholds())).is_equal([0, 2, 4, 8, 12])


func test_real_file_tops_are_one_exclusive_pair_per_branch_on_tier_5() -> void:
	for branch: Dictionary in _tree.branches():
		var groups: Dictionary = {}
		for def: TalentTree.TalentDef in _tree.nodes_of(branch["id"]):
			if def.tier == TOP_TIER:
				assert_str(def.exclusive_group).is_not_empty()
				groups[def.exclusive_group] = int(groups.get(def.exclusive_group, 0)) + 1
			else:
				assert_str(def.exclusive_group).is_empty()
		assert_dict(groups).has_size(1)
		assert_int(int(groups.values()[0])).is_equal(2)


func test_real_file_every_tier_is_reachable() -> void:
	# Arrange: all the points one could want
	_permanent.best_stage_record = FAR_STAGE

	# Act: buy whatever is buyable until nothing is
	var bought: bool = true
	while bought:
		bought = false
		for def: TalentTree.TalentDef in _tree.nodes():
			if _tree.buy(def.id):
				bought = true

	# Assert: every node is bought but the other top of each branch
	for def: TalentTree.TalentDef in _tree.nodes():
		var state: TalentTree.NodeState = _tree.state_of(def.id)
		var expected: TalentTree.NodeState = TalentTree.NodeState.EXCLUDED if def.tier == TOP_TIER and not _tree.is_owned(def.id) else TalentTree.NodeState.OWNED
		assert_int(state).override_failure_message(def.id).is_equal(expected)
	for branch: Dictionary in _tree.branches():
		assert_bool(_tree.tier_open(branch["id"], TOP_TIER)).is_true()


func test_real_file_locks_frenzy_and_gold_bonus_but_not_big_hit() -> void:
	assert_bool(_tree.skill_unlocked("big_hit")).is_true()
	assert_bool(_tree.skill_unlocked("damage_buff")).is_false()
	assert_bool(_tree.skill_unlocked("gold_bonus")).is_false()
