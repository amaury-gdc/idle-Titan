extends GdUnitTestSuite
## Story 019b, lot 9: the ItemRow variations of the theme, replaced by the cards of lot 7, are gone,
## and nothing in the game still names them. Reads the project files (res://, read-only): the proof
## that a name is used nowhere is the text of the sources themselves.

const THEME_PATH: String = "res://src/ui/main_theme.tres"
const SOURCE_ROOT: String = "res://src"
const SOURCE_EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]
const REMOVED_PREFIX: String = "ItemRow"


func _source_files(directory: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(directory):
		if file.get_extension() in SOURCE_EXTENSIONS:
			found.append(directory.path_join(file))
	for child: String in DirAccess.get_directories_at(directory):
		found.append_array(_source_files(directory.path_join(child)))
	return found


func test_theme_has_no_item_row_type() -> void:
	# Arrange
	var theme: Theme = load(THEME_PATH)
	# Act
	var left: PackedStringArray = PackedStringArray()
	for type: String in theme.get_type_list():
		if type.begins_with(REMOVED_PREFIX):
			left.append(type)
	# Assert
	assert_array(Array(left)).is_empty()


func test_no_source_names_an_item_row_style() -> void:
	# Arrange
	var files: PackedStringArray = _source_files(SOURCE_ROOT)
	# Act
	var naming: PackedStringArray = PackedStringArray()
	for path: String in files:
		if FileAccess.get_file_as_string(path).contains(REMOVED_PREFIX):
			naming.append(path)
	# Assert: the walk did read the sources, and none of them names the removed styles.
	assert_bool(files.has(THEME_PATH)).is_true()
	assert_bool(files.has("res://src/ui/inventory_screen.gd")).is_true()
	assert_array(Array(naming)).is_empty()
