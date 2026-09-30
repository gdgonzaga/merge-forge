extends TestBase

# SessionPlanner deals the next shop session from GameManager's state. The
# forecast relies on it being a pure function of that state.


func test_planning_twice_gives_the_same_session() -> void:
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
	for contract: ContractDefinition in DefinitionLibrary.contracts.values().duplicate():
		var moved: ContractDefinition = contract.duplicate()
		moved.min_shop_level = 9999
		set_definition(DefinitionLibrary.contracts, moved)
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
