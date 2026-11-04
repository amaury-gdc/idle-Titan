extends GdUnitTestSuite
## Unit tests for the Talents tab and the skill bar on the real 30-node tree (story 019,
## design/talent-tree-v2.md "Interface"): tier headers, top nodes with "Exclut X", the card with its
## total before → after, the purchase that closes the card, the 250 ms guard, every state in words,
## the Instinct card, the reset countdown from a future stamp, and the skill buttons "À débloquer"
## and "Passif".
## Story: production/epics/idle-titans/story-019-talent-tree-content.md

const SCENE: String = "res://src/ui/talent_screen.tscn"
const SKILL_BAR_SCENE: String = "res://src/ui/skill_bar.tscn"
const PHONE: Vector2 = Vector2(348, 600)
const BAND: Vector2 = Vector2(TalentScreen.DETAIL_BAND_MIN_WIDTH, TalentScreen.WIDE_MIN_HEIGHT)
const TREE_VERSION: int = 1
## 20 points: enough to open the tiers of one branch.
const STAGE_WITH_POINTS: int = 100
const NOW: int = 1_000_000
const COOLDOWN: int = TalentTree.DEFAULT_RESET_COOLDOWN_SECONDS
const TEN_DAYS: int = 864_000
const OPENED_MSEC: int = 10_000

var _state: GameState
var _permanent: PermanentState
var _combat: Combat
var _floors: FloorManager
var _tree: TalentTree
var _skills: SkillManager
var _screen: TalentScreen
var _bought: Array = []
var _now: Array[int] = [NOW]
var _msec: Array[int] = [OPENED_MSEC]


func before_test() -> void:
	var curves: Variant = DataLoader.load_json("res://assets/data/core_curves.json")
	_combat = Combat.from_data(curves, DataLoader.load_json("res://assets/data/companions_roster.json"))
	_state = GameState.new()
	_state.max_stage_reached = STAGE_WITH_POINTS
	_permanent = PermanentState.new()
	_permanent.talent_tree_seen = TREE_VERSION
	_floors = FloorManager.new(_state, _combat)
	_tree = TalentTree.from_data(DataLoader.load_json("res://assets/data/talents.json"), _permanent, _state)
	assert_str(_tree.get_error()).is_empty()
	var hub: ModifierHub = ModifierHub.new(_floors, OfflineIncome.from_data(curves, _combat), _tree, null)
	_skills = SkillManager.from_data(DataLoader.load_json("res://assets/data/skills.json"), _state, _combat, _floors, hub)
	assert_str(_skills.get_error()).is_empty()
	_now = [NOW]
	_msec = [OPENED_MSEC]
	_bought = []
	_screen = auto_free((load(SCENE) as PackedScene).instantiate())
	_screen.visible = true
	_screen._clock_msec = func() -> int: return _msec[0]
	add_child(_screen)
	_screen.buy_requested.connect(func(id: String) -> void:
		_bought.append(id)
		_tree.buy(id))


func _start(pane: Vector2 = PHONE) -> void:
	_screen.set_context(_skills, 12.0, func() -> int: return _now[0], func() -> bool: return false)
	_screen.size = pane
	_screen.setup(_tree)


func _later() -> void:
	_msec[0] += TalentScreen.ACTION_GUARD_MSEC


func _tile(id: String) -> String:
	return _screen._button_of(id).text


# Story 019b: a tier header is two labels, its name on the left and its progress on the right; this
# joins them as "Palier 3 | Ouvert".
func _header_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for header: Dictionary in _screen._headers:
		texts.append("%s | %s" % [(header["label"] as Label).text, (header["progress"] as Label).text])
	return texts


# Tier headers

func test_tier_header_says_points_spent_in_the_branch_against_the_threshold() -> void:
	# Arrange: 4 points in the click branch (tier 3 opens at 4, tier 4 at 8)
	_permanent.talents = {"click_grip": 1, "click_crit": 1, "click_ally": 1}
	_start()

	# Act
	var texts: PackedStringArray = _header_texts()

	# Assert
	assert_bool(texts.has("Palier 3 | Ouvert")).is_true()
	assert_bool(texts.has("Palier 4 | 4 / 8 points")).is_true()
	assert_bool(texts.has("Palier 2 | 0 / 2 points")).is_true()
	# The joined form of the same parts, as TalentCardText.tier_header gives it.
	assert_str(_screen._text.tier_header("click", 4)).is_equal("Palier 4 : 4 / 8 points")


# Top nodes and states

func test_top_node_tile_names_what_it_excludes() -> void:
	_start()
	assert_str(_tile("comp_top_champion")).contains("Exclut Instinct de meute")
	assert_str(_tile("comp_top_instinct")).contains("Exclut Champion")


func test_every_state_is_a_word_on_its_tile() -> void:
	# Arrange: 15 points spent in the economy, top node included, its rival excluded
	_state.max_stage_reached = 75  # 15 points
	_permanent.talents = {"eco_purse": 1, "gold_unlock": 1, "economy_offline": 1, "eco_flair": 1, "eco_haggle": 1, "gold_cd": 1, "eco_top_rentier": 1}
	_start()

	# Assert: Acheté, Exclu, Palier fermé, Requiert
	assert_int(_tree.available_points()).is_equal(0)
	assert_str(_tile("eco_purse")).ends_with("Acheté")
	assert_str(_tile("eco_top_harvest")).ends_with("Exclu")
	# Story 019b: a tile whose state does not tell the cost shows the real one after it.
	assert_str(_tile("click_heavy")).ends_with("Palier fermé · " + _screen._text.points_text(2))
	assert_str(_tile("bighit_cd")).ends_with("Requiert : Gros coup puissant · " + _screen._text.points_text(3))

	# Act: one more point
	_state.max_stage_reached = 80
	_screen.refresh()

	# Assert: Coût, Manque (Bonus durable: tier 3 open, prerequisite bought, 2 points for 1)
	assert_int(_tree.available_points()).is_equal(1)
	assert_str(_tile("click_grip")).ends_with("Coût : 1 pt")
	assert_str(_tile("gold_long")).ends_with("Coût : 2 pts, manque 1 pt")


# Card

func test_card_shows_effect_total_before_and_after_and_cost() -> void:
	# Arrange: Poigne ferme bought (+8 %), Coup lourd (+15 %) to come
	_permanent.talents = {"click_grip": 1, "click_crit": 1}
	_start()

	# Act
	_screen.open_node("click_heavy")

	# Assert
	var card: String = _screen._detail_status.text
	assert_str(card).contains("Clic +15 %")
	assert_str(card).contains("Total des talents : de +8 % à +23 %")
	assert_str(card).contains("Coût : 2 pts")


func test_instinct_card_says_it_cancels_both_frenzy_nodes() -> void:
	_start()
	_screen.open_node("comp_top_instinct")
	assert_str(_screen._detail_status.text).contains("Annule Frénésie durable et Frénésie ardente.")


func test_skill_card_shows_the_value_before_and_after() -> void:
	_permanent.talents = {"frenzy_unlock": 1, "comp_camaraderie": 1}
	_start()
	_screen.open_node("frenzy_long")
	assert_str(_screen._detail_status.text).contains("Avant : 15 s. Après : 20 s.")


func test_buying_from_the_card_closes_it() -> void:
	# Arrange
	_start()
	_screen.open_node("click_grip")
	_later()

	# Act
	_screen._action_button.pressed.emit()

	# Assert
	assert_array(_bought).contains_exactly(["click_grip"])
	assert_bool(_tree.is_owned("click_grip")).is_true()
	assert_bool(_screen.is_detail_open()).is_false()


func test_action_within_250_ms_of_opening_is_ignored() -> void:
	# Arrange
	_start()
	_screen.open_node("click_grip")

	# Act: the second touch of a double touch, 249 ms later
	_msec[0] += TalentScreen.ACTION_GUARD_MSEC - 1
	_screen._action_button.pressed.emit()

	# Assert
	assert_array(_bought).is_empty()
	assert_bool(_screen.is_detail_open()).is_true()


func test_action_at_250_ms_buys() -> void:
	_start()
	_screen.open_node("click_grip")
	_later()
	_screen._action_button.pressed.emit()
	assert_array(_bought).contains_exactly(["click_grip"])


func test_card_says_to_close_the_version_message_first() -> void:
	# Arrange: the message of the new tree is not read yet
	_permanent.talent_tree_seen = 0
	_start()

	# Act
	_screen.open_node("click_grip")

	# Assert
	assert_bool(_screen._action_button.disabled).is_true()
	assert_str(_screen._detail_status.text).contains("Ferme d'abord le message du nouvel arbre pour acheter.")


func test_no_colon_or_guillemet_can_start_or_end_a_line_in_any_card_or_tile() -> void:
	# Arrange: every node of the real tree, with a refusal of each kind
	_start()
	var texts: PackedStringArray = PackedStringArray()
	for def: TalentTree.TalentDef in _tree.nodes():
		texts.append(_tile(def.id))
		texts.append("\n".join(_screen._text.card_lines(def)))
	texts.append(TalentCardText.reset_refusal_text(_tree, NOW, true))
	texts.append_array(_header_texts())

	# Assert: a breakable space before ":", "?", "!", ";", "»" or after "«" would let a line start with it
	for text: String in texts:
		for bad: String in [" :", " ?", " !", " ;", " »", "« "]:
			assert_bool(text.contains(bad)).override_failure_message("'%s' in: %s" % [bad, text]).is_false()


func test_reset_card_offers_the_confirmation_once_the_boss_fight_is_over() -> void:
	# Arrange: a refusal told during a boss fight
	var boss: Array[bool] = [true]
	_permanent.talents = {"click_grip": 1}
	_screen.set_context(_skills, 12.0, func() -> int: return _now[0], func() -> bool: return boss[0])
	_screen.size = PHONE
	_screen.setup(_tree)
	_screen.show_reset_refused(TalentCardText.reset_refusal_text(_tree, NOW, true))
	assert_bool(_screen._action_button.visible).is_false()

	# Act: the boss dies, the card is drawn again
	boss[0] = false
	_screen.refresh()

	# Assert
	assert_str(_screen._detail_title.text).is_equal("Réinitialiser les talents ?")
	assert_bool(_screen._action_button.visible).is_true()


func test_next_point_follows_the_bands_of_the_tree() -> void:
	# Arrange: stage 100 ends the band of 1 point per 5 stages; the next band gives 1 per 20
	_start()

	# Act, Assert
	assert_str(_screen._info_label.text).contains("Prochain point à l'étage 120.")
	assert_int(_tree.stage_for_points(20)).is_equal(100)
	assert_int(_tree.stage_for_points(1)).is_equal(5)
	assert_int(_tree.stage_for_points(0)).is_equal(0)


# Layout

func test_phone_shows_one_branch_as_a_grid_of_two_tiles() -> void:
	_start(PHONE)
	assert_bool(_screen.is_wide()).is_false()
	assert_int(_screen._grids[0].columns).is_equal(TalentScreen.COMPACT_GRID_COLUMNS)
	# Story 019b: the header tells the number and "points à dépenser" (20 points at stage 100).
	assert_str(_screen._points_label.text).is_equal("20")
	assert_str(_screen._points_word.text.replace("\n", " ")).is_equal("points à dépenser")
	# (story 019 read "Points : ")


func test_from_560_the_card_is_a_band_under_the_tree() -> void:
	_start(BAND)
	_screen.open_node("click_grip")
	assert_bool(_screen.has_band()).is_true()
	assert_bool(_screen._scroll.visible).is_true()
	assert_bool(_screen._detail_panel.visible).is_true()


func test_under_560_the_card_replaces_the_tree() -> void:
	_start(Vector2(BAND.x - 1.0, BAND.y))
	_screen.open_node("click_grip")
	assert_bool(_screen._scroll.visible).is_false()


# Reset countdown (criterion: "jamais figé à 1 h en attendant un premier appui")

func test_countdown_runs_from_opening_with_a_last_reset_in_the_future() -> void:
	# Arrange: the clock was set back ten days after the last reset
	_permanent.talents = {"click_grip": 1}
	_permanent.talent_reset_unix = NOW + TEN_DAYS
	_start()
	assert_str(_screen._reset_button.text).contains("dans 60:00")

	# Act: ten seconds later, without any press
	_now[0] = NOW + 10
	_screen._process(0.0)

	# Assert
	assert_str(_screen._reset_button.text).contains("dans 59:50")


func test_tree_countdown_goes_down_with_a_last_reset_in_the_future() -> void:
	# Arrange
	_permanent.talent_reset_unix = NOW + TEN_DAYS

	# Act
	var first: int = _tree.reset_seconds_left(NOW)
	var later: int = _tree.reset_seconds_left(NOW + 10)

	# Assert
	assert_int(first).is_equal(COOLDOWN)
	assert_int(later).is_equal(COOLDOWN - 10)


# Skill bar

func _bar() -> SkillBar:
	var bar: SkillBar = auto_free((load(SKILL_BAR_SCENE) as PackedScene).instantiate())
	add_child(bar)
	bar.setup(_skills)
	return bar


func test_locked_skill_keeps_its_button_and_reads_a_debloquer() -> void:
	# Arrange
	var bar: SkillBar = _bar()
	var unlocks: Array = []
	var activations: Array = []
	bar.unlock_requested.connect(func(id: String) -> void: unlocks.append(id))
	bar.activate_requested.connect(func(id: String) -> void: activations.append(id))

	# Act
	bar.button_of("damage_buff").pressed.emit()

	# Assert: three buttons in the order of the keys, the locked one usable
	assert_int(bar._buttons_box.get_child_count()).is_equal(3)
	assert_str(bar.button_of("damage_buff").accessibility_name).ends_with("À débloquer")
	assert_int((bar.button_of("damage_buff") as SkillOrb).look()).is_equal(SkillOrb.Look.LOCKED)
	assert_bool(bar.button_of("damage_buff").disabled).is_false()
	assert_array(unlocks).contains_exactly(["damage_buff"])
	assert_array(activations).is_empty()


func test_touch_on_a_locked_skill_opens_the_card_of_its_node() -> void:
	_start()
	_screen.open_node(TalentScreen.unlock_node_of(_tree, "damage_buff"))
	assert_str(_screen.selected_node()).is_equal("frenzy_unlock")
	assert_int(_screen.open_branch()).is_equal(1)


func test_passive_skill_reads_passif_and_cannot_be_pressed() -> void:
	# Arrange: Instinct de meute bought
	_permanent.talents = {"frenzy_unlock": 1, "comp_top_instinct": 1}
	# The save was set by hand: the tree tells it as a purchase would (SkillManager caches its flags).
	_tree.changed.emit()

	# Act
	var bar: SkillBar = _bar()

	# Assert
	assert_str(bar.button_of("damage_buff").accessibility_name).ends_with("Passif")
	assert_int((bar.button_of("damage_buff") as SkillOrb).look()).is_equal(SkillOrb.Look.PASSIVE)
	assert_str(bar.hint_text("damage_buff")).contains("Passif")
	assert_bool(bar.button_of("damage_buff").disabled).is_true()
	assert_object(bar.button_of("damage_buff")).is_same(bar._buttons_box.get_child(1))


func test_skill_hint_uses_the_values_of_the_talents() -> void:
	# Arrange: Frénésie unlocked, then lasting 20 s
	_permanent.talents = {"frenzy_unlock": 1, "frenzy_long": 1}
	_tree.changed.emit()

	# Act
	var bar: SkillBar = _bar()

	# Assert
	assert_str(bar.hint_text("damage_buff")).contains("pendant 20 s")
