extends GdUnitTestSuite
## Unit tests for the ModifierHub without talents (story 019 engine review): with an inventory and no
## talent tree, a refresh pushes "no loot weight shift" without a typed-array error.
## Story: production/epics/idle-titans/story-019-talent-tree-content.md


func test_hub_with_an_inventory_and_no_talents_refreshes_without_error() -> void:
	# Arrange
	var curves: Variant = DataLoader.load_json("res://assets/data/core_curves.json")
	var combat: Combat = Combat.from_data(curves, DataLoader.load_json("res://assets/data/companions_roster.json"))
	var state: GameState = GameState.new()
	var permanent: PermanentState = PermanentState.new()
	var floors: FloorManager = FloorManager.new(state, combat, null, permanent)
	var roll: Callable = func() -> float: return 0.5
	var inventory: Inventory = Inventory.from_data(DataLoader.load_json("res://assets/data/items.json"), permanent, state, combat, roll)
	assert_str(inventory.get_error()).is_empty()
	var refreshed: Array[int] = [0]

	# Act: built (one refresh), then refreshed by hand
	var hub: ModifierHub = ModifierHub.new(floors, OfflineIncome.from_data(curves, combat), null, inventory)
	hub.changed.connect(func() -> void: refreshed[0] += 1)
	hub.refresh()

	# Assert: the refresh went to its end (it emits changed last)
	assert_int(refreshed[0]).is_equal(1)
	assert_int(hub.percent(TalentTree.STAT_CLICK_DAMAGE)).is_equal(0)
