class_name AwakeningText
extends RefCounted
## Small pure helpers for the words of the awakening (story 017): the roman numeral of a rank and
## the elision of the article before a name. The sentences themselves go through tr() in the callers.
##
## Usage:
## [codeblock]
## print(AwakeningText.roman(4))              # "IV"
## print(AwakeningText.elides("Éclaireur"))   # true: "L'Éclaireur", not "Le Éclaireur"
## [/codeblock]

## Lower-case first letters before which "le" becomes "l'" (vowels, silent h, with their accents).
const ELIDING_LETTERS: String = "aeiouhàâäéèêëîïôöûùüœ"
## Roman numeral values, largest first.
const ROMAN_VALUES: Array[int] = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
const ROMAN_SYMBOLS: PackedStringArray = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]


## The roman numeral of [param rank], 1 to 3999; the plain number outside that range.
static func roman(rank: int) -> String:
	if rank < 1 or rank > 3999:
		return str(rank)
	var text: String = ""
	var rest: int = rank
	for i in ROMAN_VALUES.size():
		while rest >= ROMAN_VALUES[i]:
			text += ROMAN_SYMBOLS[i]
			rest -= ROMAN_VALUES[i]
	return text


## The sentence of the player's first awakening, for [param display_name], through the
## localization system: "L'Éclaireur s'éveille : toute l'escouade redouble de force."
static func intro_sentence(display_name: String) -> String:
	var pattern: String
	if elides(display_name):
		pattern = TranslationServer.translate("L'%s s'éveille : toute l'escouade redouble de force.")
	else:
		pattern = TranslationServer.translate("Le %s s'éveille : toute l'escouade redouble de force.")
	return pattern % display_name


## True only the first time it is called for a player: it then marks the sentence of the first
## awakening as seen in [param settings], which outlives a reload. Every later call, in this game or
## after a reload, returns false.
## [codeblock]
## if AwakeningText.take_intro(display):
##     show_message(AwakeningText.intro_sentence(name))
## [/codeblock]
static func take_intro(settings: DisplaySettings) -> bool:
	if settings.awakening_intro_seen():
		return false
	settings.mark_awakening_intro_seen()
	return true


## True when "le" before [param display_name] becomes "l'" (it starts with a vowel or a silent h).
static func elides(display_name: String) -> bool:
	return not display_name.is_empty() and ELIDING_LETTERS.contains(display_name.substr(0, 1).to_lower())
