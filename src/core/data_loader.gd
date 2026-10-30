class_name DataLoader
extends RefCounted
## Loads external JSON data files (companions, curves, later talents/items).
##
## Usage:
## [codeblock]
## var companions: Variant = DataLoader.load_json("res://assets/data/companions_roster.json")
## [/codeblock]


## Parses a JSON file. Returns null if the file is missing or invalid
## (callers decide the fallback). Numbers come back as floats.
static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return json.data
