extends GdUnitTestSuite
## Unit tests for the visual feedback: the display signals of the core, the pool of floating
## texts, the rate limit of the companion balls, the "Effets visuels" setting, and the proof that
## none of it changes the damage, the gold or the save.
## Story: production/epics/idle-titans/story-009-visual-feedback.md

const ENEMY_HP: String = "50"
const CLICK_BASE: String = "20"
const COMPANION_DAMAGE: String = "5"
const GOLD_PER_KILL: String = "7"
const BOSS_STAGE: int = 10
const NORMAL_STAGE: int = 1
const BUFF_FACTOR: String = "2"
const BUFFED_CLICK: String = "40"
const CRIT_FACTOR: String = "2.00"
const CRITICAL_CLICK: String = "40"
const ALWAYS_CRITICAL: int = 100
const SOMETIMES_CRITICAL: int = 50
const OVERKILL: int = 1_000_000
const DIE_HIT: float = 0.0
const DICE_SEED: int = 20261031
const SCENARIO_CLICKS: int = 40
const SCENARIO_FRAME_SECONDS: float = 0.5
const SETTINGS_PATH: String = "user://visual_feedback_test_settings.cfg"
const REAL_ROSTER_PATH: String = "res://assets/data/companions_roster.json"
## A frame short enough for the animation not to clamp it.
const SHORT_FRAME: float = 0.1
## More than the seconds of any text or ball.
const LONG_FRAME: float = 100.0
## More hits than the pool holds.
const MANY_TEXTS: int = 40
## More companions than the balls can hold.
const MANY_COMPANIONS: int = 30
const FIRST_ID: String = "first"
const SECOND_ID: String = "second"
const UNIQUE_DAMAGE: int = 987

var _die: float = DIE_HIT


func before_test() -> void:
	_die = DIE_HIT
	_remove_settings_file()


func after_test() -> void:
	_remove_settings_file()


func _remove_settings_file() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _dice() -> float:
	return _die


func _new_combat() -> Combat:
	var combat: Combat = Combat.from_data({
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
	}, {
		"schema_version": 2,
		"companions": [{
			"id": FIRST_ID,
			"name": "Premier",
			"base_cost": "10",
			"base_damage": COMPANION_DAMAGE,
			"cost_growth": "1.08",
			"attack_interval_seconds": 1.0,
			"tiers": [],
		}],
	})
	assert_str(combat.get_error()).is_empty()
	return combat


func _new_boss() -> BossFight:
	var boss: BossFight = BossFight.from_data({
		"schema_version": BossFight.SUPPORTED_SCHEMA,
		"boss_every_stages": BOSS_STAGE,
		"timer_seconds": 30,
		"boss_hp_multiplier": "2",
		"boss_gold_base": "2000",
		"boss_gold_growth": "1",
		"auto_challenge_margin": "1.2",
	})
	assert_str(boss.get_error()).is_empty()
	return boss


func _new_state(stage: int) -> GameState:
	var state: GameState = GameState.new()
	state.stage = stage
	state.max_stage_reached = stage
	state.companion_levels = {FIRST_ID: 1}
	return state


func _new_floors(state: GameState, permanent: PermanentState = null) -> FloorManager:
	return FloorManager.new(state, _new_combat(), _new_boss(), permanent)


func _new_layer() -> FloatingTextLayer:
	return auto_free(FloatingTextLayer.new())


func _new_orbs(ids: Array[String]) -> CompanionOrbs:
	var orbs: CompanionOrbs = auto_free(CompanionOrbs.new())
	var entries: Array = []
	for id: String in ids:
		entries.append({"id": id, "color": "#4fc3f7"})
	orbs.setup({"companions": entries})
	for id: String in ids:
		orbs.set_level(id, 1)
	return orbs


func _damage() -> BigNumber:
	return BigNumber.from_int(1)


func _label(layer: FloatingTextLayer, index: int) -> Label:
	return layer.get_child(index) as Label


# --- Core display signals ------------------------------------------------------------------


func test_click_hit_landed_carries_the_buffed_damage_and_click_keeps_its_return_value() -> void:
	var floors: FloorManager = _new_floors(_new_state(NORMAL_STAGE))
	floors.set_damage_multiplier(BUFF_FACTOR)
	var hits: Array = []
	floors.hit_landed.connect(func(damage: BigNumber, source: int) -> void: hits.append([damage.to_decimal_string(), source]))

	var returned: BigNumber = floors.click()

	assert_str(returned.to_decimal_string()).is_equal(CLICK_BASE)
	assert_array(hits).is_equal([[BUFFED_CLICK, FloorManager.HitSource.CLICK]])


func test_killing_click_emits_hit_landed_too() -> void:
	var floors: FloorManager = _new_floors(_new_state(NORMAL_STAGE))
	var hits: Array = []
	floors.hit_landed.connect(func(damage: BigNumber, _source: int) -> void: hits.append(damage.to_decimal_string()))
	var kills: Array = []
	floors.enemy_killed.connect(func(stage: int, _gold: BigNumber) -> void: kills.append(stage))
	floors.apply_damage(BigNumber.from_string(ENEMY_HP).subtract(BigNumber.from_int(1)))
	hits.clear()

	floors.click()

	assert_array(kills).is_equal([NORMAL_STAGE])
	assert_array(hits).is_equal([CLICK_BASE])


func test_critical_click_has_critical_source_and_keeps_critical_hit_signal() -> void:
	var floors: FloorManager = _new_floors(_new_state(NORMAL_STAGE))
	floors.set_item_modifiers("1", "1", "1", ALWAYS_CRITICAL, CRIT_FACTOR)
	floors.set_crit_roll(_dice)
	var hits: Array = []
	floors.hit_landed.connect(func(damage: BigNumber, source: int) -> void: hits.append([damage.to_decimal_string(), source]))
	var criticals: Array = []
	floors.critical_hit.connect(func(damage: BigNumber) -> void: criticals.append(damage.to_decimal_string()))

	floors.click()

	assert_array(hits).is_equal([[CRITICAL_CLICK, FloorManager.HitSource.CRITICAL]])
	assert_array(criticals).is_equal([CRITICAL_CLICK])


func test_apply_damage_defaults_to_auto_and_passes_burst() -> void:
	var floors: FloorManager = _new_floors(_new_state(NORMAL_STAGE))
	var sources: Array = []
	floors.hit_landed.connect(func(_damage: BigNumber, source: int) -> void: sources.append(source))

	floors.apply_damage(_damage())
	floors.apply_damage(_damage(), FloorManager.HitSource.BURST)

	assert_array(sources).is_equal([FloorManager.HitSource.AUTO, FloorManager.HitSource.BURST])


func test_kill_rewarded_gives_the_gold_really_granted_for_a_normal_enemy() -> void:
	var state: GameState = _new_state(NORMAL_STAGE)
	var floors: FloorManager = _new_floors(state)
	var kills: Array = []
	floors.kill_rewarded.connect(func(stage: int, gold: BigNumber, was_boss: bool) -> void: kills.append([stage, gold.to_decimal_string(), was_boss]))

	floors.apply_damage(BigNumber.from_int(OVERKILL))

	assert_array(kills).is_equal([[NORMAL_STAGE, state.gold.to_decimal_string(), false]])


func test_kill_rewarded_says_boss_even_when_the_next_stage_is_a_normal_one() -> void:
	var state: GameState = _new_state(BOSS_STAGE)
	var floors: FloorManager = _new_floors(state)
	var flags: Array = []
	floors.kill_rewarded.connect(func(_stage: int, _gold: BigNumber, was_boss: bool) -> void: flags.append(was_boss))

	floors.apply_damage(BigNumber.from_int(OVERKILL))

	assert_bool(floors.is_boss_fight()).is_false()
	assert_array(flags).is_equal([true])


# --- Floating texts ------------------------------------------------------------------------


func test_layer_more_texts_than_the_pool_stays_at_the_pool_size() -> void:
	var layer: FloatingTextLayer = _new_layer()

	for i in MANY_TEXTS:
		layer.show_hit(_damage(), FloorManager.HitSource.CLICK)

	assert_int(FloatingTextLayer.POOL_SIZE).is_equal(12)
	assert_int(layer.busy_count()).is_equal(FloatingTextLayer.POOL_SIZE)


func test_layer_reuses_its_labels_and_creates_none() -> void:
	var layer: FloatingTextLayer = _new_layer()
	var before: Array[Node] = layer.get_children()

	for i in MANY_TEXTS:
		layer.show_hit(_damage(), FloorManager.HitSource.CLICK)
		layer._process(SHORT_FRAME)
	layer.clear()

	assert_int(before.size()).is_equal(FloatingTextLayer.POOL_SIZE)
	assert_array(layer.get_children()).is_equal(before)


func test_layer_full_pool_takes_over_the_oldest_text() -> void:
	var layer: FloatingTextLayer = _new_layer()
	for i in FloatingTextLayer.POOL_SIZE:
		layer.show_hit(BigNumber.from_int(i + 1), FloorManager.HitSource.CLICK)

	layer.show_hit(BigNumber.from_int(UNIQUE_DAMAGE), FloorManager.HitSource.CLICK)

	assert_str(_label(layer, 0).text).is_equal(str(UNIQUE_DAMAGE))
	assert_str(_label(layer, 1).text).is_equal("2")
	assert_int(layer.busy_count()).is_equal(FloatingTextLayer.POOL_SIZE)


func test_layer_second_takeover_takes_the_next_oldest_text() -> void:
	var layer: FloatingTextLayer = _new_layer()
	for i in FloatingTextLayer.POOL_SIZE:
		layer.show_hit(BigNumber.from_int(i + 1), FloorManager.HitSource.CLICK)

	layer.show_hit(BigNumber.from_int(UNIQUE_DAMAGE), FloorManager.HitSource.CLICK)
	layer.show_hit(BigNumber.from_int(UNIQUE_DAMAGE), FloorManager.HitSource.CLICK)

	assert_str(_label(layer, 1).text).is_equal(str(UNIQUE_DAMAGE))
	assert_str(_label(layer, 2).text).is_equal("3")


func test_layer_companion_attack_shows_no_text() -> void:
	var layer: FloatingTextLayer = _new_layer()

	layer.show_hit(_damage(), FloorManager.HitSource.AUTO)

	assert_int(layer.busy_count()).is_equal(0)


func test_layer_critical_is_bigger_and_ends_with_an_exclamation_mark() -> void:
	var layer: FloatingTextLayer = _new_layer()

	layer.show_hit(_damage(), FloorManager.HitSource.CLICK)
	layer.show_hit(_damage(), FloorManager.HitSource.CRITICAL)

	var normal: Label = _label(layer, 0)
	var critical: Label = _label(layer, 1)
	assert_bool(critical.text.ends_with("!")).is_true()
	assert_bool(normal.text.ends_with("!")).is_false()
	assert_int(critical.get_theme_font_size("font_size")).is_greater(normal.get_theme_font_size("font_size"))


func test_layer_burst_is_bigger_than_a_critical() -> void:
	var layer: FloatingTextLayer = _new_layer()

	layer.show_hit(_damage(), FloorManager.HitSource.CRITICAL)
	layer.show_hit(_damage(), FloorManager.HitSource.BURST)

	assert_int(_label(layer, 1).get_theme_font_size("font_size")).is_greater(_label(layer, 0).get_theme_font_size("font_size"))


func test_layer_gold_text_shows_the_reward_and_is_bigger_for_a_boss() -> void:
	var layer: FloatingTextLayer = _new_layer()
	var gold: BigNumber = BigNumber.from_int(UNIQUE_DAMAGE)

	layer.show_gold(NORMAL_STAGE, gold, false)
	# Past the merge window: two golds in a row would make one text (story 011).
	for i in ceili(FloatingTextLayer.GOLD_MERGE_SECONDS / FloatingTextLayer.MAX_FRAME_SECONDS) + 1:
		layer._process(FloatingTextLayer.MAX_FRAME_SECONDS)
	layer.show_gold(BOSS_STAGE, gold, true)

	assert_str(_label(layer, 0).text).is_equal("+%s or" % gold.format())
	assert_int(_label(layer, 1).get_theme_font_size("font_size")).is_greater(_label(layer, 0).get_theme_font_size("font_size"))


func test_layer_gold_text_rises_to_the_right() -> void:
	var layer: FloatingTextLayer = _new_layer()
	layer.show_gold(NORMAL_STAGE, _damage(), false)
	var start: Vector2 = _label(layer, 0).position

	layer._process(SHORT_FRAME)

	assert_float(_label(layer, 0).position.x).is_greater(start.x)
	assert_float(_label(layer, 0).position.y).is_less(start.y)


func test_layer_every_text_has_an_outline_and_ignores_the_mouse() -> void:
	var layer: FloatingTextLayer = _new_layer()

	assert_int(layer.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	for child: Node in layer.get_children():
		var label: Label = child as Label
		assert_int(label.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		assert_int(label.get_theme_constant("outline_size")).is_greater(0)
		assert_bool(label.has_theme_color_override("font_outline_color")).is_true()


func test_layer_long_frame_is_clamped_and_does_not_end_a_text() -> void:
	var layer: FloatingTextLayer = _new_layer()
	layer.show_hit(_damage(), FloorManager.HitSource.CLICK)

	layer._process(LONG_FRAME)

	assert_int(layer.busy_count()).is_equal(1)


func test_layer_text_is_released_when_its_time_is_over() -> void:
	var layer: FloatingTextLayer = _new_layer()
	layer.show_hit(_damage(), FloorManager.HitSource.CLICK)

	for i in ceili(FloatingTextLayer.HIT_SECONDS / FloatingTextLayer.MAX_FRAME_SECONDS) + 1:
		layer._process(FloatingTextLayer.MAX_FRAME_SECONDS)

	assert_int(layer.busy_count()).is_equal(0)
	assert_bool(_label(layer, 0).visible).is_false()


func test_layer_disabled_clears_the_texts_and_ignores_new_events() -> void:
	var layer: FloatingTextLayer = _new_layer()
	layer.show_hit(_damage(), FloorManager.HitSource.CLICK)

	layer.set_enabled(false)
	layer.show_hit(_damage(), FloorManager.HitSource.CLICK)
	layer.show_gold(NORMAL_STAGE, _damage(), false)

	assert_int(layer.busy_count()).is_equal(0)
	assert_bool(layer.is_processing()).is_false()


func test_layer_paused_clears_the_texts_and_nothing_comes_back() -> void:
	var layer: FloatingTextLayer = _new_layer()
	layer.show_hit(_damage(), FloorManager.HitSource.CLICK)

	layer.set_paused(true)
	layer.show_hit(_damage(), FloorManager.HitSource.CLICK)
	layer.set_paused(false)

	assert_int(layer.busy_count()).is_equal(0)


# --- Companion balls -----------------------------------------------------------------------


func test_orbs_second_attack_inside_the_interval_throws_no_ball() -> void:
	var orbs: CompanionOrbs = _new_orbs([FIRST_ID])

	orbs.on_companion_attacked(FIRST_ID, _damage())
	orbs.on_companion_attacked(FIRST_ID, _damage())

	assert_int(orbs.active_ball_count()).is_equal(1)


func test_orbs_attack_after_the_interval_throws_a_new_ball() -> void:
	var orbs: CompanionOrbs = _new_orbs([FIRST_ID])
	orbs.on_companion_attacked(FIRST_ID, _damage())
	for i in ceili(CompanionOrbs.BALL_MIN_INTERVAL_SECONDS / SHORT_FRAME):
		orbs._process(SHORT_FRAME)
	var flying: int = orbs.active_ball_count()

	orbs.on_companion_attacked(FIRST_ID, _damage())

	assert_int(orbs.active_ball_count()).is_equal(flying + 1)


func test_orbs_long_frame_is_clamped_and_opens_no_burst() -> void:
	var orbs: CompanionOrbs = _new_orbs([FIRST_ID])
	orbs.on_companion_attacked(FIRST_ID, _damage())

	orbs._process(LONG_FRAME)

	# Clamped, the ball is still flying and the interval has not run out.
	assert_int(orbs.active_ball_count()).is_equal(1)
	orbs.on_companion_attacked(FIRST_ID, _damage())
	assert_int(orbs.active_ball_count()).is_equal(1)


func test_orbs_the_limit_is_per_companion() -> void:
	var orbs: CompanionOrbs = _new_orbs([FIRST_ID, SECOND_ID])

	orbs.on_companion_attacked(FIRST_ID, _damage())
	orbs.on_companion_attacked(SECOND_ID, _damage())

	assert_int(orbs.active_ball_count()).is_equal(2)


func test_orbs_pool_never_exceeds_its_size() -> void:
	var ids: Array[String] = []
	for i in MANY_COMPANIONS:
		ids.append("companion_%d" % i)
	var orbs: CompanionOrbs = _new_orbs(ids)

	for id: String in ids:
		orbs.on_companion_attacked(id, _damage())

	assert_int(orbs.active_ball_count()).is_equal(CompanionOrbs.BALL_POOL_SIZE)


func test_orbs_unowned_companion_throws_no_ball() -> void:
	var orbs: CompanionOrbs = _new_orbs([FIRST_ID])
	orbs.set_level(FIRST_ID, 0)

	orbs.on_companion_attacked(FIRST_ID, _damage())

	assert_int(orbs.active_ball_count()).is_equal(0)


func test_orbs_ignore_the_mouse() -> void:
	var orbs: CompanionOrbs = _new_orbs([FIRST_ID])

	assert_int(orbs.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_orbs_disabled_clears_the_balls_and_ignores_new_attacks() -> void:
	var orbs: CompanionOrbs = _new_orbs([FIRST_ID, SECOND_ID])
	orbs.on_companion_attacked(FIRST_ID, _damage())

	orbs.set_enabled(false)
	orbs.on_companion_attacked(SECOND_ID, _damage())

	assert_int(orbs.active_ball_count()).is_equal(0)
	assert_bool(orbs.is_processing()).is_false()


func test_orbs_paused_clears_the_balls_and_nothing_comes_back() -> void:
	var orbs: CompanionOrbs = _new_orbs([FIRST_ID, SECOND_ID])
	orbs.on_companion_attacked(FIRST_ID, _damage())

	orbs.set_paused(true)
	orbs.on_companion_attacked(SECOND_ID, _damage())
	orbs.set_paused(false)

	assert_int(orbs.active_ball_count()).is_equal(0)


func test_orbs_attack_right_after_a_pause_throws_a_ball() -> void:
	var orbs: CompanionOrbs = _new_orbs([FIRST_ID])
	orbs.on_companion_attacked(FIRST_ID, _damage())
	orbs.set_paused(true)
	orbs.set_paused(false)

	orbs.on_companion_attacked(FIRST_ID, _damage())

	assert_int(orbs.active_ball_count()).is_equal(1)
	assert_bool(orbs.is_processing()).is_true()


func test_orbs_invalid_colors_and_entries_do_not_break_the_setup() -> void:
	var orbs: CompanionOrbs = auto_free(CompanionOrbs.new())

	orbs.setup({"companions": [{"id": FIRST_ID, "color": "not a colour"}, {"id": SECOND_ID, "color": 12}, {"color": "#ffffff"}, "junk"]})
	orbs.set_level(FIRST_ID, 1)
	orbs.set_level(SECOND_ID, 1)
	orbs.on_companion_attacked(FIRST_ID, _damage())
	orbs.on_companion_attacked(SECOND_ID, _damage())

	assert_int(orbs.active_ball_count()).is_equal(2)


func test_real_roster_gives_every_companion_a_valid_color_and_still_loads() -> void:
	var roster: Variant = DataLoader.load_json(REAL_ROSTER_PATH)
	var entries: Array = (roster as Dictionary)["companions"]

	assert_bool(entries.is_empty()).is_false()
	for entry: Dictionary in entries:
		assert_bool(Color.html_is_valid(str(entry.get("color")))).is_true()
	var combat: Combat = Combat.from_data({
		"schema_version": Combat.SUPPORTED_CURVES_SCHEMA,
		"enemy_hp_base": ENEMY_HP,
		"enemy_hp_growth": "1",
		"gold_per_kill_base": GOLD_PER_KILL,
		"gold_per_kill_growth": "1",
		"click_damage_base": CLICK_BASE,
		"click_companion_power_factor": "0",
		"cost_growth": "1.08",
	}, roster)
	assert_int(combat.companions().size()).is_equal(entries.size())


# --- Setting -------------------------------------------------------------------------------


func test_setting_missing_file_means_on() -> void:
	assert_bool(DisplaySettings.new(SETTINGS_PATH).visual_effects()).is_true()


func test_setting_is_kept_through_a_reload() -> void:
	var saved: bool = DisplaySettings.new(SETTINGS_PATH).set_visual_effects(false)

	var reloaded: DisplaySettings = DisplaySettings.new(SETTINGS_PATH)

	assert_bool(saved).is_true()
	assert_bool(reloaded.visual_effects()).is_false()


func test_setting_takes_effect_at_once() -> void:
	var settings: DisplaySettings = DisplaySettings.new(SETTINGS_PATH)

	settings.set_visual_effects(false)

	assert_bool(settings.visual_effects()).is_false()


func test_setting_unreadable_file_means_on() -> void:
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	file.store_string("[[[ not a config file")
	file.close()

	assert_bool(DisplaySettings.new(SETTINGS_PATH).visual_effects()).is_true()


func test_setting_wrong_type_means_on() -> void:
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	file.store_string("[%s]\n%s=\"no\"\n" % [DisplaySettings.SECTION, DisplaySettings.KEY_VISUAL_EFFECTS])
	file.close()

	assert_bool(DisplaySettings.new(SETTINGS_PATH).visual_effects()).is_true()


# --- No effect on the game -----------------------------------------------------------------


# Plays the same clicks and companion frames with the same dice, the display wired to the core
# and switched on or off. Returns the results the player could compare, and what was on screen.
func _play_scenario(effects: bool) -> Dictionary:
	var state: GameState = _new_state(NORMAL_STAGE)
	var permanent: PermanentState = PermanentState.new()
	var combat: Combat = _new_combat()
	var floors: FloorManager = FloorManager.new(state, combat, _new_boss(), permanent)
	var dice: RandomNumberGenerator = RandomNumberGenerator.new()
	dice.seed = DICE_SEED
	floors.set_crit_roll(dice.randf)
	floors.set_item_modifiers("1", "1", "1", SOMETIMES_CRITICAL, CRIT_FACTOR)
	var companions: CompanionManager = CompanionManager.new(state, combat, floors)
	var layer: FloatingTextLayer = _new_layer()
	var orbs: CompanionOrbs = _new_orbs([FIRST_ID])
	layer.set_enabled(effects)
	orbs.set_enabled(effects)
	floors.hit_landed.connect(layer.show_hit)
	floors.kill_rewarded.connect(layer.show_gold)
	companions.companion_attacked.connect(orbs.on_companion_attacked)
	var damage_log: PackedStringArray = PackedStringArray()
	floors.hit_landed.connect(func(damage: BigNumber, source: int) -> void: damage_log.append("%s/%d" % [damage.to_decimal_string(), source]))
	for i in SCENARIO_CLICKS:
		floors.click()
		companions.tick(SCENARIO_FRAME_SECONDS)
		floors.tick(SCENARIO_FRAME_SECONDS)
		layer._process(SCENARIO_FRAME_SECONDS)
		orbs._process(SCENARIO_FRAME_SECONDS)
	return {
		"damage": damage_log,
		"gold": state.gold.to_decimal_string(),
		"stage": state.stage,
		"hp": floors.current_hp().to_decimal_string(),
		"save": JSON.stringify(state.to_dict()) + JSON.stringify(permanent.to_dict()),
		"texts": layer.busy_count(),
		"balls": orbs.active_ball_count(),
	}


func test_scenario_same_dice_gives_same_game_with_the_setting_on_or_off() -> void:
	var on: Dictionary = _play_scenario(true)
	var off: Dictionary = _play_scenario(false)

	# The display really ran in one case and not in the other.
	assert_int(on["texts"]).is_greater(0)
	assert_int(off["texts"]).is_equal(0)
	assert_int(off["balls"]).is_equal(0)
	assert_array(on["damage"]).is_equal(off["damage"])
	assert_str(on["gold"]).is_equal(off["gold"])
	assert_int(on["stage"]).is_equal(off["stage"])
	assert_str(on["hp"]).is_equal(off["hp"])
	assert_str(on["save"]).is_equal(off["save"])


func test_scenario_reaches_critical_hits_and_a_boss() -> void:
	var played: Dictionary = _play_scenario(true)

	var damage: PackedStringArray = played["damage"]
	var critical_tag: String = "/%d" % FloorManager.HitSource.CRITICAL
	var has_critical: bool = false
	for entry: String in damage:
		has_critical = has_critical or entry.ends_with(critical_tag)
	assert_bool(has_critical).is_true()
	assert_int(played["stage"]).is_greater(BOSS_STAGE)


func test_setting_stays_out_of_the_save_text() -> void:
	var settings: DisplaySettings = DisplaySettings.new(SETTINGS_PATH)
	settings.set_visual_effects(false)

	var saved: String = _play_scenario(true)["save"]

	assert_str(saved).not_contains(DisplaySettings.KEY_VISUAL_EFFECTS)
