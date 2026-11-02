class_name BuyQuote
extends RefCounted
## What one press of a companion buy button would do under the x1 / x10 / Max / Palier selector
## (stories 010 and 013, decision D3 of design/ux/main-screen-adaptive.md). Pure reading of a
## [CompanionManager]: it changes nothing, and the row keeps the quote it displays, so a press buys
## what was shown.
##
## x1 and x10 are strict: the whole amount or nothing. Max is the real number of levels the gold
## covers; at 0 it quotes the next level, so that the player sees its price. Palier is strict too:
## exactly the levels up to the next tier; past the last tier, or without any, it quotes nothing.
##
## Awakening (story 017, amends D3): no mode goes past the next awakening threshold, so x10 quotes
## the real number of levels left (3 levels from the threshold: "x3"), Max stops at the threshold and
## Palier aims at the nearer of the next tier and the next threshold. At the threshold, whatever the
## mode, the quote is the awakening itself: [member awakening] is true, [member count] is 0 and
## [member cost] is the price of the awakening.
##
## Usage:
## [codeblock]
## var quote: BuyQuote = BuyQuote.of(companions, "scout", BuyQuote.Mode.TEN, game.gold)
## if quote.affordable and quote.awakening:
##     companions.awaken("scout")
## elif quote.affordable:
##     companions.buy_levels("scout", quote.count)
## [/codeblock]

## The segments of the selector, in display order. The value is stored in [DisplaySettings].
enum Mode { ONE, TEN, MAX, TIER }

## Number of [enum Mode] values.
const MODE_COUNT: int = 4
## Levels of the x10 segment.
const TEN_COUNT: int = 10

## Levels a press buys. 0 for Max when the gold does not cover one level, and for Palier with no
## tier left.
var count: int = 0
## Gold of the quoted levels; for Max at 0, the cost of the next level; for Palier with no tier
## left, 0, not to be displayed.
var cost: BigNumber
## True when a press can buy [member count] levels now.
var affordable: bool = false
## True when the companion stands at an awakening threshold: the quote is the awakening (count 0,
## cost of the awakening), the same in every mode.
var awakening: bool = false


## The quote for [param id], which must be in the roster, with [param gold] on hand. [param next] is
## [method CompanionManager.next_awakening] of [param id] when the caller already read it (it is read
## here otherwise, and only at a threshold).
static func of(companions: CompanionManager, id: String, mode: Mode, gold: BigNumber, next: Variant = null) -> BuyQuote:
	var quote: BuyQuote = BuyQuote.new()
	var room: int = companions.buyable_levels_cap(id)
	if room <= 0:
		var awakening: Dictionary = next if next is Dictionary else companions.next_awakening(id)
		if not awakening.is_empty():
			quote.awakening = true
			quote.cost = awakening["cost"]
			quote.affordable = gold.compare(quote.cost) >= 0
			return quote
	match mode:
		Mode.TEN:
			# Never past the threshold: the row shows the real number, "x3" three levels before it.
			quote.count = mini(TEN_COUNT, room)
			quote.cost = companions.cost_of_levels(id, quote.count)
		Mode.MAX:
			# One walk gives the count and its cost; a second one would cost as much again.
			var walk: Dictionary = companions.affordable_walk(id)
			quote.count = walk["count"]
			quote.cost = walk["total"] if quote.count > 0 else companions.next_cost(id)
		Mode.TIER:
			var next_level: int = companions.next_tier(id)["level"]
			var to_tier: int = maxi(next_level - companions.level(id), 0)
			# The nearer of the next tier and the next threshold (room is NO_CAP without a threshold).
			var to_threshold: int = room if room < CompanionManager.NO_CAP else 0
			if to_tier > 0 and to_threshold > 0:
				quote.count = mini(to_tier, to_threshold)
			else:
				quote.count = maxi(to_tier, to_threshold)
			quote.cost = companions.cost_of_levels(id, quote.count)
		_:
			quote.count = 1
			quote.cost = companions.next_cost(id)
	quote.affordable = quote.count > 0 and gold.compare(quote.cost) >= 0
	return quote
