extends TestBase

const SHOP_SESSION := preload("res://shop/shop_session.tscn")
const MAX_FRAMES := 10

var _item: ItemDefinition
var _giver: CustomerDefinition


func before_test() -> void:
	super.before_test()
	_push_shipped_shop_content_away()
	set_definition(DefinitionLibrary.shop_rules, _rules(1))
	_item = ItemDefinition.new()
	_item.id = "__test_item"
	_item.name = "Test Item"
	_item.gold_value = 60
	set_definition(DefinitionLibrary.items, _item)
	var crate := CrateDefinition.new()
	crate.id = "__test_crate"
	crate.name = "Test Crate"
	crate.min_shop_level = 1
	var weighted := WeightedItem.new()
	weighted.item = _item
	weighted.weight = 1
	crate.pool = [weighted]
	set_definition(DefinitionLibrary.crates, crate)
	_giver = _customer()
	set_definition(DefinitionLibrary.customers, _giver)
	set_definition(DefinitionLibrary.contracts, _contract(3, 0))


func test_a_partial_delivery_moves_what_the_player_has() -> void:
	GameManager.active_contracts = [_entry(0)]
	GameManager.shop_board_state = [_board_entry(0), _board_entry(1)]
	var session := _start_session()
	assert_int(session.deliver_to_contract("__test_contract", "__test_item", 5)).is_equal(2)
	assert_int(session.board.count_sellable("__test_item")).is_equal(0)
	assert_array(GameManager.active_contracts).is_equal([{"id": "__test_contract", "delivered": {"__test_item": 2}, "sessions_left": 2}])


func test_a_delivery_never_takes_more_than_the_contract_needs() -> void:
	GameManager.active_contracts = [_entry(0)]
	GameManager.shop_board_state = [_board_entry(0), _board_entry(1), _board_entry(2), _board_entry(3), _board_entry(4)]
	var session := _start_session()
	assert_int(session.deliver_to_contract("__test_contract", "__test_item", 5)).is_equal(3)
	assert_int(session.board.count_sellable("__test_item")).is_equal(2)


func test_a_delivery_is_saved_with_the_board_it_emptied() -> void:
	GameManager.active_contracts = [_entry(0)]
	GameManager.shop_board_state = [_board_entry(0)]
	var session := _start_session()
	session.deliver_to_contract("__test_contract", "__test_item", 1)
	var saved: Dictionary = SaveManager.load_game_ex()["data"]
	assert_int(int(saved["active_contracts"][0]["delivered"]["__test_item"])).is_equal(1)
	assert_array(saved["shop_board_state"]).is_empty()


func test_a_delivery_is_saved_with_the_shelf_it_emptied() -> void:
	_give_shelf(2)
	GameManager.active_contracts = [_entry(0)]
	GameManager.shop_shelf_state = [_board_entry(0)]
	var session := _start_session()
	assert_int(session.deliver_to_contract("__test_contract", "__test_item", 1)).is_equal(1)
	var saved: Dictionary = SaveManager.load_game_ex()["data"]
	assert_int(int(saved["active_contracts"][0]["delivered"]["__test_item"])).is_equal(1)
	assert_array(saved["shop_shelf_state"]).is_empty()


func test_an_item_below_the_required_quality_is_not_taken() -> void:
	set_definition(DefinitionLibrary.contracts, _contract(3, 1))
	GameManager.active_contracts = [_entry(0)]
	GameManager.shop_board_state = [_board_entry(0)]
	var session := _start_session()
	assert_int(session.deliver_to_contract("__test_contract", "__test_item", 1)).is_equal(0)
	assert_int(session.board.count_sellable("__test_item")).is_equal(1)


func test_completing_a_contract_pays_once_and_removes_it() -> void:
	GameManager.active_contracts = [_entry(2)]
	GameManager.shop_board_state = [_board_entry(0), _board_entry(1)]
	var session := _start_session()
	var gold_before := GameManager.gold
	assert_int(session.deliver_to_contract("__test_contract", "__test_item", 1)).is_equal(1)
	assert_int(GameManager.gold - gold_before).is_equal(150)
	assert_array(GameManager.active_contracts).is_empty()
	assert_int(session.deliver_to_contract("__test_contract", "__test_item", 1)).is_equal(0)
	assert_int(GameManager.gold - gold_before).is_equal(150)
	assert_int(session.board.count_sellable("__test_item")).is_equal(1)
	assert_array(session.summary_data["notes"]).is_equal(["Test Contract complete: 150 gold"])


func test_completing_a_contract_gives_its_giver_loyalty() -> void:
	var gift := LoyaltyReward.new()
	gift.points = 3
	gift.gold = 40
	_giver.loyalty_rewards = [gift]
	GameManager.active_contracts = [_entry(2)]
	GameManager.shop_board_state = [_board_entry(0)]
	var session := _start_session()
	session.deliver_to_contract("__test_contract", "__test_item", 1)
	assert_int(GameManager.get_loyalty("__test_giver")).is_equal(3)
	assert_array(session.summary_data["notes"]).is_equal(["Test Contract complete: 150 gold", "Giver gives you: 40 gold"])


func test_a_contract_expires_after_its_sessions() -> void:
	GameManager.active_contracts = [_entry(0)]
	var first := _start_session()
	first.reject_customer()
	await _await_session_end(first)
	assert_int(GameManager.active_contracts[0]["sessions_left"]).is_equal(1)
	assert_array(first.summary_data["notes"]).is_empty()
	var second := _start_session()
	second.reject_customer()
	await _await_session_end(second)
	assert_array(GameManager.active_contracts).is_empty()
	assert_array(second.summary_data["notes"]).is_equal(["Test Contract expired"])


func _start_session() -> Control:
	var session: Control = auto_free(SHOP_SESSION.instantiate())
	add_child(session)
	return session


func _await_session_end(session: Control) -> void:
	var frames := 0
	while not session.summary_data.has("level_after") and frames < MAX_FRAMES:
		await get_tree().process_frame
		frames += 1
	assert_bool(session.summary_data.has("level_after")).is_true()


func _entry(delivered: int) -> Dictionary:
	var counts := {} if delivered == 0 else {"__test_item": delivered}
	return {"id": "__test_contract", "delivered": counts, "sessions_left": 2}


func _board_entry(col: int) -> Dictionary:
	return {"col": col, "row": 0, "item_id": "__test_item", "quality": 0}


func _contract(quantity: int, min_quality: int) -> ContractDefinition:
	var requirement := OrderTemplate.new()
	requirement.item = _item
	requirement.min_quantity = quantity
	requirement.max_quantity = quantity
	requirement.min_quality = min_quality
	var contract := ContractDefinition.new()
	contract.id = "__test_contract"
	contract.name = "Test Contract"
	contract.giver = _giver
	contract.requirements = [requirement]
	contract.sessions_allowed = 2
	contract.reward_gold = 150
	contract.loyalty_points = 3
	return contract


func _customer() -> CustomerDefinition:
	var want := OrderTemplate.new()
	want.item = _item
	var customer := CustomerDefinition.new()
	customer.id = "__test_giver"
	customer.name = "Giver"
	customer.wants = [want]
	return customer


func _push_shipped_shop_content_away() -> void:
	for catalog: Dictionary in [DefinitionLibrary.customers, DefinitionLibrary.crates, DefinitionLibrary.contracts]:
		for definition: Resource in catalog.values().duplicate():
			var moved: Resource = definition.duplicate()
			moved.min_shop_level = 9999
			set_definition(catalog, moved)


func _rules(session_size: int) -> ShopRulesDefinition:
	var rules := ShopRulesDefinition.new()
	rules.id = "default"
	rules.session_size = session_size
	rules.level_xp_base = 100000
	rules.level_xp_exponent = 1.0
	rules.max_level = 5
	return rules


func _give_shelf(slots: int) -> void:
	var shelf := UpgradeDefinition.new()
	shelf.id = "__test_shelf"
	shelf.effect = "shelf_slots"
	var level := UpgradeLevel.new()
	level.value = slots
	shelf.levels = [level]
	set_definition(DefinitionLibrary.upgrades, shelf)
	GameManager.raise_upgrade_level("__test_shelf")


# --- the Contracts sheet ---

func test_the_contracts_button_is_hidden_without_a_contract() -> void:
	var session := _start_session()
	assert_bool(session.get_node("%ContractsBtn").visible).is_false()


func test_the_contracts_button_counts_the_active_contracts() -> void:
	GameManager.active_contracts = [_entry(0)]
	var session := _start_session()
	var button: Button = session.get_node("%ContractsBtn")
	assert_bool(button.visible).is_true()
	assert_str(button.text).is_equal("Contracts (1)")


func test_the_contracts_button_stays_inside_the_safe_left_margin() -> void:
	GameManager.active_contracts = [_entry(0)]
	var session := _start_session()
	await get_tree().process_frame
	var button: Button = session.get_node("%ContractsBtn")
	assert_bool(button.get_global_rect().position.x - session.get_global_rect().position.x >= 48.0).is_true()
	session.apply_contract_button_safe_area(Rect2i(240, 80, 1920, 3680), Transform2D.IDENTITY.scaled(Vector2(2, 2)), "Android")
	await get_tree().process_frame
	assert_bool(button.get_global_rect().position.x - session.get_global_rect().position.x >= 168.0).is_true()
	assert_bool(button.size.x >= 120.0).is_true()


func test_the_sheet_shows_progress_and_what_the_player_has() -> void:
	GameManager.active_contracts = [_entry(1)]
	GameManager.shop_board_state = [_board_entry(0), _board_entry(1)]
	var session := _start_session()
	var row := _rows(_open_sheet(session))[0]
	assert_str(row.get_node("%ItemLabel").text).is_equal("1/3 Test Item")
	assert_str(row.get_node("%HaveLabel").text).is_equal("You have 2")
	assert_str(row.get_node("%GiveAllBtn").text).is_equal("Give 2")


func test_give_one_hands_over_a_single_item() -> void:
	GameManager.active_contracts = [_entry(0)]
	GameManager.shop_board_state = [_board_entry(0), _board_entry(1)]
	var session := _start_session()
	var sheet := _open_sheet(session)
	_rows(sheet)[0].get_node("%GiveOneBtn").pressed.emit()
	assert_int(session.board.count_sellable("__test_item")).is_equal(1)
	var row := _rows(sheet)[0]
	assert_str(row.get_node("%ItemLabel").text).is_equal("1/3 Test Item")
	assert_str(row.get_node("%HaveLabel").text).is_equal("You have 1")


func test_give_all_completes_the_contract_and_closes_the_sheet() -> void:
	GameManager.active_contracts = [_entry(0)]
	GameManager.shop_board_state = [_board_entry(0), _board_entry(1), _board_entry(2), _board_entry(3)]
	var session := _start_session()
	var sheet := _open_sheet(session)
	var give_all: Button = _rows(sheet)[0].get_node("%GiveAllBtn")
	assert_str(give_all.text).is_equal("Give 3")
	give_all.pressed.emit()
	assert_int(session.board.count_sellable("__test_item")).is_equal(1)
	assert_bool(sheet.visible).is_false()
	assert_bool(session.get_node("%ContractsBtn").visible).is_false()


func test_android_back_closes_the_sheet() -> void:
	GameManager.active_contracts = [_entry(0)]
	var sheet := _open_sheet(_start_session())
	sheet.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_bool(sheet.visible).is_false()


func test_sheet_buttons_are_touch_sized() -> void:
	GameManager.active_contracts = [_entry(0)]
	GameManager.shop_board_state = [_board_entry(0), _board_entry(1)]
	var session := _start_session()
	var sheet := _open_sheet(session)
	var row := _rows(sheet)[0]
	for button: Button in [row.get_node("%GiveOneBtn"), row.get_node("%GiveAllBtn"), sheet.get_node("%CloseBtn"), session.get_node("%ContractsBtn")]:
		assert_bool(button.custom_minimum_size.y >= 120.0).override_failure_message("%s too short" % button.name).is_true()
		assert_bool(button.get_theme_font_size("font_size") >= 32).override_failure_message("%s text too small" % button.name).is_true()
	for button: Button in [row.get_node("%GiveOneBtn"), row.get_node("%GiveAllBtn")]:
		assert_bool(button.custom_minimum_size.x >= 120.0).override_failure_message("%s too narrow" % button.name).is_true()
	var actions: VBoxContainer = session.get_node("CustomerBox/ActionPanel/OrderActionsContainer")
	assert_int(actions.get_theme_constant("separation")).is_greater_equal(24)


func test_sheet_rectangle_fits_portrait_safe_areas() -> void:
	GameManager.active_contracts = [_entry(0)]
	var sheet := _open_sheet(_start_session())
	var transform := Transform2D.IDENTITY.scaled(Vector2(2, 2))
	var standard: Rect2i = sheet.calculate_popup_rect(Rect2i(0, 80, 2160, 3680), transform, "Android", Vector2i(1080, 1920))
	assert_bool(standard.position.x >= 48 and standard.end.x <= 1032).is_true()
	assert_bool(standard.position.y >= 88 and standard.end.y <= 1872).is_true()
	var tall: Rect2i = sheet.calculate_popup_rect(Rect2i(0, 80, 2160, 4880), transform, "Android", Vector2i(1080, 2520))
	assert_bool(tall.position.x >= 48 and tall.end.x <= 1032).is_true()
	assert_bool(tall.position.y >= 88 and tall.end.y <= 2472).is_true()


func test_sheet_has_an_opaque_panel_and_flexible_scroll() -> void:
	GameManager.active_contracts = [_entry(0)]
	var sheet := _open_sheet(_start_session())
	var panel: StyleBoxFlat = sheet.get_theme_stylebox("panel")
	var scroll: ScrollContainer = sheet.get_node("Margin/VBox/Scroll")
	assert_float(panel.bg_color.a).is_equal(1.0)
	assert_bool(scroll.size_flags_vertical & Control.SIZE_EXPAND != 0).is_true()
	assert_float(scroll.custom_minimum_size.y).is_equal(0.0)


func _open_sheet(session: Control) -> PopupPanel:
	session.get_node("%ContractsBtn").pressed.emit()
	var sheet: PopupPanel = session.get_node("%ContractDelivery")
	assert_bool(sheet.visible).is_true()
	return sheet


func _rows(sheet: PopupPanel) -> Array[Node]:
	var rows: Array[Node] = []
	for child in sheet.get_node("%Rows").get_children():
		if child.has_node("%GiveOneBtn"):
			rows.append(child)
	return rows
