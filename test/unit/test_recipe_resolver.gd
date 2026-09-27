extends TestBase

# C4 — catalog getters must return copies, not the cached entries, so the shared
# load-once catalogs are never mutated by callers. Uses injected fixture entries,
# never shipped content from res://data/.

const FIXTURE_ID := "__test_item"


func before_test() -> void:
	super.before_test()
	set_catalog_entry(RecipeResolver.items, FIXTURE_ID, {
		"name": "Test Item",
		"family": "test_family",
		"effect": {"kind": "test_effect"},
	})


func test_get_item_data_returns_copy_with_id_stamp() -> void:
	var data := RecipeResolver.get_item_data(FIXTURE_ID)
	assert_str(str(data.get("item_id", ""))).is_equal(FIXTURE_ID)
	# Catalog fields are still present on the copy.
	assert_str(str(data.get("family", ""))).is_equal("test_family")


func test_get_item_data_does_not_mutate_cache() -> void:
	# The cached entry must not gain an item_id key as a side effect of lookup.
	var _ignored := RecipeResolver.get_item_data(FIXTURE_ID)
	var cached: Dictionary = RecipeResolver.items[FIXTURE_ID]
	assert_bool(cached.has("item_id")).is_false()
	assert_int(cached.size()).is_equal(3)


func test_mutating_returned_item_nested_data_leaves_cache_intact() -> void:
	# Deep copy: editing a nested dictionary on the result must not reach the catalog.
	var data := RecipeResolver.get_item_data(FIXTURE_ID)
	data["effect"]["kind"] = "changed"
	var cached: Dictionary = RecipeResolver.items[FIXTURE_ID]
	assert_str(str(cached["effect"]["kind"])).is_equal("test_effect")


func test_mutating_returned_catalog_data_leaves_cache_intact() -> void:
	set_catalog_entry(RecipeResolver.crates, "__test_crate", {"cost": 10, "pool": [{"item_id": "a", "weight": 1}]})
	set_catalog_entry(RecipeResolver.upgrades, "__test_upgrade", {"effect_value": 2.0})
	set_catalog_entry(RecipeResolver.reagents, "__test_reagent", {"cost": 7})

	var crate := RecipeResolver.get_crate_data("__test_crate")
	crate["cost"] = 999
	crate["pool"][0]["weight"] = 999
	RecipeResolver.get_upgrade_data("__test_upgrade")["effect_value"] = 999.0
	RecipeResolver.get_reagent_data("__test_reagent")["cost"] = 999

	assert_int(int(RecipeResolver.crates["__test_crate"]["cost"])).is_equal(10)
	assert_int(int(RecipeResolver.crates["__test_crate"]["pool"][0]["weight"])).is_equal(1)
	assert_float(float(RecipeResolver.upgrades["__test_upgrade"]["effect_value"])).is_equal(2.0)
	assert_int(int(RecipeResolver.reagents["__test_reagent"]["cost"])).is_equal(7)


func test_mutating_returned_merge_option_leaves_cache_intact() -> void:
	set_catalog_entry(RecipeResolver.recipes, FIXTURE_ID, {"results": [{"result_id": "__test_result"}]})
	var options := RecipeResolver.get_options(FIXTURE_ID)
	options[0]["result_id"] = "changed"
	var cached: Dictionary = RecipeResolver.recipes[FIXTURE_ID]
	assert_str(str(cached["results"][0]["result_id"])).is_equal("__test_result")


func test_get_item_data_missing_returns_empty() -> void:
	var data := RecipeResolver.get_item_data("__does_not_exist")
	assert_dict(data).is_empty()


# Catches a renamed or removed item still named by recipes or reagent combos.
func test_recipes_and_combos_reference_defined_items_and_blueprints() -> void:
	for source_id: String in RecipeResolver.recipes:
		_assert_item_defined(source_id, "recipe source")
		for result: Dictionary in RecipeResolver.recipes[source_id].get("results", []):
			_assert_item_defined(result.get("result_id", ""), "result of %s" % source_id)
			_assert_blueprint_defined(result.get("blueprint_required", ""), source_id)
	for base_id: String in RecipeResolver.reagent_combos:
		_assert_item_defined(base_id, "combo base")
		for combo: Dictionary in RecipeResolver.reagent_combos[base_id]:
			_assert_item_defined(combo.get("variant_item_id", ""), "variant of %s" % base_id)
			_assert_blueprint_defined(combo.get("blueprint_required", ""), base_id)
			assert_bool(RecipeResolver.reagents.has(combo.get("reagent_id", ""))) \
				.override_failure_message("%s combo names unknown reagent" % base_id).is_true()


func _assert_item_defined(item_id: String, role: String) -> void:
	assert_bool(RecipeResolver.items.has(item_id)) \
		.override_failure_message("%s '%s' is not a defined item" % [role, item_id]).is_true()


func _assert_blueprint_defined(bp_id: String, source_id: String) -> void:
	if bp_id == "":
		return
	assert_bool(RecipeResolver.blueprints.has(bp_id)) \
		.override_failure_message("%s needs unknown blueprint '%s'" % [source_id, bp_id]).is_true()
