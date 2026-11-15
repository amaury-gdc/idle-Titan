class_name BalanceNotice
extends RefCounted
## The one-time message of a rebalance (stories 020 and 023). core_curves.json carries the current
## [code]balance_version[/code] and, in [code]balance_notices[/code], one entry per version with its
## own stage threshold, title and text. When the player has not seen the current version
## ([member PermanentState.balance_seen]) and their stage record is above the threshold of that
## version, the main screen shows its message once. A player at or under the threshold is not
## concerned: the version is recorded in silence. Only the entry of the current version is ever
## shown: a player who missed an older version reads the newest text, not both. Nothing in the save
## is changed besides that number.
##
## Both keys are optional. Without [code]balance_version[/code] (or at 0) there is never a message.
##
## Usage:
## [codeblock]
## var notice: BalanceNotice = BalanceNotice.from_data(curves, permanent)
## if notice.apply(talents.best_stage()):
##     # show notice.title() and notice.text(), then, when the player closes the message:
##     notice.acknowledge()
## [/codeblock]

const VERSION_KEY: String = "balance_version"
const NOTICES_KEY: String = "balance_notices"

var _permanent: PermanentState
var _version: int = 0
var _min_stage: int = 0
var _title: String = ""
var _text: String = ""
var _error: String = ""


## Reads the two keys of core_curves.json. Check [method is_valid] afterwards.
static func from_data(curves: Variant, permanent: PermanentState) -> BalanceNotice:
	var notice: BalanceNotice = BalanceNotice.new()
	notice._permanent = permanent
	if not curves is Dictionary:
		notice._error = "core_curves.json: expected an object"
		return notice
	notice._version = notice._read_count(curves, VERSION_KEY, "'%s'" % VERSION_KEY)
	if notice._error.is_empty():
		notice._read_notices(curves)
	return notice


## False when the data was refused; see [method get_error].
func is_valid() -> bool:
	return _error.is_empty()


## The reason the data was refused, empty when valid.
func get_error() -> String:
	return _error


## The [code]balance_version[/code] of the data; 0 when there is none.
func version() -> int:
	return _version


## Title of the message of the current version, as written in the data (not translated); empty
## without a version.
func title() -> String:
	return _title


## Text of the message of the current version, as written in the data (not translated); empty
## without a version.
func text() -> String:
	return _text


## True while the data has a version the player has not seen. After [method apply] it means the
## message must still be shown and closed.
func is_due() -> bool:
	return is_valid() and _version > 0 and _permanent.balance_seen != _version


## Call once after the load with the player's stage record. Returns true when the message must be
## shown. A record at or under the stage threshold of the current version records the version at
## once and returns false.
func apply(best_stage: int) -> bool:
	if not is_due():
		return false
	if best_stage <= _min_stage:
		_permanent.balance_seen = _version
		return false
	return true


## The player closed the message: it is not due again for this version.
func acknowledge() -> void:
	if is_valid() and _version > 0:
		_permanent.balance_seen = _version


# Every entry of "balance_notices" is checked, so a typo in an old entry is not found a version
# later; the entry of the current version is kept. With a version above 0 that entry is required.
func _read_notices(data: Dictionary) -> void:
	var notices: Variant = data.get(NOTICES_KEY, [])
	if not notices is Array:
		_error = "core_curves.json: '%s' must be an array of {version, min_stage, title, text}" % NOTICES_KEY
		return
	var seen: Dictionary = {}
	var found: bool = false
	for entry: Variant in notices:
		if not entry is Dictionary:
			_error = "core_curves.json: '%s' must be an array of {version, min_stage, title, text}" % NOTICES_KEY
			return
		if not entry.has("version") or not entry.has("min_stage"):
			_error = "core_curves.json: a '%s' entry needs 'version' and 'min_stage'" % NOTICES_KEY
			return
		var entry_version: int = _read_count(entry, "version", "'%s' version" % NOTICES_KEY)
		var min_stage: int = _read_count(entry, "min_stage", "'%s' min_stage" % NOTICES_KEY)
		if not _error.is_empty():
			return
		if entry_version < 1 or seen.has(entry_version):
			_error = "core_curves.json: '%s' versions must be distinct integers >= 1" % NOTICES_KEY
			return
		seen[entry_version] = true
		var entry_title: Variant = entry.get("title")
		var entry_text: Variant = entry.get("text")
		if not (entry_title is String and entry_text is String) or entry_title.is_empty() or entry_text.is_empty():
			_error = "core_curves.json: '%s' version %d needs a 'title' and a 'text'" % [NOTICES_KEY, entry_version]
			return
		if entry_version == _version:
			found = true
			_min_stage = min_stage
			_title = entry_title
			_text = entry_text
	if _version > 0 and not found:
		_error = "core_curves.json: '%s' has no entry for '%s' %d" % [NOTICES_KEY, VERSION_KEY, _version]


# [param label] names the value in the error message.
func _read_count(data: Dictionary, key: String, label: String) -> int:
	if not data.has(key):
		return 0
	var value: Variant = data[key]
	# JSON reads every number as a float.
	if not (value is float or value is int) or float(value) < 0.0 or float(value) != floorf(float(value)):
		_error = "core_curves.json: %s must be an integer >= 0" % label
		return 0
	return int(value)
