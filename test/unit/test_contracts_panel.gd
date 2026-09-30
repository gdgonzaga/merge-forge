extends TestBase

# Prep's Contracts tab shows offers and accepted delivery progress.

const PANEL := preload("res://core/contracts_panel.tscn")

var _item: ItemDefinition
var _plate: ItemDefinition
var _contract: ContractDefinition


func before_test() -> void:
	super.before_test()
	_item = ItemDefinition.new()
	_item.id = "__test_item"
	_item.name = "Test Item"
	set_definition(DefinitionLibrary.items, _item)
	_plate = ItemDefinition.new()
	_plate.id = "__test_plate"
	_plate.name = "Test Plate"
	set_definition(DefinitionLibrary.items, _plate)
	_contract = _contract_def("__test_contract", "Test Contract")
	set_definition(DefinitionLibrary.contracts, _contract)
	var board := UpgradeDefinition.new()
	board.id = "__test_board"
	board.name = "Test Board"
	board.effect = "contract_slots"
	for pair: Array in [[1, 1.0], [2, 2.0]]:
		var level := UpgradeLevel.new()
		level.cost = pair[0]
		level.value = pair[1]
		board.levels.append(level)
	set_definition(DefinitionLibrary.upgrades, board)


func test_an_offer_lists_what_it_needs_and_pays() -> void:
	var card := _card_titled(_panel([_contract]), "Test Contract")
	assert_str(card.get_node("%GiverLabel").text).is_equal("From Tester")
	assert_str(card.get_node("%RequirementsLabel").text).is_equal("3x Test Item\n1x Fine Test Plate")
	assert_str(card.get_node("%RewardLabel").text).is_equal("Reward: 150 gold, +2 loyalty")
	assert_str(card.get_node("%SessionsLabel").text).is_equal("3 sessions to deliver")


func test_without_slots_an_offer_names_the_upgrade_it_needs() -> void:
	var panel := _panel([_contract])
	var button: Button = _card_titled(panel, "Test Contract").get_node("%AcceptBtn")
	assert_str(button.text).is_equal("Needs Test Board")
	assert_bool(button.disabled).is_true()
	assert_bool(panel.accept("__test_contract")).is_false()
	assert_array(GameManager.active_contracts).is_empty()


func test_accepting_records_the_contract_and_saves() -> void:
	GameManager.raise_upgrade_level("__test_board")
	var saves := [0]
	var on_save := func() -> void: saves[0] += 1
	EventBus.save_requested.connect(on_save)
	var panel := _panel([_contract])
	var accepted: bool = panel.accept("__test_contract")
	EventBus.save_requested.disconnect(on_save)
	assert_bool(accepted).is_true()
	assert_array(GameManager.active_contracts).is_equal([{"id": "__test_contract", "delivered": {}, "sessions_left": 3}])
	assert_int(saves[0]).is_equal(1)
	var button: Button = _card_titled(panel, "Test Contract").get_node("%AcceptBtn")
	assert_str(button.text).is_equal("Accepted")
	assert_bool(button.disabled).is_true()


func test_accepting_is_refused_when_every_slot_is_in_use() -> void:
	GameManager.raise_upgrade_level("__test_board")
	var other := _contract_def("__test_other", "Other Contract")
	set_definition(DefinitionLibrary.contracts, other)
	var panel := _panel([_contract, other])
	panel.accept("__test_contract")
	assert_bool(panel.accept("__test_other")).is_false()
	assert_int(GameManager.active_contracts.size()).is_equal(1)
	assert_str(_card_titled(panel, "Other Contract").get_node("%AcceptBtn").text).is_equal("All slots in use")


func test_a_contract_not_on_offer_cannot_be_accepted() -> void:
	GameManager.raise_upgrade_level("__test_board")
	assert_bool(_panel([]).accept("__test_contract")).is_false()
	assert_array(GameManager.active_contracts).is_empty()


func test_an_accepted_contract_shows_its_progress_and_sessions_left() -> void:
	GameManager.active_contracts = [{"id": "__test_contract", "delivered": {"__test_item": 1}, "sessions_left": 2}]
	var card := _card_titled(_panel([]), "Test Contract")
	assert_str(card.get_node("%RequirementsLabel").text).is_equal("1/3 Test Item\n0/1 Fine Test Plate")
	assert_str(card.get_node("%SessionsLabel").text).is_equal("2 sessions left")
	assert_bool(card.get_node("%AcceptBtn").visible).is_false()


func test_accept_buttons_are_touch_sized() -> void:
	var button: Button = _card_titled(_panel([_contract]), "Test Contract").get_node("%AcceptBtn")
	assert_bool(button.custom_minimum_size.y >= 120.0).is_true()
	assert_bool(button.get_theme_font_size("font_size") >= 32).is_true()


func _panel(offers: Array) -> VBoxContainer:
	var panel: VBoxContainer = auto_free(PANEL.instantiate())
	add_child(panel)
	var no_customers: Array[ShopCustomer] = []
	var plan := SessionPlan.new().setup(no_customers, null)
	plan.contract_offers.assign(offers)
	panel.setup(plan)
	return panel


func _card_titled(panel: Node, title: String) -> PanelContainer:
	for card: Node in panel.find_children("*", "PanelContainer", true, false):
		if card.has_node("%TitleLabel") and card.get_node("%TitleLabel").text == title:
			return card
	return null


func _contract_def(id: String, contract_name: String) -> ContractDefinition:
	var giver := CustomerDefinition.new()
	giver.id = "__test_giver"
	giver.name = "Tester"
	var contract := ContractDefinition.new()
	contract.id = id
	contract.name = contract_name
	contract.giver = giver
	contract.requirements = [_requirement(_item, 3, 0), _requirement(_plate, 1, 1)]
	contract.sessions_allowed = 3
	contract.reward_gold = 150
	contract.loyalty_points = 2
	return contract


func _requirement(item: ItemDefinition, quantity: int, min_quality: int) -> OrderTemplate:
	var requirement := OrderTemplate.new()
	requirement.item = item
	requirement.min_quantity = quantity
	requirement.max_quantity = quantity
	requirement.min_quality = min_quality
	return requirement
