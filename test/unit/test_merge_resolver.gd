extends TestBase

# The oversized-group bonus: each item past 3 pays a share of the consumed
# source item's value. The extras are refunded too, so the share stays small.

const MERGE_RESOLVER := preload("res://board/merge_resolver.gd")

var _resolver: RefCounted


func before_test() -> void:
	super.before_test()
	_resolver = MERGE_RESOLVER.new()


func test_group_of_three_pays_no_bonus() -> void:
	assert_int(_resolver.calculate_bonus_gold(3, 40)).is_equal(0)


func test_each_extra_item_pays_a_quarter_of_the_source_value() -> void:
	# 2 extras x floor(40 x 0.25) = 2 x 10
	assert_int(_resolver.calculate_bonus_gold(5, 40)).is_equal(20)


func test_bonus_rounds_down_per_item() -> void:
	# 1 extra x floor(15 x 0.25 = 3.75) = 3
	assert_int(_resolver.calculate_bonus_gold(4, 15)).is_equal(3)


func test_cheap_source_pays_nothing() -> void:
	# 2 extras x floor(3 x 0.25 = 0.75) = 0
	assert_int(_resolver.calculate_bonus_gold(5, 3)).is_equal(0)


# A group with nothing to merge into (no blueprint, or a final item) stays on
# the board. Merge detection must leave it alone instead of re-queueing it
# forever, which used to overflow the stack.
func test_a_group_with_no_merge_options_is_left_alone() -> void:
	var dead_end := ItemDefinition.new()
	dead_end.id = "__test_dead_end"
	set_definition(DefinitionLibrary.items, dead_end)
	var board: Control = auto_free(preload("res://board/merge_board.tscn").instantiate())
	add_child(board)
	board.setup({"cols": 3, "rows": 3})
	var grid: Control = board.get_board_grid()
	for col in range(3):
		grid.place_item(RecipeResolver.make_item(dead_end), Vector2i(col, 0))
	assert_int(grid.count_items_on_board("__test_dead_end")).is_equal(3)
	assert_bool(board._resolver.is_processing).is_false()
