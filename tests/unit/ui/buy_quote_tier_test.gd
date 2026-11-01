extends GdUnitTestSuite
## Unit tests for the Palier segment: exactly the levels up to the next tier, all or nothing, spending
## the exact sum of single purchases; nothing past the last tier; the other segments unchanged.
## Story: production/epics/idle-titans/story-013-companion-touch-ups.md, D3 of
## design/ux/main-screen-adaptive.md.

const ID: String = "scout"
const BARE_ID: String = "bare"
const TIERS: Array[Dictionary] = [
	{"level": 10, "damage_multiplier": "2"},
	{"level": 25, "damage_multiplier": "2"},
	{"level": 200, "damage_multiplier": "3"},
]
const LAST_TIER: int = 200

var _state: GameState
var _companions: CompanionManager


func before_test() -> void:
	var built: Array = _build()
	_state = built[0]
	_companions = built[1]


func _build() -> Array:
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
		"companions": [_entry(ID, TIERS), _entry(BARE_ID, [])],
	}
	var combat: Combat = Combat.from_data(curves, roster)
	var state: GameState = GameState.new()
	return [state, CompanionManager.new(state, combat, FloorManager.new(state, combat))]


func _entry(id: String, tiers: Array) -> Dictionary:
	return {
		"id": id,
		"name": id,
		"base_cost": "10",
		"base_damage": "1",
		"cost_growth": "1.08",
		"attack_interval_seconds": 1.0,
		"tiers": tiers,
	}


func _quote(mode: BuyQuote.Mode = BuyQuote.Mode.TIER, id: String = ID) -> BuyQuote:
	return BuyQuote.of(_companions, id, mode, _state.gold)


func _assert_same(actual: BigNumber, expected: BigNumber) -> void:
	assert_str(actual.format()).is_equal(expected.format())
	assert_int(actual.compare(expected)).is_equal(0)


# What N presses of a single purchase spend from [param level], on a game of its own.
func _spent_by_single_purchases(level: int, presses: int) -> BigNumber:
	var built: Array = _build()
	var state: GameState = built[0]
	var companions: CompanionManager = built[1]
	state.companion_levels = {ID: level}
	var before: BigNumber = companions.cost_of_levels(ID, presses).multiply(BigNumber.from_int(2))
	state.gold = before
	for i in presses:
		assert_bool(companions.buy_or_upgrade(ID)).is_true()
	return before.subtract(state.gold)


func test_tier_from_level_0_counts_the_levels_to_the_first_tier() -> void:
	assert_int(_quote().count).is_equal(10)


func test_tier_from_a_tier_counts_the_levels_to_the_following_one() -> void:
	_state.companion_levels = {ID: 10}
	assert_int(_quote().count).is_equal(15)


func test_tier_one_level_before_a_tier_counts_one() -> void:
	_state.companion_levels = {ID: 199}
	assert_int(_quote().count).is_equal(1)


func test_tier_quotes_the_sum_of_the_single_purchases() -> void:
	_state.companion_levels = {ID: 25}
	var expected: BigNumber = _spent_by_single_purchases(25, 175)
	_assert_same(_quote().cost, expected)


func test_tier_spends_exactly_the_sum_of_the_single_purchases() -> void:
	# Arrange
	_state.companion_levels = {ID: 10}
	var spent: BigNumber = _spent_by_single_purchases(10, 15)
	var extra: BigNumber = BigNumber.from_int(7)
	_state.gold = spent.add(extra)

	# Act
	var quote: BuyQuote = _quote()
	var bought: bool = _companions.buy_levels(ID, quote.count)

	# Assert
	assert_bool(bought).is_true()
	assert_int(_companions.level(ID)).is_equal(25)
	_assert_same(_state.gold, extra)


func test_tier_with_exact_gold_is_affordable_and_leaves_nothing() -> void:
	_state.gold = _companions.cost_of_levels(ID, 10)
	var quote: BuyQuote = _quote()
	assert_bool(quote.affordable).is_true()
	assert_bool(_companions.buy_levels(ID, quote.count)).is_true()
	assert_bool(_state.gold.is_zero()).is_true()


func test_tier_one_gold_short_buys_nothing_and_keeps_the_total() -> void:
	var total: BigNumber = _companions.cost_of_levels(ID, 10)
	_state.gold = total.subtract(BigNumber.from_int(1))
	var quote: BuyQuote = _quote()
	assert_int(quote.count).is_equal(10)
	assert_bool(quote.affordable).is_false()
	_assert_same(quote.cost, total)


func test_tier_on_the_last_tier_quotes_nothing() -> void:
	_state.companion_levels = {ID: LAST_TIER}
	_state.gold = BigNumber.from_string("1" + "0".repeat(60))
	var quote: BuyQuote = _quote()
	assert_int(quote.count).is_equal(0)
	assert_bool(quote.affordable).is_false()


func test_tier_past_the_last_tier_quotes_nothing() -> void:
	_state.companion_levels = {ID: LAST_TIER + 50}
	_state.gold = BigNumber.from_string("1" + "0".repeat(60))
	var quote: BuyQuote = _quote()
	assert_int(quote.count).is_equal(0)
	assert_bool(quote.affordable).is_false()


func test_tier_of_a_companion_without_tiers_quotes_nothing() -> void:
	_state.gold = BigNumber.from_string("1" + "0".repeat(60))
	var quote: BuyQuote = _quote(BuyQuote.Mode.TIER, BARE_ID)
	assert_int(quote.count).is_equal(0)
	assert_bool(quote.affordable).is_false()


func test_tier_quote_changes_nothing() -> void:
	_state.gold = _companions.cost_of_levels(ID, 10)
	var before: BigNumber = _state.gold
	_quote()
	_assert_same(_state.gold, before)
	assert_int(_companions.level(ID)).is_equal(0)


func test_x1_is_unchanged_with_tiers_around() -> void:
	_state.companion_levels = {ID: 9}
	_state.gold = _companions.next_cost(ID)
	var quote: BuyQuote = _quote(BuyQuote.Mode.ONE)
	assert_int(quote.count).is_equal(1)
	_assert_same(quote.cost, _companions.next_cost(ID))
	assert_bool(quote.affordable).is_true()


func test_x10_is_unchanged_with_tiers_around() -> void:
	_state.companion_levels = {ID: 9}
	_state.gold = _companions.cost_of_levels(ID, BuyQuote.TEN_COUNT)
	var quote: BuyQuote = _quote(BuyQuote.Mode.TEN)
	assert_int(quote.count).is_equal(BuyQuote.TEN_COUNT)
	_assert_same(quote.cost, _state.gold)
	assert_bool(quote.affordable).is_true()


func test_max_is_unchanged_with_tiers_around() -> void:
	_state.companion_levels = {ID: 9}
	_state.gold = _companions.cost_of_levels(ID, 3)
	var quote: BuyQuote = _quote(BuyQuote.Mode.MAX)
	assert_int(quote.count).is_equal(3)
	_assert_same(quote.cost, _state.gold)


func test_x1_and_x10_and_max_still_buy_past_the_last_tier() -> void:
	_state.companion_levels = {ID: LAST_TIER}
	_state.gold = _companions.cost_of_levels(ID, BuyQuote.TEN_COUNT)
	assert_bool(_quote(BuyQuote.Mode.ONE).affordable).is_true()
	assert_bool(_quote(BuyQuote.Mode.TEN).affordable).is_true()
	assert_int(_quote(BuyQuote.Mode.MAX).count).is_equal(BuyQuote.TEN_COUNT)
