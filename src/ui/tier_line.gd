class_name TierLine
extends RefCounted
## What the progress line of a companion row says and how full its bar is (stories 013 and 017):
## the next tier, then the next awakening, then nothing left. Pure reading of a [CompanionManager]:
## it changes nothing and builds no text, the panel words each [enum Kind] with tr().
##
## The order, for a roster with an "awakening" block:
## [br]- the next tier while it stands at or before the next threshold (the tier of level 200 and the
## first threshold meet there: the tier is named first, then "Éveil disponible" takes over);
## [br]- the next awakening, with the bar from the previous threshold to it;
## [br]- at the threshold, "awakening available" on a full bar;
## [br]- past the last awakening, "all awakenings done" on a full bar.
## Without the block, only the former line remains: the next tier or "all tiers reached".
##
## Usage:
## [codeblock]
## var line: TierLine = TierLine.of(companions, "scout")
## if line.kind == TierLine.Kind.AWAKENING_AHEAD:
##     print("awakening at level %d, x%s" % [line.level, line.multiplier])
## bar.value = line.progress
## [/codeblock]

## The states of the line, in the order of a companion's life.
enum Kind { TIER, ALL_TIERS, AWAKENING_AHEAD, AWAKENING_READY, ALL_AWAKENED }

## Which state the line is in.
var kind: Kind = Kind.ALL_TIERS
## The level named: of the next tier or of the next awakening threshold; 0 when none is named.
var level: int = 0
## The factor named, as text with a decimal comma ("3,4"); empty when none is named.
var multiplier: String = ""
## Filling of the bar, 0 to 1.
var progress: float = 0.0


## The line of [param id], which must be in the roster. [param next] is
## [method CompanionManager.next_awakening] of [param id] when the caller already read it (it is
## read here otherwise).
static func of(companions: CompanionManager, id: String, next: Variant = null) -> TierLine:
	var line: TierLine = TierLine.new()
	var current: int = companions.level(id)
	var tier: Dictionary = companions.next_tier(id)
	var tier_level: int = tier["level"]
	var awakening: Dictionary = next if next is Dictionary else companions.next_awakening(id)
	if awakening.is_empty():
		if tier_level > 0 or companions.awakenings(id) == 0:
			line._set_tier(current, tier)
		else:
			line.kind = Kind.ALL_AWAKENED
			line.progress = 1.0
		return line
	var threshold: int = awakening["level"]
	if current >= threshold:
		line.kind = Kind.AWAKENING_READY
		line.level = threshold
		line.progress = 1.0
	elif tier_level > 0 and tier_level <= threshold:
		line._set_tier(current, tier)
	else:
		var thresholds: Array[int] = companions.awakening_thresholds()
		var done: int = companions.awakenings(id)
		var previous: int = thresholds[done - 1] if done > 0 else 0
		line.kind = Kind.AWAKENING_AHEAD
		line.level = threshold
		line.multiplier = companions.awakening_self_text()
		line.progress = clampf(float(current - previous) / float(threshold - previous), 0.0, 1.0)
	return line


## Filling of a tier bar, 0 to 1, for a companion at [param level] and [param tier] as given by
## [method CompanionManager.next_tier]: from the previous tier to the next, full past the last
## tier, empty when the companion has none.
static func tier_progress(level: int, tier: Dictionary) -> float:
	var next_level: int = tier["level"]
	var previous: int = tier["previous"]
	if next_level == 0:
		return 1.0 if previous > 0 else 0.0
	return float(level - previous) / float(next_level - previous)


func _set_tier(current: int, tier: Dictionary) -> void:
	progress = tier_progress(current, tier)
	var tier_level: int = tier["level"]
	if tier_level == 0:
		kind = Kind.ALL_TIERS
		return
	kind = Kind.TIER
	level = tier_level
	# Already the player's form, with a decimal comma when needed ("1,5"), like the awakening one.
	var label: String = tier["multiplier"]
	multiplier = label
