extends Control
## Main screen of Idle Titans (stories 002, 003, 004, 004b): stage, gold, click damage,
## the enemy, its HP bar, the boss banner or the "Défier le boss" button of farm mode,
## the "Défi automatique" toggle, the score (best stage reached, kept after a boss
## fallback), the companion panel and the message shown on return after an absence.
## Composition root: loads data and saves, builds the [Combat] / [BossFight] /
## [FloorManager] / [CompanionManager] / [OfflineIncome] core, feeds it frame time,
## forwards clicks to it and redraws on its signals. All rules live in src/core; this
## script only displays.
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
## Used only when core_curves.json has no valid autosave_interval_seconds
## (infrastructure setting, not a gameplay value).
const FALLBACK_AUTOSAVE_SECONDS: float = 10.0
## Time between two redraws of the DPS line (display setting, not a gameplay value).
const DPS_REFRESH_SECONDS: float = 0.25
const SECONDS_PER_MINUTE: int = 60
const SECONDS_PER_HOUR: int = 3600

var _click_dps: ClickDpsMeter = ClickDpsMeter.new()
var _dps_refresh_left: float = 0.0
var _game: GameState
var _permanent: PermanentState
var _saves: SaveManager
var _floors: FloorManager
var _companions: CompanionManager
var _autosave_timer: Timer
var _offline: OfflineIncome
var _document: JavaScriptObject
# Kept alive here: the browser listener stops working if this object is freed.
var _tab_visibility_callback: JavaScriptObject

@onready var _stage_label: Label = %StageLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _click_label: Label = %ClickDamageLabel
@onready var _hp_bar: ColorRect = %HpBar
@onready var _hp_fill: ColorRect = %HpFill
@onready var _hp_label: Label = %HpLabel
@onready var _dps_label: Label = %DpsLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _error_label: Label = %ErrorLabel
@onready var _enemy: EnemyView = %Enemy
@onready var _companion_panel: CompanionPanel = %CompanionPanel
@onready var _boss_timer: BossTimer = %BossTimer
@onready var _challenge_button: Button = %ChallengeButton
@onready var _abandon_button: Button = %AbandonButton
@onready var _auto_toggle: Button = %AutoChallengeToggle
@onready var _boss_hint_label: Label = %BossHintLabel
@onready var _offline_panel: PanelContainer = %OfflinePanel
@onready var _offline_message: Label = %OfflineMessage
@onready var _offline_close_button: Button = %OfflineCloseButton


func _ready() -> void:
	var curves: Variant = DataLoader.load_json(CURVES_PATH)
	var combat: Combat = Combat.from_data(curves, DataLoader.load_json(ROSTER_PATH))
	var boss: BossFight = BossFight.from_data(DataLoader.load_json(BOSSES_PATH))
	_offline = OfflineIncome.from_data(curves, combat)
	var error: String = combat.get_error()
	if error.is_empty():
		error = boss.get_error()
	if error.is_empty():
		error = _offline.get_error()
	if not error.is_empty():
		push_error("Main screen: " + error)
		_error_label.text = error
		_error_label.visible = true
		_enemy.visible = false
		_boss_timer.visible = false
		_auto_toggle.visible = false
		_companion_panel.visible = false
		_dps_label.visible = false
		return
	_saves = SaveManager.new()
	_game = _saves.load_game()
	_permanent = _saves.load_permanent()
	var offline_gain: Dictionary = _grant_offline_gold()
	_floors = FloorManager.new(_game, combat, boss, _permanent)
	_floors.enemy_damaged.connect(_on_enemy_damaged)
	_floors.stage_started.connect(_on_stage_started)
	_floors.farming_changed.connect(_on_farming_changed)
	_floors.boss_failed.connect(_on_boss_failed)
	_challenge_button.pressed.connect(_on_challenge_pressed)
	_abandon_button.pressed.connect(_on_abandon_pressed)
	_auto_toggle.set_pressed_no_signal(_floors.auto_challenge())
	_refresh_auto_toggle()
	_auto_toggle.toggled.connect(_on_auto_toggled)
	_enemy.clicked.connect(_on_enemy_clicked)
	_companions = CompanionManager.new(_game, combat, _floors)
	_companions.companion_leveled_up.connect(_on_companion_leveled_up)
	_companion_panel.buy_requested.connect(_on_companion_buy_requested)
	_companion_panel.setup(_companions)
	_start_autosave(curves)
	_enemy.set_stage(_game.stage, _floors.is_boss_fight())
	_refresh()
	_refresh_boss()
	_on_farming_changed(_floors.is_farming())
	_offline_close_button.pressed.connect(_offline_panel.hide)
	if not offline_gain.is_empty():
		_show_offline_gain(offline_gain)
	_watch_tab_visibility()


func _process(delta: float) -> void:
	# The game waits behind the return message: a boss countdown must not run out on it.
	if _companions == null or _offline_panel.visible:
		return
	# Damage first, then the boss countdown (see FloorManager: a boss killed this
	# frame is killed even if this frame's delta would have run the countdown out).
	_companions.tick(delta)
	_floors.tick(delta)
	_refresh_boss()
	_click_dps.tick(delta)
	_dps_refresh_left -= delta
	if _dps_refresh_left <= 0.0:
		_dps_refresh_left = DPS_REFRESH_SECONDS
		_refresh_dps()


func _exit_tree() -> void:
	_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save()


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
	if _document.hidden:
		_save()
		return
	var gain: Dictionary = _grant_offline_gold()
	if gain.is_empty():
		return
	_refresh()
	_companion_panel.refresh()
	_show_offline_gain(gain)


func _show_offline_gain(gain: Dictionary) -> void:
	var duration: String = _format_duration(gain["seconds"])
	var gold: String = (gain["gold"] as BigNumber).format()
	if gain["capped"]:
		_offline_message.text = tr("Absence prise en compte : %s (plafond atteint)\nOr gagné : %s") % [duration, gold]
	else:
		_offline_message.text = tr("Absence prise en compte : %s\nOr gagné : %s") % [duration, gold]
	_offline_panel.visible = true
	_offline_close_button.grab_focus()


@warning_ignore("integer_division")
func _format_duration(seconds: int) -> String:
	var hours: int = seconds / SECONDS_PER_HOUR
	var minutes: int = seconds % SECONDS_PER_HOUR / SECONDS_PER_MINUTE
	if hours > 0:
		return tr("%d h %02d min") % [hours, minutes]
	if minutes > 0:
		return tr("%d min") % minutes
	return tr("%d s") % seconds


func _on_enemy_clicked() -> void:
	_click_dps.record(_floors.click())
	_enemy.play_hit()


func _on_enemy_damaged(_damage: BigNumber, _remaining: BigNumber) -> void:
	_refresh()


func _on_stage_started(stage: int, _max_hp: BigNumber) -> void:
	_enemy.set_stage(stage, _floors.is_boss_fight())
	_refresh()
	_companion_panel.refresh()


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


func _on_abandon_pressed() -> void:
	_floors.abandon_boss()


func _on_auto_toggled(enabled: bool) -> void:
	_floors.set_auto_challenge(enabled)
	_refresh_auto_toggle()


func _refresh_auto_toggle() -> void:
	_auto_toggle.text = tr("Défi automatique : OUI") if _floors.auto_challenge() else tr("Défi automatique : NON")


func _on_companion_buy_requested(id: String) -> void:
	_companions.buy_or_upgrade(id)


func _on_companion_leveled_up(_id: String, _new_level: int) -> void:
	_refresh()
	_companion_panel.refresh()


func _refresh() -> void:
	var stage: int = _floors.current_stage()
	_stage_label.text = tr("Étage %d") % stage
	_gold_label.text = tr("Or : %s") % _game.gold.format()
	_click_label.text = tr("Dégâts de clic : %s") % _floors.click_damage().format()
	_score_label.text = tr("Score (étage atteint) : %d") % _floors.best_stage()
	_hp_label.text = "%s / %s" % [_floors.current_hp().format(), _floors.max_hp().format()]
	_hp_fill.size.x = _hp_bar.size.x * _floors.hp_ratio()


func _refresh_boss() -> void:
	_abandon_button.visible = _floors.is_boss_fight()
	if _floors.is_boss_fight():
		_boss_timer.show_fight(_floors.boss_time_left(), _floors.boss_timer_seconds())
	else:
		_boss_timer.hide_fight()


func _refresh_dps() -> void:
	var from_companions: BigNumber = _companions.total_power()
	var from_clicks: BigNumber = _click_dps.rate()
	_floors.set_click_dps(from_clicks)
	_dps_label.text = tr("DPS : %s") % from_companions.add(from_clicks).format()
	_dps_label.tooltip_text = tr("Compagnons : %s\nClics : %s") % [from_companions.format(), from_clicks.format()]
