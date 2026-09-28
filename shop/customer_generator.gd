extends RefCounted

# Deals a shop session's customers from the unlocked archetypes. Deterministic:
# the same archetypes, level, seed and craftability give the same session,
# which the prep-phase forecast relies on.


# `is_craftable` is Callable(ItemDefinition) -> bool.
func generate(archetypes: Array[CustomerDefinition], count: int, level: int, session_seed: int, is_craftable: Callable) -> Array[ShopCustomer]:
	var rng := RandomNumberGenerator.new()
	rng.seed = session_seed
	var dealt: Array[ShopCustomer] = []
	var pool := _eligible(archetypes, level, is_craftable)
	if pool.is_empty():
		return dealt
	var previous: CustomerDefinition = null
	for _i in range(count):
		var archetype := _draw(pool, previous, rng)
		dealt.append(ShopCustomer.new().setup(archetype, _roll_orders(archetype, rng, is_craftable)))
		previous = archetype
	return dealt


# A weight of 0 or less is never picked, unless every weight is.
static func pick_weighted(weights: Array[int], rng: RandomNumberGenerator) -> int:
	var total := 0
	for weight in weights:
		total += maxi(weight, 0)
	if total == 0:
		return rng.randi_range(0, weights.size() - 1)
	var roll := rng.randi_range(0, total - 1)
	for i in range(weights.size()):
		roll -= maxi(weights[i], 0)
		if roll < 0:
			return i
	return weights.size() - 1


# Unlocked by level and wanting at least one thing the player can make
# today. Sorted by id so catalog load order can't change a seeded session.
func _eligible(archetypes: Array[CustomerDefinition], level: int, is_craftable: Callable) -> Array[CustomerDefinition]:
	var pool: Array[CustomerDefinition] = []
	for archetype in archetypes:
		if level >= archetype.min_shop_level and not _craftable_wants(archetype, is_craftable).is_empty():
			pool.append(archetype)
	pool.sort_custom(func(a: CustomerDefinition, b: CustomerDefinition) -> bool: return a.id < b.id)
	return pool


func _craftable_wants(archetype: CustomerDefinition, is_craftable: Callable) -> Array[OrderTemplate]:
	var craftable: Array[OrderTemplate] = []
	for want in archetype.wants:
		if is_craftable.call(want.item):
			craftable.append(want)
	return craftable


# Weighted draw with replacement that avoids repeating `previous` while anyone
# else is eligible.
func _draw(pool: Array[CustomerDefinition], previous: CustomerDefinition, rng: RandomNumberGenerator) -> CustomerDefinition:
	var candidates: Array[CustomerDefinition] = []
	for archetype in pool:
		if archetype != previous:
			candidates.append(archetype)
	if candidates.is_empty():
		candidates = pool.duplicate()
	var weights: Array[int] = []
	for archetype in candidates:
		weights.append(archetype.weight)
	return candidates[pick_weighted(weights, rng)]


# The first order is always one the player can make today; the rest may not
# be, which shows what a blueprint would open up. No item appears twice.
func _roll_orders(archetype: CustomerDefinition, rng: RandomNumberGenerator, is_craftable: Callable) -> Array[OrderDefinition]:
	var orders: Array[OrderDefinition] = []
	var first := _pick_template(_craftable_wants(archetype, is_craftable), rng)
	orders.append(_make_order(first, archetype.price_multiplier, rng))
	var remaining: Array[OrderTemplate] = []
	for want in archetype.wants:
		if want.item != first.item:
			remaining.append(want)
	var target := rng.randi_range(archetype.min_orders, archetype.max_orders)
	while orders.size() < target and not remaining.is_empty():
		var template := _pick_template(remaining, rng)
		remaining = remaining.filter(func(want: OrderTemplate) -> bool: return want.item != template.item)
		orders.append(_make_order(template, archetype.price_multiplier, rng))
	return orders


func _pick_template(templates: Array[OrderTemplate], rng: RandomNumberGenerator) -> OrderTemplate:
	var weights: Array[int] = []
	for template in templates:
		weights.append(template.weight)
	return templates[pick_weighted(weights, rng)]


static func _make_order(template: OrderTemplate, price_multiplier: float, rng: RandomNumberGenerator) -> OrderDefinition:
	var order := OrderDefinition.new()
	order.item = template.item
	order.quantity = rng.randi_range(template.min_quantity, template.max_quantity)
	order.gold_reward = roundi(template.item.gold_value * order.quantity * price_multiplier)
	return order
