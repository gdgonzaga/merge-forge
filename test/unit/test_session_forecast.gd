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


func _describe(plan: SessionPlan) -> Array[String]:
	var lines: Array[String] = ["modifier:%s" % ("" if plan.modifier == null else plan.modifier.id)]
	for customer in plan.customers:
		for order in customer.orders:
			lines.append("%s:%s:%d:%d" % [customer.definition.id, order.item.id, order.quantity, order.gold_reward])
	return lines
