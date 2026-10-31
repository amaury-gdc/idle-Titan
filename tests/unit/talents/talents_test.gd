extends GdUnitTestSuite
## Unit tests for the talent tree: points, purchases, resets, old saves and the effect of
## each stat on the game formulas.
## Story: production/epics/idle-titans/story-006-talents.md

const STAGES_PER_POINT: int = 5
const ENOUGH_STAGE: int = 100
## Enemies with plenty of HP: no hit kills unless the test wants it.
const ENEMY_HP: String = "1000000"
const CLICK_BASE: String = "100"
const COMPANION_DAMAGE: String = "100"
const GOLD_PER_KILL: String = "1000"
const OFFLINE_SECONDS: int = 3600
const NOW: int = 1_000_000
const LONG_NAME: String = "Un nom de talent bien trop long pour tenir dans son bouton"

var _state: GameState
var _permanent: PermanentState
var _combat: Combat
var _curves: Dictionary
var _floors: FloorManager
var _offline: OfflineIncome
var _tree: TalentTree


func before_test() -> void:
	_curves = {
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
	_combat = Combat.from_data(_curves, roster)
	assert_str(_combat.get_error()).is_empty()
	_state = GameState.new()
	_state.companion_levels = {"scout": 1}
	_permanent = PermanentState.new()
	_floors = FloorManager.new(_state, _combat)
	_offline = OfflineIncome.from_data(_curves, _combat)
	assert_str(_offline.get_error()).is_empty()
	_tree = _make_tree(_permanent)


func _node(id: String, cost: int, requires: Array, stat: String, percent: int, node_name: String = "Nœud") -> Dictionary:
	return {"id": id, "branch": "main", "name": node_name, "cost": cost, "requires": requires, "effect": {"stat": stat, "percent": percent}}


func _tree_data(nodes: Array) -> Dictionary:
	return {
		"schema_version": TalentTree.SUPPORTED_SCHEMA,
		"stages_per_point": STAGES_PER_POINT,
		"branches": [{"id": "main", "name": "Branche"}],
		"nodes": nodes,
	}


func _make_tree(permanent: PermanentState) -> TalentTree:
	var tree: TalentTree = TalentTree.from_data(_tree_data([
		_node("root", 1, [], TalentTree.STAT_CLICK_DAMAGE, 10),
		_node("child", 2, ["root"], TalentTree.STAT_CLICK_DAMAGE, 10),
		_node("companions", 1, [], TalentTree.STAT_COMPANION_DAMAGE, 50),
		_node("gold", 1, [], TalentTree.STAT_GOLD, 50),
		_node("rentes", 1, [], TalentTree.STAT_OFFLINE_GOLD, 25),
	]), permanent, _state)
	assert_str(tree.get_error()).is_empty()
	return tree


func _make_skills() -> SkillManager:
	var data: Dictionary = {
		"schema_version": SkillManager.SUPPORTED_SCHEMA,
		"skills": [
			{"id": "big_hit", "name": "Gros coup", "effect": "burst", "dps_seconds": "6", "cooldown_seconds": 60},
			{"id": "damage_buff", "name": "Frénésie", "effect": "damage_multiplier", "multiplier": "1.5", "duration_seconds": 15, "cooldown_seconds": 90},
			{"id": "gold_bonus", "name": "Bonus d'or", "effect": "gold_multiplier", "multiplier": "1.5", "duration_seconds": 20, "cooldown_seconds": 120},
		],
	}
	var skills: SkillManager = SkillManager.from_data(data, _state, _combat, _floors)
	assert_str(skills.get_error()).is_empty()
	return skills


func _buy(ids: Array[String]) -> void:
	_state.max_stage_reached = ENOUGH_STAGE
	for id: String in ids:
		assert_bool(_tree.buy(id)).is_true()
	_tree.apply_to(_floors, _offline)


func _damage_dealt_by(hit: Callable) -> String:
	var before: BigNumber = _floors.current_hp()
	hit.call()
	return before.subtract(_floors.current_hp()).to_decimal_string()


func _offline_gold() -> String:
	_state.last_saved_unix = NOW - OFFLINE_SECONDS
	return (_offline.grant(_state, NOW)["gold"] as BigNumber).to_decimal_string()


# Data

func test_node_with_non_string_stat_is_refused() -> void:
	# Arrange: a number once stopped the loading halfway on a tree that still read as valid
	var data: Dictionary = _tree_data([{"id": "root", "branch": "main", "name": "Nœud", "cost": 1, "effect": {"stat": 5, "percent": 10}}])

	# Act
	var tree: TalentTree = TalentTree.from_data(data, _permanent, _state)

	# Assert
	assert_bool(tree.is_valid()).is_false()


func test_node_with_unknown_stat_is_refused() -> void:
	# Arrange
	var data: Dictionary = _tree_data([_node("root", 1, [], "luck", 10)])

	# Act
	var tree: TalentTree = TalentTree.from_data(data, _permanent, _state)

	# Assert
	assert_bool(tree.is_valid()).is_false()


# Points

func test_earned_points_below_first_step_are_zero() -> void:
	# Arrange
	_state.max_stage_reached = STAGES_PER_POINT - 1

	# Act
	var earned: int = _tree.earned_points()

	# Assert
	assert_int(earned).is_equal(0)


func test_earned_points_at_each_step_grow_by_one() -> void:
	# Arrange
	_state.max_stage_reached = STAGES_PER_POINT * 2

	# Act
	var earned: int = _tree.earned_points()

	# Assert
	assert_int(earned).is_equal(2)


# Purchases

func test_buy_locked_node_is_refused() -> void:
	# Arrange: enough points, the prerequisite is missing
	_state.max_stage_reached = ENOUGH_STAGE

	# Act
	var bought: bool = _tree.buy("child")

	# Assert
	assert_bool(bought).is_false()
	assert_bool(_tree.is_owned("child")).is_false()
	assert_int(_tree.spent_points()).is_equal(0)
	assert_int(_tree.state_of("child")).is_equal(TalentTree.NodeState.LOCKED)


func test_buy_without_enough_points_is_refused() -> void:
	# Arrange: 2 points, 1 goes to the prerequisite, the child costs 2
	_state.max_stage_reached = STAGES_PER_POINT * 2
	assert_bool(_tree.buy("root")).is_true()

	# Act
	var bought: bool = _tree.buy("child")

	# Assert
	assert_bool(bought).is_false()
	assert_int(_tree.available_points()).is_equal(1)
	assert_int(_tree.state_of("child")).is_equal(TalentTree.NodeState.UNAFFORDABLE)


func test_buy_with_prerequisite_and_exact_points_succeeds() -> void:
	# Arrange: 3 points, as many as the two nodes cost
	_state.max_stage_reached = STAGES_PER_POINT * 3
	assert_bool(_tree.buy("root")).is_true()

	# Act
	var bought: bool = _tree.buy("child")

	# Assert
	assert_bool(bought).is_true()
	assert_int(_tree.available_points()).is_equal(0)
	assert_int(_tree.state_of("child")).is_equal(TalentTree.NodeState.OWNED)


func test_buy_owned_node_twice_is_refused() -> void:
	# Arrange
	_state.max_stage_reached = ENOUGH_STAGE
	assert_bool(_tree.buy("root")).is_true()

	# Act
	var bought: bool = _tree.buy("root")

	# Assert
	assert_bool(bought).is_false()
	assert_int(_tree.spent_points()).is_equal(1)


func test_buy_unknown_node_is_refused() -> void:
	# Arrange
	_state.max_stage_reached = ENOUGH_STAGE

	# Act
	var bought: bool = _tree.buy("nope")

	# Assert
	assert_bool(bought).is_false()


# Resets

func test_tree_reset_gives_every_point_back() -> void:
	# Arrange
	_buy(["root", "child", "gold"])
	var earned: int = _tree.earned_points()

	# Act
	var refunded: int = _tree.reset()

	# Assert
	assert_int(refunded).is_equal(4)
	assert_int(_tree.available_points()).is_equal(earned)
	assert_bool(_tree.is_owned("root")).is_false()


func test_tree_reset_removes_the_effects() -> void:
	# Arrange
	_buy(["root"])

	# Act
	_tree.reset()
	_tree.apply_to(_floors, _offline)

	# Assert
	assert_str(_floors.click_damage().to_decimal_string()).is_equal(CLICK_BASE)


func test_run_reset_keeps_talents_and_points() -> void:
	# Arrange
	_state.max_stage_reached = STAGES_PER_POINT * 2
	assert_bool(_tree.buy("root")).is_true()

	# Act: the run restarts at stage 1, the talents are permanent
	_state.reset()

	# Assert
	assert_bool(_tree.is_owned("root")).is_true()
	assert_int(_tree.earned_points()).is_equal(2)
	assert_int(_tree.available_points()).is_equal(1)


func test_save_round_trip_keeps_talents_and_record() -> void:
	# Arrange
	_buy(["root"])

	# Act
	var restored: PermanentState = PermanentState.from_dict(_permanent.to_dict())

	# Assert
	assert_int(restored.best_stage_record).is_equal(ENOUGH_STAGE)
	assert_bool(_make_tree(restored).is_owned("root")).is_true()


# Old saves

func test_saves_older_than_version_4_earn_points_from_their_stage() -> void:
	for version: int in range(1, PermanentState.CURRENT_VERSION):
		# Arrange: no best_stage_record, a stale talent_points, a node, an unknown id
		var permanent: PermanentState = PermanentState.from_dict({
			"version": version,
			"talent_points": 7,
			"talents": {"root": 1, "removed_since": 1},
		})
		_state.max_stage_reached = 23

		# Act
		var tree: TalentTree = _make_tree(permanent)

		# Assert: 4 points earned at stage 23, 1 spent on the node; 7 and the unknown id count for nothing
		assert_int(tree.earned_points()).is_equal(4)
		assert_int(tree.spent_points()).is_equal(1)
		assert_int(tree.available_points()).is_equal(3)
		assert_bool(tree.is_owned("root")).is_true()


func test_save_without_talent_fields_starts_with_an_empty_tree() -> void:
	# Arrange
	var permanent: PermanentState = PermanentState.from_dict({"version": 1})
	_state.max_stage_reached = STAGES_PER_POINT

	# Act
	var tree: TalentTree = _make_tree(permanent)

	# Assert
	assert_int(tree.spent_points()).is_equal(0)
	assert_int(tree.available_points()).is_equal(1)


func test_spent_above_earned_gives_zero_points_and_reset_stays_possible() -> void:
	# Arrange: an old save that owns more than its stage pays for, after a cost was raised
	var permanent: PermanentState = PermanentState.from_dict({"version": 3, "talents": {"root": 1, "child": 1}})
	_state.max_stage_reached = STAGES_PER_POINT
	var tree: TalentTree = _make_tree(permanent)

	# Act
	var points_before: int = tree.available_points()
	var bought: bool = tree.buy("gold")
	var refunded: int = tree.reset()

	# Assert
	assert_int(points_before).is_equal(0)
	assert_bool(bought).is_false()
	assert_int(refunded).is_equal(3)
	assert_int(tree.available_points()).is_equal(1)


# Effects

func test_click_talent_raises_click_damage() -> void:
	# Arrange
	_buy(["root"])

	# Act
	var dealt: String = _damage_dealt_by(_floors.click)

	# Assert: 100 + 10%
	assert_str(dealt).is_equal("110")


func test_percentages_of_a_stat_add_up() -> void:
	# Arrange
	_buy(["root", "child"])

	# Act
	var dealt: String = _damage_dealt_by(_floors.click)

	# Assert: +10% and +10% give +20%, not +21%
	assert_str(dealt).is_equal("120")


func test_click_talent_stays_after_a_skill_buff_ends() -> void:
	# Arrange
	_buy(["root"])
	var skills: SkillManager = _make_skills()
	assert_bool(skills.activate("damage_buff")).is_true()

	# Act: the buff pushes its multiplier, then its end pushes "1"
	skills.tick(SkillManager.MAX_TICK_SECONDS)
	skills.tick(SkillManager.MAX_TICK_SECONDS)
	skills.tick(SkillManager.MAX_TICK_SECONDS)
	skills.tick(SkillManager.MAX_TICK_SECONDS)

	# Assert
	assert_str(_damage_dealt_by(_floors.click)).is_equal("110")


func test_companion_talent_raises_attack_damage() -> void:
	# Arrange
	_buy(["companions"])
	var companions: CompanionManager = CompanionManager.new(_state, _combat, _floors)

	# Act: one attack per second
	var dealt: String = _damage_dealt_by(func() -> void: companions.tick(1.0))

	# Assert: 100 + 50%
	assert_str(dealt).is_equal("150")


func test_companion_talent_leaves_click_damage_alone() -> void:
	# Arrange
	_buy(["companions"])

	# Act
	var click: BigNumber = _floors.click_damage()

	# Assert
	assert_str(click.to_decimal_string()).is_equal(CLICK_BASE)


func test_gold_talent_raises_kill_gold() -> void:
	# Arrange
	_buy(["gold"])

	# Act
	_floors.apply_damage(_floors.current_hp())

	# Assert: 1000 + 50%
	assert_str(_state.gold.to_decimal_string()).is_equal("1500")


func test_gold_talent_comes_before_the_gold_bonus_of_skills() -> void:
	# Arrange
	_buy(["gold"])
	_floors.set_gold_multiplier("1.5")

	# Act
	_floors.apply_damage(_floors.current_hp())

	# Assert: 1000 * 1.5 * 1.5
	assert_str(_state.gold.to_decimal_string()).is_equal("2250")


func test_big_hit_without_talents_keeps_its_base_damage() -> void:
	# Arrange
	var skills: SkillManager = _make_skills()

	# Act
	var dealt: String = _damage_dealt_by(func() -> void: skills.activate("big_hit"))

	# Assert: (100 + 100) * 6
	assert_str(dealt).is_equal("1200")


func test_big_hit_gets_click_and_companion_talents() -> void:
	# Arrange
	_buy(["root", "companions"])
	var skills: SkillManager = _make_skills()

	# Act
	var dealt: String = _damage_dealt_by(func() -> void: skills.activate("big_hit"))

	# Assert: (150 companions + 110 click) * 6
	assert_str(dealt).is_equal("1560")


func test_big_hit_is_raised_by_the_damage_buff_on_top_of_talents() -> void:
	# Arrange
	_buy(["root", "companions"])
	var skills: SkillManager = _make_skills()
	assert_bool(skills.activate("damage_buff")).is_true()

	# Act
	var dealt: String = _damage_dealt_by(func() -> void: skills.activate("big_hit"))

	# Assert: 1560 * 1.5
	assert_str(dealt).is_equal("2340")


func test_offline_gold_without_rentes_is_the_base_formula() -> void:
	# Arrange
	_tree.apply_to(_floors, _offline)

	# Act
	var gold: String = _offline_gold()

	# Assert: 100 damage/s * 3600 s * 1000 gold / 1 000 000 HP * 0.5
	assert_str(gold).is_equal("180")


func test_rentes_raises_offline_gold() -> void:
	# Arrange
	_buy(["rentes"])

	# Act
	var gold: String = _offline_gold()

	# Assert: 180 + 25%
	assert_str(gold).is_equal("225")


func test_other_talents_leave_offline_gold_alone() -> void:
	# Arrange
	_buy(["root", "companions", "gold"])

	# Act
	var gold: String = _offline_gold()

	# Assert
	assert_str(gold).is_equal("180")


func test_rentes_reset_removes_the_offline_bonus() -> void:
	# Arrange
	_buy(["rentes"])

	# Act
	_tree.reset()
	_tree.apply_to(_floors, _offline)

	# Assert
	assert_str(_offline_gold()).is_equal("180")


# Screen

func test_long_node_text_does_not_widen_its_button() -> void:
	# Arrange: the "not enough points" text once widened the nodes until the tree left the screen
	var tree: TalentTree = TalentTree.from_data(_tree_data([
		_node("root", 5, [], TalentTree.STAT_CLICK_DAMAGE, 10, LONG_NAME),
	]), _permanent, _state)
	var screen: TalentScreen = auto_free((load("res://src/ui/talent_screen.tscn") as PackedScene).instantiate())
	add_child(screen)

	# Act
	screen.setup(tree)

	# Assert
	var buttons: Array[Node] = screen.get_node("Panel/Content/Branches").find_children("*", "Button", true, false)
	assert_int(buttons.size()).is_equal(1)
	assert_float((buttons[0] as Button).get_combined_minimum_size().x).is_equal(TalentScreen.NODE_MIN_SIZE.x)
