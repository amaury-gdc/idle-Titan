extends SceneTree
## Headless progression simulator (story 003): plays a run with simulated time on
## the real [Combat], [FloorManager] and [CompanionManager], and prints when each
## milestone stage is reached. Bosses do not exist yet (story 004), so "first boss
## reached" means reaching stage 10.
##
## Player model: clicks steadily at --cps, never pauses, and after every time step
## buys the cheapest affordable next level, repeatedly, until nothing is affordable.
##
## Arguments (after --): --cps=3.0 clicks per second; --dt=0.1 seconds per step;
## --hours=3.0 simulated duration; --curves=<path> and --roster=<path> replace the
## data files, to try a variant without touching assets/data.
##
## Usage:
## [codeblock]
## godot --headless --path . -s res://tools/simulate_progress.gd -- --cps=3 --hours=3
## [/codeblock]

const CURVES_PATH: String = "res://assets/data/core_curves.json"
const ROSTER_PATH: String = "res://assets/data/companions_roster.json"
## Stages reported by the run (measurement points, not balance values).
const MILESTONES: Array[int] = [10, 50, 100, 150]
const SECONDS_PER_HOUR: float = 3600.0
## Simulated time of the extra "stage reached at" line of the report.
const REPORT_STAGE_AT_HOURS: float = 3.0


func _init() -> void:
	var args: Dictionary = _parse_args()
	var combat: Combat = Combat.from_data(
			DataLoader.load_json(args["curves"]), DataLoader.load_json(args["roster"]))
	if not combat.is_valid():
		printerr("simulate_progress: " + combat.get_error())
		quit(1)
		return
	_simulate(combat, args["cps"], args["dt"], args["hours"])
	quit(0)


func _simulate(combat: Combat, cps: float, dt: float, hours: float) -> void:
	var state: GameState = GameState.new()
	var floors: FloorManager = FloorManager.new(state, combat)
	var companions: CompanionManager = CompanionManager.new(state, combat, floors)
	print("Player model: %.2f clicks/s without pause, cheapest affordable level bought after every %.2f s step" % [cps, dt])
	var report_step: int = int(REPORT_STAGE_AT_HOURS * SECONDS_PER_HOUR / dt)
	var steps: int = int(hours * SECONDS_PER_HOUR / dt)
	var next_milestone: int = 0
	var click_debt: float = 0.0
	var started_ms: int = Time.get_ticks_msec()
	for step in steps:
		click_debt += cps * dt
		var clicks: int = int(click_debt)
		click_debt -= float(clicks)
		for i in clicks:
			floors.click()
		companions.tick(dt)
		while _buy_cheapest_affordable(companions):
			pass
		while next_milestone < MILESTONES.size() and state.stage >= MILESTONES[next_milestone]:
			var seconds: float = float(step + 1) * dt
			print("Stage %d reached at %.1f min (%.1f s)" % [MILESTONES[next_milestone], seconds / 60.0, seconds])
			next_milestone += 1
		if step + 1 == report_step:
			print("Stage at %.0f h: %d" % [REPORT_STAGE_AT_HOURS, state.stage])
	for i in range(next_milestone, MILESTONES.size()):
		print("Stage %d NOT reached in %.1f h" % [MILESTONES[i], hours])
	print("End of run at %.1f h: stage %d, levels %s" % [hours, state.stage, str(state.companion_levels)])
	print("Real time: %.1f s" % (float(Time.get_ticks_msec() - started_ms) / 1000.0))


func _buy_cheapest_affordable(companions: CompanionManager) -> bool:
	var best_id: String = ""
	var best_cost: BigNumber = null
	for companion: Companion in companions.companions():
		if not companions.can_buy(companion.id):
			continue
		var cost: BigNumber = companions.next_cost(companion.id)
		if best_cost == null or cost.compare(best_cost) < 0:
			best_id = companion.id
			best_cost = cost
	return not best_id.is_empty() and companions.buy_or_upgrade(best_id)


func _parse_args() -> Dictionary:
	var args: Dictionary = {"cps": 3.0, "dt": 0.1, "hours": 3.0, "curves": CURVES_PATH, "roster": ROSTER_PATH}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() != 2 or not args.has(parts[0]):
			printerr("simulate_progress: ignored argument " + arg)
			continue
		args[parts[0]] = parts[1] if args[parts[0]] is String else parts[1].to_float()
	return args
