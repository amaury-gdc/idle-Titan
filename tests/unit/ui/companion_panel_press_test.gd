extends GdUnitTestSuite
## Unit tests for what a press of a companion row buys: what the row displays, even when the gold
## changed since the last redraw, and for the texts of the buy button (two lines since story 019b:
## the cost, then the gain; "Acheter" over the cost at level 0; the whole sentence in its accessible
## name).
## Story: production/epics/idle-titans/story-010-adaptive-layout.md, D3 of
## design/ux/main-screen-adaptive.md; story-019b-mobile-ui-refonte.md (lot 6).

const PANEL_SCENE: String = "res://src/ui/companion_panel.tscn"
const ID: String = "scout"
const SHOWN_LEVELS: int = 3
const FAR_MORE_GOLD: int = 1_000_000

var _state: GameState
var _companions: CompanionManager
var _panel: CompanionPanel
var _requests: Array = []


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
		"companions": [{
			"id": ID,
			"name": "Scout",
			"base_cost": "10",
			"base_damage": "1",
			"cost_growth": "1.08",
			"attack_interval_seconds": 1.0,
			"tiers": [],
		}],
	}
	var combat: Combat = Combat.from_data(curves, roster)
	_state = GameState.new()
	_companions = CompanionManager.new(_state, combat, FloorManager.new(_state, combat))
	_panel = auto_free((load(PANEL_SCENE) as PackedScene).instantiate())
	add_child(_panel)
	_requests = []
	_panel.buy_requested.connect(func(id: String, count: int) -> void: _requests.append([id, count]))
	_panel.setup(_companions, func() -> BigNumber: return _state.gold)


func _button() -> Button:
	return (_panel.get("_rows") as Array)[0]["button"]


func _lines() -> PackedStringArray:
	return _panel.row_lines(0)


func _cost(cost: BigNumber) -> String:
	return CompanionPanel.keep_together(cost.format())


func _show_max_of(levels: int) -> void:
	_state.gold = _companions.cost_of_levels(ID, levels)
	_panel.set_mode(BuyQuote.Mode.MAX)
	_panel.refresh()


func test_press_buys_the_amount_shown_by_the_row() -> void:
	_show_max_of(SHOWN_LEVELS)
	_button().pressed.emit()
	assert_array(_requests).contains_exactly([[ID, SHOWN_LEVELS]])


func test_press_ignores_gold_earned_since_the_last_redraw() -> void:
	_show_max_of(SHOWN_LEVELS)
	_state.gold = BigNumber.from_int(FAR_MORE_GOLD)
	_button().pressed.emit()
	assert_array(_requests).contains_exactly([[ID, SHOWN_LEVELS]])


func test_press_at_max_zero_asks_for_nothing() -> void:
	_show_max_of(0)
	_state.gold = BigNumber.new()
	_panel.refresh()
	_button().pressed.emit()
	assert_array(_requests).is_empty()


func test_button_text_says_the_verb_for_a_first_purchase() -> void:
	# Level 0 reads "Acheter" over the cost; 10 is the count of the x10 mode, so no "×10 · ".
	_state.gold = BigNumber.from_int(FAR_MORE_GOLD)
	_panel.set_mode(BuyQuote.Mode.TEN)
	assert_array(_lines()).is_equal(PackedStringArray(["Acheter", _cost(_companions.cost_of_levels(ID, 10))]))
	assert_str(_button().accessibility_name).starts_with("Acheter Scout ×10 : %s" % _companions.cost_of_levels(ID, 10).format())


func test_button_text_says_the_cost_and_the_gain_of_an_upgrade() -> void:
	_state.companion_levels = {ID: 1}
	_state.gold = BigNumber.from_int(FAR_MORE_GOLD)
	_panel.set_mode(BuyQuote.Mode.TEN)
	var gain: BigNumber = _companions.damage_per_second_at(ID, 11).subtract(_companions.damage_per_second(ID))
	assert_array(_lines()).is_equal(PackedStringArray([_cost(_companions.cost_of_levels(ID, 10)), CompanionPanel.gain_text(gain)]))
	assert_str(_button().accessibility_name).is_equal("Améliorer Scout ×10 : %s, %s" % [_companions.cost_of_levels(ID, 10).format(), CompanionPanel.gain_text(gain)])


func test_button_text_short_of_gold_is_one_line_each_without_what_is_missing() -> void:
	_state.gold = BigNumber.new()
	_panel.set_mode(BuyQuote.Mode.TEN)
	for line: String in _lines():
		assert_str(line).not_contains("\n")
		assert_str(line).not_contains("manque")
	assert_str(_button().accessibility_name).not_contains("manque")


func test_button_text_at_max_zero_names_max_and_the_next_cost() -> void:
	# Nothing to count: no "×0 · "; the accessible name says Max and the price of the next level.
	_state.gold = BigNumber.new()
	_panel.set_mode(BuyQuote.Mode.MAX)
	assert_array(_lines()).is_equal(PackedStringArray(["Acheter", _cost(_companions.next_cost(ID))]))
	assert_str(_button().accessibility_name).starts_with("Acheter Scout Max : %s" % _companions.next_cost(ID).format())
