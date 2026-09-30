extends TestBase

# A regular's loyalty track and a contract's lookups.


func test_a_threshold_is_reached_by_landing_exactly_on_it() -> void:
	var customer := _customer([3, 6])
	assert_array(_points_of(customer.rewards_crossed(2, 3))).is_equal([3])


func test_a_gain_below_a_threshold_reaches_nothing() -> void:
	var customer := _customer([3, 6])
	assert_array(customer.rewards_crossed(0, 2)).is_empty()


func test_one_gain_crossing_two_thresholds_reaches_both() -> void:
	var customer := _customer([3, 6, 9])
	assert_array(_points_of(customer.rewards_crossed(2, 7))).is_equal([3, 6])


func test_a_threshold_already_passed_is_not_reached_again() -> void:
	var customer := _customer([3, 6])
	assert_array(customer.rewards_crossed(3, 5)).is_empty()


func test_the_title_is_the_highest_threshold_reached() -> void:
	var customer := _customer([3, 6])
	assert_str(customer.title_at(2)).is_equal("")
	assert_str(customer.title_at(3)).is_equal("Title 3")
	assert_str(customer.title_at(8)).is_equal("Title 6")


func test_next_threshold_is_the_lowest_above_the_points() -> void:
	var customer := _customer([3, 6])
	assert_int(customer.next_threshold(0)).is_equal(3)
	assert_int(customer.next_threshold(3)).is_equal(6)
	assert_int(customer.next_threshold(6)).is_equal(-1)


func test_a_contract_finds_the_requirement_for_an_item() -> void:
	var ore := _item("__test_ore")
	var plate := _item("__test_plate")
	var contract := ContractDefinition.new()
	contract.requirements = [_requirement(ore, 3), _requirement(plate, 1)]
	assert_int(contract.requirement_for("__test_plate").min_quantity).is_equal(1)
	assert_object(contract.requirement_for("__test_other")).is_null()
	assert_bool(contract.requirement_items()[0] == ore and contract.requirement_items()[1] == plate).is_true()


func test_sessions_left_reads_last_session_at_one() -> void:
	assert_str(ContractDefinition.sessions_left_text(3)).is_equal("3 sessions left")
	assert_str(ContractDefinition.sessions_left_text(1)).is_equal("Last session")


func _customer(thresholds: Array) -> CustomerDefinition:
	var customer := CustomerDefinition.new()
	for points: int in thresholds:
		var reward := LoyaltyReward.new()
		reward.points = points
		reward.title = "Title %d" % points
		customer.loyalty_rewards.append(reward)
	return customer


func _points_of(rewards: Array[LoyaltyReward]) -> Array[int]:
	var points: Array[int] = []
	for reward in rewards:
		points.append(reward.points)
	return points


func _item(id: String) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = id
	return item


func _requirement(item: ItemDefinition, quantity: int) -> OrderTemplate:
	var requirement := OrderTemplate.new()
	requirement.item = item
	requirement.min_quantity = quantity
	requirement.max_quantity = quantity
	return requirement
