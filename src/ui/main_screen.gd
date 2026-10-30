extends Control
## Main screen of Idle Titans (stories 002, 003): stage, gold, click damage, the
## enemy, its HP bar, the score and the companion panel. Composition root: loads
## data and saves, builds the [Combat] / [FloorManager] / [CompanionManager] core,
## feeds it frame time, forwards clicks to it and redraws on its signals. All rules
## live in src/core; this script only displays.
##
## Persistence: loads [GameState] and [PermanentState] through [SaveManager]
## (default user:// paths) at startup; saves every autosave_interval_seconds
## (core_curves.json), on window close request, on focus loss and on tree exit.
## Web caveat (UNVERIFIED): closing the tab may not deliver a close request, and
## when user:// writes reach IndexedDB is untested, so autosave and focus loss
## are the real safety nets there.

const CURVES_PATH: String = "res://assets/data/core_curves.json"
const ROSTER_PATH: String = "res://assets/data/companions_roster.json"
## Used only when core_curves.json has no valid autosave_interval_seconds
## (infrastructure setting, not a gameplay value).
const FALLBACK_AUTOSAVE_SECONDS: float = 10.0
## Time between two redraws of the DPS line (display setting, not a gameplay value).
const DPS_REFRESH_SECONDS: float = 0.25

var _click_dps: ClickDpsMeter = ClickDpsMeter.new()
var _dps_refresh_left: float = 0.0
var _game: GameState
var _permanent: PermanentState
var _saves: SaveManager
var _floors: FloorManager
var _companions: CompanionManager
var _autosave_timer: Timer

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


func _ready() -> void:
	var curves: Variant = DataLoader.load_json(CURVES_PATH)
	var combat: Combat = Combat.from_data(curves, DataLoader.load_json(ROSTER_PATH))
	if not combat.is_valid():
		push_error("Main screen: " + combat.get_error())
		_error_label.text = combat.get_error()
		_error_label.visible = true
		_enemy.visible = false
		_companion_panel.visible = false
		_dps_label.visible = false
		return
	_saves = SaveManager.new()
	_game = _saves.load_game()
	_permanent = _saves.load_permanent()
	_floors = FloorManager.new(_game, combat)
	_floors.enemy_damaged.connect(_on_enemy_damaged)
	_floors.stage_started.connect(_on_stage_started)
	_enemy.clicked.connect(_on_enemy_clicked)
	_companions = CompanionManager.new(_game, combat, _floors)
	_companions.companion_leveled_up.connect(_on_companion_leveled_up)
	_companion_panel.buy_requested.connect(_on_companion_buy_requested)
	_companion_panel.setup(_companions)
	_start_autosave(curves)
	_enemy.set_stage(_game.stage)
	_refresh()


func _process(delta: float) -> void:
	if _companions == null:
		return
	_companions.tick(delta)
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


func _on_enemy_clicked() -> void:
	_click_dps.record(_floors.click())
	_enemy.play_hit()


func _on_enemy_damaged(_damage: BigNumber, _remaining: BigNumber) -> void:
	_refresh()


func _on_stage_started(stage: int, _max_hp: BigNumber) -> void:
	_enemy.set_stage(stage)
	_refresh()
	_companion_panel.refresh()


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
	_score_label.text = tr("Score (étage atteint) : %d") % stage
	_hp_label.text = "%s / %s" % [_floors.current_hp().format(), _floors.max_hp().format()]
	_hp_fill.size.x = _hp_bar.size.x * _floors.hp_ratio()


func _refresh_dps() -> void:
	var from_companions: BigNumber = _companions.total_power()
	var from_clicks: BigNumber = _click_dps.rate()
	_dps_label.text = tr("DPS : %s") % from_companions.add(from_clicks).format()
	_dps_label.tooltip_text = tr("Compagnons : %s\nClics : %s") % [from_companions.format(), from_clicks.format()]
