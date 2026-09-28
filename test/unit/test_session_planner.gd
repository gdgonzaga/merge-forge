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
