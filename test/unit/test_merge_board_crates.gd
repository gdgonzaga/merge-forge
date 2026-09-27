extends TestBase

# MergeBoard.buy_crate: the crate price (after any crate discount) and what
# lands on the board or in the staging area.

const MERGE_BOARD := preload("res://board/merge_board.tscn")

var _board: Control


func before_test() -> void:
	super.before_test()
	var item := ItemDefinition.new()
	item.id = "__test_item"
	set_definition(DefinitionLibrary.items, item)
	var entry := WeightedItem.new()
	entry.item = item
	entry.weight = 1
	var crate := CrateDefinition.new()
	crate.id = "__test_crate"
	crate.cost = 40
	crate.min_items = 2
	crate.max_items = 2
	crate.pool = [entry]
	set_definition(DefinitionLibrary.crates, crate)
	_board = auto_free(MERGE_BOARD.instantiate())
	add_child(_board)
	_board.setup({"cols": 3, "rows": 3})
	GameManager.gold = 50


func test_crate_charges_its_cost_and_places_its_items() -> void:
	assert_bool(_board.buy_crate("__test_crate")).is_true()
	assert_int(GameManager.gold).is_equal(10)
	assert_int(_placed_count("__test_item")).is_equal(2)


func test_crate_discount_lowers_the_price() -> void:
	var discount := UpgradeDefinition.new()
	discount.id = "__test_discount"
	discount.effect = "crate_discount"
	discount.value = 0.5
	set_definition(DefinitionLibrary.upgrades, discount)
	GameManager.add_upgrade("__test_discount")
	assert_bool(_board.buy_crate("__test_crate")).is_true()
	assert_int(GameManager.gold).is_equal(30)


func test_crate_refused_when_gold_is_short() -> void:
	GameManager.gold = 39
	assert_bool(_board.buy_crate("__test_crate")).is_false()
	assert_int(GameManager.gold).is_equal(39)
	assert_int(_placed_count("__test_item")).is_equal(0)


# Items on the grid plus items waiting in the staging area.
func _placed_count(item_id: String) -> int:
	var count: int = _board.get_board_grid().count_items_on_board(item_id)
	for child in _board.get_staging_area().get_children():
		if child.item_data.get("item_id", "") == item_id:
			count += 1
	return count
