extends GdUnitTestSuite
## Unit tests for the talent tree schema 2 (story 018, design/talent-tree-v2.md): bands of points,
## tiers, exclusive groups, effects, skill locks and values, tree version refund, reset rules and
## the strict purchase order of the simulator. Fixtures only: the real talents.json stays schema 1.
## Story: production/epics/idle-titans/story-018-talent-tree-format.md

const TREE_VERSION: int = 2
const ENOUGH_STAGE: int = 200
## Enemies with plenty of HP: no hit kills.
const ENEMY_HP: String = "1000000"
const CLICK_BASE: String = "100"
const COMPANION_DAMAGE: String = "100"
const GOLD_PER_KILL: String = "1000"
const OFFLINE_SECONDS: int = 3600
const NOW: int = 1_000_000
const COOLDOWN: int = TalentTree.DEFAULT_RESET_COOLDOWN_SECONDS
const TEN_DAYS: int = 864_000

var _state: GameState
var _permanent: PermanentState
var _combat: Combat
var _floors: FloorManager
var _offline: OfflineIncome
var _tree: TalentTree
var _hub: ModifierHub


func before_test() -> void:
	var curves: Dictionary = {
		"schema_version": Combat.SUPPORTED_CURVES_SCHEMA,
		"enemy_hp_base": ENEMY_HP,
		"enemy_hp_growth": "1",
		"gold_per_kill_base": GOLD_PER_KILL,
		"gold_per_kill_growth": "1",
		"click_damage_base": CLICK_BASE,
		"click_companion_power_factor": "0",
		"cost_growth": "1.08",
		"offline_efficiency": "0.5",
		"offline_max_hours": 12,
		"offline_min_seconds": 60,
	}
	var roster: Dictionary = {
		"schema_version": 2,
		"companions": [{
			"id": "scout",
			"name": "Scout",
			"base_cost": "10",
			"base_damage": COMPANION_DAMAGE,
			"cost_growth": "1.08",
			"attack_interval_seconds": 1.0,
			"tiers": [],
		}],
	}
	_combat = Combat.from_data(curves, roster)
	assert_str(_combat.get_error()).is_empty()
	_state = GameState.new()
	_state.companion_levels = {"scout": 1}
	_permanent = PermanentState.new()
	_permanent.talent_tree_seen = TREE_VERSION
	_floors = FloorManager.new(_state, _combat)
	_offline = OfflineIncome.from_data(curves, _combat)
	assert_str(_offline.get_error()).is_empty()
	_build(_tree_data())


func _node(id: String, branch: String, tier: int, cost: int, effects: Array, requires: Array = [], group: String = "") -> Dictionary:
	var entry: Dictionary = {"id": id, "branch": branch, "name": id, "tier": tier, "cost": cost, "requires": requires, "effects": effects}
	if not group.is_empty():
		entry["exclusive_group"] = group
	return entry


## A small tree after design/talent-tree-v2.md, with every effect type once at least.
func _tree_data() -> Dictionary:
	return {
		"schema_version": TalentTree.TIERED_SCHEMA,
		"tree_version": TREE_VERSION,
		"stage_point_bands": [{"up_to": 100, "stages_per_point": 5}, {"stages_per_point": 20}],
		"tier_thresholds": [0, 2, 4, 8, 12],
		"branches": [{"id": "click", "name": "Clic"}, {"id": "companions", "name": "Compagnons"}, {"id": "economy", "name": "Économie"}],
		"nodes": [
			_node("click_grip", "click", 1, 1, [{"type": "stat", "stat": "click_damage", "percent": 8}]),
			_node("click_crit", "click", 1, 1, [{"type": "stat", "stat": "click_damage", "percent": 8}]),
			_node("click_top_timer", "click", 1, 3, [{"type": "boss_timer", "seconds": 5}], [], "click_top"),
			_node("click_top_rhythm", "click", 1, 3, [{"type": "rhythm", "clicks": 30, "dps_seconds": "1.5", "min_gap_seconds": 5}], [], "click_top"),
			_node("bighit_power", "click", 2, 2, [{"type": "skill_mod", "skill": "big_hit", "field": "amount", "value": "8"}]),
			_node("click_heavy", "click", 3, 2, [{"type": "stat", "stat": "click_damage", "percent": 15}]),
			_node("bighit_cd", "click", 3, 2, [{"type": "skill_mod", "skill": "big_hit", "field": "cooldown_seconds", "value": 40}], ["bighit_power"]),
			_node("frenzy_unlock", "companions", 1, 1, [{"type": "skill_unlock", "skill": "damage_buff"}]),
			_node("comp_synergy", "companions", 1, 1, [{"type": "synergy", "percent_per_companion": 1, "level": 100, "max_percent": 6}]),
			_node("comp_champion", "companions", 1, 1, [{"type": "champion", "percent": 12}]),
			_node("frenzy_long", "companions", 1, 2, [{"type": "skill_mod", "skill": "damage_buff", "field": "duration_seconds", "value": 20}], ["frenzy_unlock"]),
			_node("frenzy_power", "companions", 1, 3, [{"type": "skill_mod", "skill": "damage_buff", "field": "amount", "value": "1.75"}], ["frenzy_unlock"]),
			_node("frenzy_instinct", "companions", 1, 3, [{"type": "skill_passive", "skill": "damage_buff", "multiplier": "1.2"}], ["frenzy_unlock"]),
			_node("gold_unlock", "economy", 1, 1, [{"type": "skill_unlock", "skill": "gold_bonus"}]),
			_node("economy_offline", "economy", 1, 2, [{"type": "stat", "stat": "offline_gold", "percent": 25}]),
			_node("eco_flair", "economy", 1, 2, [{"type": "loot_shift", "from": "common", "to": "rare", "weight": 10}]),
			_node("eco_vigil", "economy", 1, 3, [{"type": "offline_cap_hours", "hours": 16}]),
		],
	}


# Builds the tree and the hub of [param data] on the shared states.
func _build(data: Dictionary) -> void:
	_tree = TalentTree.from_data(data, _permanent, _state)
	assert_str(_tree.get_error()).is_empty()
	_hub = ModifierHub.new(_floors, _offline, _tree)


func _make_skills() -> SkillManager:
	var data: Dictionary = {
		"schema_version": SkillManager.SUPPORTED_SCHEMA,
		"skills": [
			{"id": "big_hit", "name": "Gros coup", "effect": "burst", "dps_seconds": "6", "cooldown_seconds": 60},
			{"id": "damage_buff", "name": "Frénésie", "effect": "damage_multiplier", "multiplier": "1.5", "duration_seconds": 15, "cooldown_seconds": 90},
			{"id": "gold_bonus", "name": "Bonus d'or", "effect": "gold_multiplier", "multiplier": "1.5", "duration_seconds": 20, "cooldown_seconds": 120},
		],
	}
	var skills: SkillManager = SkillManager.from_data(data, _state, _combat, _floors, _hub)
	assert_str(skills.get_error()).is_empty()
	return skills


func _buy(ids: Array[String]) -> void:
	_state.max_stage_reached = ENOUGH_STAGE
	for id: String in ids:
		assert_bool(_tree.buy(id)).is_true()


func _click_dealt() -> String:
	var before: BigNumber = _floors.current_hp()
	_floors.click()
	return before.subtract(_floors.current_hp()).to_decimal_string()


func _offline_gold() -> String:
	_state.last_saved_unix = NOW - OFFLINE_SECONDS
	return (_offline.grant(_state, NOW)["gold"] as BigNumber).to_decimal_string()


# Data (criterion 1)

func test_schema_2_fixture_reads_its_version_and_tiers() -> void:
	# Arrange: built in before_test

	# Act
	var thresholds: PackedInt32Array = _tree.tier_thresholds()

	# Assert
	assert_bool(_tree.is_valid()).is_true()
	assert_int(_tree.tree_version()).is_equal(TREE_VERSION)
	assert_array(Array(thresholds)).is_equal([0, 2, 4, 8, 12])
	assert_int(_tree.node("click_top_rhythm").tier).is_equal(1)
	assert_str(_tree.node("click_top_rhythm").exclusive_group).is_equal("click_top")


func test_points_follow_the_stage_bands() -> void:
	# Arrange: 1 point per 5 stages up to 100, then 1 per 20
	var stages: Array[int] = [4, 99, 100, 119, 120, 200]

	# Act
	var points: Array[int] = []
	for stage: int in stages:
		points.append(_tree.points_at_stage(stage))

	# Assert
	assert_array(points).is_equal([0, 19, 20, 20, 21, 25])


func test_earned_points_use_the_best_stage_and_the_bands() -> void:
	# Arrange
	_state.max_stage_reached = ENOUGH_STAGE

	# Act
	var earned: int = _tree.earned_points()

	# Assert
	assert_int(earned).is_equal(25)


func test_every_effect_type_is_read_and_carried() -> void:
	# Arrange
	var types: Dictionary = {}
	for def: TalentTree.TalentDef in _tree.nodes():
		for effect: Dictionary in def.effects:
			types[effect["type"]] = true
	_buy(["click_top_rhythm", "comp_synergy"])

	# Act
	var rhythm: Array[Dictionary] = _tree.owned_effects("rhythm")
	var synergy: Array[Dictionary] = _tree.owned_effects("synergy")

	# Assert: the fixture has all of them, and the carried ones keep their whole numbers
	assert_array(types.keys()).contains_exactly_in_any_order(TalentTree.EFFECT_FIELDS.keys())
	assert_int(rhythm.size()).is_equal(1)
	assert_int(rhythm[0]["clicks"]).is_equal(30)
	assert_str(rhythm[0]["dps_seconds"]).is_equal("1.5")
	assert_bool(synergy[0]["level"] is int).is_true()
	assert_int(synergy[0]["max_percent"]).is_equal(6)


func test_invalid_schema_2_files_are_refused() -> void:
	# Arrange: one change each, every one of them breaks the file
	var breakers: Array[Callable] = [
		func(d: Dictionary) -> void: d.erase("tree_version"),
		func(d: Dictionary) -> void: d["tree_version"] = 0,
		func(d: Dictionary) -> void: d["stage_point_bands"] = [],
		func(d: Dictionary) -> void: d["stage_point_bands"][1]["up_to"] = 300,
		func(d: Dictionary) -> void: d["stage_point_bands"] = [{"up_to": 100, "stages_per_point": 5}, {"up_to": 50, "stages_per_point": 20}, {"stages_per_point": 20}],
		func(d: Dictionary) -> void: d["stage_point_bands"][0]["stages_per_point"] = 0,
		func(d: Dictionary) -> void: d["tier_thresholds"] = [1, 2, 4],
		func(d: Dictionary) -> void: d["tier_thresholds"] = [0, 4, 4],
		func(d: Dictionary) -> void: d["reset_cooldown_seconds"] = -1,
		func(d: Dictionary) -> void: d["nodes"][0]["tier"] = 6,
		func(d: Dictionary) -> void: d["nodes"][0].erase("tier"),
		func(d: Dictionary) -> void: d["nodes"][0]["effects"] = [],
		func(d: Dictionary) -> void: d["nodes"][0].erase("effects"),
		func(d: Dictionary) -> void: d["nodes"][0]["exclusive_group"] = "",
		func(d: Dictionary) -> void: d["nodes"][0]["effects"][0]["type"] = "luck",
		func(d: Dictionary) -> void: d["nodes"][0]["effects"][0]["percent"] = 0,
		func(d: Dictionary) -> void: d["nodes"][4]["effects"][0]["value"] = 8,
		func(d: Dictionary) -> void: d["nodes"][6]["effects"][0]["value"] = "40",
		func(d: Dictionary) -> void: d["nodes"][6]["effects"][0]["field"] = "range",
		func(d: Dictionary) -> void: d["nodes"][7]["effects"][0].erase("skill"),
		func(d: Dictionary) -> void: d["nodes"][3]["effects"][0]["min_gap_seconds"] = -1,
	]
	var refused: int = 0

	# Act
	for breaker: Callable in breakers:
		var data: Dictionary = _tree_data()
		breaker.call(data)
		if not TalentTree.from_data(data, _permanent, _state).is_valid():
			refused += 1

	# Assert
	assert_int(refused).is_equal(breakers.size())


func test_flat_schema_1_still_reads_with_no_version_and_one_band() -> void:
	# Arrange: the format of the real talents.json until story 019
	var data: Dictionary = {
		"schema_version": TalentTree.SUPPORTED_SCHEMA,
		"stages_per_point": 5,
		"branches": [{"id": "main", "name": "Branche"}],
		"nodes": [{"id": "root", "branch": "main", "name": "Nœud", "cost": 1, "requires": [], "effect": {"stat": "click_damage", "percent": 10}}],
	}
	_permanent.talent_tree_seen = 0

	# Act
	var tree: TalentTree = TalentTree.from_data(data, _permanent, _state)

	# Assert
	assert_str(tree.get_error()).is_empty()
	assert_int(tree.tree_version()).is_equal(0)
	assert_bool(tree.version_notice_due()).is_false()
	assert_bool(tree.apply_tree_version()).is_false()
	assert_int(tree.points_at_stage(200)).is_equal(40)
	assert_str(tree.node("root").stat).is_equal(TalentTree.STAT_CLICK_DAMAGE)


# Tiers and exclusive groups (criterion 2)

func test_tier_opens_by_points_spent_in_its_branch() -> void:
	# Arrange: points spent in other branches do not count
	_buy(["click_grip", "frenzy_unlock", "gold_unlock"])
	var before: TalentTree.NodeState = _tree.state_of("bighit_power")

	# Act: the second click point reaches the threshold of tier 2
	_buy(["click_crit"])

	# Assert
	assert_int(before).is_equal(TalentTree.NodeState.TIER_CLOSED)
	assert_bool(_tree.tier_open("click", 2)).is_true()
	assert_int(_tree.state_of("bighit_power")).is_equal(TalentTree.NodeState.BUYABLE)
	assert_int(_tree.state_of("click_heavy")).is_equal(TalentTree.NodeState.TIER_CLOSED)


func test_closed_tier_refuses_the_purchase() -> void:
	# Arrange
	_state.max_stage_reached = ENOUGH_STAGE

	# Act
	var bought: bool = _tree.buy("bighit_power")

	# Assert
	assert_bool(bought).is_false()
	assert_int(_tree.spent_points()).is_equal(0)


func test_tier_closed_again_by_a_retuned_cost_keeps_the_bought_node() -> void:
	# Arrange: 4 points spent in the click branch open tier 3, then a cost goes down by 1
	_buy(["click_grip", "click_crit", "bighit_power"])
	var data: Dictionary = _tree_data()
	data["nodes"][4]["cost"] = 1

	# Act
	_build(data)

	# Assert: tier 3 closed again, nothing taken away
	assert_int(_tree.spent_in_branch("click")).is_equal(3)
	assert_int(_tree.state_of("click_heavy")).is_equal(TalentTree.NodeState.TIER_CLOSED)
	assert_int(_tree.state_of("bighit_power")).is_equal(TalentTree.NodeState.OWNED)
	assert_str(_tree.skill_override("big_hit", TalentTree.SKILL_AMOUNT)).is_equal("8")


func test_exclusive_group_admits_one_node() -> void:
	# Arrange
	_buy(["click_top_timer"])

	# Act
	var bought: bool = _tree.buy("click_top_rhythm")

	# Assert
	assert_bool(bought).is_false()
	assert_int(_tree.state_of("click_top_rhythm")).is_equal(TalentTree.NodeState.EXCLUDED)


func test_save_with_two_nodes_of_a_group_counts_only_the_first() -> void:
	# Arrange: both tops in the save, written by hand or by an older tree
	_permanent.talents = {"click_top_rhythm": 1, "click_top_timer": 1}
	_state.max_stage_reached = ENOUGH_STAGE

	# Act
	var spent: int = _tree.spent_points()

	# Assert: the first in data order counts, the other is excluded and its points come back
	assert_int(spent).is_equal(3)
	assert_bool(_tree.is_owned("click_top_timer")).is_true()
	assert_int(_tree.state_of("click_top_rhythm")).is_equal(TalentTree.NodeState.EXCLUDED)
	assert_array(_tree.owned_effects("rhythm")).is_empty()


# Skill locks (criterion 3)

func test_locked_skill_never_activates() -> void:
	# Arrange: frenzy_unlock gates damage_buff; nothing gates big_hit
	var skills: SkillManager = _make_skills()

	# Act
	var buff: bool = skills.activate("damage_buff")
	var burst: bool = skills.activate("big_hit")

	# Assert
	assert_bool(buff).is_false()
	assert_bool(skills.can_activate("damage_buff")).is_false()
	assert_bool(skills.is_unlocked("damage_buff")).is_false()
	assert_float(skills.skill("damage_buff").cooldown_left()).is_equal(0.0)
	assert_str(_click_dealt()).is_equal(CLICK_BASE)
	assert_bool(burst).is_true()


func test_buying_the_unlock_node_frees_the_skill() -> void:
	# Arrange
	var skills: SkillManager = _make_skills()

	# Act
	_buy(["frenzy_unlock"])

	# Assert
	assert_bool(skills.activate("damage_buff")).is_true()
	assert_str(_click_dealt()).is_equal("150")


# Saved timers of locked skills and removed buffs (criterion 4)

func test_saved_cooldown_of_a_locked_skill_is_ignored() -> void:
	# Arrange: a save from before the reset, with the buff running
	_state.skill_timers = {"damage_buff": {"cooldown_left": 60.0, "active_left": 10.0}}

	# Act
	var skills: SkillManager = _make_skills()
	_buy(["frenzy_unlock"])

	# Assert: no buff, no cooldown left over once it is unlocked again
	assert_float(skills.skill("damage_buff").cooldown_left()).is_equal(0.0)
	assert_int(skills.skill("damage_buff").state()).is_equal(Skill.State.READY)
	assert_str(_click_dealt()).is_equal(CLICK_BASE)


func test_reset_stops_the_running_buff_of_a_skill_it_locks() -> void:
	# Arrange
	var skills: SkillManager = _make_skills()
	_buy(["frenzy_unlock"])
	assert_bool(skills.activate("damage_buff")).is_true()

	# Act
	_tree.reset()

	# Assert
	assert_int(skills.skill("damage_buff").state()).is_equal(Skill.State.READY)
	assert_float(skills.skill("damage_buff").cooldown_left()).is_equal(0.0)
	assert_str(_click_dealt()).is_equal(CLICK_BASE)
	skills.save_to(_state)
	assert_dict(_state.skill_timers).is_empty()


# Per-skill values (criterion 5)

func test_restored_buff_keeps_its_improved_duration() -> void:
	# Arrange: 18 s left of a buff lengthened to 20 s
	_buy(["frenzy_unlock", "frenzy_long"])
	_state.skill_timers = {"damage_buff": {"cooldown_left": 80.0, "active_left": 18.0}}

	# Act
	var skills: SkillManager = _make_skills()

	# Assert
	assert_float(skills.skill("damage_buff").active_left()).is_equal(18.0)
	assert_float(skills.effective_duration(skills.skill("damage_buff"))).is_equal(20.0)


func test_restored_buff_without_the_node_is_cut_to_the_data() -> void:
	# Arrange
	_buy(["frenzy_unlock"])
	_state.skill_timers = {"damage_buff": {"cooldown_left": 80.0, "active_left": 18.0}}

	# Act
	var skills: SkillManager = _make_skills()

	# Assert
	assert_float(skills.skill("damage_buff").active_left()).is_equal(15.0)


func test_skill_mods_change_the_activation() -> void:
	# Arrange
	_buy(["click_grip", "click_crit", "bighit_power", "bighit_cd", "frenzy_unlock", "frenzy_power"])
	var skills: SkillManager = _make_skills()
	_state.companion_levels = {}
	var before: BigNumber = _floors.current_hp()

	# Act: click 116 (two +8%) and no companion, 8 seconds instead of 6
	assert_bool(skills.activate("big_hit")).is_true()
	var burst: String = before.subtract(_floors.current_hp()).to_decimal_string()
	assert_bool(skills.activate("damage_buff")).is_true()

	# Assert
	assert_str(burst).is_equal("928")
	assert_float(skills.skill("big_hit").cooldown_left()).is_equal(40.0)
	assert_str(_click_dealt()).is_equal("203")


func test_shrunk_duration_cuts_the_running_buff() -> void:
	# Arrange: a 20 s buff running, then frenzy_long leaves the save while the unlock stays
	_buy(["frenzy_unlock", "frenzy_long"])
	var skills: SkillManager = _make_skills()
	assert_bool(skills.activate("damage_buff")).is_true()

	# Act
	_permanent.talents.erase("frenzy_long")
	_hub.refresh()

	# Assert
	assert_float(skills.skill("damage_buff").active_left()).is_equal(15.0)


# Tree version (criterion 6)

func test_version_change_hands_every_point_back_old_ids_included() -> void:
	# Arrange: a save of version 1 with a node still in the data and two old ids
	_permanent.talent_tree_seen = 1
	_permanent.talents = {"click_grip": 1, "click_1": 1, "economy_5": 1}
	_state.max_stage_reached = ENOUGH_STAGE

	# Act
	var due: bool = _tree.apply_tree_version()

	# Assert
	assert_bool(due).is_true()
	assert_dict(_permanent.talents).is_empty()
	assert_int(_tree.available_points()).is_equal(_tree.earned_points())
	assert_bool(_tree.version_notice_due()).is_true()
	assert_bool(_tree.buy("click_grip")).is_false()


func test_version_refund_happens_once() -> void:
	# Arrange
	_permanent.talent_tree_seen = 1
	_permanent.talents = {"click_grip": 1}
	_state.max_stage_reached = ENOUGH_STAGE
	_tree.apply_tree_version()
	_tree.acknowledge_version()
	assert_bool(_tree.buy("click_crit")).is_true()

	# Act
	var again: bool = _tree.apply_tree_version()

	# Assert
	assert_bool(again).is_false()
	assert_bool(_tree.is_owned("click_crit")).is_true()
	assert_int(_permanent.talent_tree_seen).is_equal(TREE_VERSION)


func test_absence_is_paid_with_the_old_bonus_before_the_refund() -> void:
	# Arrange: building the tree and the hub never refunds by itself
	_permanent.talent_tree_seen = 1
	_permanent.talents = {"economy_offline": 1}
	_build(_tree_data())

	# Act
	var paid_before: String = _offline_gold()
	_tree.apply_tree_version()
	var paid_after: String = _offline_gold()

	# Assert: 180 + 25%, then the bonus is gone
	assert_str(paid_before).is_equal("225")
	assert_str(paid_after).is_equal("180")


func test_version_refund_lifts_the_reset_wait() -> void:
	# Arrange
	_permanent.talent_tree_seen = 1
	_permanent.talents = {"click_grip": 1}
	_permanent.talent_reset_unix = NOW

	# Act
	_tree.apply_tree_version()

	# Assert
	assert_int(_tree.reset_seconds_left(NOW)).is_equal(0)


func test_new_player_gets_no_version_message() -> void:
	# Arrange: a fresh save at stage 1
	_permanent = PermanentState.new()
	_build(_tree_data())

	# Act
	var due: bool = _tree.apply_tree_version()

	# Assert
	assert_bool(due).is_false()
	assert_bool(_tree.version_notice_due()).is_false()
	assert_int(_permanent.talent_tree_seen).is_equal(TREE_VERSION)


func test_save_newer_than_the_code_is_refunded_too() -> void:
	# Arrange: the save was written by a tree of version 3, the code knows 2
	_permanent.talent_tree_seen = 3
	_permanent.talents = {"click_grip": 1}

	# Act
	var due: bool = _tree.apply_tree_version()

	# Assert
	assert_bool(due).is_true()
	assert_dict(_permanent.talents).is_empty()


# Reset rules (criterion 8)

func test_reset_is_refused_during_a_boss_fight() -> void:
	# Arrange
	_buy(["click_grip"])

	# Act
	var done: bool = _tree.try_reset(NOW, true)

	# Assert
	assert_bool(done).is_false()
	assert_int(_tree.reset_block(NOW, true)).is_equal(TalentTree.ResetBlock.BOSS)
	assert_bool(_tree.is_owned("click_grip")).is_true()


func test_reset_waits_one_hour_between_two_resets() -> void:
	# Arrange
	_buy(["click_grip"])
	assert_bool(_tree.try_reset(NOW, false)).is_true()
	_buy(["click_grip"])

	# Act
	var too_soon: bool = _tree.try_reset(NOW + COOLDOWN - 1, false)
	var block: TalentTree.ResetBlock = _tree.reset_block(NOW + COOLDOWN - 1, false)
	var on_time: bool = _tree.try_reset(NOW + COOLDOWN, false)

	# Assert
	assert_bool(too_soon).is_false()
	assert_int(block).is_equal(TalentTree.ResetBlock.COOLDOWN)
	assert_bool(on_time).is_true()
	assert_bool(_tree.is_owned("click_grip")).is_false()


func test_clock_set_back_waits_at_most_one_cooldown() -> void:
	# Arrange: the last reset is dated ten days after the clock of now
	_buy(["click_grip"])
	_permanent.talent_reset_unix = NOW + TEN_DAYS

	# Act: the query shows one cooldown and changes nothing; the refused try pulls the stamp back
	var at_once: int = _tree.reset_seconds_left(NOW)
	var stamp_after_query: int = _permanent.talent_reset_unix
	var refused: bool = _tree.try_reset(NOW, false)
	var an_hour_later: int = _tree.reset_seconds_left(NOW + COOLDOWN)
	var done: bool = _tree.try_reset(NOW + COOLDOWN, false)

	# Assert
	assert_int(at_once).is_equal(COOLDOWN)
	assert_int(stamp_after_query).is_equal(NOW + TEN_DAYS)
	assert_bool(refused).is_false()
	assert_int(an_hour_later).is_equal(0)
	assert_bool(done).is_true()


func test_reset_is_refused_while_the_version_message_is_due() -> void:
	# Arrange: a refunded save whose message is not read yet, with a node of the old version left
	_permanent.talent_tree_seen = 1
	_permanent.talents = {"click_grip": 1}
	_state.max_stage_reached = ENOUGH_STAGE

	# Act
	var done: bool = _tree.try_reset(NOW, false)

	# Assert: nothing removed, no wait started
	assert_bool(done).is_false()
	assert_bool(_tree.is_owned("click_grip")).is_true()
	assert_int(_permanent.talent_reset_unix).is_equal(0)


func test_talents_and_data_cut_running_cooldowns_without_the_modifier() -> void:
	# Arrange: a cooldown started with a modifier of 2 (180 s), then a talent change
	_buy(["frenzy_unlock"])
	var skills: SkillManager = _make_skills()
	skills.set_cooldown_modifier(2.0)
	assert_bool(skills.activate("damage_buff")).is_true()
	assert_float(skills.skill("damage_buff").cooldown_left()).is_equal(180.0)

	# Act
	_hub.refresh()

	# Assert: cut to the 90 s of the data, the modifier only counts for the next activation
	assert_float(skills.skill("damage_buff").cooldown_left()).is_equal(90.0)
	assert_float(skills.effective_cooldown(skills.skill("damage_buff"))).is_equal(180.0)


func test_reset_ignores_the_wait_when_spent_exceeds_earned() -> void:
	# Arrange: costs raised above the points of stage 10 (2 points), right after a reset
	_permanent.talents = {"click_grip": 1, "click_crit": 1, "bighit_power": 1}
	_permanent.talent_reset_unix = NOW
	_state.max_stage_reached = 10

	# Act
	var in_boss: TalentTree.ResetBlock = _tree.reset_block(NOW, true)
	var done: bool = _tree.try_reset(NOW, false)

	# Assert: still refused in a boss fight, allowed otherwise
	assert_int(in_boss).is_equal(TalentTree.ResetBlock.BOSS)
	assert_bool(done).is_true()
	assert_int(_tree.spent_points()).is_equal(0)


func test_reset_with_nothing_bought_starts_no_wait() -> void:
	# Arrange
	_state.max_stage_reached = ENOUGH_STAGE

	# Act
	var done: bool = _tree.try_reset(NOW, false)

	# Assert
	assert_bool(done).is_false()
	assert_int(_tree.reset_seconds_left(NOW)).is_equal(0)


# Simulator order (criterion 9)

func test_ordered_purchase_waits_for_its_turn() -> void:
	# Arrange: click_heavy's tier is closed, click_grip is buyable but comes after it
	_state.max_stage_reached = ENOUGH_STAGE

	# Act
	var waiting: String = SimMeasures.next_ordered_talent(_tree, PackedStringArray(["click_heavy", "click_grip"]))
	var first: String = SimMeasures.next_ordered_talent(_tree, PackedStringArray(["click_grip", "click_crit"]))

	# Assert
	assert_str(waiting).is_empty()
	assert_str(first).is_equal("click_grip")


func test_ordered_purchase_skips_owned_and_excluded_nodes() -> void:
	# Arrange
	_buy(["click_grip", "click_top_timer"])

	# Act
	var next: String = SimMeasures.next_ordered_talent(_tree, PackedStringArray(["click_grip", "click_top_rhythm", "frenzy_unlock"]))
	var done: String = SimMeasures.next_ordered_talent(_tree, PackedStringArray(["click_grip"]))

	# Assert
	assert_str(next).is_equal("frenzy_unlock")
	assert_str(done).is_empty()


func test_simulated_tree_buys_with_a_versioned_tree() -> void:
	# Arrange: a fresh simulated player, past stage 1, on a tree of version 1
	var data: Dictionary = _tree_data()
	data["tree_version"] = 1
	var permanent: PermanentState = PermanentState.new()
	_state.max_stage_reached = ENOUGH_STAGE
	var tree: TalentTree = SimMeasures.simulated_tree(data, permanent, _state)

	# Act
	var bought: int = SimMeasures.spend_talents(tree, [], SimMeasures.parse_order(" click_grip , click_crit,,"))

	# Assert
	assert_bool(tree.version_notice_due()).is_false()
	assert_int(bought).is_equal(2)
	assert_bool(tree.is_owned("click_crit")).is_true()


func test_unacknowledged_versioned_tree_buys_nothing() -> void:
	# Arrange: what the simulator did before it acknowledged the version
	var data: Dictionary = _tree_data()
	data["tree_version"] = 1
	_state.max_stage_reached = ENOUGH_STAGE
	var tree: TalentTree = TalentTree.from_data(data, PermanentState.new(), _state)
	var greedy: Array[String] = ["click_grip", "click_crit"]

	# Act
	var bought: int = SimMeasures.spend_talents(tree, greedy, PackedStringArray())

	# Assert
	assert_int(bought).is_equal(0)


func test_greedy_spending_buys_the_first_buyable_node_again_and_again() -> void:
	# Arrange
	_state.max_stage_reached = 10
	var greedy: Array[String] = ["bighit_power", "click_grip", "click_crit", "frenzy_unlock"]

	# Act: 2 points, bighit_power waits for its tier
	var bought: int = SimMeasures.spend_talents(_tree, greedy, PackedStringArray())

	# Assert
	assert_int(bought).is_equal(2)
	assert_bool(_tree.is_owned("click_crit")).is_true()
	assert_bool(_tree.is_owned("frenzy_unlock")).is_false()
