extends TestBase

# The codex panel: made items show their name and stars, the rest are nameless
# black silhouettes (spec review focus 5), grouped by family.

const PANEL := preload("res://core/codex_panel.tscn")


func before_test() -> void:
	super.before_test()
	var plate := _item("__test_plate", "Test Plate", 75)
	var ingot := _item("__test_ingot", "Test Ingot", 20)
	ingot.merge_results.append(_merge(plate))
	var ore := _item("__test_ore", "Test Ore", 5)
	ore.merge_results.append(_merge(ingot))
	var entry := WeightedItem.new()
	entry.item = ore
	var crate := CrateDefinition.new()
	crate.id = "__test_crate"
	crate.pool = [entry]
	set_definition(DefinitionLibrary.crates, crate)
	var rules: ShopRulesDefinition = DefinitionLibrary.get_shop_rules().duplicate()
	rules.codex_family_points = 5
	set_definition(DefinitionLibrary.shop_rules, rules)


func test_an_item_not_made_yet_is_a_nameless_silhouette() -> void:
	var entry := _entry(_panel(), "__test_plate")
	assert_str(entry.get_node("%NameLabel").text).is_equal("???")
	assert_that(entry.get_node("%Icon").modulate).is_equal(Color.BLACK)
	assert_bool(entry.get_node("%Stars").visible).is_false()


func test_a_made_item_shows_its_name_and_a_star_per_quality() -> void:
	GameManager.record_crafted("__test_plate", 1)
	var entry := _entry(_panel(), "__test_plate")
	assert_str(entry.get_node("%NameLabel").text).is_equal("Test Plate")
	assert_that(entry.get_node("%Icon").modulate).is_equal(Color.WHITE)
	assert_int(entry.get_node("%Stars").quality).is_equal(2)


func test_a_family_header_counts_what_is_made() -> void:
	GameManager.record_crafted("__test_ingot", 0)
	var section := _section(_panel(), "testgems")
	assert_str(section.get_node("%FamilyLabel").text).is_equal("Testgems · 1/2 made")
	assert_bool(section.get_node("%StatusLabel").visible).is_false()


func test_a_complete_family_says_what_it_adds_at_the_next_charter() -> void:
	GameManager.record_crafted("__test_ingot", 0)
	GameManager.record_crafted("__test_plate", 0)
	var section := _section(_panel(), "testgems")
	assert_str(section.get_node("%StatusLabel").text).is_equal("Complete: +5 charter points at your next charter")


func test_a_family_already_paid_for_just_says_complete() -> void:
	GameManager.record_crafted("__test_ingot", 0)
	GameManager.record_crafted("__test_plate", 0)
	GameManager.codex_families_credited.assign(["testgems"])
	var section := _section(_panel(), "testgems")
	assert_str(section.get_node("%StatusLabel").text).is_equal("Complete")


func _panel() -> VBoxContainer:
	var panel: VBoxContainer = auto_free(PANEL.instantiate())
	add_child(panel)
	panel.setup()
	return panel


func _section(panel: VBoxContainer, family: String) -> VBoxContainer:
	for child in panel.get_children():
		if child.family == family:
			return child
	return null


func _entry(panel: VBoxContainer, item_id: String) -> VBoxContainer:
	for entry in _section(panel, "testgems").get_node("%Grid").get_children():
		if entry.item_id == item_id:
			return entry
	return null


func _item(id: String, item_name: String, gold: int) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = id
	item.name = item_name
	item.family = "testgems"
	item.gold_value = gold
	item.sprite = PlaceholderTexture2D.new()
	set_definition(DefinitionLibrary.items, item)
	return item


func _merge(result: ItemDefinition) -> MergeResult:
	var option := MergeResult.new()
	option.result = result
	return option
