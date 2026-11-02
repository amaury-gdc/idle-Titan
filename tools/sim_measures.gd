class_name SimMeasures
extends RefCounted
## Pure helpers of [code]tools/simulate_progress.gd[/code] (story 014): the milestone list, the
## estimated click share and the "best ratio" buyer. Kept apart because the simulator is a
## [SceneTree] script that runs as soon as it is loaded, so it cannot be unit tested itself.
## Measurement only: nothing here is read by the game.
##
## Usage:
## [codeblock]
## var stages: Array[int] = SimMeasures.merged_milestones("10,50", [50, 100], [10, 11])
## var share: float = SimMeasures.click_share(click_dps, companion_dps)
## var id: String = SimMeasures.best_ratio_id(companions)
## var tree: TalentTree = SimMeasures.simulated_tree(data, permanent, state)
## var bought: int = SimMeasures.spend_talents(tree, greedy_ids, SimMeasures.parse_order("click_grip, bighit_power"))
## [/codeblock]

## Buyer that takes the cheapest affordable level.
const BUYER_CHEAPEST: String = "cheapest"
## Buyer that takes the affordable level with the most damage per gold.
const BUYER_RATIO: String = "ratio"


## True when [param buyer] is a known buyer name.
static func is_known_buyer(buyer: String) -> bool:
	return buyer == BUYER_CHEAPEST or buyer == BUYER_RATIO


## The stages to follow, ascending and without duplicates: [param first_stages] plus the stages
## of [param text] ("10,20,50"), or plus [param fallback] when [param text] is empty. Returns []
## when an entry of [param text] is not a whole number >= 1.
static func merged_milestones(text: String, fallback: Array[int], first_stages: Array[int]) -> Array[int]:
	var stages: Array[int] = first_stages.duplicate()
	if text.is_empty():
		stages.append_array(fallback)
	else:
		for entry: String in text.split(","):
			if not entry.is_valid_int() or entry.to_int() < 1:
				return []
			stages.append(entry.to_int())
	stages.sort()
	var unique: Array[int] = []
	for stage: int in stages:
		if unique.is_empty() or unique[-1] != stage:
			unique.append(stage)
	return unique


## Share of the clicks in the damage per second, 0.0 to 1.0: [param click_dps] / (click + companions).
## 0.0 when both are zero.
static func click_share(click_dps: float, companion_dps: float) -> float:
	var total: float = click_dps + companion_dps
	return click_dps / total if total > 0.0 else 0.0


## Damage per second the next level of [param companion] adds per gold it costs, from level
## [param level], with [param own_awakenings] of its own and [param squad_awakenings] counted for the
## squad (story 016). Floats: a measure to compare, never a game value.
static func damage_per_gold(companion: Companion, level: int, own_awakenings: int, squad_awakenings: int) -> float:
	var now: float = companion.damage_per_second_at_level(level, own_awakenings, squad_awakenings).to_decimal_string().to_float()
	var next: float = companion.damage_per_second_at_level(level + 1, own_awakenings, squad_awakenings).to_decimal_string().to_float()
	return (next - now) / companion.cost_of_level(level + 1).to_decimal_string().to_float()


## The talent tree of a simulated run: built from [param data] on [param permanent] and
## [param state], and, when valid, with its version acknowledged. A simulated player starts fresh and
## has nothing to be refunded; without it a tree_version >= 1 would refuse every purchase.
static func simulated_tree(data: Variant, permanent: PermanentState, state: GameState) -> TalentTree:
	var tree: TalentTree = TalentTree.from_data(data, permanent, state)
	if tree.is_valid():
		tree.acknowledge_version()
	return tree


## The node ids of --order ("a, b,c"), trimmed, empty entries dropped.
static func parse_order(text: String) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for entry: String in text.split(","):
		if not entry.strip_edges().is_empty():
			ids.append(entry.strip_edges())
	return ids


## Spends the points of [param talents] as the simulated player does: with [param strict] (--order),
## its nodes one after the other (see [method next_ordered_talent]); else the first buyable node of
## [param greedy_order], again and again. Returns the number of nodes bought.
static func spend_talents(talents: TalentTree, greedy_order: Array[String], strict: PackedStringArray) -> int:
	var count: int = 0
	if not strict.is_empty():
		var next: String = next_ordered_talent(talents, strict)
		while not next.is_empty() and talents.buy(next):
			count += 1
			next = next_ordered_talent(talents, strict)
		return count
	var bought: bool = true
	while bought:
		bought = false
		for id: String in greedy_order:
			if talents.buy(id):
				count += 1
				bought = true
				break
	return count


## Id of the node a player following [param order] (--order, story 018) buys now, or "" when the
## next one must wait. The order is strict: bought nodes and nodes excluded by their group are
## passed, the first other node is bought when it is BUYABLE, else everything waits for it (a node
## whose prerequisites are never bought stops the order there). Every id must be in the tree.
static func next_ordered_talent(talents: TalentTree, order: PackedStringArray) -> String:
	for id: String in order:
		var state: TalentTree.NodeState = talents.state_of(id)
		if state == TalentTree.NodeState.OWNED or state == TalentTree.NodeState.EXCLUDED:
			continue
		return id if state == TalentTree.NodeState.BUYABLE else ""
	return ""


## Id of the affordable companion whose next level gives the most damage per gold, the first in
## roster order on a tie, or "" when none is affordable.
static func best_ratio_id(companions: CompanionManager) -> String:
	var best_id: String = ""
	var best_ratio: float = -1.0
	for companion: Companion in companions.companions():
		if not companions.can_buy(companion.id):
			continue
		var ratio: float = damage_per_gold(companion, companions.level(companion.id), companions.awakenings(companion.id), companions.squad_awakenings())
		if ratio > best_ratio:
			best_ratio = ratio
			best_id = companion.id
	return best_id
