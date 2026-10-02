extends TestBase

# Each Guild perk's effect: multipliers read from GameManager, and the starting
# perks a charter applies to the run it founds.


func test_without_perks_xp_is_added_as_given() -> void:
	assert_int(GameManager.add_shop_xp(40)).is_equal(40)
	assert_int(GameManager.shop_xp).is_equal(40)


func test_an_xp_perk_multiplies_every_gain() -> void:
	_own("__test_xp", "xp_multiplier", 1.5)
	assert_int(GameManager.add_shop_xp(40)).is_equal(60)
	assert_int(GameManager.shop_xp).is_equal(60)


func test_a_loyalty_perk_multiplies_every_gain() -> void:
	_own("__test_loyalty", "loyalty_multiplier", 1.5)
	GameManager.add_loyalty("__regular", 2)
	assert_int(GameManager.get_loyalty("__regular")).is_equal(3)


func test_a_crate_perk_stacks_with_the_crate_upgrade() -> void:
	_own("__test_ties", "crate_discount", 0.9)
	_upgrade("__test_bulk", "crate_discount", 0.8)
	# 0.8 x 0.9.
	assert_float(GameManager.get_crate_discount()).is_equal_approx(0.72, 0.0001)


func test_a_shelf_perk_adds_slots_up_to_the_cap() -> void:
	var rules: ShopRulesDefinition = DefinitionLibrary.get_shop_rules().duplicate()
	rules.max_shelf_slots = 4
	set_definition(DefinitionLibrary.shop_rules, rules)
	_own("__test_shelf_perk", "shelf_bonus", 1.0)
	assert_int(GameManager.get_shelf_slots()).is_equal(1)
	_upgrade("__test_shelf", "shelf_slots", 2.0)
	assert_int(GameManager.get_shelf_slots()).is_equal(3)
	GameManager.upgrade_levels.clear()
	_upgrade("__test_wide_shelf", "shelf_slots", 4.0)
	assert_int(GameManager.get_shelf_slots()).is_equal(4)


func test_a_charter_starts_with_the_stipend() -> void:
	_charter_ready()
	_own("__test_stipend", "starting_gold", 400.0)
	assert_bool(GameManager.found_charter(TEST_TOWN_ID)).is_true()
	assert_int(GameManager.gold).is_equal(400)


func test_a_charter_starts_with_the_towns_cheapest_open_blueprints() -> void:
	_charter_ready()
	var a := _blueprint("__test_bp_a", 100)
	var b := _blueprint("__test_bp_b", 50)
	b.dependencies = [a]
	_blueprint("__test_bp_c", 70)
	_own("__test_plans", "starting_blueprint", 2.0)
	GameManager.found_charter(TEST_TOWN_ID)
	# B is cheapest but needs A; C (70) comes first, then A (100).
	assert_array(GameManager.unlocked_blueprints).is_equal(["__test_bp_c", "__test_bp_a"])


func test_starting_blueprints_stop_when_the_town_runs_out() -> void:
	_charter_ready()
	_blueprint("__test_bp_only", 10)
	_own("__test_plans", "starting_blueprint", 3.0)
	GameManager.found_charter(TEST_TOWN_ID)
	assert_array(GameManager.unlocked_blueprints).is_equal(["__test_bp_only"])


# Owns level 1 of a one-level perk with this effect and value.
func _own(id: String, effect: String, value: float) -> void:
	var perk := PerkDefinition.new()
	perk.id = id
	perk.effect = effect
	var level := PerkLevel.new()
	level.cost_points = 1
	level.value = value
	perk.levels = [level]
	set_definition(DefinitionLibrary.perks, perk)
	GameManager.perk_levels[id] = 1


func _upgrade(id: String, effect: String, value: float) -> void:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = id
	upgrade.effect = effect
	var level := UpgradeLevel.new()
	level.value = value
	upgrade.levels = [level]
	set_definition(DefinitionLibrary.upgrades, upgrade)
	GameManager.raise_upgrade_level(id)


func _blueprint(id: String, cost: int) -> BlueprintDefinition:
	var blueprint := BlueprintDefinition.new()
	blueprint.id = id
	blueprint.cost = cost
	set_definition(DefinitionLibrary.blueprints, blueprint)
	return blueprint


# Level 3 of a 3-level curve with charters at level 3.
func _charter_ready() -> void:
	var rules := ShopRulesDefinition.new()
	rules.id = "default"
	rules.starting_town = test_town
	rules.level_xp_base = 100
	rules.level_xp_exponent = 1.0
	rules.max_level = 3
	rules.charter_level = 3
	set_definition(DefinitionLibrary.shop_rules, rules)
	GameManager.shop_xp = 300
