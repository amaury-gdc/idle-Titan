extends SceneTree
## Headless progression simulator (stories 003, 004): plays a run with simulated time
## on the real [Combat], [BossFight], [FloorManager] and [CompanionManager], and
## prints when each milestone stage is reached. "Reached" is the best stage reached
## (GameState.max_stage_reached): a stage counts as soon as its fight begins, so the
## first boss is "reached" when its fight starts and "killed" when the next stage is
## reached. The boss countdown runs on the simulated time and a failed boss falls
## back one stage into farm mode (see [FloorManager]).
##
## Player model: clicks steadily at --cps, never pauses, and after every time step
## buys the cheapest affordable next level, repeatedly, until nothing is affordable.
## In farm mode it challenges the boss as soon as [method FloorManager.can_beat_next_boss]
## says so, with click dps = cps * click_damage, checked once per simulated second.
## With --auto=1 the "Défi automatique" setting makes the same test at each farm kill.
##
## Arguments (after --): --cps=3.0 clicks per second; --dt=0.1 seconds per step;
## --hours=3.0 simulated duration; --auto=1 for the auto challenge policy (default 0);
## --curves=<path>, --roster=<path> and --bosses=<path>
## replace the data files, to try a variant without touching assets/data.
## Report: time to the first boss fight, to the first boss kill, to stages 50/100/150,
## the stage at 3 h and the number of failed boss attempts (at each milestone and at the end).
##
## Usage:
## [codeblock]
## godot --headless --path . -s res://tools/simulate_progress.gd -- --cps=3 --hours=3
## [/codeblock]

const CURVES_PATH: String = "res://assets/data/core_curves.json"
const ROSTER_PATH: String = "res://assets/data/companions_roster.json"
const BOSSES_PATH: String = "res://assets/data/boss_curves.json"
## Stages reported by the run besides the first boss fight and the first boss kill,
## which come from the boss data (measurement points, not balance values).
const MILESTONES: Array[int] = [50, 100, 110, 120, 130, 150]
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
	var boss: BossFight = BossFight.from_data(DataLoader.load_json(args["bosses"]))
	if not boss.is_valid():
		printerr("simulate_progress: " + boss.get_error())
		quit(1)
		return
	_simulate(combat, boss, args["cps"], args["dt"], args["hours"], args["auto"] > 0.0)
	quit(0)


func _simulate(combat: Combat, boss: BossFight, cps: float, dt: float, hours: float, auto: bool) -> void:
	var state: GameState = GameState.new()
	var permanent: PermanentState = PermanentState.new()
	permanent.auto_challenge = auto
	var floors: FloorManager = FloorManager.new(state, combat, boss, permanent)
	var companions: CompanionManager = CompanionManager.new(state, combat, floors)
	var failed_attempts: Array[int] = [0]
	floors.boss_failed.connect(func(_failed: int, _back_to: int) -> void: failed_attempts[0] += 1)
	var first_boss_stage: int = 1
	while not boss.is_boss_stage(first_boss_stage):
		first_boss_stage += 1
	var milestones: Array[int] = [first_boss_stage, first_boss_stage + 1]
	milestones.append_array(MILESTONES)
	# Boss HP to beat, computed once per fallback; power is checked once per simulated
	# second so a long farm stays cheap to simulate (GrowthCurve, BigNumber sums).
	var check_every: int = maxi(int(1.0 / dt), 1)
	var cps_factor: String = "%.3f" % cps
	print("Player model: %.2f clicks/s without pause, cheapest affordable level bought after every %.2f s step; boss countdown %.0f s; farm mode exit: %s" % [cps, dt, boss.timer_seconds(), "auto challenge setting" if auto else "challenge when expected damage covers the boss HP"])
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
		# Same order as the main screen: damage first, then the boss countdown.
		companions.tick(dt)
		floors.tick(dt)
		while _buy_cheapest_affordable(companions):
			pass
		if floors.is_farming() and step % check_every == 0:
			floors.set_click_dps(floors.click_damage().multiply_decimal(cps_factor))
			if not auto and floors.can_beat_next_boss():
				floors.challenge_boss()
		while next_milestone < milestones.size() and state.max_stage_reached >= milestones[next_milestone]:
			var seconds: float = float(step + 1) * dt
			var note: String = ""
			if milestones[next_milestone] == first_boss_stage:
				note = " [first boss fight begins]"
			elif milestones[next_milestone] == first_boss_stage + 1:
				note = " [first boss KILLED]"
			print("Stage %d reached at %.1f min (%.1f s)%s, failed boss attempts so far: %d" % [milestones[next_milestone], seconds / 60.0, seconds, note, failed_attempts[0]])
			next_milestone += 1
		if step + 1 == report_step:
			print("Stage at %.0f h: best %d (current %d), failed boss attempts so far: %d" % [REPORT_STAGE_AT_HOURS, state.max_stage_reached, state.stage, failed_attempts[0]])
	for i in range(next_milestone, milestones.size()):
		print("Stage %d NOT reached in %.1f h" % [milestones[i], hours])
	print("End of run at %.1f h: best stage %d (current %d), failed boss attempts %d, levels %s" % [hours, state.max_stage_reached, state.stage, failed_attempts[0], str(state.companion_levels)])
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
	var args: Dictionary = {"cps": 3.0, "dt": 0.1, "hours": 3.0, "curves": CURVES_PATH, "roster": ROSTER_PATH, "bosses": BOSSES_PATH, "auto": 0.0}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() != 2 or not args.has(parts[0]):
			printerr("simulate_progress: ignored argument " + arg)
			continue
		args[parts[0]] = parts[1] if args[parts[0]] is String else parts[1].to_float()
	return args
