extends TestBase

const CONTRACT_PROGRESS := preload("res://shop/contract_progress.gd")

var _contract: ContractDefinition


func before_test() -> void:
	super.before_test()
	_contract = ContractDefinition.new()
	_contract.id = "__test_contract"
	_contract.sessions_allowed = 2
	_contract.requirements = [_requirement("__test_ore", 3, 0), _requirement("__test_plate", 2, 1)]


func test_a_partial_delivery_counts_up_to_what_is_still_needed() -> void:
	var progress := _fresh()
	assert_int(progress.deliver("__test_ore", 2, 0)).is_equal(2)
	assert_int(progress.deliver("__test_ore", 5, 0)).is_equal(1)
	assert_int(progress.delivered("__test_ore")).is_equal(3)
	assert_int(progress.remaining("__test_ore")).is_equal(0)
	assert_int(progress.deliver("__test_ore", 1, 0)).is_equal(0)


func test_an_item_below_the_required_quality_is_refused() -> void:
	var progress := _fresh()
	assert_int(progress.deliver("__test_plate", 1, 0)).is_equal(0)
	assert_int(progress.delivered("__test_plate")).is_equal(0)
	assert_int(progress.deliver("__test_plate", 1, 2)).is_equal(1)


func test_an_item_the_contract_does_not_ask_for_is_refused() -> void:
	var progress := _fresh()
	assert_int(progress.deliver("__test_other", 1, 0)).is_equal(0)
	assert_dict(progress.to_entry()["delivered"]).is_empty()


func test_it_is_complete_only_once_every_requirement_is_met() -> void:
	var progress := _fresh()
	progress.deliver("__test_ore", 3, 0)
	assert_bool(progress.is_complete()).is_false()
	progress.deliver("__test_plate", 2, 1)
	assert_bool(progress.is_complete()).is_true()


func test_it_expires_after_its_sessions_run_out() -> void:
	var progress := _fresh()
	assert_bool(progress.tick_session()).is_false()
	assert_int(progress.sessions_left).is_equal(1)
	assert_bool(progress.tick_session()).is_true()


func test_a_saved_entry_round_trips() -> void:
	var entry := {"id": "__test_contract", "delivered": {"__test_ore": 1}, "sessions_left": 1}
	var progress: RefCounted = CONTRACT_PROGRESS.new().setup(_contract, entry)
	assert_int(progress.remaining("__test_ore")).is_equal(2)
	assert_dict(progress.to_entry()).is_equal(entry)


func _fresh() -> RefCounted:
	return CONTRACT_PROGRESS.new().setup(_contract, {"id": "__test_contract", "delivered": {}, "sessions_left": 2})


func _requirement(item_id: String, quantity: int, min_quality: int) -> OrderTemplate:
	var item := ItemDefinition.new()
	item.id = item_id
	var requirement := OrderTemplate.new()
	requirement.item = item
	requirement.min_quantity = quantity
	requirement.max_quantity = quantity
	requirement.min_quality = min_quality
	return requirement
