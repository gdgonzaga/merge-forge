extends TestBase

# Merge resolution on a real MergeBoard: what quality a group's results and
# refunds carry, chain merges reading the quality actually on the board, and
# groups with nothing to merge into.

const MERGE_BOARD := preload("res://board/merge_board.tscn")
const MERGE_DETECTOR := preload("res://board/merge_detector.gd")
# The merge tween runs about 0.45 s of real time, and headless frames are short.
const MAX_FRAMES := 5000

var _board: Control
var _grid: Control
var _ore: ItemDefinition
var _ingot: ItemDefinition
var _plate: ItemDefinition


func before_test() -> void:
	super.before_test()
	_plate = _item("__test_plate", null)
	_ingot = _item("__test_ingot", _plate)
	_ore = _item("__test_ore", _ingot)
	_board = auto_free(MERGE_BOARD.instantiate())
	add_child(_board)
	_board.setup({"cols": 5, "rows": 3})
	_grid = _board.get_board_grid()


func test_detection_groups_mixed_qualities_together() -> void:
	var grid: Array[Array] = [[
		RecipeResolver.make_item(_ore, 0),
		RecipeResolver.make_item(_ore, 1),
		RecipeResolver.make_item(_ore, 2),
	]]
	var groups: Array[Dictionary] = MERGE_DETECTOR.new().scan(grid)
	assert_int(groups.size()).is_equal(1)
	assert_int(groups[0]["positions"].size()).is_equal(3)


func test_five_normal_make_a_fine_result_and_two_normal_refunds() -> void:
	_lay_row(_ore, [0, 0, 0, 0])
	_grid.place_item(RecipeResolver.make_item(_ore, 0), Vector2i(4, 0))
	await _await_merges()
	assert_array(_qualities(_ingot)).is_equal([1])
	assert_array(_qualities(_ore)).is_equal([0, 0])


func test_a_mixed_four_consumes_the_masterwork() -> void:
	_lay_row(_ore, [2, 0, 0])
	_grid.place_item(RecipeResolver.make_item(_ore, 0), Vector2i(3, 0))
	await _await_merges()
	assert_array(_qualities(_ingot)).is_equal([0])
	assert_array(_qualities(_ore)).is_equal([0])


func test_a_fine_result_chains_with_a_fine_pair_into_a_fine_item() -> void:
	# Row 0 cols 0-4 merge at their centre, (2, 0), right above a Fine pair.
	_grid.grid[1][2] = RecipeResolver.make_item(_ingot, 1)
	_grid.grid[2][2] = RecipeResolver.make_item(_ingot, 1)
	_lay_row(_ore, [0, 0, 0, 0])
	_grid.place_item(RecipeResolver.make_item(_ore, 0), Vector2i(4, 0))
	await _await_merges()
	# Three Fine ingots: floor(1) + 0 = Fine.
	assert_array(_qualities(_plate)).is_equal([1])
	assert_array(_qualities(_ingot)).is_empty()


func test_merge_completed_reports_the_result_quality() -> void:
	var received: Array = []
	var handler := func(result_id: String, result_quality: int) -> void:
		received.append([result_id, result_quality])
	EventBus.merge_completed.connect(handler)
	_lay_row(_ore, [0, 0, 0, 0])
	_grid.place_item(RecipeResolver.make_item(_ore, 0), Vector2i(4, 0))
	await _await_merges()
	EventBus.merge_completed.disconnect(handler)
	assert_array(received).is_equal([["__test_ingot", 1]])


# Row [2,2,2,0] plus a 0 placed at col 4: floor(6/5) + 1 = mean(2+2+2+0+0 /5=1.2 -> floor=1) + 1 = 2 (Masterwork).
# Refunds the two lowest qualities: [0, 0].
func test_a_mixed_five_upgrades_and_refunds_the_lowest() -> void:
	_lay_row(_ore, [2, 2, 2, 0])
	_grid.place_item(RecipeResolver.make_item(_ore, 0), Vector2i(4, 0))
	await _await_merges()
	assert_array(_qualities(_ingot)).is_equal([2])
	assert_array(_qualities(_ore)).is_equal([0, 0])


func test_a_merge_that_loses_quality_shows_a_lost_cue() -> void:
	monitor_signals(_board)
	_lay_row(_ore, [1, 0])
	_grid.place_item(RecipeResolver.make_item(_ore, 0), Vector2i(2, 0))
	await _await_merges()
	await assert_signal(_board).is_emitted("quality_lost", [1, Vector2i(1, 0)])


func test_an_all_normal_merge_shows_no_lost_cue() -> void:
	monitor_signals(_board)
	_lay_row(_ore, [0, 0])
	_grid.place_item(RecipeResolver.make_item(_ore, 0), Vector2i(2, 0))
	await _await_merges()
	await assert_signal(_board).is_not_emitted("quality_lost")


# A group with nothing to merge into (no blueprint, or a final item) stays on
# the board. Merge detection must leave it alone instead of re-queueing it
# forever, which used to overflow the stack.
func test_a_group_with_no_merge_options_is_left_alone() -> void:
	for col in range(3):
		_grid.place_item(RecipeResolver.make_item(_plate), Vector2i(col, 0))
	assert_int(_grid.count_items_on_board("__test_plate")).is_equal(3)
	assert_bool(_board._resolver.is_processing).is_false()


func test_a_variant_option_says_how_many_of_its_reagent_are_left() -> void:
	var ice := ReagentDefinition.new()
	ice.id = "__test_ice"
	ice.name = "Test Ice"
	var frost := _item("__test_frost", null)
	var variant := ReagentVariant.new()
	variant.result = frost
	variant.reagent = ice
	_ore.reagent_variants = [variant]
	GameManager.add_reagent("__test_ice", 1)
	_lay_row(_ore, [0, 0])
	_grid.place_item(RecipeResolver.make_item(_ore, 0), Vector2i(2, 0))
	var popup: PopupPanel = _board.find_children("*", "PopupPanel", true, false)[0]
	var frames := 0
	while not popup.visible and frames < MAX_FRAMES:
		await get_tree().process_frame
		frames += 1
	var texts: Array = []
	for button: Button in popup.find_children("*", "Button", true, false):
		if not button.is_queued_for_deletion():
			texts.append(button.text)
	assert_array(texts).is_equal(["__test_ingot", "__test_frost (1 Test Ice left)"])


# Fills row 0 from column 0 without triggering detection.
func _lay_row(def: ItemDefinition, qualities: Array) -> void:
	for col in range(qualities.size()):
		_grid.grid[0][col] = RecipeResolver.make_item(def, qualities[col])
		_grid.refresh_cell(Vector2i(col, 0))


func _await_merges() -> void:
	var frames := 0
	while _board._resolver.is_processing and frames < MAX_FRAMES:
		await get_tree().process_frame
		frames += 1
	assert_bool(_board._resolver.is_processing).override_failure_message("merge never settled").is_false()


# Sorted qualities of every `def` on the board.
func _qualities(def: ItemDefinition) -> Array:
	var found: Array = []
	for row in _grid.grid:
		for cell in row:
			if cell != null and cell["item_id"] == def.id:
				found.append(cell["quality"])
	found.sort()
	return found


func _item(id: String, merges_into: ItemDefinition) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.name = id
	def.sprite = PlaceholderTexture2D.new()
	if merges_into != null:
		var option := MergeResult.new()
		option.result = merges_into
		def.merge_results = [option]
	set_definition(DefinitionLibrary.items, def)
	return def
