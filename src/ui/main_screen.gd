extends Control
## Main screen of Idle Titans (stories 002, 003, 004, 004b, 010, 019b): a one-line header (stage and
## best stage; gold and DPS in a button that opens the detail of the DPS; the gear of "Réglages"), a
## [GameZone] (enemy, HP bar, boss timer, "Boss" or "Abandonner" in a corner, skills) and a
## [ManagementTabs] zone (the tab bar over the companion list, the [InventoryScreen] and the
## [TalentScreen]). "Défi auto" and the version live in "Réglages". "Abandonner" asks for a second
## press within [constant ConfirmPress.WINDOW_SECONDS]. The game never waits for a tab (story 011,
## D1): only "Réglages", which opens the [SaveScreen], and the return message stop it, and they are
## the two modal windows left. The loot message comes during the fight, so it lives here and not in
## the inventory, takes no mouse and no focus, and hides by itself.
##
## Adaptive layout (story 010, design/ux/main-screen-adaptive.md): [AdaptiveLayout] decides the
## shape from the window size in CSS pixels; this script applies it synchronously, in [method _ready]
## and on each [signal Viewport.size_changed]. There is one tree: a shape change only moves the
## same nodes, so the focus and the scroll survive it. Portrait and landscape differ by the
## direction of Split (landscape: the scene on the left, about 3/7 of the width, the panel on the
## right, story 019b lot 9), the height of the scene and the handle of the panel.
##
## Visual feedback (story 009, display only): a [FloatingTextLayer] shows the damage of the
## player's hits (a critical hit is a bigger number ending with "!", which replaces the former
## "Critique !" text) and the gold of a kill; [CompanionOrbs] draws one sphere per owned companion
## beside the enemy and a ball thrown at it on each attack. Both read the [FloorManager] and
## [CompanionManager] signals and change nothing. The "Effets visuels" toggle of "Réglages" turns them
## off, with the monster squash; the choice lives in [DisplaySettings], a file of its own, never in
## the save, and until the player makes one it follows the browser's prefers-reduced-motion. Hidden
## tab and modal screens stop and clear them. Both layers stay full-rect overlays at the root: they
## aim at [method EnemyView.anchor_global], converted to their own space whenever the enemy or any of
## its ancestors moves. The transition between monsters (story 012) follows the same toggle and the
## same pause; its values are in monster_transition.json, a file that can never stop the game.
##
## Input (story 010): 1, 2 and 3 activate the skills, by key position so that they work on any
## keyboard layout; the [SaveScreen] text field is inside a modal, and every modal stops them. A
## [HintBubble] shows what hovering shows on a PC, on a long press, on keyboard focus and on the DPS
## button. The cost of the companion rows is redrawn on a change of gold, 4 times a second at most,
## with [NotificationDots] reading the same change.
## Composition root: loads data and saves, builds the [Combat] / [BossFight] /
## [FloorManager] / [CompanionManager] / [SkillManager] / [OfflineIncome] / [TalentTree] /
## [Inventory] / [ModifierHub] core, feeds it frame time, forwards clicks to it and redraws on
## its signals. All rules live in src/core; this script only displays.
##
## Permanent bonuses: only the [ModifierHub] pushes them. It is built BEFORE the handlers of
## this script connect to the "changed" signals of the talents and the inventory: a signal
## calls its connections in order, so the factors are fresh when those handlers redraw. It is
## also built before the first offline grant, which reads the offline gold factor.
##
## Persistence: loads [GameState] and [PermanentState] through [SaveManager]
## (default user:// paths) at startup; saves every autosave_interval_seconds
## (core_curves.json), on window close request, on focus loss and on tree exit.
## Offline gold is granted right after the load and before any save: a save stamps the
## current time, so saving first would erase the absence. The gain is then saved at
## once. On the web, the same happens when a hidden tab becomes visible again, and the
## game also saves when the tab becomes hidden.
## Web caveat (measured in Edge, story 004b): user:// writes reach IndexedDB on the next
## frame and a hidden tab runs no frames. The save made on hiding therefore stays in
## memory: it counts if the tab comes back, but a tab closed while hidden reloads the
## last autosave, at most autosave_interval_seconds old.

const CURVES_PATH: String = "res://assets/data/core_curves.json"
const ROSTER_PATH: String = "res://assets/data/companions_roster.json"
const BOSSES_PATH: String = "res://assets/data/boss_curves.json"
const SKILLS_PATH: String = "res://assets/data/skills.json"
const TALENTS_PATH: String = "res://assets/data/talents.json"
const ITEMS_PATH: String = "res://assets/data/items.json"
const TRANSITION_PATH: String = "res://assets/data/monster_transition.json"
## Used only when core_curves.json has no valid autosave_interval_seconds
## (infrastructure setting, not a gameplay value).
const FALLBACK_AUTOSAVE_SECONDS: float = 10.0
## Time between two redraws of the DPS line and of the costs (display setting, not a gameplay value).
const DPS_REFRESH_SECONDS: float = 0.25
## Physical keys of the skills, in the order of the bar.
const SKILL_KEYS: Array[int] = [KEY_1, KEY_2, KEY_3]
## Time the loot message stays on screen (display setting, not a gameplay value).
const LOOT_MESSAGE_SECONDS: float = 4.0
## Widest loot message (display setting, not a gameplay value).
const LOOT_MAX_WIDTH: float = 340.0
## Under this width the loot message drops its title (display setting, not a gameplay value).
const LOOT_TITLE_MIN_WIDTH: float = 220.0
## Measures of the toast: its side margins and borders, a line of 16 u, and what its height adds
## to the lines (ToastPanel in the theme).
const LOOT_SIDE_MARGINS: float = 16.0
const LOOT_LINE_HEIGHT: float = 26.0
const LOOT_VERTICAL_MARGINS: float = 9.0
## Window metadata keeping the shape across a scene reload: a save reset must not flip the layout
## of a window standing in the dead zone.
const SHAPE_META: StringName = &"adaptive_shape"
## Height of the return message when the window allows it; its content scrolls otherwise.
const OFFLINE_PANEL_HEIGHT: float = 300.0
## (Story 019) the window grows past it to hold its content, up to the view: see _fit_message_window.
## Longest value a header cell must hold without moving its neighbours (spec, Localization): the
## widest text of [method BigNumber.format] up to stage 300, the same as the companion buttons.
const HEADER_LONGEST_VALUE: String = CompanionPanel.LONGEST_COST
const HEADER_LONGEST_STAGE: int = 999
## Room on each side of the gold and DPS inside their button (display setting).
const HEADER_DPS_MARGIN: float = 8.0
## Sizes of the coin and of the "opens" sign beside the gold and the DPS, and their gaps (as in
## main_screen.tscn).
const HEADER_COIN_WIDTH: float = 22.0
const HEADER_COIN_GAP: float = 6.0
const HEADER_OPEN_WIDTH: float = 10.0
const HEADER_OPEN_GAP: float = 4.0
## The font sizes of the spec, in logical units.
const FONT_16: int = 16
const SECONDS_PER_MINUTE: int = 60
const SECONDS_PER_HOUR: int = 3600

var _click_dps: ClickDpsMeter = ClickDpsMeter.new()
var _dps_refresh_left: float = 0.0
var _game: GameState
var _permanent: PermanentState
var _saves: SaveManager
var _floors: FloorManager
var _companions: CompanionManager
var _skills: SkillManager
var _talents: TalentTree
var _inventory: Inventory
# Kept alive here: it stops pushing the bonuses if this object is freed.
var _modifiers: ModifierHub
var _loot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _crit_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _autosave_timer: Timer
var _loot_timer: Timer
var _offline: OfflineIncome
var _display: DisplaySettings
# Whether the effects are stopped now (modal screen or hidden tab); see _sync_effects_pause.
var _effects_paused: bool = false
var _tab_hidden: bool = false
var _document: JavaScriptObject
# Kept alive here: the browser listener stops working if this object is freed.
var _tab_visibility_callback: JavaScriptObject
var _shape: AdaptiveLayout.Shape = AdaptiveLayout.Shape.UNDECIDED
# Changing the content scale makes the window report a new size: see _sync_window.
var _syncing_window: bool = false
var _dots: NotificationDots = NotificationDots.new()
# The place of the loot message, shared with the sentence of the first awakening (story 017).
var _message_slot: MessageSlot = MessageSlot.new()
# Reference to the gold value last drawn: every change of gold is a new BigNumber.
var _gold_drawn: BigNumber
var _talent_points_seen: int = -1
# The loot message being shown, line by line: its title depends on where it goes.
var _loot_lines: PackedStringArray = PackedStringArray()
# Its sale in a few words, for a narrow slot; empty when nothing was sold to make room.
var _loot_short_sale: String = ""
# First-run answer for the visual effects: see _setup_visual_effects.
var _effects_when_never_set: bool = true
# Whether the last input was a key: a focus moved for a mouse user keeps its ring hidden.
var _keyboard_used: bool = false
# Whether the window of the return message shows the new talent tree message now.
var _version_notice_open: bool = false
# Height the window of the return message asks for: its content, at least OFFLINE_PANEL_HEIGHT; the
# view caps it (AdaptiveLayout.modal_rect).
var _message_window_height: float = OFFLINE_PANEL_HEIGHT
# The first press of "Abandonner" waits here for its confirmation.
var _abandon_confirm: ConfirmPress = ConfirmPress.new()

@onready var _layout: Control = %Layout
@onready var _split: BoxContainer = %Split
@onready var _game_zone: GameZone = %GameZone
@onready var _tabs: ManagementTabs = %ManagementTabs
@onready var _stage_label: Label = %StageLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _dps_button: Button = %DpsButton
@onready var _bubble: HintBubble = %HintBubble
@onready var _hp_fill: ColorRect = %HpFill
@onready var _hp_label: Label = %HpLabel
@onready var _dps_label: Label = %DpsLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _error_label: Label = %ErrorLabel
@onready var _enemy: EnemyView = %Enemy
@onready var _companion_panel: CompanionPanel = %CompanionPanel
@onready var _skill_bar: SkillBar = %SkillBar
@onready var _boss_timer: BossTimer = %BossTimer
@onready var _challenge_button: Button = %ChallengeButton
@onready var _abandon_button: Button = %AbandonButton
@onready var _boss_hint_label: Label = %BossHintLabel
@onready var _talent_screen: TalentScreen = %TalentScreen
@onready var _inventory_screen: InventoryScreen = %InventoryScreen
@onready var _save_button: Button = %SaveButton
@onready var _save_screen: SaveScreen = %SaveScreen
@onready var _orbs: CompanionOrbs = %CompanionOrbs
@onready var _texts: FloatingTextLayer = %FloatingTextLayer
@onready var _loot_toast: PanelContainer = %LootToast
@onready var _loot_message: Label = %LootMessage
@onready var _offline_blocker: ColorRect = %OfflineBlocker
@onready var _offline_panel: PanelContainer = %OfflinePanel
@onready var _offline_title: Label = %OfflineTitle
@onready var _offline_message: Label = %OfflineMessage
@onready var _offline_close_button: Button = %OfflineCloseButton


func _ready() -> void:
	# Icons only: the names are what a screen reader and a pointer read.
	_save_button.tooltip_text = tr("Réglages")
	_save_button.accessibility_name = tr("Réglages")
	_dps_button.accessibility_name = tr("Détail du DPS")
	# Before anything else and without waiting a frame: no wrong layout may ever be shown.
	_sync_window()
	get_window().size_changed.connect(_sync_window)
	resized.connect(_fit_overlays)
	_fit_overlays()
	var curves: Variant = DataLoader.load_json(CURVES_PATH)
	var roster: Variant = DataLoader.load_json(ROSTER_PATH)
	var combat: Combat = Combat.from_data(curves, roster)
	var boss: BossFight = BossFight.from_data(DataLoader.load_json(BOSSES_PATH))
	_offline = OfflineIncome.from_data(curves, combat)
	var error: String = combat.get_error()
	if error.is_empty():
		error = boss.get_error()
	if error.is_empty():
		error = _offline.get_error()
	if not error.is_empty():
		_show_error(error)
		return
	_saves = SaveManager.new()
	_game = _saves.load_game()
	_permanent = _saves.load_permanent()
	_floors = FloorManager.new(_game, combat, boss, _permanent)
	_talents = TalentTree.from_data(DataLoader.load_json(TALENTS_PATH), _permanent, _game)
	if not _talents.is_valid():
		_show_error(_talents.get_error())
		return
	_loot_rng.randomize()
	_crit_rng.randomize()
	_inventory = Inventory.from_data(DataLoader.load_json(ITEMS_PATH), _permanent, _game, combat, _loot_rng.randf)
	if not _inventory.is_valid():
		_show_error(_inventory.get_error())
		return
	_floors.set_crit_roll(_crit_rng.randf)
	_floors.boss_killed.connect(_inventory.on_boss_killed)
	# Before the offline grant, and before any handler below connects to a "changed" signal.
	_modifiers = ModifierHub.new(_floors, _offline, _talents, _inventory)
	# After the hub: the locks and values of the talents apply to the restored timers at once.
	_skills = SkillManager.from_data(DataLoader.load_json(SKILLS_PATH), _game, combat, _floors, _modifiers)
	if not _skills.is_valid():
		_show_error(_skills.get_error())
		return
	var offline_gain: Dictionary = _grant_offline_gold()
	# After the absence is paid with the bonuses the player had (design/talent-tree-v2.md, Données).
	_talents.apply_tree_version()
	_floors.enemy_damaged.connect(_on_enemy_damaged)
	_floors.stage_started.connect(_on_stage_started)
	_floors.farming_changed.connect(_on_farming_changed)
	_floors.boss_failed.connect(_on_boss_failed)
	_challenge_button.pressed.connect(_on_challenge_pressed)
	_abandon_button.pressed.connect(_on_abandon_pressed)
	_save_screen.set_auto_challenge(_floors.auto_challenge())
	_save_screen.auto_challenge_toggled.connect(_on_auto_toggled)
	_enemy.clicked.connect(_on_enemy_clicked)
	_companions = CompanionManager.new(_game, combat, _floors)
	_companions.companion_leveled_up.connect(_on_companion_leveled_up)
	_companions.companions_bought.connect(_on_companion_leveled_up)
	_setup_visual_effects(roster)
	_companion_panel.buy_requested.connect(_on_companion_buy_requested)
	_companion_panel.awaken_requested.connect(_on_companion_awaken_requested)
	_companions.awakened.connect(_on_companion_awakened)
	_companion_panel.mode_changed.connect(_on_buy_mode_changed)
	_companion_panel.set_mode(_display.buy_mode())
	_companion_panel.squad_dps_pressed.connect(_on_squad_dps_pressed)
	_tabs.set_collapsed(_display.panel_collapsed())
	_tabs.collapsed_changed.connect(_on_panel_collapsed)
	_sync_window()
	_companion_panel.set_colors(roster)
	_companion_panel.setup(_companions, func() -> BigNumber: return _game.gold)
	_gold_drawn = _game.gold
	_skill_bar.activate_requested.connect(_on_skill_requested)
	_skill_bar.unlock_requested.connect(_on_skill_unlock_requested)
	_skill_bar.setup(_skills)
	_skill_bar.watch_with(_bubble)
	_dps_button.pressed.connect(_on_dps_pressed)
	_dps_button.focus_exited.connect(_on_dps_unfocused)
	_tabs.tab_selected.connect(_on_tab_selected)
	_abandon_button.focus_exited.connect(_on_action_unfocused.bind(_abandon_button))
	_challenge_button.focus_exited.connect(_on_action_unfocused.bind(_challenge_button))
	_talents.changed.connect(_on_talents_changed)
	_talent_screen.buy_requested.connect(_on_talent_buy_requested)
	_talent_screen.reset_requested.connect(_on_talent_reset_requested)
	_talent_screen.set_context(_skills, float((curves as Dictionary).get("offline_max_hours", 0.0)),
			func() -> int: return int(Time.get_unix_time_from_system()), _floors.is_boss_fight)
	_talent_screen.setup(_talents)
	_refresh_talents_button()
	_inventory.changed.connect(_on_inventory_changed)
	_inventory.loot_received.connect(_on_loot_received)
	_inventory_screen.equip_requested.connect(_on_equip_requested)
	_inventory_screen.setup(_inventory)
	# The last skill of the bar ends the game zone for the keyboard, now that "Défi auto" left it.
	_tabs.link_focus(_skill_bar.button_of(_skills.skills()[-1].id), _dps_button)
	_save_screen.copy_requested.connect(_on_save_copy_requested)
	_save_screen.reset_confirmed.connect(_on_save_reset_confirmed)
	_save_screen.effects_toggled.connect(_on_effects_toggled)
	_save_screen.fullscreen_toggled.connect(_on_fullscreen_toggled)
	_refresh_fullscreen()
	_save_screen.closed.connect(_on_save_screen_closed)
	_save_screen.setup(_game_version())
	_save_button.pressed.connect(_on_save_button_pressed)
	_start_message_timers()
	_start_autosave(curves)
	_show_stage(_game.stage)
	_refresh()
	_refresh_boss()
	_observe_companions()
	_on_farming_changed(_floors.is_farming())
	_offline_close_button.pressed.connect(_on_offline_closed)
	if not offline_gain.is_empty():
		_show_offline_gain(offline_gain)
	elif _talents.version_notice_due():
		_show_version_notice()
	_watch_tab_visibility()


func _process(delta: float) -> void:
	# The game waits behind the return message and "Réglages", never behind a tab (D1).
	if _companions == null:
		return
	_sync_effects_pause()
	if _game_waits():
		return
	# Damage first, then the boss countdown (see FloorManager: a boss killed this
	# frame is killed even if this frame's delta would have run the countdown out).
	_companions.tick(delta)
	_floors.tick(delta)
	_skills.tick(delta)
	_skill_bar.refresh()
	_refresh_boss()
	_click_dps.tick(delta)
	_dps_refresh_left -= delta
	if _dps_refresh_left <= 0.0:
		_dps_refresh_left = DPS_REFRESH_SECONDS
		_refresh_dps()
		_refresh_costs()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		_keyboard_used = true
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		_keyboard_used = false


# Escape closes the detail of the open tab, and does nothing else here. The modal screens come
# first: "Réglages" handles Escape itself, and the return message leaves what lies behind alone.
func _unhandled_input(event: InputEvent) -> void:
	if _companions == null or _game_waits() or not event.is_action_pressed("ui_cancel"):
		return
	if _tabs.close_open_detail():
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or _skills == null or _game_waits():
		return
	var index: int = SKILL_KEYS.find(key.physical_keycode)
	if index < 0 or index >= _skills.skills().size():
		return
	_on_skill_key(_skills.skills()[index].id)
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_save()
	# The tab listener would outlive this scene when a save reset reloads it.
	if _document != null:
		_document.removeEventListener("visibilitychange", _tab_visibility_callback)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save()


## Replaces the game with the data error: nothing else is shown or run.
func _show_error(error: String) -> void:
	push_error("Main screen: " + error)
	_error_label.text = error
	_error_label.visible = true
	# Header, game zone and tabs: the message stands alone.
	_layout.visible = false


func _game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "?"))


# Reads the window and applies the shape and the scale. Changing the content scale makes the window
# signal a new size at once, hence the guard; everything here gives the same answer a second time.
func _sync_window() -> void:
	if _syncing_window:
		return
	_syncing_window = true
	var css_size: Vector2 = Vector2(get_window().size) / _device_pixel_ratio()
	# After a reload this node knows no shape yet, but the window remembers the last one.
	var previous: AdaptiveLayout.Shape = _shape
	if previous == AdaptiveLayout.Shape.UNDECIDED:
		previous = get_window().get_meta(SHAPE_META, AdaptiveLayout.Shape.UNDECIDED)
	var shape: AdaptiveLayout.Shape = AdaptiveLayout.decide_shape(css_size, previous)
	if shape != _shape:
		_shape = shape
		get_window().set_meta(SHAPE_META, shape)
		_bubble.cancel()
		_apply_shape()
	_bubble.set_css_per_unit(AdaptiveLayout.css_per_unit(css_size, shape))
	var logical_height: float = AdaptiveLayout.logical_size(css_size, shape).y
	# A collapsed panel gives its height to the scene (story 019b); only portrait has the handle.
	var scene: float = AdaptiveLayout.portrait_scene_collapsed(logical_height) if _tabs.is_collapsed() \
			else AdaptiveLayout.portrait_scene(logical_height)
	_game_zone.set_layout(shape, scene)
	var content: Vector2i = AdaptiveLayout.content_size(css_size, shape)
	if get_window().content_scale_size != content:
		get_window().content_scale_size = content
	# Leaving full screen (back gesture, Escape) resizes the window and never touches the toggle.
	_refresh_fullscreen()
	_syncing_window = false


# get_window().size is in physical pixels on the web, and 1 CSS pixel is that many of them.
func _device_pixel_ratio() -> float:
	if not OS.has_feature("web"):
		return 1.0
	var ratio: Variant = JavaScriptBridge.eval("window.devicePixelRatio", true)
	return float(ratio) if (ratio is float or ratio is int) and float(ratio) > 0.0 else 1.0


# Everything that differs between the shapes and is not a rectangle of the game zone.
func _apply_shape() -> void:
	var portrait: bool = _shape == AdaptiveLayout.Shape.PORTRAIT
	_split.vertical = portrait
	_game_zone.size_flags_vertical = Control.SIZE_FILL if portrait else Control.SIZE_EXPAND_FILL
	# The header is the same line in both shapes (story 019b): its sizes are in main_screen.tscn.
	# The scene is the same in both shapes too (lot 9): the left column of the landscape screen holds
	# the portrait scene, its corner, its thin timer band and its row of skills.
	_set_font_size([_hp_label, _abandon_button, _challenge_button], FONT_16)
	_boss_timer.set_compact(true)
	_reserve_header_widths()
	_skill_bar.set_compact(true)
	_tabs.set_handle_enabled(portrait)
	if _floors != null:
		_refresh()


func _set_font_size(controls: Array, font_size: int) -> void:
	for control: Control in controls:
		control.add_theme_font_size_override("font_size", font_size)


# Each value keeps the room of its longest text, so that a growing number never pushes its
# neighbours. Measured, not guessed: the widths follow the font sizes of the shape.
func _reserve_header_widths() -> void:
	_stage_label.custom_minimum_size.x = _text_width(_stage_label, tr("Étage %d") % HEADER_LONGEST_STAGE)
	_score_label.custom_minimum_size.x = _text_width(_score_label, _record_text(HEADER_LONGEST_STAGE))
	_gold_label.custom_minimum_size.x = _text_width(_gold_label, HEADER_LONGEST_VALUE)
	_dps_label.custom_minimum_size.x = _text_width(_dps_label, _dps_text(HEADER_LONGEST_VALUE))
	# The labels sit inside the button: it cannot take its width from them by itself.
	var gold_row: float = HEADER_COIN_WIDTH + HEADER_COIN_GAP + _gold_label.custom_minimum_size.x
	var dps_row: float = _dps_label.custom_minimum_size.x + HEADER_OPEN_GAP + HEADER_OPEN_WIDTH
	_dps_button.custom_minimum_size.x = maxf(gold_row, dps_row) + HEADER_DPS_MARGIN * 2.0


func _text_width(control: Control, text: String) -> float:
	var font: Font = control.get_theme_font("font")
	var font_size: int = control.get_theme_font_size("font_size")
	return ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)


func _record_text(stage: int) -> String:
	return tr("Record %d") % stage


func _dps_text(value: String) -> String:
	return tr("%s DPS") % value


# The overlays that take their size from the screen and not from a container.
func _fit_overlays() -> void:
	var rect: Rect2 = AdaptiveLayout.modal_rect(size, _message_window_height)
	_offline_panel.position = rect.position
	_offline_panel.size = rect.size


func _show_stage(stage: int) -> void:
	_enemy.set_stage(stage, _floors.is_boss_fight())
	_game_zone.set_stage_tint(EnemyView.stage_color(stage))


func _start_message_timers() -> void:
	_loot_timer = Timer.new()
	_loot_timer.wait_time = LOOT_MESSAGE_SECONDS
	_loot_timer.one_shot = true
	_loot_timer.timeout.connect(_on_message_timeout)
	add_child(_loot_timer)


# The message ends; a loot that waited behind the sentence of the first awakening shows now.
func _on_message_timeout() -> void:
	_loot_toast.hide()
	_message_slot.release()


func _start_autosave(curves: Variant) -> void:
	var seconds: float = FALLBACK_AUTOSAVE_SECONDS
	var configured: Variant = (curves as Dictionary).get("autosave_interval_seconds")
	if (configured is int or configured is float) and float(configured) > 0.0:
		seconds = float(configured)
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = seconds
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(_save)
	add_child(_autosave_timer)


func _save() -> void:
	if _saves == null or _game == null:
		return
	if _skills != null and _skills.is_valid():
		_skills.save_to(_game)
	if _talents != null and _talents.is_valid():
		_talents.sync_best_stage()
	_saves.save(_game, _permanent)


func _grant_offline_gold() -> Dictionary:
	var gain: Dictionary = _offline.grant(_game, int(Time.get_unix_time_from_system()))
	_save()
	return gain


func _watch_tab_visibility() -> void:
	if not OS.has_feature("web"):
		return
	_document = JavaScriptBridge.get_interface("document")
	_tab_visibility_callback = JavaScriptBridge.create_callback(_on_tab_visibility_changed)
	_document.addEventListener("visibilitychange", _tab_visibility_callback)


func _on_tab_visibility_changed(_args: Array) -> void:
	_tab_hidden = _document.hidden
	_sync_effects_pause()
	if _tab_hidden:
		_bubble.reset()
		_save()
		return
	var gain: Dictionary = _grant_offline_gold()
	if gain.is_empty():
		return
	_refresh()
	_companion_panel.refresh()
	_show_offline_gain(gain)


func _show_offline_gain(gain: Dictionary) -> void:
	# A web return can come while "Réglages" is open: the message goes first. Tabs stay as they are.
	_bubble.cancel()
	_save_screen.close()
	_version_notice_open = false
	_offline_title.text = tr("Bon retour !")
	var duration: String = _format_duration(gain["seconds"])
	var gold: String = (gain["gold"] as BigNumber).format()
	if gain["capped"]:
		_offline_message.text = tr("Absence prise en compte : %s (plafond atteint)\nOr gagné : %s") % [duration, gold]
	else:
		_offline_message.text = tr("Absence prise en compte : %s\nOr gagné : %s") % [duration, gold]
	_open_message_window()


## Shows the window of the return message with the texts already set. The focus goes to Continuer
## for the keyboard, but the ScrollContainer follows the focus and would open the window scrolled to
## that button, the title out of sight: the window first grows to its content (up to the view), then
## the scroll goes back to the top once the layout is known.
func _open_message_window() -> void:
	_offline_blocker.visible = true
	_offline_panel.visible = true
	_offline_close_button.grab_focus()
	_fit_message_window()


func _fit_message_window() -> void:
	var scroll: ScrollContainer = _offline_panel.get_child(0) as ScrollContainer
	if not _offline_panel.is_inside_tree():
		return
	# Wrapped labels know their height only once the layout gave them their width.
	await _offline_panel.get_tree().process_frame
	var content: Control = scroll.get_child(0) as Control
	var margins: float = _offline_panel.get_theme_stylebox("panel").get_minimum_size().y
	_message_window_height = maxf(OFFLINE_PANEL_HEIGHT, content.get_combined_minimum_size().y + margins)
	_fit_overlays()
	await _offline_panel.get_tree().process_frame
	scroll.scroll_vertical = 0


## What closing the message window means for the talent tree: the version message it showed is
## acknowledged (the tree sells again), or, after a return message, the version message is still
## due and must come next. Returns true when it must be shown now.
func _close_talent_notice() -> bool:
	if _version_notice_open:
		_version_notice_open = false
		_talents.acknowledge_version()
		return false
	return _talents != null and _talents.version_notice_due()


## The one-time message of a new talent tree (story 019): the points came back, the old bonuses are
## gone until the next purchases. It uses the window of the return message, so the game waits the
## same way; closing it is the acknowledgment the tree waits for before it sells anything again.
func _show_version_notice() -> void:
	_bubble.cancel()
	_save_screen.close()
	_version_notice_open = true
	_offline_title.text = tr("Nouvel arbre de talents")
	# A non-breaking space before the colon: it never starts a line.
	_offline_message.text = tr("L'arbre de talents a changé : tous tes points te sont rendus. Les bonus de tes anciens talents sont retirés jusqu'à tes prochains achats.")
	_open_message_window()


func _on_offline_closed() -> void:
	if _close_talent_notice():
		_show_version_notice()
		return
	_offline_blocker.visible = false
	_offline_panel.visible = false
	# The focus was in the panel: a keyboard player would otherwise have it nowhere.
	_tabs.focus_active(not _keyboard_used)


@warning_ignore("integer_division")
func _format_duration(seconds: int) -> String:
	var hours: int = seconds / SECONDS_PER_HOUR
	var minutes: int = seconds % SECONDS_PER_HOUR / SECONDS_PER_MINUTE
	if hours > 0:
		return tr("%d h %02d min") % [hours, minutes]
	if minutes > 0:
		return tr("%d min") % minutes
	return tr("%d s") % seconds


func _game_waits() -> bool:
	return _offline_panel.visible or _save_screen.visible


func _on_talent_buy_requested(id: String) -> void:
	_talents.buy(id)


# Always through the rules of the tree (boss fight, real-time wait, version message), never the
# unconditional TalentTree.reset(); a refusal is told in the reset card, with its reason.
func _on_talent_reset_requested() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var in_boss_fight: bool = _floors.is_boss_fight()
	if not _talents.try_reset(now, in_boss_fight):
		_talent_screen.show_reset_refused(TalentScreen.reset_refusal_text(_talents, now, in_boss_fight))


func _on_talents_changed() -> void:
	_talent_screen.refresh()
	_refresh_talents_button()
	_refresh()
	_companion_panel.refresh()
	_refresh_dps()


# A node can only become buyable when the unspent points change: buying and resetting change them.
func _refresh_talents_button() -> void:
	var points: int = _talents.available_points()
	if points == _talent_points_seen:
		return
	_talent_points_seen = points
	_tabs.set_talent_points(points)
	var buyable: PackedStringArray = PackedStringArray()
	for talent: Variant in _talents.nodes():
		if _talents.can_buy(talent.id):
			buyable.append(talent.id)
	_dots.observe_talents(buyable)
	_show_dots()


func _on_save_button_pressed() -> void:
	_bubble.cancel()
	focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_save_screen.open()


func _on_save_screen_closed() -> void:
	focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	_save_button.grab_focus(not _keyboard_used)


func _on_tab_selected(tab: int) -> void:
	_bubble.cancel()
	_dots.set_open_tab(tab)
	_show_dots()
	match tab:
		ManagementTabs.Tab.INVENTORY:
			_inventory_screen.refresh()
		ManagementTabs.Tab.TALENTS:
			_talent_screen.refresh()


func _show_dots() -> void:
	for tab: int in ManagementTabs.Tab.values():
		_tabs.set_dot(tab, _dots.is_lit(tab))


# Asks each companion's next goal of the gold: enough scanning for the goal and no more.
func _observe_companions() -> void:
	var goals: Dictionary = {}
	for companion: Companion in _companions.companions():
		var id: String = companion.id
		var level: int = _companions.level(id)
		var goal: int = NotificationDots.next_goal(level, _companions.tier_levels(id))
		var levels_needed: int = goal - level
		var reached: bool = goal > 0 and _companions.affordable_levels(id, levels_needed) >= levels_needed
		goals[id] = goal if reached else 0
	_dots.observe_companions(goals)
	_show_dots()


# Costs and dots follow the gold at the pace of _process, never each frame.
func _refresh_costs() -> void:
	if _game.gold == _gold_drawn:
		return
	_gold_drawn = _game.gold
	_companion_panel.refresh()
	_observe_companions()


# Abandon or Défier vanished under the keyboard focus: the player would be nowhere.
func _on_action_unfocused(button: Button) -> void:
	if not button.is_visible_in_tree():
		_tabs.focus_active.call_deferred(not _keyboard_used)


func _on_dps_pressed() -> void:
	if _bubble.is_showing_for(_dps_button):
		_bubble.dismiss()
		return
	_bubble.show_for(_dps_button, _dps_button.tooltip_text)


func _on_dps_unfocused() -> void:
	if _bubble.is_showing_for(_dps_button):
		_bubble.dismiss()


# "DPS des souris" in the header of the Souris tab opens the same detail as the screen header
# (Amaury, 2026-11-04), next to itself; a second touch closes it.
func _on_squad_dps_pressed() -> void:
	var target: Control = _companion_panel.squad_dps_button()
	if _bubble.is_showing_for(target):
		_bubble.dismiss()
		return
	_bubble.show_for(target, _dps_button.tooltip_text)


# The handle, a header or a tab changed the panel: the scene takes or gives back the height.
func _on_panel_collapsed(collapsed: bool) -> void:
	_bubble.cancel()
	_display.set_panel_collapsed(collapsed)
	_sync_window()


func _on_save_copy_requested() -> void:
	_save()
	var text: String = _saves.export_text(_game_version())
	DisplayServer.clipboard_set(text)
	_save_screen.show_copied(text)


func _on_save_reset_confirmed() -> void:
	if not _saves.reset():
		_save_screen.show_reset_failed()
		return
	# No save may follow, not even the one of _exit_tree: it would write the old game back.
	_saves = null
	get_tree().reload_current_scene()


func _on_equip_requested(uid: int) -> void:
	_inventory.equip(uid)


func _on_inventory_changed() -> void:
	_inventory_screen.refresh()
	_refresh()
	_companion_panel.refresh()
	_refresh_dps()


func _on_loot_received(item: Item, sold: Array[Item], gold_gained: BigNumber) -> void:
	if not sold.has(item):
		_dots.note_item_kept()
		_show_dots()
	# The sentence of the first awakening is shown once in a game's life: a loot waits behind it.
	_message_slot.offer(_show_loot.bind(item, sold, gold_gained))


func _show_loot(item: Item, sold: Array[Item], gold_gained: BigNumber) -> void:
	_loot_lines = _loot_text(item, sold, gold_gained)
	_loot_short_sale = ""
	if not sold.is_empty() and not sold.has(item):
		# Whole on its line: a narrow toast breaks after the colon, never inside the amount.
		_loot_short_sale = tr("Sac plein : %s") % CompanionPanel.keep_together(tr("+%s or") % gold_gained.format())
	_loot_message.add_theme_color_override("font_color", _inventory_screen.rarity_color(item.rarity))
	_loot_toast.visible = true
	_place_loot_toast()
	_loot_timer.start()


func _loot_text(item: Item, sold: Array[Item], gold_gained: BigNumber) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray([tr("Butin !"), _inventory_screen.describe(item)])
	var gold: String = gold_gained.format()
	if sold.has(item):
		lines.append(tr("Vendu aussitôt : +%s or") % gold)
	elif sold.size() == 1:
		lines.append(tr("Sac plein, vendu (%s), +%s or") % [_inventory_screen.describe(sold[0]), gold])
	elif sold.size() > 1:
		lines.append(tr("Sac plein, %d objets vendus, +%s or") % [sold.size(), gold])
	return lines


# Wires the floating texts and the companion spheres to the core signals and applies the saved
# "Effets visuels" setting. [param roster] is the data of companions_roster.json (sphere colours).
func _setup_visual_effects(roster: Variant) -> void:
	_display = DisplaySettings.new()
	_enemy.configure_transition(DataLoader.load_json(TRANSITION_PATH))
	_orbs.setup(roster)
	for companion: Companion in _companions.companions():
		_orbs.set_level(companion.id, _companions.level(companion.id))
	_floors.hit_landed.connect(_texts.show_hit)
	_floors.kill_rewarded.connect(_texts.show_gold)
	_companions.companion_attacked.connect(_orbs.on_companion_attacked)
	# The enemy can stand still in its parent while the parent moves: a shape change does that.
	var moving: Control = _enemy
	while moving != null:
		moving.item_rect_changed.connect(_sync_effects_layout)
		moving = moving.get_parent_control()
	_game_zone.sort_children.connect(_sync_effects_layout)
	# The room of the loot message depends on what stands in the action band, and on its height.
	_challenge_button.visibility_changed.connect(_place_loot_toast)
	_boss_timer.visibility_changed.connect(_place_loot_toast)
	_loot_toast.resized.connect(_place_loot_toast)
	# A wrapped label finds its height after the layout, and a Control never shrinks by itself.
	_loot_message.minimum_size_changed.connect(_place_loot_toast)
	_sync_effects_layout()
	_effects_when_never_set = not _prefers_reduced_motion()
	_apply_visual_effects()


# Both effects aim at the center of the enemy, wherever the layout put it: the global anchor,
# converted into each layer's own space, and never a local position of another parent.
func _sync_effects_layout() -> void:
	var anchor: Vector2 = _enemy.anchor_global()
	var anchor_in_texts: Vector2 = _texts.get_global_transform().affine_inverse() * anchor
	_texts.set_target_point(anchor_in_texts)
	_texts.set_box_scale(_enemy.box_scale())
	# The monster area, from the unscaled size: a squash must not change where the texts may go.
	_texts.set_bounds(Rect2(anchor_in_texts - _enemy.size / 2.0, _enemy.size))
	var to_orbs: Transform2D = _orbs.get_global_transform().affine_inverse()
	_orbs.set_target_point(to_orbs * anchor)
	var slots: PackedVector2Array = (to_orbs * _game_zone.get_global_transform()) * _game_zone.orb_slots()
	_orbs.set_slots(slots, _game_zone.orb_slot_radius())
	_place_loot_toast()


# In the room the game zone gives (see GameZone.loot_slot_for): the free band when the message fits
# there, otherwise the same place as with an occupied band. In a narrow slot the title goes, the
# rarity colour and the item saying it, and the longest sale takes its short form. Whatever the
# width, the first version that fits the height of the slot is shown: the message never reaches the
# HP bar.
func _place_loot_toast() -> void:
	if _loot_lines.is_empty():
		return
	var versions: PackedStringArray = InventoryScreen.loot_versions(_loot_lines, _loot_short_sale)
	var slot: Rect2 = _game_zone.loot_slot(true)
	var free_fits: bool = _loot_height(versions[0], minf(slot.size.x, LOOT_MAX_WIDTH)) <= slot.size.y
	if not _game_zone.band_free() or not free_fits:
		slot = _game_zone.loot_slot(false)
	var width: float = minf(slot.size.x, LOOT_MAX_WIDTH)
	var text: String = versions[-1]
	var narrow: bool = slot.size.x < LOOT_TITLE_MIN_WIDTH
	for i in range(InventoryScreen.loot_first_version(versions, _loot_short_sale, narrow), versions.size()):
		if _loot_height(versions[i], width) <= slot.size.y:
			text = versions[i]
			break
	_loot_message.text = text
	_loot_message.max_lines_visible = InventoryScreen.loot_max_lines(slot.size.y, LOOT_LINE_HEIGHT, LOOT_VERTICAL_MARGINS)
	var to_root: Transform2D = get_global_transform().affine_inverse() * _game_zone.get_global_transform()
	var corner: Vector2 = to_root * slot.position
	_loot_toast.custom_minimum_size.x = width
	_loot_toast.position = Vector2(corner.x + (slot.size.x - width) / 2.0, corner.y)
	_loot_toast.size = Vector2(width, 0.0)


# Height of the toast for [param text] at [param width], before it is there to be measured: its
# size only follows at the next layout, too late to choose where it goes.
func _loot_height(text: String, width: float) -> float:
	var font: Font = _loot_message.get_theme_font("font")
	var font_size: int = _loot_message.get_theme_font_size("font_size")
	var inner: float = width - LOOT_SIDE_MARGINS
	var text_height: float = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, inner, font_size).y
	return roundf(text_height / font.get_height(font_size)) * LOOT_LINE_HEIGHT + LOOT_VERTICAL_MARGINS


func _on_effects_toggled(enabled: bool) -> void:
	_display.set_visual_effects(enabled)
	_apply_visual_effects()


func _apply_visual_effects() -> void:
	var enabled: bool = _visual_effects_on()
	_texts.set_enabled(enabled)
	_orbs.set_enabled(enabled)
	_enemy.set_transition_enabled(enabled)
	_save_screen.set_effects(enabled)


func _visual_effects_on() -> bool:
	return _display.visual_effects(_effects_when_never_set)


func _prefers_reduced_motion() -> bool:
	if not OS.has_feature("web"):
		return false
	# A String, because a JavaScript boolean does not come back equal to true here (seen in the export).
	return JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'reduce' : ''", true) == "reduce"


# Modal screens and a hidden tab stop the effects and clear what was running, so that nothing
# replays when the game goes on.
func _sync_effects_pause() -> void:
	var paused: bool = _tab_hidden or _game_waits()
	if paused == _effects_paused:
		return
	_effects_paused = paused
	_texts.set_paused(paused)
	_orbs.set_paused(paused)
	_enemy.set_paused(paused)


func _on_enemy_clicked() -> void:
	_click_dps.record(_floors.click())
	if _visual_effects_on():
		_enemy.play_hit()


func _on_enemy_damaged(_damage: BigNumber, _remaining: BigNumber) -> void:
	_refresh()


func _on_stage_started(stage: int, _max_hp: BigNumber) -> void:
	_show_stage(stage)
	_refresh()
	_refresh_talents_button()
	# A new best stage changes the points and the text of the tree; most stage changes do neither.
	if _tabs.selected() == ManagementTabs.Tab.TALENTS:
		_talent_screen.refresh_if_stale()


func _on_farming_changed(farming: bool) -> void:
	_challenge_button.visible = farming
	if not farming:
		_boss_hint_label.visible = false


func _on_boss_failed(_failed_stage: int, _fallback_stage: int) -> void:
	if _permanent.boss_hint_shown:
		return
	_permanent.boss_hint_shown = true
	_boss_hint_label.visible = true


func _on_challenge_pressed() -> void:
	_floors.challenge_boss()


# A stray touch near the monster must not end a fight: the first press only asks to confirm.
func _on_abandon_pressed() -> void:
	if _abandon_confirm.press(_now_seconds()):
		_floors.abandon_boss()
	_refresh_boss()


func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0


func _on_auto_toggled(enabled: bool) -> void:
	_floors.set_auto_challenge(enabled)
	_save_screen.set_auto_challenge(_floors.auto_challenge())


# Only the export can go full screen, and only where the browser allows it (not on an iPhone).
func _fullscreen_available() -> bool:
	if not OS.has_feature("web"):
		return false
	# A String, as in _prefers_reduced_motion: a JavaScript boolean does not come back equal to true.
	return JavaScriptBridge.eval("document.fullscreenEnabled ? 'yes' : ''", true) == "yes"


func _is_fullscreen() -> bool:
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("document.fullscreenElement ? 'yes' : ''", true) == "yes"
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func _refresh_fullscreen() -> void:
	_save_screen.set_fullscreen(_fullscreen_available(), _is_fullscreen())


# The press is a user gesture, which the browser requires. The window then resizes, and
# _sync_window tells the real state to the toggle.
func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	_refresh_fullscreen()


func _on_companion_buy_requested(id: String, count: int) -> void:
	_companions.buy_levels(id, count)


func _on_companion_awaken_requested(id: String) -> void:
	_companions.awaken(id)


# The awakening multiplies the damage at once: everything showing a damage or a cost is redrawn. The
# player's very first awakening says what it did, once, in the loot message (story 017).
func _on_companion_awakened(id: String) -> void:
	_refresh()
	_companion_panel.refresh()
	_refresh_dps()
	_observe_companions()
	if AwakeningText.take_intro(_display):
		# Pinned for its whole duration: a loot arriving meanwhile waits (see MessageSlot).
		_message_slot.pin()
		_show_message(AwakeningText.intro_sentence(_companions.display_name(id)))


# One sentence in the loot message, in its neutral colour, placed and timed like a loot.
func _show_message(text: String) -> void:
	_loot_lines = PackedStringArray([text])
	_loot_short_sale = ""
	_loot_message.remove_theme_color_override("font_color")
	_loot_toast.visible = true
	_place_loot_toast()
	_loot_timer.start()


func _on_buy_mode_changed(mode: int) -> void:
	_display.set_buy_mode(mode)


func _on_skill_requested(id: String) -> void:
	# Behind a modal the game is paused (see _process): so are the skills.
	if _game_waits():
		return
	_skills.activate(id)
	_skill_bar.refresh()


# Keys 1/2/3: a locked or passive skill explains itself in the bubble, and the tab stays as it is.
func _on_skill_key(id: String) -> void:
	if _game_waits():
		return
	if not _skills.is_unlocked(id) or _skills.is_passive(id):
		_bubble.show_for(_skill_bar.button_of(id), _skill_bar.hint_text(id))
		return
	_on_skill_requested(id)


# A touch on a locked skill opens the card of the node that unlocks it, in the Talents tab.
func _on_skill_unlock_requested(id: String) -> void:
	var node_id: String = TalentScreen.unlock_node_of(_talents, id)
	if _game_waits() or node_id.is_empty():
		return
	_tabs.select(ManagementTabs.Tab.TALENTS)
	_talent_screen.open_node(node_id)


func _on_companion_leveled_up(id: String, new_level: int) -> void:
	_orbs.set_level(id, new_level)
	_refresh()
	_companion_panel.refresh()


func _refresh() -> void:
	var stage: int = _floors.current_stage()
	_stage_label.text = tr("Étage %d") % stage
	_gold_label.text = _game.gold.format()
	_score_label.text = _record_text(_floors.best_stage())
	_hp_label.text = "%s / %s" % [_floors.current_hp().format(), _floors.max_hp().format()]
	# keep_offset: the bar must follow the anchor, not stay where it was.
	_hp_fill.set_anchor(SIDE_RIGHT, _floors.hp_ratio(), true)


func _refresh_boss() -> void:
	var fighting: bool = _floors.is_boss_fight()
	_abandon_button.visible = fighting
	if not fighting:
		# A fight that ended forgets its first press: the next one starts from "Abandonner".
		_abandon_confirm.cancel()
	# A non-breaking space before the question mark: it never starts a line. The word says the state;
	# the dark red and the white edge only add to it.
	var armed: bool = _abandon_confirm.is_armed(_now_seconds())
	_abandon_button.text = tr("Confirmer ?") if armed else tr("Abandonner")
	_abandon_button.theme_type_variation = &"CornerConfirm" if armed else &"CornerButton"
	if fighting:
		_boss_timer.show_fight(_floors.boss_time_left(), _floors.boss_timer_seconds())
	else:
		_boss_timer.hide_fight()


func _refresh_dps() -> void:
	var clicks_without_buff: BigNumber = _click_dps.rate()
	_floors.set_click_dps(clicks_without_buff)
	var from_companions: BigNumber = _floors.buffed_damage(_companions.total_power())
	var from_clicks: BigNumber = _floors.buffed_damage(clicks_without_buff)
	_dps_label.text = _dps_text(from_companions.add(from_clicks).format())
	_companion_panel.set_squad_dps(from_companions.format())
	var click_damage: BigNumber = _floors.buffed_damage(_floors.click_damage())
	_dps_button.tooltip_text = tr("Compagnons : %s\nDPS des clics : %s\nDégâts de clic : %s") % [from_companions.format(), from_clicks.format(), click_damage.format()]
