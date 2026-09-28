extends TestBase

# Board state as saved by BoardGrid: item ids only, rebuilt from the catalog on
# load. Guards the bug where saving whole item dicts turned the sprite texture
# into a string in JSON, so reloaded boards showed no icons.

const GEM_ID := "__test_gem"

var _gem: ItemDefinition


func before_test() -> void:
	super.before_test()
	_gem = ItemDefinition.new()
	_gem.id = GEM_ID
	_gem.name = "Gem"
	_gem.sprite = PlaceholderTexture2D.new()
	set_definition(DefinitionLibrary.items, _gem)


func test_board_state_saves_ids_and_quality() -> void:
	var board := _make_board()
	board.place_item(RecipeResolver.make_item(_gem), Vector2i(1, 2))
	assert_array(board.get_board_state()).is_equal([{"col": 1, "row": 2, "item_id": GEM_ID, "quality": 0}])


func test_quality_survives_a_json_round_trip() -> void:
	var board := _make_board()
	board.place_item(RecipeResolver.make_item(_gem, 2), Vector2i(0, 1))
	var saved: Array = JSON.parse_string(JSON.stringify(board.get_board_state()))
	var reloaded := _make_board()
	reloaded.load_board_state(saved)
	# JSON turns 2 into 2.0; the reloaded item must hold an int again.
	assert_int(reloaded.grid[1][0]["quality"]).is_equal(2)
	assert_bool(reloaded.grid[1][0]["quality"] is int).is_true()


func test_board_state_restores_sprite_after_json_round_trip() -> void:
	var board := _make_board()
	board.place_item(RecipeResolver.make_item(_gem), Vector2i(1, 2))
	var saved: Array = JSON.parse_string(JSON.stringify(board.get_board_state()))

	var reloaded := _make_board()
	reloaded.load_board_state(saved)
	assert_object(reloaded.get_cell_at(Vector2i(1, 2)).get_icon_texture()).is_same(_gem.sprite)
	assert_str(reloaded.grid[2][1]["item_id"]).is_equal(GEM_ID)


func test_board_state_skips_ids_missing_from_catalog() -> void:
	var board := _make_board()
	board.load_board_state([{"col": 0, "row": 0, "item_id": "__test_missing"}])
	assert_array(board.get_board_state()).is_empty()


func test_a_full_board_keeps_its_items_in_place_on_a_taller_board() -> void:
	var state: Array = []
	for r in range(3):
		for c in range(3):
			state.append({"col": c, "row": r, "item_id": GEM_ID, "quality": 0})
	var taller := _make_board()
	taller.setup({"cols": 3, "rows": 4})
	taller.load_board_state(state)
	assert_array(taller.get_board_state()).is_equal(state)
	for c in range(3):
		assert_object(taller.grid[3][c]).is_null()


func _make_board() -> GridContainer:
	var board: GridContainer = auto_free(load("res://board/board_grid.gd").new())
	add_child(board)
	board.set_cell_scene(load("res://board/board_cell.tscn"))
	board.setup({"cols": 3, "rows": 3})
	return board
