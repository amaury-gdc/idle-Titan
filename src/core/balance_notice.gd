class_name BalanceNotice
extends RefCounted
## The one-time message of a rebalance (story 020): when core_curves.json carries a
## [code]balance_version[/code] the player has not seen ([member PermanentState.balance_seen]) and
## their stage record is above [code]balance_notice_min_stage[/code], the main screen tells them
## once that the high stages changed. A player at or under that stage is not concerned: the
## version is recorded in silence. Nothing in the save is changed besides that number.
##
## Both keys are optional. Without [code]balance_version[/code] (or at 0) there is never a message.
##
## Usage:
## [codeblock]
## var notice: BalanceNotice = BalanceNotice.from_data(curves, permanent)
## if notice.apply(talents.best_stage()):
##     # show the message, then, when the player closes it:
##     notice.acknowledge()
## [/codeblock]

const VERSION_KEY: String = "balance_version"
const MIN_STAGE_KEY: String = "balance_notice_min_stage"

var _permanent: PermanentState
var _version: int = 0
var _min_stage: int = 0
var _error: String = ""


## Reads the two keys of core_curves.json. Check [method is_valid] afterwards.
static func from_data(curves: Variant, permanent: PermanentState) -> BalanceNotice:
	var notice: BalanceNotice = BalanceNotice.new()
	notice._permanent = permanent
	if not curves is Dictionary:
		notice._error = "core_curves.json: expected an object"
		return notice
	notice._version = notice._read_count(curves, VERSION_KEY)
	notice._min_stage = notice._read_count(curves, MIN_STAGE_KEY)
	return notice


## False when a key is present and is not an integer >= 0; see [method get_error].
func is_valid() -> bool:
	return _error.is_empty()


## The reason the data was refused, empty when valid.
func get_error() -> String:
	return _error


## The [code]balance_version[/code] of the data; 0 when there is none.
func version() -> int:
	return _version


## True while the data has a version the player has not seen. After [method apply] it means the
## message must still be shown and closed.
func is_due() -> bool:
	return is_valid() and _version > 0 and _permanent.balance_seen != _version


## Call once after the load with the player's stage record. Returns true when the message must be
## shown. A record at or under the minimum stage records the version at once and returns false.
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


func _read_count(data: Dictionary, key: String) -> int:
	if not data.has(key):
		return 0
	var value: Variant = data[key]
	# JSON reads every number as a float.
	if not (value is float or value is int) or float(value) < 0.0 or float(value) != floorf(float(value)):
		_error = "core_curves.json: '%s' must be an integer >= 0" % key
		return 0
	return int(value)
