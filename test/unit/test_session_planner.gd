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
