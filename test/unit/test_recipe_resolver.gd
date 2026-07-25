extends TestBase

# C4 — get_item_data must return an id-stamped copy, not the cached entry,
# so the shared items catalog is never mutated by lookups.


func test_get_item_data_returns_copy_with_id_stamp() -> void:
	var data := RecipeResolver.get_item_data("iron_ore")
	assert_dict(data).is_not_empty()
	assert_str(str(data.get("item_id", ""))).is_equal("iron_ore")
	# A real field from the JSON is still present.
	assert_str(str(data.get("family", ""))).is_equal("metal")


func test_get_item_data_does_not_mutate_cache() -> void:
	# The cached entry must not gain an item_id key as a side effect of lookup.
	var cached_before: Dictionary = RecipeResolver.items["iron_ore"]
	var keys_before: int = cached_before.size()
	var _ignored := RecipeResolver.get_item_data("iron_ore")
	var _ignored2 := RecipeResolver.get_item_data("iron_ore")
	var cached_after: Dictionary = RecipeResolver.items["iron_ore"]
	assert_int(cached_after.size()).is_equal(keys_before)
	assert_bool(cached_after.has("item_id")).is_false()


func test_get_item_data_missing_returns_empty() -> void:
	var data := RecipeResolver.get_item_data("does_not_exist")
	assert_dict(data).is_empty()
