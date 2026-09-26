extends TestBase

# Board state as saved by BoardGrid: item ids only, rebuilt from the catalog on
# load. Guards the bug where saving whole item dicts turned the sprite texture
# into a string in JSON, so reloaded boards showed no icons.

const GEM_ID := "__test_gem"

var _gem_texture: Texture2D


func before_test() -> void:
	super.before_test()
	_gem_texture = PlaceholderTexture2D.new()
	set_catalog_entry(RecipeResolver.items, GEM_ID, {
		"id": GEM_ID,
		"name": "Gem",
		"family": "test",
		"gold_value": 1,
		"dungeon_usable": false,
		"dungeon_use_target": "",
		"effect": null,
		"sprite": _gem_texture,
	})


func test_board_state_saves_only_ids() -> void:
	var board := _make_board()
	board.place_item(RecipeResolver.get_item_data(GEM_ID), Vector2i(1, 2))
	assert_array(board.get_board_state()).is_equal([{"col": 1, "row": 2, "item_id": GEM_ID}])


func test_board_state_restores_sprite_after_json_round_trip() -> void:
	var board := _make_board()
	board.place_item(RecipeResolver.get_item_data(GEM_ID), Vector2i(1, 2))
	var saved: Array = JSON.parse_string(JSON.stringify(board.get_board_state()))

	var reloaded := _make_board()
	reloaded.load_board_state(saved)
	assert_object(reloaded.get_cell_at(Vector2i(1, 2)).get_icon_texture()).is_same(_gem_texture)
	assert_str(reloaded.grid[2][1]["item_id"]).is_equal(GEM_ID)


func test_board_state_skips_ids_missing_from_catalog() -> void:
	var board := _make_board()
	board.load_board_state([{"col": 0, "row": 0, "item_id": "__test_missing"}])
	assert_array(board.get_board_state()).is_empty()


func _make_board() -> GridContainer:
	var board: GridContainer = auto_free(load("res://board/board_grid.gd").new())
	add_child(board)
	board.set_cell_scene(load("res://board/board_cell.tscn"))
	board.setup({"cols": 3, "rows": 3})
	return board
