class_name BuyQuote
extends RefCounted
## What one press of a companion buy button would do under the x1 / x10 / Max selector (story 010,
## decision D3 of design/ux/main-screen-adaptive.md). Pure reading of a [CompanionManager]: it
## changes nothing, and the row keeps the quote it displays, so a press buys what was shown.
##
## x1 and x10 are strict: the whole amount or nothing. Max is the real number of levels the gold
## covers; at 0 it quotes the next level, so that the player sees what is missing.
##
## Usage:
## [codeblock]
## var quote: BuyQuote = BuyQuote.of(companions, "scout", BuyQuote.Mode.TEN, game.gold)
## if quote.affordable:
##     companions.buy_levels("scout", quote.count)
## [/codeblock]

## The segments of the selector, in display order. The value is stored in [DisplaySettings].
enum Mode { ONE, TEN, MAX }

## Number of [enum Mode] values.
const MODE_COUNT: int = 3
## Levels of the x10 segment.
const TEN_COUNT: int = 10

## Levels a press buys. 0 only for Max when the gold does not cover one level.
var count: int = 0
## Gold of the quoted levels; for Max at 0, the cost of the next level.
var cost: BigNumber
## True when a press can buy [member count] levels now.
var affordable: bool = false
## Gold short of [member cost]; 0 when [member affordable].
var missing: BigNumber


## The quote for [param id], which must be in the roster, with [param gold] on hand.
static func of(companions: CompanionManager, id: String, mode: Mode, gold: BigNumber) -> BuyQuote:
	var quote: BuyQuote = BuyQuote.new()
	match mode:
		Mode.TEN:
			quote.count = TEN_COUNT
			quote.cost = companions.cost_of_levels(id, TEN_COUNT)
		Mode.MAX:
			# One walk gives the count and its cost; a second one would cost as much again.
			var walk: Dictionary = companions.affordable_walk(id)
			quote.count = walk["count"]
			quote.cost = walk["total"] if quote.count > 0 else companions.next_cost(id)
		_:
			quote.count = 1
			quote.cost = companions.next_cost(id)
	quote.affordable = quote.count > 0 and gold.compare(quote.cost) >= 0
	quote.missing = BigNumber.new() if quote.affordable else quote.cost.subtract(gold)
	return quote
