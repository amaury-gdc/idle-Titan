extends GdUnitTestSuite
## Unit tests for the damage buff of the active skills.
## Story: production/epics/idle-titans/story-005-skills.md

const BUFF: String = "1.5"


func _make_floors() -> FloorManager:
	# Enemies with plenty of HP, so no hit kills and every hit lands on the same enemy.
	var curves: Dictionary = {
		"schema_version": Combat.SUPPORTED_CURVES_SCHEMA,
		"enemy_hp_base": "1000",
		"enemy_hp_growth": "1",
		"gold_per_kill_base": "1",
		"gold_per_kill_growth": "1",
		"click_damage_base": "1",
		"click_companion_power_factor": "0",
	}
	var roster: Dictionary = {"schema_version": 2, "companions": []}
	return FloorManager.new(GameState.new(), Combat.from_data(curves, roster))


func test_buff_on_one_damage_hit_deals_more_than_one() -> void:
	# Arrange: floor(1 * 1.5) is 1, the buff must still show on the smallest hit
	var floors: FloorManager = _make_floors()
	var max_hp: BigNumber = floors.current_hp()
	floors.set_damage_multiplier(BUFF)

	# Act
	floors.apply_damage(BigNumber.from_int(1))

	# Assert
	assert_str(max_hp.subtract(floors.current_hp()).to_decimal_string()).is_equal("2")


func test_buff_on_big_hit_multiplies_it() -> void:
	# Arrange
	var floors: FloorManager = _make_floors()
	var max_hp: BigNumber = floors.current_hp()
	floors.set_damage_multiplier(BUFF)

	# Act
	floors.apply_damage(BigNumber.from_int(100))

	# Assert
	assert_str(max_hp.subtract(floors.current_hp()).to_decimal_string()).is_equal("150")


func test_buff_multiplier_of_one_is_refused() -> void:
	# Arrange: with the damage floor, "1.0" would act as +1 per hit instead of no buff
	var entry: Dictionary = {
		"id": "damage_buff",
		"name": "Frénésie",
		"effect": "damage_multiplier",
		"multiplier": "1.0",
		"duration_seconds": 15,
		"cooldown_seconds": 90,
	}

	# Act
	var skill: Skill = Skill.from_entry(entry)

	# Assert
	assert_bool(skill.is_valid()).is_false()


func test_without_buff_damage_is_unchanged() -> void:
	# Arrange
	var floors: FloorManager = _make_floors()
	var max_hp: BigNumber = floors.current_hp()

	# Act
	floors.apply_damage(BigNumber.from_int(1))

	# Assert
	assert_str(max_hp.subtract(floors.current_hp()).to_decimal_string()).is_equal("1")
