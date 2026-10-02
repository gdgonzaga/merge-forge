extends TestBase

# The codex: GameManager keeps the best quality each item was merged at, and
# RecipeResolver lists the items the codex shows.

var _ore: ItemDefinition
var _ingot: ItemDefinition
var _plate: ItemDefinition
var _gem: ItemDefinition


func before_test() -> void:
	super.before_test()
	_plate = _item("__test_plate", 75)
	_gem = _item("__test_gem", 200)
	_ingot = _item("__test_ingot", 20)
	_ingot.merge_results.append(_merge(_plate))
	var variant := ReagentVariant.new()
	variant.result = _gem
	variant.reagent = ReagentDefinition.new()
	variant.blueprint = BlueprintDefinition.new()
	_ingot.reagent_variants.append(variant)
	_ore = _item("__test_ore", 5)
	_ore.merge_results.append(_merge(_ingot))
	# Made only from an item no crate sells, so no town reaches it.
	var unsold := _item("__test_unsold", 5)
	unsold.merge_results.append(_merge(_item("__test_stray", 20)))
	var entry := WeightedItem.new()
	entry.item = _ore
	var crate := CrateDefinition.new()
	crate.id = "__test_crate"
	crate.pool = [entry]
	set_definition(DefinitionLibrary.crates, crate)


func test_a_merge_records_its_result_in_the_codex() -> void:
	EventBus.merge_completed.emit("__test_ingot", 1)
	assert_dict(GameManager.codex).is_equal({"__test_ingot": 1})


func test_the_codex_keeps_the_best_quality() -> void:
	EventBus.merge_completed.emit("__test_ingot", 2)
	EventBus.merge_completed.emit("__test_ingot", 0)
	EventBus.merge_completed.emit("__test_ingot", 1)
	assert_dict(GameManager.codex).is_equal({"__test_ingot": 2})


func test_stars_count_one_per_quality_reached() -> void:
	GameManager.codex = {"__a": 0, "__b": 2}
	# Normal is 1 star, Masterwork 3.
	assert_int(GameManager.get_codex_stars()).is_equal(4)


func test_the_codex_lists_what_merges_make_from_a_towns_crates() -> void:
	var ids := _ids(RecipeResolver.get_codex_items())
	assert_array(ids).contains(["__test_ingot", "__test_plate", "__test_gem"])
	assert_array(ids).not_contains(["__test_ore", "__test_stray", "__test_unsold"])


func test_codex_items_come_by_family_then_value() -> void:
	var ours: Array[String] = []
	for item in RecipeResolver.get_codex_items():
		if item.family == "__test_fam":
			ours.append(item.id)
	assert_array(ours).is_equal(["__test_ingot", "__test_plate", "__test_gem"])


func test_crafting_an_item_no_crate_reaches_is_not_recorded() -> void:
	EventBus.merge_completed.emit("__test_stray", 2)
	assert_dict(GameManager.codex).is_empty()
	assert_int(GameManager.get_codex_stars()).is_equal(0)


func test_a_family_is_complete_once_every_codex_item_is_made() -> void:
	GameManager.record_crafted("__test_ingot", 0)
	GameManager.record_crafted("__test_plate", 0)
	assert_array(GameManager.get_completed_codex_families()).not_contains(["__test_fam"])
	GameManager.record_crafted("__test_gem", 0)
	assert_array(GameManager.get_completed_codex_families()).contains(["__test_fam"])


func _item(id: String, gold: int) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = id
	item.name = id
	item.family = "__test_fam"
	item.gold_value = gold
	set_definition(DefinitionLibrary.items, item)
	return item


func _merge(result: ItemDefinition) -> MergeResult:
	var option := MergeResult.new()
	option.result = result
	return option


func _ids(items: Array[ItemDefinition]) -> Array[String]:
	var ids: Array[String] = []
	for item in items:
		ids.append(item.id)
	return ids
