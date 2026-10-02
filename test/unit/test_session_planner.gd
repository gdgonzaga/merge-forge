extends TestBase

# SessionPlanner deals the next shop session from GameManager's state. The
# forecast relies on it being a pure function of that state.


func test_planning_twice_gives_the_same_session() -> void:
	set_definition(DefinitionLibrary.customers, _wanting("__test_local", _sold_item("__test_town_item"), 1))
	var first := _describe(SessionPlanner.plan_next_session())
	var second := _describe(SessionPlanner.plan_next_session())
	assert_array(first).is_not_empty()
	assert_array(second).is_equal(first)


func _describe(plan: SessionPlan) -> Array[String]:
	var lines: Array[String] = []
	for customer in plan.customers:
		for order in customer.orders:
			lines.append("%s:%s:%d:%d" % [customer.definition.id, order.item.id, order.quantity, order.gold_reward])
	return lines


func test_family_demand_is_the_share_of_orders_largest_first() -> void:
	var herb := ItemDefinition.new()
	herb.id = "__test_herb"
	herb.family = "herb"
	var ore := ItemDefinition.new()
	ore.id = "__test_ore"
	ore.family = "metal"
	var plan := SessionPlan.new().setup([_customer([herb, ore]), _customer([herb]), _customer([herb])], null)
	var demand := plan.family_demand()
	assert_int(demand.size()).is_equal(2)
	assert_str(demand[0]["family"]).is_equal("herb")
	assert_float(demand[0]["share"]).is_equal_approx(0.75, 0.0001)
	assert_str(demand[1]["family"]).is_equal("metal")
	assert_float(demand[1]["share"]).is_equal_approx(0.25, 0.0001)


func test_family_demand_of_an_empty_plan_is_empty() -> void:
	var none: Array[ShopCustomer] = []
	assert_array(SessionPlan.new().setup(none, null).family_demand()).is_empty()


func _customer(items: Array) -> ShopCustomer:
	var orders: Array[OrderDefinition] = []
	for item: ItemDefinition in items:
		var order := OrderDefinition.new()
		order.item = item
		order.quantity = 1
		orders.append(order)
	return ShopCustomer.new().setup(CustomerDefinition.new(), orders)


# Accepting in prep leaves the visible offer unchanged. A session tick removes
# it from later offers while it remains active.
func test_an_accepted_contract_stays_on_offer_until_a_session_has_passed() -> void:
	var contract := _reachable_contract()
	GameManager.active_contracts = [{"id": "__test_contract", "delivered": {}, "sessions_left": 3}]
	assert_bool(contract in SessionPlanner.plan_next_session().contract_offers).is_true()
	GameManager.active_contracts[0]["sessions_left"] = 2
	assert_bool(contract in SessionPlanner.plan_next_session().contract_offers).is_false()


func test_planning_twice_offers_the_same_contracts() -> void:
	var contract := _reachable_contract()
	assert_bool(contract in SessionPlanner.plan_next_session().contract_offers).is_true()
	assert_bool(contract in SessionPlanner.plan_next_session().contract_offers).is_true()


func _reachable_contract() -> ContractDefinition:
	var item := ItemDefinition.new()
	item.id = "__test_contract_item"
	set_definition(DefinitionLibrary.items, item)
	var entry := WeightedItem.new()
	entry.item = item
	var crate := CrateDefinition.new()
	crate.id = "__test_contract_crate"
	crate.pool = [entry]
	set_definition(DefinitionLibrary.crates, crate)
	var requirement := OrderTemplate.new()
	requirement.item = item
	var contract := ContractDefinition.new()
	contract.id = "__test_contract"
	contract.giver = CustomerDefinition.new()
	contract.requirements = [requirement]
	contract.sessions_allowed = 3
	set_definition(DefinitionLibrary.contracts, contract)
	return contract


# --- towns ---

func test_the_plan_deals_only_the_current_towns_customers() -> void:
	var item := _sold_item("__test_town_item")
	set_definition(DefinitionLibrary.customers, _wanting("__test_local", item, 1))
	var elsewhere := _wanting("__test_elsewhere", item, 100000)
	set_definition(DefinitionLibrary.customers, elsewhere)
	test_town.customers.erase(elsewhere)
	var ids := {}
	for customer in SessionPlanner.plan_next_session().customers:
		ids[customer.definition.id] = true
	assert_array(ids.keys()).is_equal(["__test_local"])


func test_the_towns_price_multiplier_scales_every_order() -> void:
	var item := _sold_item("__test_town_item")
	item.gold_value = 10
	set_definition(DefinitionLibrary.customers, _wanting("__test_local", item, 1))
	test_town.price_multiplier = 2.0
	# 10 gold x 1 item x the town's 2.0; no upgrade, modifier or quality applies.
	assert_int(SessionPlanner.plan_next_session().customers[0].orders[0].gold_reward).is_equal(20)


func test_a_modifier_outside_the_town_never_rolls() -> void:
	var rules: ShopRulesDefinition = DefinitionLibrary.get_shop_rules().duplicate()
	rules.modifier_chance = 1.0
	set_definition(DefinitionLibrary.shop_rules, rules)
	var fair := SessionModifierDefinition.new()
	fair.id = "__test_fair"
	set_definition(DefinitionLibrary.modifiers, fair)
	test_town.modifiers.erase(fair)
	assert_object(SessionPlanner.plan_next_session().modifier).is_null()


func test_a_contract_outside_the_town_is_never_offered() -> void:
	var contract := _reachable_contract()
	test_town.contracts.erase(contract)
	assert_bool(contract in SessionPlanner.plan_next_session().contract_offers).is_false()


# An item a test-town crate sells.
func _sold_item(id: String) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = id
	set_definition(DefinitionLibrary.items, item)
	var entry := WeightedItem.new()
	entry.item = item
	var crate := CrateDefinition.new()
	crate.id = id + "_crate"
	crate.pool = [entry]
	set_definition(DefinitionLibrary.crates, crate)
	return item


func _wanting(id: String, item: ItemDefinition, weight: int) -> CustomerDefinition:
	var want := OrderTemplate.new()
	want.item = item
	var customer := CustomerDefinition.new()
	customer.id = id
	customer.weight = weight
	customer.wants = [want]
	return customer
