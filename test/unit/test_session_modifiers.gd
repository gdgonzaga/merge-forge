extends TestBase

# Market modifiers: which one a session rolls, and (Task 3) what it changes.
# Everything is injected into the generator, so no shipped content is read.

const GENERATOR := preload("res://autoloads/customer_generator.gd")

var _generator: RefCounted
var _ingot: ItemDefinition


func before_test() -> void:
	super.before_test()
	_generator = GENERATOR.new()
	_ingot = _item("__test_ingot", 20, "metal")


func test_zero_chance_never_rolls_a_modifier() -> void:
	var modifiers: Array[SessionModifierDefinition] = [_modifier("__m", 1)]
	for session_seed in range(20):
		assert_object(_generator.roll_modifier(modifiers, 0.0, 1, session_seed)).is_null()


func test_full_chance_always_rolls_a_modifier() -> void:
	var modifiers: Array[SessionModifierDefinition] = [_modifier("__m", 1)]
	for session_seed in range(20):
		assert_object(_generator.roll_modifier(modifiers, 1.0, 1, session_seed)).is_same(modifiers[0])


func test_a_modifier_above_the_level_is_never_rolled() -> void:
	var open := _modifier("__open", 1)
	var locked := _modifier("__locked", 5)
	var modifiers: Array[SessionModifierDefinition] = [open, locked]
	for session_seed in range(20):
		assert_object(_generator.roll_modifier(modifiers, 1.0, 4, session_seed)).is_same(open)
	var only_locked: Array[SessionModifierDefinition] = [locked]
	assert_object(_generator.roll_modifier(only_locked, 1.0, 4, 3)).is_null()


func test_weight_sets_how_often_a_modifier_is_rolled() -> void:
	var common := _modifier("__common", 1)
	common.weight = 100000
	var modifiers: Array[SessionModifierDefinition] = [common, _modifier("__rare", 1)]
	for session_seed in range(20):
		assert_object(_generator.roll_modifier(modifiers, 1.0, 1, session_seed)).is_same(common)


func test_adding_a_modifier_does_not_change_the_customers_a_seed_deals() -> void:
	var archetypes: Array[CustomerDefinition] = [
		_archetype("__a", [_want(_ingot, 1, 3)]),
		_archetype("__b", [_want(_ingot, 1, 3)]),
	]
	var rules := _rules(1.0)
	var none: Array[SessionModifierDefinition] = []
	var neutral: Array[SessionModifierDefinition] = [_modifier("__neutral", 1)]
	var without: SessionPlan = _generator.plan(archetypes, none, rules, 1, 42, _all_craftable)
	var with_neutral: SessionPlan = _generator.plan(archetypes, neutral, rules, 1, 42, _all_craftable)
	assert_object(without.modifier).is_null()
	assert_object(with_neutral.modifier).is_same(neutral[0])
	assert_array(_describe(with_neutral)).is_equal(_describe(without))


func test_a_boosted_archetype_takes_every_slot_it_can() -> void:
	var boosted := _archetype("__boosted", [_want(_ingot, 1, 1)])
	var archetypes: Array[CustomerDefinition] = [
		boosted,
		_archetype("__b", [_want(_ingot, 1, 1)]),
		_archetype("__c", [_want(_ingot, 1, 1)]),
	]
	var modifier := _modifier("__m", 1)
	modifier.boosted_customers = [boosted]
	modifier.customer_weight_multiplier = 100000.0
	var ids := _ids_of(_generator.generate(archetypes, 20, 1, 7, _all_craftable, modifier))
	# No archetype follows itself, so the boosted one takes every other slot.
	for i in range(0, ids.size(), 2):
		assert_str(ids[i]).is_equal("__boosted")
	for i in range(1, ids.size(), 2):
		assert_str(ids[i]).is_not_equal("__boosted")


func test_boosting_only_a_locked_archetype_still_deals_the_session() -> void:
	var locked := _archetype("__locked", [_want(_ingot, 1, 1)])
	locked.min_shop_level = 5
	var archetypes: Array[CustomerDefinition] = [locked, _archetype("__open", [_want(_ingot, 1, 1)])]
	var modifier := _modifier("__m", 1)
	modifier.boosted_customers = [locked]
	modifier.customer_weight_multiplier = 3.0
	var ids := _ids_of(_generator.generate(archetypes, 10, 1, 7, _all_craftable, modifier))
	assert_int(ids.size()).is_equal(10)
	assert_array(ids).not_contains(["__locked"])


func test_a_family_modifier_scales_only_that_familys_prices() -> void:
	var herb := _item("__test_herb", 10, "herb")
	var archetype := _archetype("__a", [_want(_ingot, 2, 2), _want(herb, 2, 2)])
	archetype.min_orders = 2
	archetype.max_orders = 2
	archetype.price_multiplier = 1.5
	var archetypes: Array[CustomerDefinition] = [archetype]
	var modifier := _modifier("__m", 1)
	modifier.family = "metal"
	modifier.family_price_multiplier = 1.3
	var prices := {}
	for order in _generator.generate(archetypes, 1, 1, 1, _all_craftable, modifier)[0].orders:
		prices[order.item.id] = order.gold_reward
	# Ingot: 20 x 2 x 1.5 x 1.3 = 78. Herb: 10 x 2 x 1.5 = 30, untouched.
	assert_int(prices["__test_ingot"]).is_equal(78)
	assert_int(prices["__test_herb"]).is_equal(30)


func test_a_modifier_with_no_family_scales_every_price() -> void:
	var archetypes: Array[CustomerDefinition] = [_archetype("__a", [_want(_ingot, 2, 2)])]
	var modifier := _modifier("__m", 1)
	modifier.family_price_multiplier = 1.2
	# 20 x 2 x 1.2 = 48
	assert_int(_generator.generate(archetypes, 1, 1, 1, _all_craftable, modifier)[0].orders[0].gold_reward).is_equal(48)


func test_session_size_delta_changes_the_customer_count() -> void:
	var archetypes: Array[CustomerDefinition] = [_archetype("__a", [_want(_ingot, 1, 1)])]
	var modifier := _modifier("__m", 1)
	modifier.session_size_delta = 3
	var modifiers: Array[SessionModifierDefinition] = [modifier]
	assert_int(_generator.plan(archetypes, modifiers, _rules(1.0), 1, 1, _all_craftable).customers.size()).is_equal(13)


func test_session_size_never_drops_below_one() -> void:
	var archetypes: Array[CustomerDefinition] = [_archetype("__a", [_want(_ingot, 1, 1)])]
	var modifier := _modifier("__m", 1)
	modifier.session_size_delta = -20
	var modifiers: Array[SessionModifierDefinition] = [modifier]
	assert_int(_generator.plan(archetypes, modifiers, _rules(1.0), 1, 1, _all_craftable).customers.size()).is_equal(1)


func _all_craftable(_item_def: ItemDefinition) -> bool:
	return true


func _rules(chance: float) -> ShopRulesDefinition:
	var rules := ShopRulesDefinition.new()
	rules.id = "default"
	rules.session_size = 10
	rules.modifier_chance = chance
	return rules


func _modifier(id: String, min_shop_level: int) -> SessionModifierDefinition:
	var modifier := SessionModifierDefinition.new()
	modifier.id = id
	modifier.min_shop_level = min_shop_level
	return modifier


func _item(id: String, value: int, family: String) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = id
	item.gold_value = value
	item.family = family
	return item


func _want(item: ItemDefinition, min_quantity: int, max_quantity: int) -> OrderTemplate:
	var want := OrderTemplate.new()
	want.item = item
	want.min_quantity = min_quantity
	want.max_quantity = max_quantity
	return want


func _archetype(id: String, wants: Array) -> CustomerDefinition:
	var archetype := CustomerDefinition.new()
	archetype.id = id
	archetype.wants.assign(wants)
	return archetype


func _ids_of(customers: Array[ShopCustomer]) -> Array[String]:
	var ids: Array[String] = []
	for customer in customers:
		ids.append(customer.definition.id)
	return ids


func _describe(plan: SessionPlan) -> Array[String]:
	var lines: Array[String] = []
	for customer in plan.customers:
		for order in customer.orders:
			lines.append("%s:%s:%d:%d" % [customer.definition.id, order.item.id, order.quantity, order.gold_reward])
	return lines
