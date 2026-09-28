extends TestBase

# MergeBoard's display shelf: a second BoardGrid that never merges. Covers what
# the shop can sell from board plus shelf, drags between the two, and loading
# a shelf smaller than its saved state.

const MERGE_BOARD := preload("res://board/merge_board.tscn")
const FLOATING_ITEM := preload("res://board/floating_item.tscn")
const MERGE_DETECTOR := preload("res://board/merge_detector.gd")
# The move tween runs 0.15 s of real time, and headless frames are short.
const MAX_FRAMES := 5000

var _board: Control
var _gem: ItemDefinition
var _ore: ItemDefinition


func before_test() -> void:
	super.before_test()
	_gem = _item("__test_gem")
	_ore = _item("__test_ore")
	_board = _make_board({"cols": 3, "rows": 3, "shelf_slots": 3})


func test_a_board_set_up_without_shelf_slots_has_no_shelf() -> void:
	var dungeon_board := _make_board({"cols": 3, "rows": 3})
	var shelf: Control = dungeon_board.get_shelf_grid()
	assert_int(shelf.grid_cols).is_equal(0)
	assert_int(shelf.get_child_count()).is_equal(0)
	assert_bool(shelf.is_visible_in_tree()).is_false()


func test_shelf_slots_make_a_one_row_shelf() -> void:
	var shelf: Control = _board.get_shelf_grid()
	assert_int(shelf.grid_cols).is_equal(3)
	assert_int(shelf.grid_rows).is_equal(1)
	assert_int(shelf.get_child_count()).is_equal(3)
	assert_bool(shelf.is_visible_in_tree()).is_true()


func test_three_alike_on_the_shelf_make_no_merge_group() -> void:
	var detector: RefCounted = MERGE_DETECTOR.new()
	var shelf: Control = _board.get_shelf_grid()
	var grid: Control = _board.get_board_grid()
	for c in range(3):
		shelf.grid[0][c] = RecipeResolver.make_item(_gem)
		grid.grid[0][c] = RecipeResolver.make_item(_gem)
	assert_array(detector.scan_grid(shelf)).is_empty()
	assert_int(detector.scan_grid(grid).size()).is_equal(1)


func test_sellable_counts_board_and_shelf_and_takes_from_the_shelf_first() -> void:
	var shelf: Control = _board.get_shelf_grid()
	var grid: Control = _board.get_board_grid()
	shelf.grid[0][1] = RecipeResolver.make_item(_gem)
	grid.grid[0][0] = RecipeResolver.make_item(_gem)
	grid.grid[2][2] = RecipeResolver.make_item(_gem)
	assert_int(_board.count_sellable("__test_gem")).is_equal(3)
	_board.take_sellable("__test_gem", 2)
	assert_int(shelf.count_items_on_board("__test_gem")).is_equal(0)
	assert_int(grid.count_items_on_board("__test_gem")).is_equal(1)


func test_dragging_a_board_item_onto_an_empty_shelf_slot_moves_it() -> void:
	var shelf: Control = _board.get_shelf_grid()
	var grid: Control = _board.get_board_grid()
	grid.place_item(RecipeResolver.make_item(_gem), Vector2i(0, 0))
	_drop(grid, Vector2i(0, 0), shelf, Vector2i(2, 0))
	assert_object(grid.grid[0][0]).is_null()
	assert_str(shelf.grid[0][2]["item_id"]).is_equal("__test_gem")
	await _await_cell_item(shelf, Vector2i(2, 0), "__test_gem")
	assert_str(grid.get_cell_at(Vector2i(0, 0)).item.get("item_id", "")).is_empty()


func test_dropping_a_shelf_item_on_an_occupied_board_cell_swaps_them() -> void:
	var shelf: Control = _board.get_shelf_grid()
	var grid: Control = _board.get_board_grid()
	grid.place_item(RecipeResolver.make_item(_ore), Vector2i(1, 1))
	shelf.place_item(RecipeResolver.make_item(_gem), Vector2i(0, 0))
	_drop(shelf, Vector2i(0, 0), grid, Vector2i(1, 1))
	assert_str(grid.grid[1][1]["item_id"]).is_equal("__test_gem")
	assert_str(shelf.grid[0][0]["item_id"]).is_equal("__test_ore")
	await _await_cell_item(shelf, Vector2i(0, 0), "__test_ore")
	await _await_cell_item(grid, Vector2i(1, 1), "__test_gem")


func test_dropping_a_board_item_on_an_occupied_board_cell_still_swaps() -> void:
	var grid: Control = _board.get_board_grid()
	grid.place_item(RecipeResolver.make_item(_ore), Vector2i(0, 0))
	grid.place_item(RecipeResolver.make_item(_gem), Vector2i(2, 2))
	_drop(grid, Vector2i(0, 0), grid, Vector2i(2, 2))
	assert_str(grid.grid[2][2]["item_id"]).is_equal("__test_ore")
	assert_str(grid.grid[0][0]["item_id"]).is_equal("__test_gem")


func test_dropping_a_board_item_on_an_occupied_shelf_slot_swaps() -> void:
	var shelf: Control = _board.get_shelf_grid()
	var grid: Control = _board.get_board_grid()
	grid.place_item(RecipeResolver.make_item(_ore), Vector2i(1, 1))
	shelf.place_item(RecipeResolver.make_item(_gem), Vector2i(0, 0))
	_drop(grid, Vector2i(1, 1), shelf, Vector2i(0, 0))
	assert_str(shelf.grid[0][0]["item_id"]).is_equal("__test_ore")
	assert_str(grid.grid[1][1]["item_id"]).is_equal("__test_gem")
	await _await_cell_item(shelf, Vector2i(0, 0), "__test_ore")
	await _await_cell_item(grid, Vector2i(1, 1), "__test_gem")


# MergeBoard has no public getter for its resolver; there is no clean public
# route to force is_processing, so the test sets it directly on the private
# member, as the fix-round notes allow.
func test_a_shelf_item_dropped_on_the_board_during_a_merge_changes_neither_grid() -> void:
	var shelf: Control = _board.get_shelf_grid()
	var grid: Control = _board.get_board_grid()
	grid.place_item(RecipeResolver.make_item(_ore), Vector2i(1, 1))
	shelf.place_item(RecipeResolver.make_item(_gem), Vector2i(0, 0))
	_board._resolver.is_processing = true
	_drop(shelf, Vector2i(0, 0), grid, Vector2i(1, 1))
	assert_str(grid.grid[1][1]["item_id"]).is_equal("__test_ore")
	assert_str(shelf.grid[0][0]["item_id"]).is_equal("__test_gem")
	_board._resolver.is_processing = false


func test_a_staging_item_dropped_on_the_shelf_during_a_merge_stays_in_staging() -> void:
	var shelf: Control = _board.get_shelf_grid()
	var floating: Control = FLOATING_ITEM.instantiate()
	floating.setup(RecipeResolver.make_item(_gem), 60.0)
	_board.get_staging_area().add_child(floating)
	_board._resolver.is_processing = true
	shelf.get_cell_at(Vector2i(1, 0))._drop_data(Vector2.ZERO, floating.make_drag_data())
	assert_object(shelf.grid[0][1]).is_null()
	assert_int(_live_children(_board.get_staging_area())).is_equal(1)
	_board._resolver.is_processing = false


func test_dragging_a_board_item_to_the_shelf_leaves_a_matching_staging_item() -> void:
	var shelf: Control = _board.get_shelf_grid()
	var grid: Control = _board.get_board_grid()
	grid.place_item(RecipeResolver.make_item(_gem), Vector2i(0, 0))
	var floating: Control = FLOATING_ITEM.instantiate()
	floating.setup(RecipeResolver.make_item(_gem), 60.0)
	_board.get_staging_area().add_child(floating)
	_drop(grid, Vector2i(0, 0), shelf, Vector2i(2, 0))
	await _await_cell_item(shelf, Vector2i(2, 0), "__test_gem")
	assert_int(_live_children(_board.get_staging_area())).is_equal(1)


func test_dragging_a_board_item_to_another_board_cell_leaves_a_matching_staging_item() -> void:
	var grid: Control = _board.get_board_grid()
	grid.place_item(RecipeResolver.make_item(_gem), Vector2i(0, 0))
	var floating: Control = FLOATING_ITEM.instantiate()
	floating.setup(RecipeResolver.make_item(_gem), 60.0)
	_board.get_staging_area().add_child(floating)
	_drop(grid, Vector2i(0, 0), grid, Vector2i(2, 2))
	await _await_cell_item(grid, Vector2i(2, 2), "__test_gem")
	assert_int(_live_children(_board.get_staging_area())).is_equal(1)


func test_a_staging_item_dropped_on_the_shelf_leaves_staging() -> void:
	var shelf: Control = _board.get_shelf_grid()
	var floating: Control = FLOATING_ITEM.instantiate()
	floating.setup(RecipeResolver.make_item(_gem), 60.0)
	_board.get_staging_area().add_child(floating)
	shelf.get_cell_at(Vector2i(1, 0))._drop_data(Vector2.ZERO, floating.make_drag_data())
	assert_str(shelf.grid[0][1]["item_id"]).is_equal("__test_gem")
	var frames := 0
	while _live_children(_board.get_staging_area()) > 0 and frames < MAX_FRAMES:
		await get_tree().process_frame
		frames += 1
	assert_int(_live_children(_board.get_staging_area())).is_equal(0)


# A smaller shelf (a later prestige reset) must not lose what was on it.
func test_items_beyond_a_smaller_shelf_go_to_the_board() -> void:
	var small := _make_board({"cols": 3, "rows": 3, "shelf_slots": 2})
	small.load_shelf_state([
		{"col": 0, "row": 0, "item_id": "__test_gem"},
		{"col": 1, "row": 0, "item_id": "__test_gem"},
		{"col": 2, "row": 0, "item_id": "__test_ore"},
		{"col": 3, "row": 0, "item_id": "__test_ore"},
	])
	assert_int(small.get_shelf_grid().count_items_on_board("__test_gem")).is_equal(2)
	assert_int(small.get_shelf_grid().count_items_on_board("__test_ore")).is_equal(0)
	assert_int(small.get_board_grid().count_items_on_board("__test_ore")).is_equal(2)


func test_shelf_state_round_trips() -> void:
	_board.get_shelf_grid().place_item(RecipeResolver.make_item(_gem), Vector2i(2, 0))
	var saved: Array = _board.get_shelf_state()
	assert_array(saved).is_equal([{"col": 2, "row": 0, "item_id": "__test_gem"}])
	var reloaded := _make_board({"cols": 3, "rows": 3, "shelf_slots": 3})
	reloaded.load_shelf_state(saved)
	assert_str(reloaded.get_shelf_grid().grid[0][2]["item_id"]).is_equal("__test_gem")


func _make_board(config: Dictionary) -> Control:
	var board: Control = auto_free(MERGE_BOARD.instantiate())
	add_child(board)
	board.setup(config)
	return board


# Drives the real drop path: the payload a drag would carry, then the target
# cell's _drop_data (Godot's own drop callback). A real drag can't start
# headless.
func _drop(from_grid: Control, from_pos: Vector2i, to_grid: Control, to_pos: Vector2i) -> void:
	var data: Dictionary = from_grid.get_cell_at(from_pos).make_drag_data()
	to_grid.get_cell_at(to_pos)._drop_data(Vector2.ZERO, data)


func _await_cell_item(grid: Control, pos: Vector2i, item_id: String) -> void:
	var frames := 0
	while grid.get_cell_at(pos).item.get("item_id", "") != item_id and frames < MAX_FRAMES:
		await get_tree().process_frame
		frames += 1
	assert_str(grid.get_cell_at(pos).item.get("item_id", "")).is_equal(item_id)


func _live_children(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	return count


func _item(id: String) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = id
	item.sprite = PlaceholderTexture2D.new()
	set_definition(DefinitionLibrary.items, item)
	return item
