extends TestBase

# The Guild Hall: the charter's two-step confirm (spec review focus 2), perk
# picks against the points budget, the town choice, and the way back to prep.

const SCREEN := preload("res://core/charter_screen.tscn")


func before_test() -> void:
	super.before_test()
	var rules := ShopRulesDefinition.new()
	rules.id = "default"
	rules.starting_town = test_town
	rules.level_xp_base = 100
	rules.level_xp_exponent = 1.0
	rules.max_level = 5
	rules.charter_level = 3
	rules.charter_base_points = 10
	rules.charter_points_per_level = 0.0
	set_definition(DefinitionLibrary.shop_rules, rules)
	set_definition(DefinitionLibrary.perks, _perk("__test_perk", [4, 7]))
	GameManager.shop_xp = 300  # level 3: a charter earns the base 10


func test_below_the_charter_level_founding_is_off() -> void:
	GameManager.shop_xp = 0
	var screen := _screen()
	assert_bool(screen.get_node("%FoundBtn").disabled).is_true()
	assert_str(screen.get_node("%StatusLabel").text).is_equal("Reach shop level 3 to found a charter (you are level 1).")
	screen.ask_to_found()
	assert_object(_dialog(screen)).is_null()


func test_the_points_line_adds_banked_and_earned() -> void:
	GameManager.charter_points = 2
	var screen := _screen()
	assert_str(screen.get_node("%PointsLabel").text).is_equal("Charter points: 2 banked + 10 from this charter. 12 left after your picks.")


func test_a_pick_spends_from_the_budget_until_it_runs_out() -> void:
	var screen := _screen()
	assert_bool(screen.pick_perk("__test_perk")).is_true()
	assert_str(screen.get_node("%PointsLabel").text).is_equal("Charter points: 0 banked + 10 from this charter. 6 left after your picks.")
	assert_str(_row(screen, "__test_perk").get_node("%NameLabel").text).is_equal("Test Perk (1/2)")
	# Level 2 costs 7 of the 6 left.
	assert_bool(screen.pick_perk("__test_perk")).is_false()
	assert_bool(_row(screen, "__test_perk").get_node("%PickBtn").disabled).is_true()


func test_clearing_the_picks_gives_the_points_back() -> void:
	var screen := _screen()
	screen.pick_perk("__test_perk")
	screen.get_node("%ClearPicksBtn").pressed.emit()
	assert_str(screen.get_node("%PointsLabel").text).is_equal("Charter points: 0 banked + 10 from this charter. 10 left after your picks.")


func test_found_only_asks_and_confirm_founds() -> void:
	var founded: Array[String] = []
	var on_founded := func(town_id: String) -> void: founded.append(town_id)
	EventBus.charter_founded.connect(on_founded)
	var screen := _screen()
	screen.pick_perk("__test_perk")
	screen.get_node("%FoundBtn").pressed.emit()
	var dialog := _dialog(screen)
	assert_object(dialog).is_not_null()
	assert_int(GameManager.charters).is_equal(0)
	dialog.get_node("Margin/VBox/BtnBox/ConfirmBtn").pressed.emit()
	EventBus.charter_founded.disconnect(on_founded)
	assert_int(GameManager.charters).is_equal(1)
	assert_int(GameManager.get_perk_level("__test_perk")).is_equal(1)
	# 0 banked + 10 earned - 4 for the pick.
	assert_int(GameManager.charter_points).is_equal(6)
	assert_array(founded).is_equal([TEST_TOWN_ID])
	assert_bool(FileAccess.file_exists(SaveManager.save_path)).is_true()


func test_cancel_leaves_the_run_alone() -> void:
	var screen := _screen()
	screen.get_node("%FoundBtn").pressed.emit()
	_dialog(screen).get_node("Margin/VBox/BtnBox/CancelBtn").pressed.emit()
	assert_int(GameManager.charters).is_equal(0)
	assert_int(GameManager.shop_xp).is_equal(300)


func test_the_confirm_says_what_is_lost_and_kept() -> void:
	var screen := _screen()
	screen.ask_to_found()
	assert_str(_dialog(screen).get_node("Margin/VBox/MessageLabel").text).is_equal(
		"Found a charter in Test Town?\nYou lose your gold, shop level, blueprints, upgrades, board, shelf, reagents, contracts and loyalty.\nYou keep your charter points, perks and codex.")


func test_a_town_not_open_yet_cannot_be_chosen() -> void:
	set_definition(DefinitionLibrary.towns, _town("__test_far", "Far Town", 5))
	var screen := _screen()
	var button := _town_button(screen, "Far Town (opens at charter 5)")
	assert_object(button).is_not_null()
	assert_bool(button.disabled).is_true()
	screen.select_town("__test_far")
	assert_str(screen.get_node("%FoundBtn").text).is_equal("Found in Test Town")


func test_choosing_an_open_town_founds_there() -> void:
	set_definition(DefinitionLibrary.towns, _town("__test_near", "Near Town", 1))
	var screen := _screen()
	_town_button(screen, "Near Town").pressed.emit()
	assert_str(screen.get_node("%FoundBtn").text).is_equal("Found in Near Town")
	assert_bool(screen.confirm_found()).is_true()
	assert_str(GameManager.current_town).is_equal("__test_near")


func test_back_and_android_back_return_to_prep() -> void:
	var closed: Array[bool] = []
	var on_closed := func() -> void: closed.append(true)
	EventBus.charter_closed.connect(on_closed)
	var screen := _screen()
	screen.get_node("%BackBtn").pressed.emit()
	screen.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	EventBus.charter_closed.disconnect(on_closed)
	assert_int(closed.size()).is_equal(2)


func test_android_back_closes_the_confirm_first() -> void:
	var closed: Array[bool] = []
	var on_closed := func() -> void: closed.append(true)
	EventBus.charter_closed.connect(on_closed)
	var screen := _screen()
	screen.ask_to_found()
	var dialog := _dialog(screen)
	screen.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	EventBus.charter_closed.disconnect(on_closed)
	assert_bool(dialog.visible).is_false()
	assert_array(closed).is_empty()
	assert_int(GameManager.charters).is_equal(0)


func test_the_hall_has_a_charter_and_a_codex_tab() -> void:
	var tabs: TabContainer = _screen().get_node("%Tabs")
	assert_int(tabs.get_tab_count()).is_equal(2)
	assert_str(tabs.get_tab_title(0)).is_equal("Charter")
	assert_str(tabs.get_tab_title(1)).is_equal("Codex")


func test_buttons_are_touch_sized() -> void:
	var screen := _screen()
	await get_tree().process_frame
	var buttons: Array[Button] = [
		screen.get_node("%FoundBtn"),
		screen.get_node("%BackBtn"),
		screen.get_node("%ClearPicksBtn"),
		_row(screen, "__test_perk").get_node("%PickBtn"),
		_town_button(screen, "Test Town"),
	]
	for button in buttons:
		assert_bool(button.size.x >= 120.0 and button.size.y >= 120.0) \
			.override_failure_message("%s is %s" % [button.name, str(button.size)]).is_true()


func _screen() -> Control:
	var screen: Control = auto_free(SCREEN.instantiate())
	add_child(screen)
	return screen


func _dialog(screen: Control) -> PopupPanel:
	for child in screen.get_children():
		if child is PopupPanel and not child.is_queued_for_deletion():
			return child
	return null


func _row(screen: Control, perk_id: String) -> PanelContainer:
	for row in screen.get_node("%Perks").get_children():
		if row.perk_id == perk_id:
			return row
	return null


func _town_button(screen: Control, text: String) -> Button:
	for button: Button in screen.get_node("%Towns").get_children():
		if button.text == text:
			return button
	return null


func _town(id: String, town_name: String, charters_required: int) -> TownDefinition:
	var town := TownDefinition.new()
	town.id = id
	town.name = town_name
	town.charters_required = charters_required
	return town


func _perk(id: String, costs: Array) -> PerkDefinition:
	var perk := PerkDefinition.new()
	perk.id = id
	perk.name = "Test Perk"
	perk.description = "Testing."
	perk.effect = "loyalty_multiplier"
	for cost: int in costs:
		var level := PerkLevel.new()
		level.cost_points = cost
		level.value = 1.5
		perk.levels.append(level)
	return perk
