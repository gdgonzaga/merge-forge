extends TestBase

# The prep forecast and the shop session must agree (spec review focus 1):
# the shop deals exactly the plan prep showed.

const PREP := preload("res://core/prep_phase.tscn")
const SHOP := preload("res://shop/shop_session.tscn")


func test_the_session_deals_what_prep_forecast() -> void:
	var plan := _forecast_plan()
	assert_bool(plan.customers.is_empty()).is_false()
	assert_array(_describe(_shop_plan())).is_equal(_describe(plan))


func test_the_session_rolls_the_modifier_prep_forecast() -> void:
	var rules: ShopRulesDefinition = DefinitionLibrary.get_shop_rules().duplicate()
	rules.modifier_chance = 1.0
	set_definition(DefinitionLibrary.shop_rules, rules)
	var fair := SessionModifierDefinition.new()
	fair.id = "__test_fair"
	fair.name = "Test Fair"
	fair.weight = 100000
	fair.family_price_multiplier = 2.0
	set_definition(DefinitionLibrary.modifiers, fair)
	var plan := _forecast_plan()
	assert_object(plan.modifier).is_same(fair)
	assert_array(_describe(_shop_plan())).is_equal(_describe(plan))


func test_a_crate_cost_modifier_reaches_the_shop_board_and_its_button() -> void:
	var rules: ShopRulesDefinition = DefinitionLibrary.get_shop_rules().duplicate()
	rules.modifier_chance = 1.0
	set_definition(DefinitionLibrary.shop_rules, rules)
	var item := ItemDefinition.new()
	item.id = "__test_crate_item"
	item.name = "Test Crate Item"
	set_definition(DefinitionLibrary.items, item)
	var entry := WeightedItem.new()
	entry.item = item
	entry.weight = 1
	var crate := CrateDefinition.new()
	crate.id = "__test_crate"
	crate.name = "Test Crate"
	crate.cost = 40
	crate.min_shop_level = 1
	crate.pool = [entry]
	set_definition(DefinitionLibrary.crates, crate)
	var surge := SessionModifierDefinition.new()
	surge.id = "__test_surge"
	surge.name = "Test Surge"
	surge.weight = 100000
	surge.affected_crates = [crate]
	surge.crate_cost_multiplier = 2.0
	set_definition(DefinitionLibrary.modifiers, surge)

	var shop: Control = auto_free(SHOP.instantiate())
	add_child(shop)

	# 40 x 2.0 x 1.0 (no discount) = 80.
	assert_int(shop.board.get_crate_cost(crate)).is_equal(80)
	var button := _crate_button_named(shop, "Test Crate")
	assert_object(button).is_not_null()
	assert_str(button.text).contains("(80g)")


func test_buying_a_blueprint_in_prep_updates_the_forecast() -> void:
	# A crate sells ore; the blueprint merges 3 ore into a blade; the knight
	# wants only the blade, so he's dealt only once the blueprint is owned.
	var ore := ItemDefinition.new()
	ore.id = "__test_ore"
	ore.name = "Test Ore"
	var blade := ItemDefinition.new()
	blade.id = "__test_blade"
	blade.name = "Test Blade"
	var blueprint := BlueprintDefinition.new()
	blueprint.id = "__test_blade_bp"
	blueprint.name = "Test Blade Blueprint"
	blueprint.cost = 10
	var merge := MergeResult.new()
	merge.result = blade
	merge.blueprint = blueprint
	ore.merge_results = [merge]
	var entry := WeightedItem.new()
	entry.item = ore
	entry.weight = 1
	var crate := CrateDefinition.new()
	crate.id = "__test_crate"
	crate.name = "Test Crate"
	crate.cost = 1
	crate.pool = [entry]
	var want := OrderTemplate.new()
	want.item = blade
	var knight := CustomerDefinition.new()
	knight.id = "__test_knight"
	knight.name = "Test Knight"
	knight.weight = 100000
	knight.wants = [want]
	set_definition(DefinitionLibrary.items, ore)
	set_definition(DefinitionLibrary.items, blade)
	set_definition(DefinitionLibrary.blueprints, blueprint)
	set_definition(DefinitionLibrary.crates, crate)
	set_definition(DefinitionLibrary.customers, knight)
	var prep: Control = auto_free(PREP.instantiate())
	add_child(prep)
	assert_array(_ids(prep.get_forecast_plan())).not_contains(["__test_knight"])
	assert_bool(prep.try_purchase("blueprint", "__test_blade_bp")).is_true()
	assert_array(_ids(prep.get_forecast_plan())).contains(["__test_knight"])
	assert_array(_describe(_shop_plan())).is_equal(_describe(prep.get_forecast_plan()))


func _ids(plan: SessionPlan) -> Array[String]:
	var ids: Array[String] = []
	for customer in plan.customers:
		ids.append(customer.definition.id)
	return ids


func _forecast_plan() -> SessionPlan:
	var prep: Control = PREP.instantiate()
	add_child(prep)
	var plan: SessionPlan = prep.get_forecast_plan()
	prep.free()
	return plan


func _shop_plan() -> SessionPlan:
	var shop: Control = auto_free(SHOP.instantiate())
	add_child(shop)
	return shop.plan


func _crate_button_named(shop: Control, crate_name: String) -> Button:
	for child: Button in shop.get_node("CustomerBox/ActionPanel/CratePanel/CrateButtonsPanel").get_children():
		if child.text.begins_with(crate_name + " ("):
			return child
	return null


func _describe(plan: SessionPlan) -> Array[String]:
	var lines: Array[String] = ["modifier:%s" % ("" if plan.modifier == null else plan.modifier.id)]
	for customer in plan.customers:
		for order in customer.orders:
			lines.append("%s:%s:%d:%d" % [customer.definition.id, order.item.id, order.quantity, order.gold_reward])
	return lines
