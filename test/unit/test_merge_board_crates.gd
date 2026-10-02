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
	_give_discount(0.5)
	assert_bool(_board.buy_crate("__test_crate")).is_true()
	assert_int(GameManager.gold).is_equal(30)


func test_a_market_multiplier_stacks_with_the_crate_discount() -> void:
	DefinitionLibrary.get_crate("__test_crate").cost = 25
	_give_discount(0.8)
	_board.setup({"cols": 3, "rows": 3, "crate_cost_multipliers": {"__test_crate": 1.5}})
	# 25 x 1.5 x 0.8 = 30, rounded down once.
	assert_int(_board.get_crate_cost(DefinitionLibrary.get_crate("__test_crate"))).is_equal(30)
	assert_bool(_board.buy_crate("__test_crate")).is_true()
	assert_int(GameManager.gold).is_equal(20)


func test_float_error_does_not_lose_a_gold() -> void:
	DefinitionLibrary.get_crate("__test_crate").cost = 30
	_board.setup({"cols": 3, "rows": 3, "crate_cost_multipliers": {"__test_crate": 0.7}})
	# 30 x 0.7 = 21 exactly, though floats make it 20.999...
	assert_int(_board.get_crate_cost(DefinitionLibrary.get_crate("__test_crate"))).is_equal(21)


func test_a_crate_never_costs_less_than_one_gold() -> void:
	DefinitionLibrary.get_crate("__test_crate").cost = 1
	_give_discount(0.5)
	_board.setup({"cols": 3, "rows": 3, "crate_cost_multipliers": {"__test_crate": 0.5}})
	assert_int(_board.get_crate_cost(DefinitionLibrary.get_crate("__test_crate"))).is_equal(1)


func test_a_multiplier_for_another_crate_leaves_this_one_alone() -> void:
	_board.setup({"cols": 3, "rows": 3, "crate_cost_multipliers": {"__other_crate": 2.0}})
	assert_int(_board.get_crate_cost(DefinitionLibrary.get_crate("__test_crate"))).is_equal(40)


func test_crate_refused_when_gold_is_short() -> void:
	GameManager.gold = 39
	assert_bool(_board.buy_crate("__test_crate")).is_false()
	assert_int(GameManager.gold).is_equal(39)
	assert_int(_placed_count("__test_item")).is_equal(0)


func test_crate_refused_below_its_level() -> void:
	set_definition(DefinitionLibrary.shop_rules, _level_rules())
	DefinitionLibrary.get_crate("__test_crate").min_shop_level = 2
	assert_bool(_board.buy_crate("__test_crate")).is_false()
	assert_int(GameManager.gold).is_equal(50)
	assert_int(_placed_count("__test_item")).is_equal(0)


func _level_rules() -> ShopRulesDefinition:
	var rules := ShopRulesDefinition.new()
	rules.id = "default"
	rules.level_xp_base = 100
	rules.level_xp_exponent = 1.0
	rules.max_level = 5
	return rules


# Items on the grid plus items waiting in the staging area.
func _placed_count(item_id: String) -> int:
	var count: int = _board.get_board_grid().count_items_on_board(item_id)
	for child in _board.get_staging_area().get_children():
		if child.item_data.get("item_id", "") == item_id:
			count += 1
	return count


func _give_discount(value: float) -> void:
	var discount := UpgradeDefinition.new()
	discount.id = "__test_discount"
	discount.effect = "crate_discount"
	var level := UpgradeLevel.new()
	level.value = value
	discount.levels = [level]
	set_definition(DefinitionLibrary.upgrades, discount)
	GameManager.raise_upgrade_level("__test_discount")


func test_a_crate_outside_the_town_is_refused() -> void:
	test_town.crates.erase(DefinitionLibrary.get_crate("__test_crate"))
	assert_bool(_board.buy_crate("__test_crate")).is_false()
	assert_int(GameManager.gold).is_equal(50)
