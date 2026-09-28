extends TestBase

# Quality shows as stars (1 Fine, 2 Masterwork) on board cells and staging
# items; Normal shows none. Star count, not color, carries the meaning.

const BOARD_CELL := preload("res://board/board_cell.tscn")
const FLOATING_ITEM := preload("res://board/floating_item.tscn")
const QUALITY_STARS := preload("res://ui/quality_stars.tscn")

var _item: ItemDefinition


func before_test() -> void:
	super.before_test()
	_item = ItemDefinition.new()
	_item.id = "__test_item"
	_item.sprite = PlaceholderTexture2D.new()
	set_definition(DefinitionLibrary.items, _item)


func test_normal_shows_no_stars() -> void:
	var stars: Control = auto_free(QUALITY_STARS.instantiate())
	add_child(stars)
	stars.set_quality(0)
	assert_bool(stars.visible).is_false()


func test_a_masterwork_cell_shows_two_stars_until_cleared() -> void:
	var cell: Control = auto_free(BOARD_CELL.instantiate())
	add_child(cell)
	cell.set_item(RecipeResolver.make_item(_item, 2))
	var stars: Control = cell.get_node("%QualityStars")
	assert_int(stars.quality).is_equal(2)
	assert_bool(stars.visible).is_true()
	cell.clear_item()
	assert_bool(stars.visible).is_false()


func test_a_normal_cell_after_a_fine_one_hides_its_stars() -> void:
	var cell: Control = auto_free(BOARD_CELL.instantiate())
	add_child(cell)
	cell.set_item(RecipeResolver.make_item(_item, 1))
	cell.set_item(RecipeResolver.make_item(_item, 0))
	assert_bool(cell.get_node("%QualityStars").visible).is_false()


func test_a_fine_staging_item_shows_one_star() -> void:
	var floating: Control = auto_free(FLOATING_ITEM.instantiate())
	add_child(floating)
	floating.setup(RecipeResolver.make_item(_item, 1), 60.0)
	var stars: Control = floating.get_node("%QualityStars")
	assert_int(stars.quality).is_equal(1)
	assert_bool(stars.visible).is_true()


func test_a_staging_item_drags_with_its_quality() -> void:
	var floating: Control = auto_free(FLOATING_ITEM.instantiate())
	add_child(floating)
	floating.setup(RecipeResolver.make_item(_item, 2), 60.0)
	assert_int(floating.make_drag_data()["quality"]).is_equal(2)
