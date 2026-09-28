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


func _ids(plan: SessionPlan) -> Array[String]:
	var ids: Array[String] = []
	for customer in plan.customers:
		ids.append(customer.definition.id)
	return ids


func _describe(plan: SessionPlan) -> Array[String]:
	var lines: Array[String] = []
	for customer in plan.customers:
		for order in customer.orders:
			lines.append("%s:%s:%d:%d" % [customer.definition.id, order.item.id, order.quantity, order.gold_reward])
	return lines
