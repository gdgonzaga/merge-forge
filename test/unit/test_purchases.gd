extends TestBase

# Prep-phase purchase rules (core/purchases.gd): what each buy charges, grants
# and refuses. Every fixture goes in through set_definition.

const PURCHASES := preload("res://core/purchases.gd")

var _purchases: RefCounted


func before_test() -> void:
	super.before_test()
	_purchases = PURCHASES.new()
	GameManager.gold = 50


func test_blueprint_costs_its_price() -> void:
	set_definition(DefinitionLibrary.blueprints, _blueprint("__test_bp", 30))
	assert_bool(_purchases.buy_blueprint("__test_bp")).is_true()
	assert_int(GameManager.gold).is_equal(20)
	assert_bool(RecipeResolver.has_blueprint("__test_bp")).is_true()


func test_blueprint_refused_while_a_dependency_is_missing() -> void:
	var dep := _blueprint("__test_dep", 10)
	var blueprint := _blueprint("__test_bp", 30)
	blueprint.dependencies = [dep]
	set_definition(DefinitionLibrary.blueprints, dep)
	set_definition(DefinitionLibrary.blueprints, blueprint)
	assert_bool(_purchases.buy_blueprint("__test_bp")).is_false()
	assert_int(GameManager.gold).is_equal(50)
	assert_bool(RecipeResolver.has_blueprint("__test_bp")).is_false()


func test_blueprint_with_its_dependency_owned_is_bought() -> void:
	var dep := _blueprint("__test_dep", 10)
	var blueprint := _blueprint("__test_bp", 30)
	blueprint.dependencies = [dep]
	set_definition(DefinitionLibrary.blueprints, dep)
	set_definition(DefinitionLibrary.blueprints, blueprint)
	GameManager.add_blueprint("__test_dep")
	assert_bool(_purchases.buy_blueprint("__test_bp")).is_true()
	assert_int(GameManager.gold).is_equal(20)


func test_blueprint_refused_when_already_owned() -> void:
	set_definition(DefinitionLibrary.blueprints, _blueprint("__test_bp", 30))
	GameManager.add_blueprint("__test_bp")
	assert_bool(_purchases.buy_blueprint("__test_bp")).is_false()
	assert_int(GameManager.gold).is_equal(50)


func test_blueprint_refused_when_gold_is_short() -> void:
	set_definition(DefinitionLibrary.blueprints, _blueprint("__test_bp", 51))
	assert_bool(_purchases.buy_blueprint("__test_bp")).is_false()
	assert_int(GameManager.gold).is_equal(50)
	assert_bool(RecipeResolver.has_blueprint("__test_bp")).is_false()


func test_blueprint_refused_for_an_unknown_id() -> void:
	assert_bool(_purchases.buy_blueprint("__test_missing")).is_false()
	assert_int(GameManager.gold).is_equal(50)


func test_grid_size_upgrade_grows_the_grid() -> void:
	set_definition(DefinitionLibrary.upgrades, _grid_upgrade("__test_grid", 30, 1, 2))
	GameManager.grid_cols = 5
	GameManager.grid_rows = 5
	var sizes: Array[Vector2i] = []
	var on_size := func(cols: int, rows: int) -> void: sizes.append(Vector2i(cols, rows))
	GameManager.grid_size_changed.connect(on_size)
	var bought: bool = _purchases.buy_upgrade("__test_grid")
	GameManager.grid_size_changed.disconnect(on_size)
	assert_bool(bought).is_true()
	assert_int(GameManager.gold).is_equal(20)
	assert_int(GameManager.grid_cols).is_equal(6)
	assert_int(GameManager.grid_rows).is_equal(7)
	assert_array(sizes).is_equal([Vector2i(6, 7)])


func test_upgrade_second_purchase_is_refused() -> void:
	set_definition(DefinitionLibrary.upgrades, _grid_upgrade("__test_grid", 20, 1, 1))
	GameManager.grid_cols = 5
	GameManager.grid_rows = 5
	assert_bool(_purchases.buy_upgrade("__test_grid")).is_true()
	assert_bool(_purchases.buy_upgrade("__test_grid")).is_false()
	assert_int(GameManager.gold).is_equal(30)
	assert_int(GameManager.grid_cols).is_equal(6)
	assert_array(GameManager.purchased_upgrades).is_equal(["__test_grid"])


func test_blueprint_refused_below_its_level() -> void:
	set_definition(DefinitionLibrary.shop_rules, _level_rules())
	var blueprint := _blueprint("__test_bp", 30)
	blueprint.min_shop_level = 3
	set_definition(DefinitionLibrary.blueprints, blueprint)
	GameManager.shop_xp = 299  # level 2
	assert_bool(_purchases.buy_blueprint("__test_bp")).is_false()
	assert_int(GameManager.gold).is_equal(50)
	GameManager.shop_xp = 300  # level 3
	assert_bool(_purchases.buy_blueprint("__test_bp")).is_true()
	assert_int(GameManager.gold).is_equal(20)


func test_reagent_refused_below_its_level() -> void:
	set_definition(DefinitionLibrary.shop_rules, _level_rules())
	var reagent := ReagentDefinition.new()
	reagent.id = "__test_reagent"
	reagent.cost = 15
	reagent.min_shop_level = 2
	set_definition(DefinitionLibrary.reagents, reagent)
	assert_bool(_purchases.buy_reagent("__test_reagent")).is_false()
	assert_int(GameManager.gold).is_equal(50)
	assert_int(GameManager.reagent_inventory.get("__test_reagent", 0)).is_equal(0)


func test_reagent_adds_one_and_charges_its_cost() -> void:
	var reagent := ReagentDefinition.new()
	reagent.id = "__test_reagent"
	reagent.cost = 15
	set_definition(DefinitionLibrary.reagents, reagent)
	assert_bool(_purchases.buy_reagent("__test_reagent")).is_true()
	assert_int(GameManager.gold).is_equal(35)
	assert_int(GameManager.reagent_inventory.get("__test_reagent", 0)).is_equal(1)


func _level_rules() -> ShopRulesDefinition:
	var rules := ShopRulesDefinition.new()
	rules.id = "default"
	rules.level_xp_base = 100
	rules.level_xp_exponent = 1.0
	rules.max_level = 5
	return rules


func _blueprint(id: String, cost: int) -> BlueprintDefinition:
	var blueprint := BlueprintDefinition.new()
	blueprint.id = id
	blueprint.cost = cost
	return blueprint


func _grid_upgrade(id: String, cost: int, cols: int, rows: int) -> UpgradeDefinition:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = id
	upgrade.cost = cost
	upgrade.effect = "grid_size"
	upgrade.grid_cols = cols
	upgrade.grid_rows = rows
	return upgrade
