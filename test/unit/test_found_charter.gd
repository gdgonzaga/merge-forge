extends TestBase

# GameManager.found_charter: the Guild Charter's hard reset (README decision 3).
# Every save field is kept, set by the charter, or back to its fresh-game
# default. The dirty save below must cover every save field, so a field added
# later has to be listed here and then resets unless it's kept.

# Kept unchanged across a charter.
const KEPT: Array[String] = ["sessions_played", "seen_intro", "codex"]
# Set by the charter itself (checked separately).
const SET_BY_CHARTER: Array[String] = ["current_town", "charters", "charter_points", "perk_levels", "codex_stars_credited", "codex_families_credited", "run_seed"]

var _far: TownDefinition


func before_test() -> void:
	super.before_test()
	set_definition(DefinitionLibrary.shop_rules, _rules())
	set_definition(DefinitionLibrary.perks, _perk("__test_perk", [4, 5]))
	set_definition(DefinitionLibrary.perks, _perk("__test_dear", [999]))
	_far = _town("__test_far", 1)


func test_the_dirty_save_covers_every_save_field() -> void:
	var dirty_keys := _dirty_save().keys()
	dirty_keys.sort()
	var save_keys := GameManager.serialize().keys()
	save_keys.sort()
	assert_array(dirty_keys).is_equal(save_keys)


func test_a_charter_resets_every_field_it_does_not_keep_or_set() -> void:
	var fresh := _fresh_save()
	GameManager.deserialize(_dirty_save())
	assert_bool(GameManager.found_charter(TEST_TOWN_ID)).is_true()
	var after := GameManager.serialize()
	for field: String in after:
		if field in KEPT or field in SET_BY_CHARTER:
			continue
		assert_bool(after[field] == fresh[field]) \
			.override_failure_message("%s is %s after a charter, not the fresh %s" % [field, str(after[field]), str(fresh[field])]).is_true()


func test_a_charter_keeps_what_it_keeps() -> void:
	GameManager.deserialize(_dirty_save())
	GameManager.found_charter(TEST_TOWN_ID)
	assert_int(GameManager.sessions_played).is_equal(9)
	assert_bool(GameManager.seen_intro).is_true()
	assert_dict(GameManager.codex).is_equal({"__crafted": 2})
	assert_dict(GameManager.perk_levels).is_equal({"__test_perk": 1})


func test_a_charter_moves_town_and_banks_its_points() -> void:
	GameManager.deserialize(_dirty_save())
	GameManager.found_charter(TEST_TOWN_ID)
	assert_str(GameManager.current_town).is_equal(TEST_TOWN_ID)
	assert_int(GameManager.charters).is_equal(2)
	# Level 5, charter level 3: base 10 + floor(2 x 2.0) = 4, + 2 new stars
	# (Masterwork is 3 stars, 1 already paid), no new family. 7 banked + 16.
	assert_int(GameManager.charter_points).is_equal(23)
	assert_int(GameManager.codex_stars_credited).is_equal(3)
	assert_array(GameManager.codex_families_credited).is_equal(["__credited"])


# The append_array line: a newly completed family both pays and gets marked
# credited, so a later charter doesn't earn it again.
func test_a_completed_family_pays_and_is_credited_once() -> void:
	_family_of_two()
	GameManager.deserialize(_dirty_save())
	GameManager.record_crafted("__test_ingot", 0)
	GameManager.record_crafted("__test_plate", 0)
	# Level 5, charter level 3: base 10 + floor(2 x 2.0) = 14. Codex stars:
	# __crafted (quality 2, 3 stars, 1 already credited) plus the new family's
	# ingot and plate (quality 0, 1 star each) = 5 stars, 1 already credited:
	# 4 new. One newly completed family, __test_fam: +5. 7 banked + 14 + 4 + 5 = 30.
	assert_bool(GameManager.found_charter(TEST_TOWN_ID)).is_true()
	assert_int(GameManager.charter_points).is_equal(30)
	assert_array(GameManager.codex_families_credited).is_equal(["__credited", "__test_fam"])
	# Paid once: a second charter earns nothing more for the same family.
	assert_array(GameManager.get_new_codex_families()).is_empty()


# Spec review focus 3: re-founding in the same town must not replay its sessions.
func test_refounding_the_same_town_rolls_a_new_seed() -> void:
	GameManager.deserialize(_dirty_save())
	var old_session_seed := GameManager.get_session_seed()
	assert_bool(GameManager.found_charter("__test_far")).is_true()
	assert_str(GameManager.current_town).is_equal("__test_far")
	assert_int(GameManager.run_seed).is_not_equal(12345)
	assert_int(GameManager.get_session_seed()).is_not_equal(old_session_seed)


func test_no_charter_below_the_charter_level() -> void:
	var dirty := _dirty_save()
	dirty["shop_xp"] = 299  # level 2
	GameManager.deserialize(dirty)
	var before := GameManager.serialize().duplicate(true)
	assert_bool(GameManager.found_charter(TEST_TOWN_ID)).is_false()
	assert_dict(GameManager.serialize()).is_equal(before)


func test_a_town_opens_only_with_enough_charters() -> void:
	_town("__test_farther", 3)
	_town("__test_next", 2)
	GameManager.deserialize(_dirty_save())
	var before := GameManager.serialize().duplicate(true)
	assert_bool(GameManager.found_charter("__test_farther")).is_false()
	assert_bool(GameManager.found_charter("__missing_town")).is_false()
	assert_dict(GameManager.serialize()).is_equal(before)
	# The dirty save has 1 charter, so a town needing 2 opens with this one.
	assert_bool(GameManager.found_charter("__test_next")).is_true()


func test_picked_perks_are_bought_with_the_points() -> void:
	GameManager.deserialize(_dirty_save())
	# Level 2 of __test_perk costs 5 of the 23 points.
	assert_bool(GameManager.found_charter(TEST_TOWN_ID, ["__test_perk"] as Array[String])).is_true()
	assert_int(GameManager.charter_points).is_equal(18)
	assert_dict(GameManager.perk_levels).is_equal({"__test_perk": 2})


func test_picks_past_the_max_or_over_the_budget_change_nothing() -> void:
	GameManager.deserialize(_dirty_save())
	var before := GameManager.serialize().duplicate(true)
	assert_bool(GameManager.found_charter(TEST_TOWN_ID, ["__test_perk", "__test_perk"] as Array[String])).is_false()
	assert_bool(GameManager.found_charter(TEST_TOWN_ID, ["__test_dear"] as Array[String])).is_false()
	assert_dict(GameManager.serialize()).is_equal(before)


# Spec review focus 1: nothing cached from the old town survives.
func test_the_next_session_is_planned_in_the_new_town() -> void:
	var item := ItemDefinition.new()
	item.id = "__test_far_item"
	set_definition(DefinitionLibrary.items, item)
	var entry := WeightedItem.new()
	entry.item = item
	var crate := CrateDefinition.new()
	crate.id = "__test_far_crate"
	crate.pool = [entry]
	_move_to_far("crates", crate)
	var want := OrderTemplate.new()
	want.item = item
	var local := CustomerDefinition.new()
	local.id = "__test_far_customer"
	local.wants = [want]
	_move_to_far("customers", local)
	GameManager.deserialize(_dirty_save())
	GameManager.current_town = TEST_TOWN_ID
	assert_array(SessionPlanner.plan_next_session().customers).is_empty()
	GameManager.found_charter("__test_far")
	var customers := SessionPlanner.plan_next_session().customers
	assert_array(customers).is_not_empty()
	for customer in customers:
		assert_object(customer.definition).is_same(local)


# Every save field set away from its default. Level 5 (1000 XP), 1 charter.
func _dirty_save() -> Dictionary:
	return {
		"version": GameManager.SAVE_VERSION,
		"gold": 999,
		"shop_xp": 1000,
		"unlocked_blueprints": ["__bp"],
		"reagent_inventory": {"__reagent": 2},
		"upgrade_levels": {"__upgrade": 1},
		"shop_board_state": [{"col": 0, "row": 0, "item_id": "__x", "quality": 1}],
		"shop_shelf_state": [{"col": 0, "row": 0, "item_id": "__y", "quality": 0}],
		"dungeon_board_state": [{"col": 1, "row": 1, "item_id": "__z", "quality": 2}],
		"grid_cols": 6,
		"grid_rows": 7,
		"run_seed": 12345,
		"sessions_played": 9,
		"regular_loyalty": {"__regular": 4},
		"active_contracts": [{"id": "__contract", "delivered": {"__x": 1}, "sessions_left": 2}],
		"seen_intro": true,
		"current_town": "__test_far",
		"charters": 1,
		"charter_points": 7,
		"perk_levels": {"__test_perk": 1},
		"codex": {"__crafted": 2},
		"codex_stars_credited": 1,
		"codex_families_credited": ["__credited"],
	}


func _fresh_save() -> Dictionary:
	GameManager.deserialize({})
	var fresh := GameManager.serialize().duplicate(true)
	reset_game_state()
	return fresh


# Levels 2-5 start at 100, 300, 600 and 1000 XP; charters open at level 3.
func _rules() -> ShopRulesDefinition:
	var rules := ShopRulesDefinition.new()
	rules.id = "default"
	rules.starting_town = test_town
	rules.level_xp_base = 100
	rules.level_xp_exponent = 1.0
	rules.max_level = 5
	rules.charter_level = 3
	rules.charter_base_points = 10
	rules.charter_points_per_level = 2.0
	rules.codex_family_points = 5
	return rules


func _town(id: String, charters_required: int) -> TownDefinition:
	var town := TownDefinition.new()
	town.id = id
	town.name = id
	town.charters_required = charters_required
	set_definition(DefinitionLibrary.towns, town)
	return town


# Registers `def` for this test but lists it in the far town, not the test town.
func _move_to_far(folder: String, def: Resource) -> void:
	set_definition(DefinitionLibrary.get_catalogs()[folder], def)
	test_town.content(folder).erase(def)
	_far.content(folder).append(def)


# A test-town crate sells ore; ore merges to an ingot, the ingot to a plate.
# The codex counts ingot and plate (raw ore is left out); both crafted
# completes the family. Mirrors test_charter_points.gd's _family_of_two().
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
	crate.id = "__test_family_crate"
	crate.pool = [entry]
	set_definition(DefinitionLibrary.crates, crate)


func _item(id: String) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = id
	item.family = "__test_fam"
	set_definition(DefinitionLibrary.items, item)
	return item


# A perk whose effect changes nothing a charter resets.
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
