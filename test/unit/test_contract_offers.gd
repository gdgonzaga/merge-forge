extends TestBase

# Offers are seeded, level and giver gated, reachable, and stable when the
# eligible pool changes around an existing offer.

const CONTRACT_OFFERS := preload("res://autoloads/contract_offers.gd")
const SEED := 4242

var _giver: CustomerDefinition
var _item: ItemDefinition


func before_test() -> void:
	super.before_test()
	_giver = CustomerDefinition.new()
	_giver.id = "__test_giver"
	_item = ItemDefinition.new()
	_item.id = "__test_item"


func test_the_same_seed_offers_the_same_contracts() -> void:
	var pool := _pool(["__a", "__b", "__c", "__d"])
	var first := _ids(_offer(pool, 1, [], 2))
	assert_int(first.size()).is_equal(2)
	assert_array(_ids(_offer(pool, 1, [], 2))).is_equal(first)


func test_no_more_than_count_are_offered() -> void:
	var pool := _pool(["__a", "__b", "__c"])
	assert_int(_offer(pool, 1, [], 2).size()).is_equal(2)
	assert_int(_offer(pool, 1, [], 5).size()).is_equal(3)


func test_a_contract_above_the_level_is_not_offered() -> void:
	var gated := _contract("__gated")
	gated.min_shop_level = 5
	assert_array(_offer([gated], 4, [], 5)).is_empty()
	assert_array(_ids(_offer([gated], 5, [], 5))).is_equal(["__gated"])


func test_a_contract_whose_giver_is_locked_is_not_offered() -> void:
	var locked := CustomerDefinition.new()
	locked.id = "__test_locked"
	locked.min_shop_level = 7
	var contract := _contract("__a")
	contract.giver = locked
	assert_array(_offer([contract], 6, [], 5)).is_empty()
	assert_array(_ids(_offer([contract], 7, [], 5))).is_equal(["__a"])


func test_a_settled_contract_is_not_offered_again() -> void:
	assert_array(_ids(_offer(_pool(["__a", "__b"]), 1, ["__a"], 5))).is_equal(["__b"])


func test_a_contract_the_player_cannot_reach_is_not_offered() -> void:
	var far_item := ItemDefinition.new()
	far_item.id = "__test_far"
	var far := _contract("__far")
	far.requirements[0].item = far_item
	var reachable := func(items: Array[ItemDefinition]) -> bool: return not far_item in items
	var offered: Array[ContractDefinition] = CONTRACT_OFFERS.new().offer(
		[far, _contract("__a")] as Array[ContractDefinition], 1, SEED, [] as Array[String], reachable, 5)
	assert_array(_ids(offered)).is_equal(["__a"])


func test_changing_the_pool_never_reshuffles_the_other_offers() -> void:
	var ids: Array[String] = ["__a", "__b", "__c", "__d", "__e"]
	var pool := _pool(ids)
	var offered := _ids(_offer(pool, 1, [], 2))
	var unoffered := ""
	for id in ids:
		if not id in offered:
			unoffered = id
			break
	assert_array(_ids(_offer(pool, 1, [unoffered], 2))).is_equal(offered)
	assert_bool(offered[1] in _ids(_offer(pool, 1, [offered[0]], 2))).is_true()


func test_a_zero_weight_contract_is_never_offered() -> void:
	var never := _contract("__never")
	never.weight = 0
	assert_array(_offer([never], 1, [], 5)).is_empty()


func _offer(pool: Array, level: int, settled: Array, count: int) -> Array[ContractDefinition]:
	var contracts: Array[ContractDefinition] = []
	contracts.assign(pool)
	var settled_ids: Array[String] = []
	settled_ids.assign(settled)
	var always := func(_items: Array[ItemDefinition]) -> bool: return true
	return CONTRACT_OFFERS.new().offer(contracts, level, SEED, settled_ids, always, count)


func _pool(ids: Array) -> Array[ContractDefinition]:
	var pool: Array[ContractDefinition] = []
	for id: String in ids:
		pool.append(_contract(id))
	return pool


func _contract(id: String) -> ContractDefinition:
	var requirement := OrderTemplate.new()
	requirement.item = _item
	var contract := ContractDefinition.new()
	contract.id = id
	contract.giver = _giver
	contract.requirements = [requirement]
	return contract


func _ids(contracts: Array[ContractDefinition]) -> Array[String]:
	var ids: Array[String] = []
	for contract in contracts:
		ids.append(contract.id)
	return ids
