extends GdUnitTestSuite
## Unit tests for the click formula of Combat: click_damage_base + floor(sum of click_share_i * dps_i)
## when every companion has a "click_share", the former click_companion_power_factor otherwise.
## Story: production/epics/idle-titans/story-015-hp-segments-click-share.md
## Design: design/economy-rework.md "Clic".

const CLICK_BASE: String = "1"


func _curves(power_factor: String = "") -> Dictionary:
	var curves: Dictionary = {
		"schema_version": Combat.SUPPORTED_CURVES_SCHEMA,
		"enemy_hp_base": "1",
		"enemy_hp_growth": "1",
		"gold_per_kill_base": "1",
		"gold_per_kill_growth": "1",
		"click_damage_base": CLICK_BASE,
	}
	if not power_factor.is_empty():
		curves["click_companion_power_factor"] = power_factor
	return curves


## One companion: level L deals base_damage * L per attack, no tier, one attack per [param interval] seconds.
func _entry(id: String, base_damage: String, share: Variant = null, interval: float = 1.0) -> Dictionary:
	var entry: Dictionary = {
		"id": id,
		"name": id,
		"base_cost": "1",
		"base_damage": base_damage,
		"cost_growth": "1",
		"attack_interval_seconds": interval,
		"tiers": [],
	}
	if share != null:
		entry["click_share"] = share
	return entry


func _combat(entries: Array, power_factor: String = "") -> Combat:
	return Combat.from_data(_curves(power_factor), {"schema_version": 2, "companions": entries})


func _click(combat: Combat, levels: Dictionary) -> String:
	return combat.click_damage(levels).to_decimal_string()


# --- Shares: one floor ---

func test_shares_are_summed_before_a_single_floor() -> void:
	# Arrange: 0.5 * 1 + 0.5 * 1 = 1.0 exactly; flooring each term would give 0 + 0
	var combat: Combat = _combat([_entry("a", "1", "0.5"), _entry("b", "1", "0.5")])

	# Act
	var click: String = _click(combat, {"a": 1, "b": 1})

	# Assert: base 1 + 1
	assert_str(combat.get_error()).is_empty()
	assert_str(click).is_equal("2")


func test_shares_of_different_precision_share_one_floor() -> void:
	# Arrange: 0.25 * 6 + 0.5 * 3 + 1 * 2 = 1.5 + 1.5 + 2 = 5; per-term floors would give 4
	var combat: Combat = _combat([_entry("a", "6", "0.25"), _entry("b", "3", "0.5"), _entry("c", "2", "1")])

	# Act
	var click: String = _click(combat, {"a": 1, "b": 1, "c": 1})

	# Assert
	assert_str(click).is_equal("6")


func test_the_fraction_is_dropped_once_for_shares_of_two_and_three_decimals() -> void:
	# Arrange: 0.45 * 4 + 0.125 * 4 = 1.8 + 0.5 = 2.3; per-term floors would give 1 + 0
	var combat: Combat = _combat([_entry("a", "4", "0.45"), _entry("b", "4", "0.125")])

	# Act
	var click: String = _click(combat, {"a": 1, "b": 1})

	# Assert: base 1 + floor(2.3)
	assert_str(click).is_equal("3")


func test_shares_work_beyond_int64() -> void:
	# Arrange: 0.45 * 10^20 = 45 * 10^18
	var combat: Combat = _combat([_entry("a", "100000000000000000000", "0.45")])

	# Act
	var click: String = _click(combat, {"a": 1})

	# Assert
	assert_str(click).is_equal("45000000000000000001")


func test_share_applies_to_the_floored_damage_per_second() -> void:
	# Arrange: 3 damage every 2 s is floor(1.5) = 1 dps each; with share 1 the click gets 1 + 1, not 1.5 + 1.5
	var combat: Combat = _combat([_entry("a", "3", "1", 2.0), _entry("b", "3", "1", 2.0)])

	# Act
	var click: String = _click(combat, {"a": 1, "b": 1})

	# Assert
	assert_str(click).is_equal("3")


func test_share_follows_the_companion_level() -> void:
	# Arrange: dps is 7 * level
	var combat: Combat = _combat([_entry("a", "7", "1")])

	# Act / Assert
	assert_str(_click(combat, {"a": 3})).is_equal("22")


# --- Shares: edges ---

func test_no_bought_companion_gives_the_base_click_with_shares() -> void:
	# Arrange
	var combat: Combat = _combat([_entry("a", "5", "0.5")])

	# Act / Assert
	assert_str(_click(combat, {})).is_equal(CLICK_BASE)


func test_level_zero_and_unknown_ids_add_nothing() -> void:
	# Arrange
	var combat: Combat = _combat([_entry("a", "5", "1"), _entry("b", "5", "1")])

	# Act: "a" not bought, "ghost" is not in the roster, "b" counts
	var click: String = _click(combat, {"a": 0, "ghost": 9, "b": 2})

	# Assert: base 1 + 5 * 2
	assert_str(click).is_equal("11")


func test_empty_roster_gives_the_base_click() -> void:
	# Arrange: no companion, so no share: the factor is read and has nothing to multiply
	var combat: Combat = _combat([], "0.1")

	# Act / Assert
	assert_str(combat.get_error()).is_empty()
	assert_str(_click(combat, {})).is_equal(CLICK_BASE)


func test_share_zero_adds_nothing() -> void:
	# Arrange
	var combat: Combat = _combat([_entry("a", "50", "0"), _entry("b", "50", "0.00")])

	# Act
	var click: String = _click(combat, {"a": 4, "b": 4})

	# Assert
	assert_str(combat.get_error()).is_empty()
	assert_str(click).is_equal(CLICK_BASE)


func test_share_one_adds_the_whole_damage_per_second() -> void:
	# Arrange
	var combat: Combat = _combat([_entry("a", "50", "1")])

	# Act
	var click: String = _click(combat, {"a": 4})

	# Assert: base 1 + 200
	assert_str(click).is_equal("201")


func test_share_one_written_with_decimals_is_accepted() -> void:
	# Arrange / Act
	var combat: Combat = _combat([_entry("a", "50", "1.00")])

	# Assert
	assert_str(combat.get_error()).is_empty()
	assert_str(_click(combat, {"a": 4})).is_equal("201")


func test_power_factor_is_not_required_when_shares_are_set() -> void:
	# Arrange / Act
	var combat: Combat = _combat([_entry("a", "10", "0.5")])

	# Assert
	assert_bool(combat.is_valid()).is_true()
	assert_str(_click(combat, {"a": 1})).is_equal("6")


func test_shares_win_over_a_power_factor_left_in_the_file() -> void:
	# Arrange: factor 0.9 would give 1 + 9
	var combat: Combat = _combat([_entry("a", "10", "0.5")], "0.9")

	# Act / Assert
	assert_str(_click(combat, {"a": 1})).is_equal("6")


# --- Shares: refused ---

func test_mixed_shares_are_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat([_entry("a", "10", "0.5"), _entry("b", "10")], "0.1")

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).is_equal("companions_roster.json: 'click_share' must be set on every companion or on none (1 of 2 have it)")


func test_mixed_shares_are_refused_whichever_companion_has_one() -> void:
	# Arrange / Act
	var combat: Combat = _combat([_entry("a", "10"), _entry("b", "10", "0.5")])

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).contains("'click_share' must be set on every companion or on none")


func test_share_above_one_is_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat([_entry("a", "10", "1.01")])

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).is_equal("companions_roster.json: 'a' click_share must be a decimal string from 0 to 1, such as \"0.45\"")


func test_malformed_shares_are_refused() -> void:
	# Arrange
	var bad_shares: Array = ["2", "-0.5", ".5", "0.", "abc", "0,5", "", 0.5, 1, true]

	# Act / Assert
	for bad: Variant in bad_shares:
		var combat: Combat = _combat([_entry("a", "10", bad)])
		assert_bool(combat.is_valid()).is_false()
		assert_str(combat.get_error()).contains("a' click_share must be a decimal string from 0 to 1")


# --- Former formula ---

func test_without_shares_the_click_uses_the_power_factor() -> void:
	# Arrange: dps 25 * 0.1 = 2.5, floored to 2
	var combat: Combat = _combat([_entry("a", "25")], "0.1")

	# Act
	var click: String = _click(combat, {"a": 1})

	# Assert
	assert_str(combat.get_error()).is_empty()
	assert_str(click).is_equal("3")


func test_without_shares_the_factor_applies_to_the_total_power() -> void:
	# Arrange: (3 + 3) * 0.25 = 1.5 floors to 1; flooring each companion (0.75 and 0.75) would give 0
	var combat: Combat = _combat([_entry("a", "3"), _entry("b", "3")], "0.25")

	# Act
	var click: String = _click(combat, {"a": 1, "b": 1})

	# Assert: base 1 + floor(1.5)
	assert_str(click).is_equal("2")


func test_without_shares_and_without_factor_is_refused() -> void:
	# Arrange / Act
	var combat: Combat = _combat([_entry("a", "25")])

	# Assert
	assert_bool(combat.is_valid()).is_false()
	assert_str(combat.get_error()).contains("click_companion_power_factor")


func test_without_shares_no_bought_companion_gives_the_base_click() -> void:
	# Arrange
	var combat: Combat = _combat([_entry("a", "25")], "0.1")

	# Act / Assert
	assert_str(_click(combat, {})).is_equal(CLICK_BASE)


func test_click_on_a_combat_with_an_invalid_roster_returns_the_base() -> void:
	# Arrange: valid curves with a factor, but a companion without base_damage: the roster is refused
	var broken: Dictionary = _entry("a", "10")
	broken.erase("base_damage")
	var combat: Combat = _combat([broken], "0.1")
	assert_bool(combat.is_valid()).is_false()

	# Act: the main screen may still query the click before it shows the error
	var click: BigNumber = combat.click_damage({"a": 1})

	# Assert
	assert_object(click).is_not_null()
	assert_str(click.to_decimal_string()).is_equal(CLICK_BASE)


func test_companion_without_share_reports_none() -> void:
	# Arrange
	var combat: Combat = _combat([_entry("a", "25"), _entry("b", "25")], "0.1")

	# Act / Assert
	assert_bool(combat.companion("a").click_share().is_empty()).is_true()
