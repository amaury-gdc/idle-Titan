extends GdUnitTestSuite
## Unit tests of the talent effects of story 019 (design/talent-tree-v2.md "Nœuds"): every effect the
## tree gives acts in the core through [ModifierHub], each from a fixture node. The real talents.json is
## checked in talents_real_file_test.gd.
## Story: production/epics/idle-titans/story-019-talent-tree-content.md

const TREE_VERSION: int = 1
## Enough stages for every node of the fixture.
const ENOUGH_STAGE: int = 1000
## Enemies with plenty of HP: no hit kills.
const ENEMY_HP: String = "1000000000"
const CLICK_BASE: String = "100"
const SCOUT_DAMAGE: String = "100"
const KNIGHT_DAMAGE: String = "300"
const GOLD_PER_KILL: String = "1000"
const BOSS_EVERY: int = 10
const BOSS_TIMER: float = 30.0
const HOUR: int = 3600

var _state: GameState
var _permanent: PermanentState
var _combat: Combat
var _boss: BossFight
var _floors: FloorManager
var _offline: OfflineIncome
var _tree: TalentTree
var _hub: ModifierHub
var _companions: CompanionManager
var _bursts: Array[BigNumber] = []


func before_test() -> void:
	_combat = Combat.from_data(_curves(), _roster())
	assert_str(_combat.get_error()).is_empty()
	_boss = BossFight.from_data({
		"schema_version": BossFight.SUPPORTED_SCHEMA,
		"boss_every_stages": BOSS_EVERY,
		"timer_seconds": BOSS_TIMER,
		"boss_hp_multiplier": "1",
		"boss_gold_base": "1",
		"boss_gold_growth": "1",
		"auto_challenge_margin": "1",
	})
	assert_str(_boss.get_error()).is_empty()
	_state = GameState.new()
	_state.companion_levels = {"scout": 1}
	_permanent = PermanentState.new()
	_permanent.talent_tree_seen = TREE_VERSION
	_permanent.best_stage_record = ENOUGH_STAGE
	_bursts = []
	_build(null)


func _curves() -> Dictionary:
	return {
		"schema_version": Combat.SUPPORTED_CURVES_SCHEMA,
		"enemy_hp_base": ENEMY_HP,
		"enemy_hp_growth": "1",
		"gold_per_kill_base": GOLD_PER_KILL,
		"gold_per_kill_growth": "1",
		"click_damage_base": CLICK_BASE,
		"click_companion_power_factor": "0.5",
		"cost_growth": "1",
		"offline_efficiency": "1",
		"offline_max_hours": 12,
		"offline_min_seconds": 0,
	}


func _roster() -> Dictionary:
	return {
		"schema_version": Combat.SUPPORTED_ROSTER_SCHEMA,
		"companions": [
			{"id": "scout", "name": "Scout", "base_cost": "100", "base_damage": SCOUT_DAMAGE, "attack_interval_seconds": 1.0, "tiers": []},
			{"id": "knight", "name": "Knight", "base_cost": "100", "base_damage": KNIGHT_DAMAGE, "attack_interval_seconds": 1.0, "tiers": []},
		],
		"awakening": {"thresholds": [2], "self_multiplier": "2", "squad_multiplier": "1", "squad_until_threshold": 0, "cost_level_multiplier": "10"},
	}


func _node(id: String, effects: Array, requires: Array = []) -> Dictionary:
	return {"id": id, "branch": "all", "name": id, "tier": 1, "cost": 1, "requires": requires, "effects": effects}


## One node per effect of story 019, all on tier 1 and costing 1, with values that make each effect easy to read.
func _tree_data() -> Dictionary:
	return {
		"schema_version": TalentTree.TIERED_SCHEMA,
		"tree_version": TREE_VERSION,
		"stage_point_bands": [{"stages_per_point": 1}],
		"tier_thresholds": [0],
		"branches": [{"id": "all", "name": "Tout"}],
		"nodes": [
			_node("crit", [{"type": "stat", "stat": "crit_chance", "percent": 50}]),
			_node("ally", [{"type": "stat", "stat": "click_share", "percent": 50}]),
			_node("rhythm", [{"type": "rhythm", "clicks": 4, "dps_seconds": "1", "min_gap_seconds": 5}]),
			_node("virtuoso", [{"type": "rhythm", "clicks": 2, "dps_seconds": "2", "min_gap_seconds": 5}], ["rhythm"]),
			_node("hunter", [{"type": "stat", "stat": "boss_damage", "percent": 10}]),
			_node("reprieve", [{"type": "boss_timer", "seconds": 5}]),
			_node("cadence", [{"type": "stat", "stat": "attack_speed", "percent": 100}]),
			_node("synergy", [{"type": "synergy", "percent_per_companion": 4, "level": 100, "max_percent": 6}]),
			_node("champion", [{"type": "champion", "percent": 12}]),
			_node("flair", [{"type": "loot_shift", "from": "common", "to": "rare", "weight": 10}]),
			_node("haggle", [{"type": "stat", "stat": "cost_discount", "percent": 5}]),
			_node("vigil", [{"type": "offline_cap_hours", "hours": 16}]),
			_node("harvest", [{"type": "stat", "stat": "farm_gold", "percent": 12}]),
			_node("frenzy_unlock", [{"type": "skill_unlock", "skill": "damage_buff"}]),
			_node("frenzy_long", [{"type": "skill_mod", "skill": "damage_buff", "field": "duration_seconds", "value": 20}], ["frenzy_unlock"]),
			_node("frenzy_power", [{"type": "skill_mod", "skill": "damage_buff", "field": "amount", "value": "1.75"}], ["frenzy_unlock"]),
			_node("instinct", [{"type": "skill_passive", "skill": "damage_buff", "multiplier": "1.2"}], ["frenzy_unlock"]),
		],
	}


## A small items.json: two rarities, every stat at 1, critical hits doubling, one boss tier.
func _items_data(common_weight: int) -> Dictionary:
	var stats: Array = []
	for stat: String in Item.STATS:
		stats.append({"id": stat, "name": stat, "ranges": {"common": [1, 1], "rare": [1, 1]}})
	return {
		"schema_version": LootTable.SUPPORTED_SCHEMA,
		"worse_item_rule": "test",
		"inventory_capacity": 4,
		"crit": {"base_chance_percent": 0, "base_bonus_percent": 100, "max_chance_percent": 100},
		"stats": stats,
		"rarities": [
			{"id": "common", "name": "Commun", "secondary_stats": 0, "sell_kills": 1},
			{"id": "rare", "name": "Rare", "secondary_stats": 0, "sell_kills": 1},
		],
		"types": [{"id": "sword", "name": "Épée", "primary_stat": "click_damage", "drop_weight": 1}],
		"boss_loot": [{"from_stage": 1, "drop_percent": 100, "rarity_weights": {"common": common_weight, "rare": 10}}],
	}


# Builds the floors, the tree, the hub and the companions on the shared states, with [param inventory].
func _build(inventory: Inventory) -> void:
	_floors = FloorManager.new(_state, _combat, _boss, _permanent)
	_floors.rhythm_triggered.connect(func(damage: BigNumber) -> void: _bursts.append(damage))
	_offline = OfflineIncome.from_data(_curves(), _combat)
	_tree = TalentTree.from_data(_tree_data(), _permanent, _state)
	assert_str(_tree.get_error()).is_empty()
	_hub = ModifierHub.new(_floors, _offline, _tree, inventory)
	_companions = CompanionManager.new(_state, _combat, _floors)


func _buy(ids: Array[String]) -> void:
	for id: String in ids:
		assert_bool(_tree.buy(id)).override_failure_message("cannot buy " + id).is_true()


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


func _clicks(count: int) -> void:
	for i in count:
		_floors.click()


# --- Frappe alliée ---------------------------------------------------------------------------------

func test_click_ally_multiplies_the_companion_share_and_not_the_base() -> void:
	# Arrange: scout 100 dps, share 0.5: click = 100 + 50
	var before: String = _floors.click_damage().to_decimal_string()

	# Act
	_buy(["ally"])

	# Assert: 100 + floor(100 * 1.5 * 0.5)
	assert_str(before).is_equal("150")
	assert_str(_floors.click_damage().to_decimal_string()).is_equal("175")


# --- Œil vif ---------------------------------------------------------------------------------------

func test_crit_chance_talent_makes_a_low_roll_critical() -> void:
	# Arrange: critical hits come from the item data (base 0 %, +100 %); the talent gives 50 %
	_build(Inventory.from_data(_items_data(90), _permanent, _state, _combat, func() -> float: return 0.0))
	_buy(["crit"])
	var hits: Array[int] = []
	_floors.hit_landed.connect(func(_damage: BigNumber, source: int) -> void: hits.append(source))

	# Act: a roll of 0.49 is below 50 %, 0.5 is not
	_floors.set_crit_roll(func() -> float: return 0.49)
	_floors.click()
	_floors.set_crit_roll(func() -> float: return 0.5)
	_floors.click()

	# Assert
	assert_int(_hub.crit_chance_percent()).is_equal(50)
	assert_array(hits).is_equal([FloorManager.HitSource.CRITICAL, FloorManager.HitSource.CLICK])


# --- Rythme ----------------------------------------------------------------------------------------

func test_rhythm_deals_one_second_of_damage_every_count_of_clicks() -> void:
	# Arrange
	_buy(["rhythm"])
	var expected: String = _floors.companion_power().add(_floors.click_damage()).to_decimal_string()

	# Act
	_clicks(3)
	var after_three: int = _bursts.size()
	_floors.click()

	# Assert
	assert_int(after_three).is_equal(0)
	assert_int(_bursts.size()).is_equal(1)
	assert_str(_bursts[0].to_decimal_string()).is_equal(expected)
	assert_int(_floors.rhythm_count()).is_equal(0)


func test_rhythm_waits_five_seconds_between_two_bursts() -> void:
	# Arrange: a first burst at once
	_buy(["rhythm"])
	_clicks(4)

	# Act: four clicks 4.9 s later, then one at 5 s
	_floors.tick(4.9)
	_clicks(4)
	var inside_gap: int = _bursts.size()
	_floors.tick(0.1)
	_floors.click()

	# Assert: held, then given by the first click after the gap
	assert_int(inside_gap).is_equal(1)
	assert_int(_bursts.size()).is_equal(2)


func test_rhythm_count_is_not_saved() -> void:
	# Arrange: three clicks of four, then a save and a load
	_buy(["rhythm"])
	_clicks(3)
	_state = GameState.from_dict(_state.to_dict())
	_permanent = PermanentState.from_dict(_permanent.to_dict())
	_build(null)

	# Act
	_floors.click()

	# Assert: counting starts again from zero
	assert_int(_bursts.size()).is_equal(0)
	assert_int(_floors.rhythm_count()).is_equal(1)


func test_virtuoso_replaces_the_rhythm_numbers() -> void:
	# Arrange
	_buy(["rhythm", "virtuoso"])
	var expected: String = _floors.companion_power().add(_floors.click_damage()).multiply_decimal("2").to_decimal_string()

	# Act
	_clicks(2)

	# Assert
	assert_int(_floors.rhythm_clicks()).is_equal(2)
	assert_int(_bursts.size()).is_equal(1)
	assert_str(_bursts[0].to_decimal_string()).is_equal(expected)


# --- Chasseur de boss, Sursis ----------------------------------------------------------------------

func test_boss_hunter_raises_damage_in_boss_fights_only() -> void:
	# Arrange
	_buy(["hunter"])
	var hit: BigNumber = BigNumber.from_int(1000)
	var outside: String = _floors.buffed_damage(hit).to_decimal_string()

	# Act
	_state.stage = BOSS_EVERY
	_build(null)

	# Assert
	assert_str(outside).is_equal("1000")
	assert_bool(_floors.is_boss_fight()).is_true()
	assert_str(_floors.buffed_damage(hit).to_decimal_string()).is_equal("1100")


func test_reprieve_adds_five_seconds_to_the_boss_countdown() -> void:
	# Arrange
	_buy(["reprieve"])

	# Act: a boss fight begins
	_state.stage = BOSS_EVERY
	_build(null)

	# Assert
	assert_float(_floors.boss_timer_seconds()).is_equal(BOSS_TIMER + 5.0)
	assert_float(_floors.boss_time_left()).is_equal(BOSS_TIMER + 5.0)


# --- Cadence, Synergie, Champion -------------------------------------------------------------------

func test_cadence_speeds_up_the_attacks_and_the_dps() -> void:
	# Arrange: +100 % to read it at once
	_buy(["cadence"])
	var attacks: Array[int] = [0]
	_companions.companion_attacked.connect(func(_id: String, _damage: BigNumber) -> void: attacks[0] += 1)

	# Act
	_companions.tick(1.0)

	# Assert
	assert_int(attacks[0]).is_equal(2)
	assert_str(_companions.damage_per_second("scout").to_decimal_string()).is_equal("200")


func test_synergy_counts_the_companions_at_the_level_and_stops_at_the_max() -> void:
	# Arrange
	_buy(["synergy"])

	# Act / Assert: none at 100, one (4 %), two (8 % cut to 6 %)
	var none: int = _floors.synergy_percent()
	_state.companion_levels = {"scout": 100, "knight": 1}
	var one: int = _floors.synergy_percent()
	var scout_one: String = _companions.damage("scout").to_decimal_string()
	_state.companion_levels = {"scout": 100, "knight": 100}
	assert_int(none).is_equal(0)
	assert_int(one).is_equal(4)
	assert_str(scout_one).is_equal("10400")
	assert_int(_floors.synergy_percent()).is_equal(6)
	assert_str(_companions.damage("scout").to_decimal_string()).is_equal("10600")


func test_champion_raises_the_strongest_companion_only() -> void:
	# Arrange: knight 300 dps beats scout 100
	_state.companion_levels = {"scout": 1, "knight": 1}
	_buy(["champion"])

	# Act / Assert
	assert_str(_floors.strongest_companion_id()).is_equal("knight")
	assert_str(_companions.damage("knight").to_decimal_string()).is_equal("336")
	assert_str(_companions.damage("scout").to_decimal_string()).is_equal("100")


func test_champion_follows_when_another_companion_becomes_stronger() -> void:
	# Arrange
	_state.companion_levels = {"scout": 1, "knight": 1}
	_buy(["champion"])

	# Act: scout at level 4 deals 400, more than the knight
	_state.companion_levels["scout"] = 4

	# Assert
	assert_str(_floors.strongest_companion_id()).is_equal("scout")
	assert_str(_companions.damage("scout").to_decimal_string()).is_equal("448")
	assert_str(_companions.damage("knight").to_decimal_string()).is_equal("300")


func test_companion_cache_follows_a_level_up() -> void:
	# Arrange: knight (300) is the champion, the cache is filled; scout needs 4 levels to pass it
	_state.companion_levels = {"scout": 1, "knight": 1}
	_buy(["champion", "synergy"])
	var power_before: String = _floors.companion_power().to_decimal_string()
	var before: String = _floors.strongest_companion_id()
	_state.gold = BigNumber.from_int(1000000)

	# Act: scout 1 -> 2 (threshold 2), so it awakens next; here only the level moves to 2 = 200 dps
	assert_bool(_companions.buy_levels("scout", 1)).is_true()

	# Assert: the power reads the new level at once
	assert_str(before).is_equal("knight")
	assert_str(power_before).is_equal("436")
	assert_str(_floors.companion_power().to_decimal_string()).is_equal("536")
	assert_str(_floors.strongest_companion_id()).is_equal("knight")


func test_companion_cache_follows_an_awakening() -> void:
	# Arrange: scout at 2 (200 dps) under the knight (300); the cache is filled
	_state.companion_levels = {"scout": 2, "knight": 1}
	_buy(["champion"])
	var before: String = _floors.strongest_companion_id()
	_state.gold = BigNumber.from_int(1000000)

	# Act: the awakening doubles the scout (self multiplier 2): 400 dps
	assert_bool(_companions.awaken("scout")).is_true()

	# Assert
	assert_str(before).is_equal("knight")
	assert_str(_floors.strongest_companion_id()).is_equal("scout")
	assert_str(_companions.damage("scout").to_decimal_string()).is_equal("448")


func test_synergy_cache_follows_a_level_up() -> void:
	# Arrange: scout at 99, one level from the synergy level 100; no threshold in the way
	_state.companion_levels = {"scout": 99, "knight": 1}
	_state.companion_awakenings = {"scout": 1}
	_buy(["synergy"])
	var before: int = _floors.synergy_percent()
	_state.gold = BigNumber.from_int(1000000)

	# Act
	assert_bool(_companions.buy_levels("scout", 1)).is_true()

	# Assert
	assert_int(before).is_equal(0)
	assert_int(_floors.synergy_percent()).is_equal(4)


# --- Flair -----------------------------------------------------------------------------------------

func test_flair_moves_ten_points_of_weight_from_common_to_rare() -> void:
	# Arrange
	var inventory: Inventory = Inventory.from_data(_items_data(90), _permanent, _state, _combat, func() -> float: return 0.0)
	_build(inventory)

	# Act
	_buy(["flair"])

	# Assert
	assert_dict(inventory.table().tier_at(BOSS_EVERY)["weights"]).is_equal({"common": 80, "rare": 20})


func test_flair_with_a_common_weight_of_zero_changes_nothing() -> void:
	# Arrange
	var inventory: Inventory = Inventory.from_data(_items_data(0), _permanent, _state, _combat, func() -> float: return 0.0)
	_build(inventory)

	# Act
	_buy(["flair"])

	# Assert
	assert_dict(inventory.table().tier_at(BOSS_EVERY)["weights"]).is_equal({"common": 0, "rare": 10})


func test_flair_with_a_common_weight_below_ten_moves_only_what_there_is() -> void:
	# Arrange
	var inventory: Inventory = Inventory.from_data(_items_data(4), _permanent, _state, _combat, func() -> float: return 0.0)
	_build(inventory)

	# Act
	_buy(["flair"])

	# Assert: never negative, the sum stays 14
	assert_dict(inventory.table().tier_at(BOSS_EVERY)["weights"]).is_equal({"common": 0, "rare": 14})


func test_flair_reset_gives_the_data_weights_back() -> void:
	# Arrange
	var inventory: Inventory = Inventory.from_data(_items_data(90), _permanent, _state, _combat, func() -> float: return 0.0)
	_build(inventory)
	_buy(["flair"])

	# Act
	_tree.reset()

	# Assert
	assert_dict(inventory.table().tier_at(BOSS_EVERY)["weights"]).is_equal({"common": 90, "rare": 10})


# --- Négociation -----------------------------------------------------------------------------------

func test_haggle_takes_five_percent_off_a_level() -> void:
	# Act
	_buy(["haggle"])

	# Assert: scout level 2 costs 100
	assert_str(_companions.next_cost("scout").to_decimal_string()).is_equal("95")


func test_haggle_keeps_max_and_single_purchases_consistent() -> void:
	# Arrange: gold for exactly one discounted level of knight (level 0 -> 1); the threshold is 2
	_buy(["haggle"])
	_state.companion_levels = {"scout": 1}
	_state.gold = BigNumber.from_int(190)

	# Act
	var count: int = _companions.affordable_levels("knight")
	var walk: Dictionary = _companions.affordable_walk("knight")
	var quoted: String = _companions.cost_of_levels("knight", count).to_decimal_string()
	var bought: bool = _companions.buy_levels("knight", count)

	# Assert: two levels at 95 fit in 190 (they would not at 100) and Max stops at the threshold 2
	assert_int(count).is_equal(2)
	assert_str((walk["total"] as BigNumber).to_decimal_string()).is_equal("190")
	assert_str(quoted).is_equal("190")
	assert_bool(bought).is_true()
	assert_str(_state.gold.to_decimal_string()).is_equal("0")
	assert_int(_companions.buyable_levels_cap("knight")).is_equal(0)


func test_haggle_leaves_the_awakening_cost_unchanged() -> void:
	# Arrange: scout at the threshold 2; awakening = 10 * cost of level 2 = 1000 (Amaury's ruling:
	# Négociation does not touch awakenings); 950 gold is not enough
	_buy(["haggle"])
	_state.companion_levels = {"scout": 2}
	_state.gold = BigNumber.from_int(950)

	# Act
	var cost: String = (_companions.next_awakening("scout")["cost"] as BigNumber).to_decimal_string()
	var can: bool = _companions.can_awaken("scout")
	var awoke: bool = _companions.awaken("scout")

	# Assert
	assert_str(cost).is_equal("1000")
	assert_bool(can).is_false()
	assert_bool(awoke).is_false()
	assert_str(_state.gold.to_decimal_string()).is_equal("950")


# --- Longue veille, Moisson ------------------------------------------------------------------------

func test_vigil_raises_the_offline_cap_to_sixteen_hours() -> void:
	# Arrange
	var away: int = 20 * HOUR
	var before: int = _offline.counted_seconds(1, 1 + away)

	# Act
	_buy(["vigil"])

	# Assert
	assert_int(before).is_equal(12 * HOUR)
	assert_int(_offline.counted_seconds(1, 1 + away)).is_equal(16 * HOUR)


func test_harvest_raises_the_gold_of_farm_kills_only() -> void:
	# Arrange: stage 9 in farm mode (the boss of 10 is next)
	_buy(["harvest"])
	_state.stage = BOSS_EVERY - 1
	_state.farming = true
	_build(null)
	var gained: Array[String] = []
	_floors.enemy_killed.connect(func(_stage: int, gold: BigNumber) -> void: gained.append(gold.to_decimal_string()))

	# Act: a farm kill, then a normal kill
	_floors.apply_damage(BigNumber.from_string(ENEMY_HP))
	_state.farming = false
	_floors.apply_damage(BigNumber.from_string(ENEMY_HP))

	# Assert
	assert_array(gained).is_equal(["1120", "1000"])


# --- Instinct de meute -----------------------------------------------------------------------------

func test_instinct_makes_frenzy_passive_and_cancels_its_mods() -> void:
	# Arrange
	_buy(["frenzy_unlock", "frenzy_long", "frenzy_power"])
	var skills: SkillManager = _make_skills()
	var buff: Skill = skills.skill("damage_buff")

	# Act
	_buy(["instinct"])

	# Assert: always x1.2, nothing to press, durable and ardente cancelled
	assert_bool(skills.is_passive("damage_buff")).is_true()
	assert_bool(skills.can_activate("damage_buff")).is_false()
	assert_bool(skills.activate("damage_buff")).is_false()
	assert_str(skills.effective_amount(buff)).is_equal("1.2")
	assert_str(_floors.buffed_damage(BigNumber.from_int(1000)).to_decimal_string()).is_equal("1200")
	assert_bool(skills.is_passive("gold_bonus")).is_false()


func test_instinct_stops_a_running_frenzy_and_reset_brings_the_button_back() -> void:
	# Arrange: frenzy running at x1.75
	_buy(["frenzy_unlock", "frenzy_power"])
	var skills: SkillManager = _make_skills()
	assert_bool(skills.activate("damage_buff")).is_true()
	_buy(["instinct"])
	var passive_state: Skill.State = skills.skill("damage_buff").state()

	# Act
	_tree.reset()

	# Assert
	assert_int(passive_state).is_equal(Skill.State.READY)
	assert_bool(skills.is_passive("damage_buff")).is_false()
	assert_str(_floors.buffed_damage(BigNumber.from_int(1000)).to_decimal_string()).is_equal("1000")
