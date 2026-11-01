class_name NotificationDots
extends RefCounted
## The rules of the notification dots of the tabs (story 010, decision D4 of
## design/ux/main-screen-adaptive.md). A dot says "something new happened", not "something is
## possible": in an idle game the second one would stay lit for good. So it lights on an event,
## goes out on a visit, and never lights on the open tab. Memory only: nothing here is saved, and
## the first look after a load is a baseline that lights nothing.
##
## Events: a companion's next goal (first level, then next tier) becomes affordable, a talent node
## becomes buyable for the first time, an item is kept. Tabs are [enum ManagementTabs.Tab] values.
##
## Usage:
## [codeblock]
## var dots: NotificationDots = NotificationDots.new()
## dots.observe_talents(buyable_ids)     # after any change, a dot lights if an id is new
## dots.note_item_kept()
## if dots.is_lit(ManagementTabs.Tab.INVENTORY):
##     show_dot()
## dots.visit(ManagementTabs.Tab.INVENTORY)
## [/codeblock]

var _lit: Dictionary = {}
var _open_tab: int = ManagementTabs.Tab.COMPANIONS
## Companion id -> highest goal level already reported.
var _companion_goals: Dictionary = {}
## Ids of the talent nodes already reported as buyable.
var _talents_seen: Dictionary = {}
var _companions_baseline_done: bool = false
var _talents_baseline_done: bool = false


## The next level of a companion at [param level] worth a dot: level 1 when not bought, then the
## first of [param tier_levels] above [param level]; 0 when there is none left.
static func next_goal(level: int, tier_levels: Array) -> int:
	if level <= 0:
		return 1
	for tier: Variant in tier_levels:
		if int(tier) > level:
			return int(tier)
	return 0


## True when the dot of [param tab] is on.
func is_lit(tab: int) -> bool:
	return _lit.get(tab, false)


## The tab now open: its dot goes out and cannot light while it stays open.
func set_open_tab(tab: int) -> void:
	_open_tab = tab
	visit(tab)


## The player looked at [param tab]: its dot goes out.
func visit(tab: int) -> void:
	_lit[tab] = false


## Compares the affordable goals with what was already reported. [param goals] maps a companion id
## to the level it can reach now as a goal, 0 for none (see [method next_goal]).
func observe_companions(goals: Dictionary) -> void:
	var fresh: bool = false
	for id: String in goals:
		var goal: int = goals[id]
		if goal > _companion_goals.get(id, 0):
			_companion_goals[id] = goal
			fresh = true
	if fresh and _companions_baseline_done:
		_light(ManagementTabs.Tab.COMPANIONS)
	_companions_baseline_done = true


## Compares [param buyable] (ids of the nodes buyable now) with what was already reported.
func observe_talents(buyable: PackedStringArray) -> void:
	var fresh: bool = false
	for id: String in buyable:
		if not _talents_seen.has(id):
			_talents_seen[id] = true
			fresh = true
	if fresh and _talents_baseline_done:
		_light(ManagementTabs.Tab.TALENTS)
	_talents_baseline_done = true


## A loot item went into the bag.
func note_item_kept() -> void:
	_light(ManagementTabs.Tab.INVENTORY)


func _light(tab: int) -> void:
	if tab != _open_tab:
		_lit[tab] = true
