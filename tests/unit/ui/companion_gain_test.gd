extends GdUnitTestSuite
## Unit tests for the "+X DPS" of the companion buy button (story 019b, lot 6): what the button shows
## before a press equals the gain of damage per second measured after the purchase it makes, in every
## mode, from level 0, across a tier, at an awakening threshold, with the companion talents and
## "Cadence". "Champion" is left out on purpose: a purchase that changes the strongest companion moves
## the damage of another one, which the button of this one does not foresee (see CompanionPanel).
## Story: production/epics/idle-titans/story-019b-mobile-ui-refonte.md

const PANEL_SCENE: String = "res://src/ui/companion_panel.tscn"
const ID: String = "scout"
const OTHER_ID: String = "archer"
const TIER_LEVEL: int = 10
const FIRST_THRESHOLD: int = 200
const MAX_LEVELS: int = 7
const COMPANION_TALENT: String = "1.25"
const CADENCE_PERCENT: int = 15

var _state: GameState
var _floors: FloorManager
var _companions: CompanionManager
var _panel: CompanionPanel


func before_test() -> void:
	var curves: Dictionary = {
		"schema_version": Combat.SUPPORTED_CURVES_SCHEMA,
		"enemy_hp_base": "1000",
		"enemy_hp_growth": "1",
		"gold_per_kill_base": "1",
		"gold_per_kill_growth": "1",
		"click_damage_base": "1",
		"click_companion_power_factor": "0",
		"cost_growth": "1.08",
		"offline_efficiency": "0.5",
		"offline_max_hours": 12,
		"offline_min_seconds": 60,
	}
	var roster: Dictionary = {
		"schema_version": 2,
		"awakening": {"thresholds": [FIRST_THRESHOLD, 300], "self_multiplier": "3.4", "squad_multiplier": "2.10",
				"squad_until_threshold": 300, "cost_level_multiplier": "10"},
		"companions": [_entry(ID, "7"), _entry(OTHER_ID, "30")],
	}
	var combat: Combat = Combat.from_data(curves, roster)
	_state = GameState.new()
	_floors = FloorManager.new(_state, combat)
	_companions = CompanionManager.new(_state, combat, _floors)
	_panel = auto_free((load(PANEL_SCENE) as PackedScene).instantiate())
	add_child(_panel)
	_panel.setup(_companions, func() -> BigNumber: return _state.gold)


func _entry(id: String, damage: String) -> Dictionary:
	return {"id": id, "name": id, "base_cost": "10", "base_damage": damage, "cost_growth": "1.08",
			"attack_interval_seconds": 1.3, "tiers": [{"level": TIER_LEVEL, "damage_multiplier": "2"}]}


func _plenty() -> BigNumber:
	return BigNumber.from_string("1" + "0".repeat(60))


func _at(level: int, mode: BuyQuote.Mode, gold: BigNumber = _plenty()) -> void:
	_state.companion_levels[ID] = level
	_state.gold = gold
	_panel.set_mode(mode)
	_panel.refresh()


# Buys what the row shows, and returns the real gain of damage per second of the companion.
func _buy_what_is_shown() -> BigNumber:
	var count: int = (_panel.get("_rows") as Array)[0]["count"]
	var before: BigNumber = _companions.damage_per_second(ID)
	assert_bool(_companions.buy_levels(ID, count)).override_failure_message("the purchase failed").is_true()
	return _companions.damage_per_second(ID).subtract(before)


# The gain the button shows: its bottom line from level 1 on, its accessible name at level 0.
func _shown(level: int) -> String:
	if level == 0:
		return (((_panel.get("_rows") as Array)[0]["button"]) as Button).accessibility_name
	return _panel.row_lines(0)[1]


func _assert_shown_gain_is_the_real_one(level: int, mode: BuyQuote.Mode) -> void:
	_at(level, mode)
	var shown: String = _shown(level)
	var real: BigNumber = _buy_what_is_shown()
	assert_bool(real.is_zero()).override_failure_message("no gain at all: the case proves nothing").is_false()
	assert_str(shown).ends_with(CompanionPanel.gain_text(real))


func test_x1_shows_the_gain_of_its_level() -> void:
	_assert_shown_gain_is_the_real_one(5, BuyQuote.Mode.ONE)


func test_x10_across_a_tier_shows_the_gain_of_the_ten_levels() -> void:
	# From 5 to 15: the tier of level 10 doubles the damage on the way
	_assert_shown_gain_is_the_real_one(5, BuyQuote.Mode.TEN)


func test_x100_shows_the_gain_of_the_hundred_levels() -> void:
	_assert_shown_gain_is_the_real_one(20, BuyQuote.Mode.HUNDRED)


func test_max_shows_the_gain_of_the_levels_the_gold_covers() -> void:
	# Arrange: gold for exactly MAX_LEVELS levels from 30
	_state.companion_levels[ID] = 30
	var gold: BigNumber = _companions.cost_of_levels(ID, MAX_LEVELS)

	# Act
	_at(30, BuyQuote.Mode.MAX, gold)
	var shown: String = _shown(30)
	var real: BigNumber = _buy_what_is_shown()

	# Assert
	assert_int(_companions.level(ID)).is_equal(30 + MAX_LEVELS)
	assert_str(shown).is_equal(CompanionPanel.keep_together("×%d ·" % MAX_LEVELS) + " " + CompanionPanel.gain_text(real))


func test_palier_shows_the_gain_up_to_the_tier() -> void:
	_assert_shown_gain_is_the_real_one(3, BuyQuote.Mode.TIER)


func test_first_purchase_shows_the_gain_of_level_1_in_its_accessible_name() -> void:
	_assert_shown_gain_is_the_real_one(0, BuyQuote.Mode.ONE)


func test_first_ten_levels_show_their_gain_in_the_accessible_name() -> void:
	_assert_shown_gain_is_the_real_one(0, BuyQuote.Mode.TEN)


func test_x10_cut_by_a_threshold_shows_the_gain_of_the_levels_left() -> void:
	_assert_shown_gain_is_the_real_one(FIRST_THRESHOLD - 3, BuyQuote.Mode.TEN)


func test_gain_after_an_awakening_counts_it() -> void:
	_state.companion_awakenings = {ID: 1}
	_assert_shown_gain_is_the_real_one(FIRST_THRESHOLD + 4, BuyQuote.Mode.TEN)


func test_gain_counts_the_companion_talents_and_cadence() -> void:
	_floors.set_talent_modifiers("1", COMPANION_TALENT, "1")
	_floors.set_talent_effects("1", "1", 0, CADENCE_PERCENT, 0.0)
	_assert_shown_gain_is_the_real_one(5, BuyQuote.Mode.TEN)


func test_talent_bought_after_a_redraw_updates_the_gain_at_the_same_level() -> void:
	# Arrange: drawn once without the talent
	_at(5, BuyQuote.Mode.TEN)
	var before: String = _shown(5)

	# Act: the talent comes, nothing else moves
	_floors.set_talent_modifiers("1", COMPANION_TALENT, "1")
	_panel.refresh()
	var shown: String = _shown(5)
	var real: BigNumber = _buy_what_is_shown()

	# Assert
	assert_str(shown).is_not_equal(before)
	assert_str(shown).ends_with(CompanionPanel.gain_text(real))


func test_gain_of_one_companion_ignores_the_others() -> void:
	_state.companion_levels[OTHER_ID] = 40
	_assert_shown_gain_is_the_real_one(12, BuyQuote.Mode.TEN)
