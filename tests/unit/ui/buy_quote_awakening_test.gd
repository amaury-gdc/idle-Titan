extends GdUnitTestSuite
## Unit tests for the quotes around an awakening threshold (story 017, amends D3): the awakening
## quote at the threshold, x10 and Max stopping at it, Palier aiming at the nearer of the next tier
## and the next threshold, and nothing left once everything is awakened. Also the pure words of the
## awakening ([AwakeningText]) and the first-time flag of [DisplaySettings].
## Story: production/epics/idle-titans/story-017-awakening-ui.md, design/economy-rework.md "Éveil".

const ID: String = "scout"
const TIERS: Array[Dictionary] = [
	{"level": 10, "damage_multiplier": "2"},
	{"level": 25, "damage_multiplier": "2"},
	{"level": 200, "damage_multiplier": "3"},
]
## The block of the design, as in the real roster.
const AWAKENING: Dictionary = {
	"thresholds": [200, 300, 400, 500, 600, 700, 800, 900, 1000],
	"self_multiplier": "3.4",
	"squad_multiplier": "2.10",
	"squad_until_threshold": 600,
	"cost_level_multiplier": "10",
}
const FIRST_THRESHOLD: int = 200
const SECOND_THRESHOLD: int = 300
const LAST_THRESHOLD: int = 1000
const ALL_AWAKENINGS: int = 9
const SETTINGS_PATH: String = "user://buy_quote_awakening_test_settings.cfg"

var _combat: Combat
var _state: GameState
var _companions: CompanionManager


func before_test() -> void:
	# A crashed run may have left the file: every test starts without it.
	_remove_settings()
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
		"awakening": AWAKENING.duplicate(true),
		"companions": [{
			"id": ID,
			"name": "Éclaireur",
			"base_cost": "10",
			"base_damage": "1",
			"cost_growth": "1.08",
			"attack_interval_seconds": 1.0,
			"tiers": TIERS,
		}],
	}
	_combat = Combat.from_data(curves, roster)
	assert_str(_combat.get_error()).is_empty()
	_state = GameState.new()
	_companions = CompanionManager.new(_state, _combat, FloorManager.new(_state, _combat))


func after_test() -> void:
	_remove_settings()


func _remove_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


func _at(level: int, awakenings: int = 0, gold: BigNumber = _plenty()) -> void:
	_state.companion_levels = {ID: level}
	_state.companion_awakenings = {ID: awakenings} if awakenings > 0 else {}
	_state.gold = gold


func _plenty() -> BigNumber:
	return BigNumber.from_string("1" + "0".repeat(80))


func _quote(mode: BuyQuote.Mode) -> BuyQuote:
	return BuyQuote.of(_companions, ID, mode, _state.gold)


func _awakening_cost() -> BigNumber:
	return _companions.next_awakening(ID)["cost"]


func test_one_level_before_the_threshold_still_buys_a_level() -> void:
	_at(FIRST_THRESHOLD - 1)
	var quote: BuyQuote = _quote(BuyQuote.Mode.ONE)
	assert_bool(quote.awakening).is_false()
	assert_int(quote.count).is_equal(1)
	assert_bool(quote.affordable).is_true()


func test_at_the_threshold_every_mode_quotes_the_awakening() -> void:
	_at(FIRST_THRESHOLD)
	for mode: int in BuyQuote.Mode.values():
		var quote: BuyQuote = _quote(mode)
		assert_bool(quote.awakening).is_true()
		assert_int(quote.count).is_equal(0)
		assert_int(quote.cost.compare(_awakening_cost())).is_equal(0)


func test_awakening_cost_is_ten_times_the_cost_of_the_threshold_level() -> void:
	_at(FIRST_THRESHOLD)
	var expected: BigNumber = _combat.companion(ID).cost_of_level(FIRST_THRESHOLD).multiply(BigNumber.from_int(10))
	assert_str(_quote(BuyQuote.Mode.ONE).cost.to_decimal_string()).is_equal(expected.to_decimal_string())


func test_awakening_with_exact_gold_is_affordable() -> void:
	_at(FIRST_THRESHOLD, 0, BigNumber.new())
	_state.gold = _awakening_cost()
	assert_bool(_quote(BuyQuote.Mode.ONE).affordable).is_true()


func test_awakening_one_gold_short_is_not_affordable() -> void:
	_at(FIRST_THRESHOLD, 0, BigNumber.new())
	_state.gold = _awakening_cost().subtract(BigNumber.from_int(1))
	var quote: BuyQuote = _quote(BuyQuote.Mode.MAX)
	assert_bool(quote.awakening).is_true()
	assert_bool(quote.affordable).is_false()


func test_level_201_without_its_awakening_still_quotes_the_awakening() -> void:
	# A save whose level passed the threshold before story 016: it must pay, never buy past it
	_at(FIRST_THRESHOLD + 1)
	var quote: BuyQuote = _quote(BuyQuote.Mode.TEN)
	assert_bool(quote.awakening).is_true()
	assert_int(quote.count).is_equal(0)


func test_level_201_once_awakened_buys_levels_again() -> void:
	_at(FIRST_THRESHOLD + 1, 1)
	var quote: BuyQuote = _quote(BuyQuote.Mode.TEN)
	assert_bool(quote.awakening).is_false()
	assert_int(quote.count).is_equal(BuyQuote.TEN_COUNT)


func test_x10_three_levels_before_the_threshold_quotes_three() -> void:
	# Arrange
	_at(FIRST_THRESHOLD - 3)

	# Act
	var quote: BuyQuote = _quote(BuyQuote.Mode.TEN)

	# Assert: the real number, and the cost of those three levels only
	assert_int(quote.count).is_equal(3)
	assert_int(quote.cost.compare(_companions.cost_of_levels(ID, 3))).is_equal(0)
	assert_bool(quote.affordable).is_true()


func test_max_with_plenty_of_gold_stops_at_the_threshold() -> void:
	_at(150)
	assert_int(_quote(BuyQuote.Mode.MAX).count).is_equal(FIRST_THRESHOLD - 150)


func test_max_buys_what_the_quote_shows_and_lands_on_the_threshold() -> void:
	_at(150)
	var quote: BuyQuote = _quote(BuyQuote.Mode.MAX)
	assert_bool(_companions.buy_levels(ID, quote.count)).is_true()
	assert_int(_companions.level(ID)).is_equal(FIRST_THRESHOLD)
	assert_bool(_quote(BuyQuote.Mode.MAX).awakening).is_true()


func test_tier_aims_at_the_next_threshold_past_the_last_tier() -> void:
	_at(250, 1)
	assert_int(_quote(BuyQuote.Mode.TIER).count).is_equal(SECOND_THRESHOLD - 250)


func test_tier_aims_at_the_tier_when_it_is_nearer() -> void:
	_at(12)
	assert_int(_quote(BuyQuote.Mode.TIER).count).is_equal(25 - 12)


func test_tier_aims_at_the_shared_level_of_the_last_tier_and_the_first_threshold() -> void:
	_at(150)
	assert_int(_quote(BuyQuote.Mode.TIER).count).is_equal(FIRST_THRESHOLD - 150)


func test_level_1000_before_its_last_awakening_quotes_it() -> void:
	_at(LAST_THRESHOLD, ALL_AWAKENINGS - 1)
	assert_bool(_quote(BuyQuote.Mode.ONE).awakening).is_true()


func test_level_1000_fully_awakened_buys_freely_and_tier_quotes_nothing() -> void:
	_at(LAST_THRESHOLD, ALL_AWAKENINGS)
	assert_bool(_quote(BuyQuote.Mode.ONE).awakening).is_false()
	assert_int(_quote(BuyQuote.Mode.TEN).count).is_equal(BuyQuote.TEN_COUNT)
	assert_int(_quote(BuyQuote.Mode.TIER).count).is_equal(0)
	assert_bool(_quote(BuyQuote.Mode.TIER).affordable).is_false()


func test_quote_at_the_threshold_changes_nothing() -> void:
	_at(FIRST_THRESHOLD)
	var gold: String = _state.gold.to_decimal_string()
	_quote(BuyQuote.Mode.MAX)
	assert_str(_state.gold.to_decimal_string()).is_equal(gold)
	assert_int(_companions.awakenings(ID)).is_equal(0)


func test_multiplier_texts_keep_the_digits_of_the_data() -> void:
	assert_str(_companions.awakening_self_text()).is_equal("3,4")
	assert_str(_companions.awakening_squad_text()).is_equal("2,10")


func test_squad_counts_up_to_its_limit_only() -> void:
	_at(600, 4)
	assert_bool(_companions.next_awakening_counts_for_squad(ID)).is_true()
	_at(700, 5)
	assert_bool(_companions.next_awakening_counts_for_squad(ID)).is_false()


func test_roman_numerals_of_the_ranks() -> void:
	var expected: PackedStringArray = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]
	for rank in expected.size():
		assert_str(AwakeningText.roman(rank + 1)).is_equal(expected[rank])


func test_intro_sentence_elides_the_article_before_a_vowel() -> void:
	assert_str(AwakeningText.intro_sentence("Éclaireur")).is_equal("L'Éclaireur s'éveille : toute l'escouade redouble de force.")
	assert_str(AwakeningText.intro_sentence("Archer")).is_equal("L'Archer s'éveille : toute l'escouade redouble de force.")
	assert_str(AwakeningText.intro_sentence("Dragon")).is_equal("Le Dragon s'éveille : toute l'escouade redouble de force.")


func test_intro_is_taken_once_and_stays_taken_after_a_reload() -> void:
	# Arrange
	var settings: DisplaySettings = DisplaySettings.new(SETTINGS_PATH)

	# Act
	var first: bool = AwakeningText.take_intro(settings)
	var second: bool = AwakeningText.take_intro(settings)
	var after_reload: bool = AwakeningText.take_intro(DisplaySettings.new(SETTINGS_PATH))

	# Assert
	assert_bool(first).is_true()
	assert_bool(second).is_false()
	assert_bool(after_reload).is_false()
