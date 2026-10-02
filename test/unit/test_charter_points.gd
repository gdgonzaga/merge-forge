extends TestBase

# Charter points: ShopRulesDefinition's formula, what GameManager says a
# charter would earn now, which towns are open, and what perk picks cost.


func test_no_points_below_the_charter_level() -> void:
	assert_int(_formula_rules().charter_points(39, 20, 1)).is_equal(0)


func test_points_at_the_charter_level_are_the_base() -> void:
	assert_int(_formula_rules().charter_points(40, 0, 0)).is_equal(10)


func test_points_add_levels_past_the_charter_stars_and_families() -> void:
	# 10 + floor(3 x 1.5 = 4.5) = 14, + 7 stars = 21, + 2 families x 5 = 31.
	assert_int(_formula_rules().charter_points(43, 7, 2)).is_equal(31)


func test_a_charter_opens_at_the_charter_level() -> void:
	set_definition(DefinitionLibrary.shop_rules, _level_rules())
	GameManager.shop_xp = 299  # level 2
	assert_bool(GameManager.can_found_charter()).is_false()
	assert_int(GameManager.get_charter_points_earned()).is_equal(0)
	GameManager.shop_xp = 300  # level 3
	assert_bool(GameManager.can_found_charter()).is_true()


func test_a_charter_earns_only_stars_not_yet_paid_for() -> void:
	set_definition(DefinitionLibrary.shop_rules, _level_rules())
	GameManager.shop_xp = 300
	GameManager.codex = {"__a": 0, "__b": 2}
	GameManager.codex_stars_credited = 1
	# 4 stars, 1 already paid: 3 new. Base 10 + 0 levels past + 3.
	assert_int(GameManager.get_new_codex_stars()).is_equal(3)
	assert_int(GameManager.get_charter_points_earned()).is_equal(13)


func test_a_completed_family_pays_once() -> void:
	set_definition(DefinitionLibrary.shop_rules, _level_rules())
	GameManager.shop_xp = 300
	_family_of_two()
	GameManager.record_crafted("__test_ingot", 0)
	GameManager.record_crafted("__test_plate", 0)
	assert_array(GameManager.get_new_codex_families()).is_equal(["__test_fam"])
	# Base 10 + 2 stars + 1 family x 5.
	assert_int(GameManager.get_charter_points_earned()).is_equal(17)
	GameManager.codex_families_credited.assign(["__test_fam"])
	assert_array(GameManager.get_new_codex_families()).is_empty()
	assert_int(GameManager.get_charter_points_earned()).is_equal(12)


func test_a_town_opens_with_the_charter_that_reaches_its_count() -> void:
	var near := TownDefinition.new()
	near.charters_required = 1
	var far := TownDefinition.new()
	far.charters_required = 2
	assert_bool(GameManager.is_town_open(near)).is_true()
	assert_bool(GameManager.is_town_open(far)).is_false()
	GameManager.charters = 1
	assert_bool(GameManager.is_town_open(far)).is_true()


func test_picks_cost_each_next_level_in_order() -> void:
	set_definition(DefinitionLibrary.perks, _perk("__test_perk", [2, 5, 9]))
	GameManager.perk_levels = {"__test_perk": 1}
	assert_int(GameManager.perk_purchase_cost(["__test_perk", "__test_perk"] as Array[String])).is_equal(14)


func test_a_pick_past_the_max_level_is_invalid() -> void:
	set_definition(DefinitionLibrary.perks, _perk("__test_perk", [2, 5]))
	GameManager.perk_levels = {"__test_perk": 1}
	assert_int(GameManager.perk_purchase_cost(["__test_perk", "__test_perk"] as Array[String])).is_equal(-1)


func test_an_unknown_perk_is_an_invalid_pick() -> void:
	assert_int(GameManager.perk_purchase_cost(["__missing_perk"] as Array[String])).is_equal(-1)


func test_no_picks_cost_nothing() -> void:
	var none: Array[String] = []
	assert_int(GameManager.perk_purchase_cost(none)).is_equal(0)


# charter_level 40, base 10, 1.5 per level past, 5 per family.
func _formula_rules() -> ShopRulesDefinition:
	var rules := ShopRulesDefinition.new()
	rules.charter_level = 40
	rules.charter_base_points = 10
	rules.charter_points_per_level = 1.5
	rules.codex_family_points = 5
	return rules


# Levels 2-5 start at 100, 300, 600 and 1000 XP; charters open at level 3.
func _level_rules() -> ShopRulesDefinition:
	var rules := ShopRulesDefinition.new()
	rules.id = "default"
	rules.level_xp_base = 100
	rules.level_xp_exponent = 1.0
	rules.max_level = 5
	rules.charter_level = 3
	rules.charter_base_points = 10
	rules.charter_points_per_level = 1.0
	rules.codex_family_points = 5
	return rules


# A test-town crate sells ore; ore merges to an ingot, the ingot to a plate.
func _family_of_two() -> void:
	var plate := _item("__test_plate")
	var ingot := _item("__test_ingot")
	var to_plate := MergeResult.new()
	to_plate.result = plate
	ingot.merge_results = [to_plate]
	var ore := _item("__test_ore")
	var to_ingot := MergeResult.new()
	to_ingot.result = ingot
	ore.merge_results = [to_ingot]
	var entry := WeightedItem.new()
	entry.item = ore
	var crate := CrateDefinition.new()
	crate.id = "__test_crate"
	crate.pool = [entry]
	set_definition(DefinitionLibrary.crates, crate)


func _item(id: String) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = id
	item.family = "__test_fam"
	set_definition(DefinitionLibrary.items, item)
	return item


func _perk(id: String, costs: Array) -> PerkDefinition:
	var perk := PerkDefinition.new()
	perk.id = id
	perk.effect = "loyalty_multiplier"
	for cost: int in costs:
		var level := PerkLevel.new()
		level.cost_points = cost
		level.value = 1.5
		perk.levels.append(level)
	return perk
