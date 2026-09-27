extends TestBase

# Merge options gated by blueprints and reagents, weighted rolls, and the board
# item dictionary. Uses fixture definitions only, never shipped content.

var _source: ItemDefinition
var _plain: ItemDefinition
var _gated: ItemDefinition
var _variant: ItemDefinition
var _blueprint: BlueprintDefinition
var _reagent: ReagentDefinition


func before_test() -> void:
	super.before_test()
	_plain = _item("__test_plain")
	_gated = _item("__test_gated")
	_variant = _item("__test_variant")
	_blueprint = BlueprintDefinition.new()
	_blueprint.id = "__test_bp"
	_reagent = ReagentDefinition.new()
	_reagent.id = "__test_reagent"
	_source = _item("__test_source")
	_source.merge_results.append(_merge_result(_plain, null))
	_source.merge_results.append(_merge_result(_gated, _blueprint))
	var rv := ReagentVariant.new()
	rv.result = _variant
	rv.reagent = _reagent
	rv.blueprint = _blueprint
	_source.reagent_variants.append(rv)
	set_definition(DefinitionLibrary.items, _source)


func test_make_item_carries_id_and_definition() -> void:
	var item := RecipeResolver.make_item(_plain)
	assert_str(item["item_id"]).is_equal("__test_plain")
	assert_object(item["definition"]).is_same(_plain)


func test_blueprint_gated_result_needs_its_blueprint() -> void:
	assert_array(_results(RecipeResolver.get_options("__test_source"))).is_equal([_plain])
	GameManager.add_blueprint("__test_bp")
	assert_array(_results(RecipeResolver.get_options("__test_source"))).is_equal([_plain, _gated])


func test_variant_needs_its_blueprint_and_a_reagent() -> void:
	GameManager.add_reagent("__test_reagent", 1)
	assert_array(RecipeResolver.get_variant_options("__test_source")).is_empty()
	GameManager.add_blueprint("__test_bp")
	assert_array(_results(RecipeResolver.get_variant_options("__test_source"))).is_equal([_variant])
	GameManager.consume_reagent("__test_reagent")
	assert_array(RecipeResolver.get_variant_options("__test_source")).is_empty()


func test_unknown_item_has_no_options() -> void:
	assert_array(RecipeResolver.get_options("__test_missing")).is_empty()
	assert_array(RecipeResolver.get_variant_options("__test_missing")).is_empty()


func test_dependencies_met_once_all_are_unlocked() -> void:
	var dep_a := BlueprintDefinition.new()
	dep_a.id = "__test_dep_a"
	var dep_b := BlueprintDefinition.new()
	dep_b.id = "__test_dep_b"
	_blueprint.dependencies.append(dep_a)
	_blueprint.dependencies.append(dep_b)
	GameManager.add_blueprint("__test_dep_a")
	assert_bool(RecipeResolver.are_dependencies_met(_blueprint)).is_false()
	GameManager.add_blueprint("__test_dep_b")
	assert_bool(RecipeResolver.are_dependencies_met(_blueprint)).is_true()


func test_weighted_roll_skips_zero_weight_and_respects_count() -> void:
	var pool: Array[WeightedItem] = [_weighted(_plain, 0), _weighted(_gated, 2)]
	var rolled := RecipeResolver.roll_weighted_pool(pool, 4, 4)
	assert_array(rolled).is_equal([_gated, _gated, _gated, _gated])


func test_weighted_roll_of_an_empty_pool_is_empty() -> void:
	var pool: Array[WeightedItem] = []
	assert_array(RecipeResolver.roll_weighted_pool(pool, 2, 2)).is_empty()


func _results(options: Array) -> Array[ItemDefinition]:
	var results: Array[ItemDefinition] = []
	for option: Resource in options:
		results.append(option.result)
	return results


func _item(id: String) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = id
	item.name = id
	return item


func _merge_result(result: ItemDefinition, blueprint: BlueprintDefinition) -> MergeResult:
	var option := MergeResult.new()
	option.result = result
	option.blueprint = blueprint
	return option


func _weighted(item: ItemDefinition, weight: int) -> WeightedItem:
	var entry := WeightedItem.new()
	entry.item = item
	entry.weight = weight
	return entry
