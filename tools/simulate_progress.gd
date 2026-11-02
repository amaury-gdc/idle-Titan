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
## replace the data files, to try a variant without touching assets/data;
## --away=<start>:<duration>,... absences (story 004b), in hours: <start> is counted in
## active play, and each return grants gold through the real [OfflineIncome], which
## applies the cap of the data; --eff=<decimal> replaces offline_efficiency.
## --skills=0|1|2 (story 005): 0 = no skills (default); 1 = each skill is activated as soon
## as it is ready; 2 = the gold bonus as soon as it is ready, the burst and the damage buff
## only during a boss fight (the way a player who knows the game would use them).
## --skillsdata=<path> replaces skills.json.
## --talents=1 (story 006) spends the points on the real [TalentTree] as soon as they are
## earned, greedily: the first buyable node in data order, checked once per simulated
## second (default 0, no talents). --build=<branch>,<branch> looks at the nodes of these
## branches first (ids of talents.json); --talentsdata=<path> replaces talents.json.
## --loot=1 (story 007) drops the real items of the bosses and critical hits, and wears a drop
## as soon as it beats the worn item of its type by the "worse item" rule (rarity, then sum of
## percentages, blind to the stat: an honest measure, not an optimistic one). Default 0, no
## items, no critical hit. --seed=<n> seeds the dice (default 1), --itemsdata=<path> replaces items.json.
## Story 014, see [SimMeasures]: --milestones=10,20,... follows these stages, plus those of the
## first boss, instead of the default list. --report=1 prints a line at each milestone: levels,
## power, estimated click share (clicks * click damage against the companions) and damage per gold of
## each next level. --buyer=cheapest (default) or ratio: the affordable level with the most
## damage per gold, instead of the cheapest one.
## --awaken=1|0 (story 016, default 1): 1 = every companion awakens as soon as it can, before levels are
## bought; 0 = never, so the companions stay blocked at the thresholds. Only matters with a roster that
## has an "awakening" block (try one through --roster=): without it nothing changes, nothing is printed.
## Report: time to the first boss fight, to the first boss kill, to stages 50/100/150,
## the stage at 3 h and the number of failed boss attempts (at each milestone and at the
## end). With --away, milestones also give the wall time (active + away) and each
## return prints the gold, compared with the income of the last 10 active minutes.
## That average lags behind a growing income, so the comparison overstates a return
## early in a run, while income doubles quickly.
##
## Usage:
## [codeblock]
## godot --headless --path . -s res://tools/simulate_progress.gd -- --cps=3 --hours=3
## [/codeblock]

const CURVES_PATH: String = "res://assets/data/core_curves.json"
const ROSTER_PATH: String = "res://assets/data/companions_roster.json"
const BOSSES_PATH: String = "res://assets/data/boss_curves.json"
const SKILLS_PATH: String = "res://assets/data/skills.json"
const TALENTS_PATH: String = "res://assets/data/talents.json"
const ITEMS_PATH: String = "res://assets/data/items.json"
## Stages reported by the run besides the first boss fight and the first boss kill,
## which come from the boss data (measurement points, not balance values).
const MILESTONES: Array[int] = [50, 100, 110, 120, 130, 150]
const SECONDS_PER_HOUR: float = 3600.0
## Simulated time of the extra "stage reached at" line of the report.
const REPORT_STAGE_AT_HOURS: float = 3.0
## Income comparison of a return: one sample per minute, averaged over 10 samples
## (measurement settings, not balance values).
const INCOME_SAMPLE_SECONDS: float = 60.0
const INCOME_WINDOW_SAMPLES: int = 10
## Any positive Unix time: only the difference with the return time matters.
const AWAY_START_UNIX: int = 1


func _init() -> void:
	var args: Dictionary = _parse_args()
	var curves: Variant = DataLoader.load_json(args["curves"])
	if curves is Dictionary and not args["eff"].is_empty():
		curves["offline_efficiency"] = args["eff"]
	var combat: Combat = Combat.from_data(curves, DataLoader.load_json(args["roster"]))
	if not combat.is_valid():
		printerr("simulate_progress: " + combat.get_error())
		quit(1)
		return
	var boss: BossFight = BossFight.from_data(DataLoader.load_json(args["bosses"]))
	if not boss.is_valid():
		printerr("simulate_progress: " + boss.get_error())
		quit(1)
		return
	var offline: OfflineIncome = OfflineIncome.from_data(curves, combat)
	if not offline.is_valid():
		printerr("simulate_progress: " + offline.get_error())
		quit(1)
		return
	if not SimMeasures.is_known_buyer(args["buyer"]):
		printerr("simulate_progress: unknown buyer " + args["buyer"])
		quit(1)
		return
	var ran: bool = _simulate(combat, boss, offline, args["cps"], args["dt"], args["hours"], args["auto"] > 0.0, _parse_away(args["away"]), int(args["skills"]), args["skillsdata"], args["talents"] > 0.0, args["talentsdata"], args["build"], args["loot"] > 0.0, int(args["seed"]), args["itemsdata"], args["milestones"], args["report"] > 0.0, args["buyer"], args["awaken"] > 0.0)
	quit(0 if ran else 1)


func _simulate(combat: Combat, boss: BossFight, offline: OfflineIncome, cps: float, dt: float, hours: float, auto: bool, absences: Array[Vector2], skill_mode: int, skills_path: String, use_talents: bool, talents_path: String, build: String, use_loot: bool, seed_value: int, items_path: String, milestone_text: String, report: bool, buyer: String, awaken: bool) -> bool:
	var state: GameState = GameState.new()
	var permanent: PermanentState = PermanentState.new()
	permanent.auto_challenge = auto
	var floors: FloorManager = FloorManager.new(state, combat, boss, permanent)
	var companions: CompanionManager = CompanionManager.new(state, combat, floors)
	var skills: SkillManager = null
	if skill_mode > 0:
		skills = SkillManager.from_data(DataLoader.load_json(skills_path), state, combat, floors)
		if not skills.is_valid():
			printerr("simulate_progress: " + skills.get_error())
			return false
	var talents: TalentTree = null
	var talent_order: Array[String] = []
	if use_talents:
		talents = TalentTree.from_data(DataLoader.load_json(talents_path), permanent, state)
		if not talents.is_valid():
			printerr("simulate_progress: " + talents.get_error())
			return false
		talent_order = _talent_order(talents, build)
	# Two generators: the many critical rolls must not shift the loot of a seed.
	var loot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	loot_rng.seed = seed_value
	var crit_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	crit_rng.seed = seed_value + 1
	var inventory: Inventory = null
	var hub: ModifierHub = null
	var drops: Array[int] = [0, 0]
	if use_loot:
		inventory = Inventory.from_data(DataLoader.load_json(items_path), permanent, state, combat, loot_rng.randf)
		if not inventory.is_valid():
			printerr("simulate_progress: " + inventory.get_error())
			return false
		floors.set_crit_roll(crit_rng.randf)
		floors.boss_killed.connect(inventory.on_boss_killed)
		inventory.loot_received.connect(func(item: Item, sold: Array[Item], _gold: BigNumber) -> void: _wear_if_better(inventory, item, sold, drops))
		hub = ModifierHub.new(floors, offline, talents, inventory)
		print("Loot: greedy on rarity then sum of percentages, blind to the stat; seed %d" % seed_value)
	var skill_uses: Array[int] = [0, 0, 0]
	var failed_attempts: Array[int] = [0]
	floors.boss_failed.connect(func(_failed: int, _back_to: int) -> void: failed_attempts[0] += 1)
	var first_boss_stage: int = 1
	while not boss.is_boss_stage(first_boss_stage):
		first_boss_stage += 1
	var milestones: Array[int] = SimMeasures.merged_milestones(milestone_text, MILESTONES, [first_boss_stage, first_boss_stage + 1])
	if milestones.is_empty():
		printerr("simulate_progress: invalid milestones " + milestone_text)
		return false
	# Boss HP to beat, computed once per fallback; power is checked once per simulated
	# second so a long farm stays cheap to simulate (GrowthCurve, BigNumber sums).
	var check_every: int = maxi(int(1.0 / dt), 1)
	var cps_factor: String = "%.3f" % cps
	var skill_text: String = ["none", "each skill as soon as it is ready", "gold bonus when ready, burst and damage buff in boss fights only"][clampi(skill_mode, 0, 2)]
	print("Player model: %.2f clicks/s without pause, cheapest affordable level bought after every %.2f s step; boss countdown %.0f s; farm mode exit: %s; skills: %s" % [cps, dt, boss.timer_seconds(), "auto challenge setting" if auto else "challenge when expected damage covers the boss HP", skill_text])
	if talents != null:
		print("Talents: greedy, order %s" % str(talent_order))
	var report_step: int = int(REPORT_STAGE_AT_HOURS * SECONDS_PER_HOUR / dt)
	var steps: int = int(hours * SECONDS_PER_HOUR / dt)
	var next_milestone: int = 0
	var click_debt: float = 0.0
	var started_ms: int = Time.get_ticks_msec()
	var next_absence: int = 0
	var away_seconds: float = 0.0
	var income_every: int = maxi(int(INCOME_SAMPLE_SECONDS / dt), 1)
	var earned: Array[float] = [0.0]
	var earned_samples: Array[float] = []
	if not absences.is_empty():
		floors.enemy_killed.connect(func(_stage: int, gold: BigNumber) -> void: earned[0] += gold.to_decimal_string().to_float())
	# Story 016: one line per awakening, only printed when the roster has an "awakening" block.
	var clock: Array[float] = [0.0, 0.0]
	if combat.awakening_rules().is_enabled():
		print("Awakening: %s" % ("as soon as affordable, before buying levels" if awaken else "never (companions stay blocked at the thresholds)"))
		companions.awakened.connect(func(id: String) -> void: _print_awakening(id, companions, state, clock[0], clock[1], not absences.is_empty()))
	for step in steps:
		if not absences.is_empty() and step % income_every == 0:
			earned_samples.append(earned[0])
		if next_absence < absences.size() and float(step) * dt >= absences[next_absence].x * SECONDS_PER_HOUR:
			var duration: float = absences[next_absence].y * SECONDS_PER_HOUR
			_apply_absence(offline, state, companions, duration, float(step) * dt, earned[0], earned_samples)
			away_seconds += duration
			next_absence += 1
		if skills != null:
			_use_skills(skills, floors, skill_mode, skill_uses)
		click_debt += cps * dt
		var clicks: int = int(click_debt)
		click_debt -= float(clicks)
		for i in clicks:
			floors.click()
		# Same order as the main screen: damage first, then the boss countdown.
		companions.tick(dt)
		floors.tick(dt)
		if skills != null:
			skills.tick(dt)
		if awaken:
			clock[0] = float(step + 1) * dt
			clock[1] = away_seconds
			_awaken_all(companions)
		while _buy_next(companions, buyer):
			pass
		if talents != null and step % check_every == 0 and talents.available_points() > 0:
			_spend_talents(talents, talent_order, floors, offline, hub)
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
			if not absences.is_empty():
				note += " [wall time %.1f min]" % ((seconds + away_seconds) / 60.0)
			print("Stage %d reached at %.1f min (%.1f s)%s, failed boss attempts so far: %d" % [milestones[next_milestone], seconds / 60.0, seconds, note, failed_attempts[0]])
			if report:
				_print_report(state, floors, combat, cps)
			next_milestone += 1
		if step + 1 == report_step:
			print("Stage at %.0f h: best %d (current %d), failed boss attempts so far: %d" % [REPORT_STAGE_AT_HOURS, state.max_stage_reached, state.stage, failed_attempts[0]])
	for i in range(next_milestone, milestones.size()):
		print("Stage %d NOT reached in %.1f h" % [milestones[i], hours])
	print("End of run at %.1f h: best stage %d (current %d), failed boss attempts %d, levels %s" % [hours, state.max_stage_reached, state.stage, failed_attempts[0], str(state.companion_levels)])
	if combat.awakening_rules().is_enabled():
		print("Awakenings at the end: %s, squad count %d" % [str(state.companion_awakenings), companions.squad_awakenings()])
	if talents != null:
		print("Talents at the end: %d earned, %d spent, %d left; click x%s, companions x%s, gold x%s, offline gold x%s" % [talents.earned_points(), talents.spent_points(), talents.available_points(), talents.factor(TalentTree.STAT_CLICK_DAMAGE), talents.factor(TalentTree.STAT_COMPANION_DAMAGE), talents.factor(TalentTree.STAT_GOLD), talents.factor(TalentTree.STAT_OFFLINE_GOLD)])
	if inventory != null:
		var worn: Array[String] = []
		for item: Item in inventory.equipped_items():
			worn.append("%s %s %s" % [item.rarity, item.type, str(item.stats)])
		print("Loot at the end: %d drops, %d sold, %d in the bag; worn %s" % [drops[0], drops[1], inventory.bag().size(), str(worn)])
		print("Item totals: %s; critical chance %d%%, bonus %d%%" % [str(inventory.totals()), hub.crit_chance_percent(), hub.crit_bonus_percent()])
	if skills != null:
		print("Skill activations: %d big hits, %d damage buffs, %d gold bonuses" % [skill_uses[0], skill_uses[1], skill_uses[2]])
	print("Real time: %.1f s" % (float(Time.get_ticks_msec() - started_ms) / 1000.0))
	return true


# Grants the gold of an absence of [param duration] seconds, as the main screen does on
# return, and prints it next to the recent active income.
func _apply_absence(offline: OfflineIncome, state: GameState, companions: CompanionManager, duration: float, active_seconds: float, earned: float, samples: Array[float]) -> void:
	state.last_saved_unix = AWAY_START_UNIX
	var gain: Dictionary = offline.grant(state, AWAY_START_UNIX + int(duration))
	var line: String = "Return at %.2f h active (stage %d, power %s) after %.1f h away: " % [active_seconds / SECONDS_PER_HOUR, state.stage, companions.total_power().format(), duration / SECONDS_PER_HOUR]
	if gain.is_empty():
		print(line + "no gold")
		return
	var gold: BigNumber = gain["gold"]
	var window: int = mini(samples.size() - 1, INCOME_WINDOW_SAMPLES)
	var income: float = 0.0
	if window > 0:
		income = (earned - samples[samples.size() - 1 - window]) / (float(window) * INCOME_SAMPLE_SECONDS)
	var minutes: float = gold.to_decimal_string().to_float() / income / 60.0 if income > 0.0 else 0.0
	print(line + "%.1f h counted, +%s gold, %.1f min of recent active income (%.2f gold/s)" % [float(gain["seconds"]) / SECONDS_PER_HOUR, gold.format(), minutes, income])


# Mode 1: every skill as soon as it is ready. Mode 2: the gold bonus as soon as it is ready,
# the burst and the damage buff only while a boss fight runs.
func _use_skills(skills: SkillManager, floors: FloorManager, mode: int, uses: Array[int]) -> void:
	for skill: Skill in skills.skills():
		if skill.state() != Skill.State.READY:
			continue
		if mode == 2 and skill.effect != Skill.Effect.GOLD_MULTIPLIER and not floors.is_boss_fight():
			continue
		skills.activate(skill.id)
		uses[int(skill.effect)] += 1


# Node ids in buying order: the branches of [param build] first, then data order.
func _talent_order(talents: TalentTree, build: String) -> Array[String]:
	var order: Array[String] = []
	for branch: String in build.split(",", false):
		for def: TalentTree.TalentDef in talents.nodes_of(branch):
			order.append(def.id)
	for def: TalentTree.TalentDef in talents.nodes():
		if not order.has(def.id):
			order.append(def.id)
	return order


# Buys the first buyable node of [param order], again and again, then updates the formulas.
func _spend_talents(talents: TalentTree, order: Array[String], floors: FloorManager, offline: OfflineIncome, hub: ModifierHub) -> void:
	var bought: bool = true
	while bought:
		bought = false
		for id: String in order:
			if talents.buy(id):
				bought = true
				break
	# The hub already followed each purchase; apply_to would overwrite the items.
	if hub == null:
		talents.apply_to(floors, offline)


# Wears the new item when it was not sold and beats the worn item of its type. Counts drops and sales.
func _wear_if_better(inventory: Inventory, item: Item, sold: Array[Item], drops: Array[int]) -> void:
	drops[0] += 1
	drops[1] += sold.size()
	if sold.has(item):
		return
	var worn: Item = inventory.equipped(item.type)
	if worn == null or inventory.is_worse(worn, item):
		inventory.equip(item.uid)


# Prints the line of --report=1 for the stage just reached.
func _print_report(state: GameState, floors: FloorManager, combat: Combat, cps: float) -> void:
	var power: float = floors.companion_power().to_decimal_string().to_float()
	var click_dps: float = floors.click_damage().to_decimal_string().to_float() * cps
	var levels: Array[String] = []
	var ratios: Array[String] = []
	for companion: Companion in combat.companions():
		var level: int = int(state.companion_levels.get(companion.id, 0))
		levels.append("%s %d" % [companion.id, level])
		var own: int = combat.awakening_count(state.companion_awakenings, companion.id)
		ratios.append("%s %s" % [companion.id, String.num_scientific(SimMeasures.damage_per_gold(companion, level, own, combat.squad_awakenings(state.companion_awakenings)))])
	print("  levels %s; power %s; click share %.3f; damage per gold %s" % [", ".join(levels), String.num_scientific(power), SimMeasures.click_share(click_dps, power), ", ".join(ratios)])


# --awaken=1: every companion that can awaken does, in roster order, again until none can.
func _awaken_all(companions: CompanionManager) -> void:
	var awoke: bool = true
	while awoke:
		awoke = false
		for companion: Companion in companions.companions():
			if companions.awaken(companion.id):
				awoke = true


# One line per awakening: who, which rank, at which stage and time.
func _print_awakening(id: String, companions: CompanionManager, state: GameState, active_seconds: float, away_seconds: float, with_wall: bool) -> void:
	var wall: String = " [wall time %.1f min]" % ((active_seconds + away_seconds) / 60.0) if with_wall else ""
	print("Awakening %d of %s at level %d: stage %d (best %d) at %.1f min (%.2f h active)%s, squad count %d" % [companions.awakenings(id), id, companions.level(id), state.stage, state.max_stage_reached, active_seconds / 60.0, active_seconds / SECONDS_PER_HOUR, wall, companions.squad_awakenings()])


func _buy_next(companions: CompanionManager, buyer: String) -> bool:
	if buyer == SimMeasures.BUYER_RATIO:
		var id: String = SimMeasures.best_ratio_id(companions)
		return not id.is_empty() and companions.buy_or_upgrade(id)
	return _buy_cheapest_affordable(companions)


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


# "0.5:8,3:12" gives [Vector2(0.5, 8), Vector2(3, 12)]: (start, duration) in hours.
func _parse_away(text: String) -> Array[Vector2]:
	var absences: Array[Vector2] = []
	for entry: String in text.split(",", false):
		var parts: PackedStringArray = entry.split(":")
		if parts.size() != 2 or not parts[0].is_valid_float() or not parts[1].is_valid_float():
			printerr("simulate_progress: ignored absence " + entry)
			continue
		absences.append(Vector2(parts[0].to_float(), parts[1].to_float()))
	return absences


func _parse_args() -> Dictionary:
	var args: Dictionary = {"cps": 3.0, "dt": 0.1, "hours": 3.0, "curves": CURVES_PATH, "roster": ROSTER_PATH, "bosses": BOSSES_PATH, "auto": 0.0, "away": "", "eff": "", "skills": 0.0, "skillsdata": SKILLS_PATH, "talents": 0.0, "talentsdata": TALENTS_PATH, "build": "", "loot": 0.0, "seed": 1.0, "itemsdata": ITEMS_PATH, "milestones": "", "report": 0.0, "buyer": SimMeasures.BUYER_CHEAPEST, "awaken": 1.0}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() != 2 or not args.has(parts[0]):
			printerr("simulate_progress: ignored argument " + arg)
			continue
		args[parts[0]] = parts[1] if args[parts[0]] is String else parts[1].to_float()
	return args
