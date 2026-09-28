extends TestBase

# The customer generator deals a session from archetype fixtures. Craftability
# is injected, so these tests don't depend on crates or blueprints.

const GENERATOR := preload("res://autoloads/customer_generator.gd")

var _generator: RefCounted
var _ingot: ItemDefinition
var _sword: ItemDefinition


func before_test() -> void:
	super.before_test()
	_generator = GENERATOR.new()
	_ingot = _item("__test_ingot", 20)
	_sword = _item("__test_sword", 280)


func test_same_seed_deals_the_same_session() -> void:
	var archetypes: Array[CustomerDefinition] = [
		_archetype("__a", 1, [_want(_ingot, 1, 1, 3)], 1, 2),
		_archetype("__b", 1, [_want(_ingot, 1, 1, 3), _want(_sword, 1, 1, 1)], 1, 2),
	]
	var first: Array[ShopCustomer] = _generator.generate(archetypes, 10, 1, 42, _all_craftable)
	var second: Array[ShopCustomer] = _generator.generate(archetypes, 10, 1, 42, _all_craftable)
	assert_array(_describe(first)).is_equal(_describe(second))


func test_deals_the_requested_count() -> void:
	var archetypes: Array[CustomerDefinition] = [_archetype("__a", 1, [_want(_ingot, 1, 1, 1)], 1, 1)]
	assert_int(_generator.generate(archetypes, 10, 1, 1, _all_craftable).size()).is_equal(10)


func test_locked_archetype_is_dealt_only_from_its_level() -> void:
	var archetypes: Array[CustomerDefinition] = [
		_archetype("__open", 1, [_want(_ingot, 1, 1, 1)], 1, 1),
		_archetype("__locked", 5, [_want(_ingot, 1, 1, 1)], 1, 1),
	]
	assert_bool("__locked" in _ids(_generator.generate(archetypes, 10, 4, 1, _all_craftable))).is_false()
	# With two archetypes and no immediate repeats, 10 customers must include both.
	assert_bool("__locked" in _ids(_generator.generate(archetypes, 10, 5, 1, _all_craftable))).is_true()


func test_archetype_wanting_nothing_craftable_is_never_dealt() -> void:
	var archetypes: Array[CustomerDefinition] = [
		_archetype("__smith", 1, [_want(_ingot, 1, 1, 1)], 1, 1),
		_archetype("__knight", 1, [_want(_sword, 1, 1, 1)], 1, 1),
	]
	assert_array(_ids(_generator.generate(archetypes, 10, 1, 1, _only_ingot))).not_contains(["__knight"])


func test_no_eligible_archetype_deals_nobody() -> void:
	var archetypes: Array[CustomerDefinition] = [_archetype("__locked", 10, [_want(_ingot, 1, 1, 1)], 1, 1)]
	assert_int(_generator.generate(archetypes, 10, 1, 1, _all_craftable).size()).is_equal(0)


func test_first_order_is_craftable_and_later_ones_may_not_be() -> void:
	# The sword is 100x likelier, but only the ingot is craftable, so it must lead.
	var archetypes: Array[CustomerDefinition] = [
		_archetype("__a", 1, [_want(_sword, 100, 1, 1), _want(_ingot, 1, 1, 1)], 2, 2),
	]
	for customer in _generator.generate(archetypes, 10, 1, 7, _only_ingot):
		assert_int(customer.orders.size()).is_equal(2)
		assert_object(customer.orders[0].item).is_same(_ingot)
		assert_object(customer.orders[1].item).is_same(_sword)


func test_order_count_stays_in_bounds_without_repeating_an_item() -> void:
	var archetypes: Array[CustomerDefinition] = [
		_archetype("__a", 1, [_want(_ingot, 1, 1, 1), _want(_sword, 1, 1, 1), _want(_item("__test_herb", 5), 1, 1, 1)], 1, 3),
	]
	for customer in _generator.generate(archetypes, 30, 1, 3, _all_craftable):
		assert_int(customer.orders.size()).is_between(1, 3)
		var items := {}
		for order in customer.orders:
			assert_bool(items.has(order.item.id)).is_false()
			items[order.item.id] = true


func test_never_repeats_an_item_from_two_templates_wanting_it() -> void:
	var archetypes: Array[CustomerDefinition] = [
		_archetype("__a", 1, [_want(_ingot, 1, 1, 1), _want(_sword, 1, 1, 1), _want(_sword, 1, 1, 1), _want(_item("__test_herb", 5), 1, 1, 1)], 1, 4),
	]
	for customer in _generator.generate(archetypes, 30, 1, 3, _all_craftable):
		var items := {}
		for order in customer.orders:
			assert_bool(items.has(order.item.id)).is_false()
			items[order.item.id] = true


func test_no_customer_follows_itself_when_another_is_available() -> void:
	var archetypes: Array[CustomerDefinition] = [
		_archetype("__a", 1, [_want(_ingot, 1, 1, 1)], 1, 1),
		_archetype("__b", 1, [_want(_ingot, 1, 1, 1)], 1, 1),
	]
	var ids := _ids(_generator.generate(archetypes, 10, 1, 5, _all_craftable))
	for i in range(1, ids.size()):
		assert_str(ids[i]).is_not_equal(ids[i - 1])


func test_weight_sets_how_often_an_archetype_is_dealt() -> void:
	var heavy := _archetype("__heavy", 1, [_want(_ingot, 1, 1, 1)], 1, 1)
	heavy.weight = 18
	var archetypes: Array[CustomerDefinition] = [
		heavy,
		_archetype("__b", 1, [_want(_ingot, 1, 1, 1)], 1, 1),
		_archetype("__c", 1, [_want(_ingot, 1, 1, 1)], 1, 1),
	]
	var ids := _ids(_generator.generate(archetypes, 100, 1, 11, _all_craftable))
	# Expected about 45 heavy (it follows every b/c with 18/19 odds); a deck would give 34.
	assert_int(ids.count("__heavy")).is_greater(40)


func test_single_archetype_is_dealt_every_time() -> void:
	var archetypes: Array[CustomerDefinition] = [_archetype("__a", 1, [_want(_ingot, 1, 1, 1)], 1, 1)]
	assert_array(_ids(_generator.generate(archetypes, 3, 1, 1, _all_craftable))).is_equal(["__a", "__a", "__a"])


func test_order_price_is_value_times_quantity_times_multiplier() -> void:
	var archetype := _archetype("__a", 1, [_want(_ingot, 1, 2, 2)], 1, 1)
	archetype.price_multiplier = 1.5
	var archetypes: Array[CustomerDefinition] = [archetype]
	# 20 gold x 2 x 1.5
	assert_int(_generator.generate(archetypes, 1, 1, 1, _all_craftable)[0].orders[0].gold_reward).is_equal(60)


func test_order_price_multiplier_scales_every_order() -> void:
	var archetype := _archetype("__a", 1, [_want(_ingot, 1, 2, 2)], 1, 1)
	archetype.price_multiplier = 1.5
	var archetypes: Array[CustomerDefinition] = [archetype]
	# 20 gold x 2 x 1.5 x 1.1 = 66
	assert_int(_generator.generate(archetypes, 1, 1, 1, _all_craftable, null, 1.1)[0].orders[0].gold_reward).is_equal(66)


func test_pick_weighted_never_picks_a_zero_weight() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var weights: Array[int] = [0, 5]
	for _i in range(50):
		assert_int(GENERATOR.pick_weighted(weights, rng)).is_equal(1)


func test_pick_weighted_with_all_zero_weights_stays_in_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var weights: Array[int] = [0, 0, 0]
	for _i in range(50):
		assert_int(GENERATOR.pick_weighted(weights, rng)).is_between(0, 2)


func _all_craftable(_item_def: ItemDefinition) -> bool:
	return true


func _only_ingot(item_def: ItemDefinition) -> bool:
	return item_def == _ingot


func _item(id: String, value: int) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = id
	item.gold_value = value
	return item


func _want(item: ItemDefinition, weight: int, min_quantity: int, max_quantity: int) -> OrderTemplate:
	var want := OrderTemplate.new()
	want.item = item
	want.weight = weight
	want.min_quantity = min_quantity
	want.max_quantity = max_quantity
	return want


func _archetype(id: String, min_shop_level: int, wants: Array, min_orders: int, max_orders: int) -> CustomerDefinition:
	var archetype := CustomerDefinition.new()
	archetype.id = id
	archetype.min_shop_level = min_shop_level
	archetype.wants.assign(wants)
	archetype.min_orders = min_orders
	archetype.max_orders = max_orders
	return archetype


func _ids(customers: Array[ShopCustomer]) -> Array[String]:
	var ids: Array[String] = []
	for customer in customers:
		ids.append(customer.definition.id)
	return ids


func _describe(customers: Array[ShopCustomer]) -> Array[String]:
	var lines: Array[String] = []
	for customer in customers:
		for order in customer.orders:
			lines.append("%s:%s:%d:%d" % [customer.definition.id, order.item.id, order.quantity, order.gold_reward])
	return lines
