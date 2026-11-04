extends GdUnitTestSuite
## Unit tests for the amounts of the x1 / x10 / x100 / Max modes: strict x10 and x100, real Max, that
## a quote spends exactly what it says, and the order of the one buy mode button. The Palier mode:
## buy_quote_tier_test.gd.
## Stories: production/epics/idle-titans/story-010-adaptive-layout.md, D3 of
## design/ux/main-screen-adaptive.md; story-019b-mobile-ui-refonte.md (x100, cycle).

const ID: String = "scout"
const SEVEN_LEVELS: int = 7
const LATER_LEVEL: int = 23
const TIER_LEVEL: int = 10

var _state: GameState
var _companions: CompanionManager


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
			"tiers": [{"level": TIER_LEVEL, "damage_multiplier": "2"}],
		}],
	}
	var combat: Combat = Combat.from_data(curves, roster)
	_state = GameState.new()
	_companions = CompanionManager.new(_state, combat, FloorManager.new(_state, combat))


func _quote(mode: BuyQuote.Mode) -> BuyQuote:
	return BuyQuote.of(_companions, ID, mode, _state.gold)


func _assert_same(actual: BigNumber, expected: BigNumber) -> void:
	assert_str(actual.format()).is_equal(expected.format())
	assert_int(actual.compare(expected)).is_equal(0)


func _one() -> BigNumber:
	return BigNumber.from_int(1)


func test_x1_quotes_the_next_level() -> void:
	_state.gold = _companions.next_cost(ID)
	var quote: BuyQuote = _quote(BuyQuote.Mode.ONE)
	assert_int(quote.count).is_equal(1)
	_assert_same(quote.cost, _companions.next_cost(ID))
	assert_bool(quote.affordable).is_true()


func test_x1_short_of_gold_is_not_affordable() -> void:
	_state.gold = _companions.next_cost(ID).subtract(_one())
	var quote: BuyQuote = _quote(BuyQuote.Mode.ONE)
	assert_bool(quote.affordable).is_false()


func test_x10_with_exact_gold_is_affordable() -> void:
	_state.gold = _companions.cost_of_levels(ID, BuyQuote.TEN_COUNT)
	var quote: BuyQuote = _quote(BuyQuote.Mode.TEN)
	assert_int(quote.count).is_equal(BuyQuote.TEN_COUNT)
	_assert_same(quote.cost, _state.gold)
	assert_bool(quote.affordable).is_true()


func test_x10_one_gold_short_is_strict_and_keeps_the_total() -> void:
	var total: BigNumber = _companions.cost_of_levels(ID, BuyQuote.TEN_COUNT)
	_state.gold = total.subtract(_one())
	var quote: BuyQuote = _quote(BuyQuote.Mode.TEN)
	assert_int(quote.count).is_equal(BuyQuote.TEN_COUNT)
	assert_bool(quote.affordable).is_false()
	_assert_same(quote.cost, total)


func test_x100_with_exact_gold_is_affordable() -> void:
	_state.gold = _companions.cost_of_levels(ID, BuyQuote.HUNDRED_COUNT)
	var quote: BuyQuote = _quote(BuyQuote.Mode.HUNDRED)
	assert_int(quote.count).is_equal(BuyQuote.HUNDRED_COUNT)
	_assert_same(quote.cost, _state.gold)
	assert_bool(quote.affordable).is_true()


func test_x100_one_gold_short_is_strict_and_keeps_the_total() -> void:
	var total: BigNumber = _companions.cost_of_levels(ID, BuyQuote.HUNDRED_COUNT)
	_state.gold = total.subtract(_one())
	var quote: BuyQuote = _quote(BuyQuote.Mode.HUNDRED)
	assert_int(quote.count).is_equal(BuyQuote.HUNDRED_COUNT)
	assert_bool(quote.affordable).is_false()
	_assert_same(quote.cost, total)


func test_cycle_goes_x1_x10_x100_max_palier_and_back() -> void:
	var walked: Array = []
	var mode: int = BuyQuote.Mode.ONE
	for i in BuyQuote.MODE_COUNT:
		mode = BuyQuote.next_mode(mode)
		walked.append(mode)
	assert_array(walked).is_equal([BuyQuote.Mode.TEN, BuyQuote.Mode.HUNDRED, BuyQuote.Mode.MAX, BuyQuote.Mode.TIER, BuyQuote.Mode.ONE])


func test_cycle_holds_every_mode_once() -> void:
	assert_int(BuyQuote.CYCLE.size()).is_equal(BuyQuote.MODE_COUNT)
	for mode: int in BuyQuote.Mode.values():
		assert_int(BuyQuote.CYCLE.count(mode)).is_equal(1)


func test_max_counts_the_real_levels_and_their_cost() -> void:
	var total: BigNumber = _companions.cost_of_levels(ID, SEVEN_LEVELS)
	_state.gold = total
	var quote: BuyQuote = _quote(BuyQuote.Mode.MAX)
	assert_int(quote.count).is_equal(SEVEN_LEVELS)
	_assert_same(quote.cost, total)
	assert_bool(quote.affordable).is_true()


func test_max_at_zero_quotes_the_next_cost_and_is_disabled() -> void:
	var next: BigNumber = _companions.next_cost(ID)
	_state.gold = next.subtract(_one())
	var quote: BuyQuote = _quote(BuyQuote.Mode.MAX)
	assert_int(quote.count).is_equal(0)
	assert_bool(quote.affordable).is_false()
	_assert_same(quote.cost, next)


func test_max_quote_spends_exactly_what_it_shows() -> void:
	_state.gold = _companions.cost_of_levels(ID, SEVEN_LEVELS).add(_one())
	var quote: BuyQuote = _quote(BuyQuote.Mode.MAX)
	var left: BigNumber = _state.gold.subtract(quote.cost)
	assert_bool(_companions.buy_levels(ID, quote.count)).is_true()
	_assert_same(_state.gold, left)
	assert_int(_companions.level(ID)).is_equal(SEVEN_LEVELS)


func _sum_of_levels(first: int, count: int) -> BigNumber:
	var companion: Companion = _companions.companions()[0]
	var total: BigNumber = BigNumber.new()
	for level in range(first, first + count):
		total = total.add(companion.cost_of_level(level))
	return total


func test_x10_from_a_later_level_is_the_sum_of_those_levels() -> void:
	_state.companion_levels = {ID: LATER_LEVEL}
	_state.gold = _sum_of_levels(LATER_LEVEL + 1, BuyQuote.TEN_COUNT)
	var quote: BuyQuote = _quote(BuyQuote.Mode.TEN)
	_assert_same(quote.cost, _state.gold)
	assert_bool(quote.affordable).is_true()


func test_max_from_a_later_level_is_counted_from_that_level() -> void:
	_state.companion_levels = {ID: LATER_LEVEL}
	var total: BigNumber = _sum_of_levels(LATER_LEVEL + 1, SEVEN_LEVELS)
	_state.gold = total
	var quote: BuyQuote = _quote(BuyQuote.Mode.MAX)
	assert_int(quote.count).is_equal(SEVEN_LEVELS)
	_assert_same(quote.cost, total)


func test_max_at_zero_from_a_later_level_quotes_the_level_after_it() -> void:
	_state.companion_levels = {ID: LATER_LEVEL}
	var next: BigNumber = _sum_of_levels(LATER_LEVEL + 1, 1)
	_state.gold = next.subtract(_one())
	var quote: BuyQuote = _quote(BuyQuote.Mode.MAX)
	assert_int(quote.count).is_equal(0)
	_assert_same(quote.cost, next)


func test_walk_gives_the_same_count_as_the_plain_scan() -> void:
	_state.companion_levels = {ID: LATER_LEVEL}
	_state.gold = _sum_of_levels(LATER_LEVEL + 1, SEVEN_LEVELS).add(_one())
	assert_int(_companions.affordable_walk(ID)["count"]).is_equal(_companions.affordable_levels(ID))


func test_walk_of_an_unknown_id_counts_nothing() -> void:
	_state.gold = BigNumber.from_int(1000)
	assert_int(_companions.affordable_walk("nobody")["count"]).is_equal(0)


func test_tier_levels_come_from_the_roster() -> void:
	assert_array(_companions.tier_levels(ID)).contains_exactly([TIER_LEVEL])


func test_quote_changes_nothing() -> void:
	_state.gold = _companions.cost_of_levels(ID, SEVEN_LEVELS)
	var before: BigNumber = _state.gold
	_quote(BuyQuote.Mode.MAX)
	_assert_same(_state.gold, before)
	assert_int(_companions.level(ID)).is_equal(0)
