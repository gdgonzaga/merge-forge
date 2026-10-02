extends TestBase

# ShopSession's shop-level wiring: the XP each order earns (with the fulfil
# streak), the levels the summary reports, the crate buttons a mid-session
# level-up opens, and its GameManager connection.

const SHOP_SESSION := preload("res://shop/shop_session.tscn")
const MAX_FRAMES := 10
const CRATE_BUTTONS_PATH := "CustomerBox/ActionPanel/CratePanel/CrateButtonsPanel"

var _item: ItemDefinition


func before_test() -> void:
	super.before_test()
	set_definition(DefinitionLibrary.shop_rules, _rules(3))
	_item = ItemDefinition.new()
	_item.id = "__test_item"
	_item.name = "Test Item"
	_item.gold_value = 60
	set_definition(DefinitionLibrary.items, _item)
	set_definition(DefinitionLibrary.crates, _crate("__test_crate_l1", "Level One Crate", 1, _item))
	set_definition(DefinitionLibrary.customers, _customer(_item))


func test_each_order_earns_streak_xp_and_a_rejection_earns_none() -> void:
	set_definition(DefinitionLibrary.shop_rules, _rules(4))
	var session := _start_session()
	var earned: Array[int] = []
	earned.append(await _fulfil_next(session))
	earned.append(await _fulfil_next(session))
	var before_reject := GameManager.shop_xp
	session.reject_customer()
	earned.append(GameManager.shop_xp - before_reject)
	earned.append(await _fulfil_next(session))
	await _await_session_end(session)
	assert_array(earned).is_equal([30, 33, 0, 30])
	assert_int(GameManager.shop_xp).is_equal(93)
	assert_int(session.summary_data["xp_earned"]).is_equal(93)


func test_summary_reports_the_level_at_start_and_at_end() -> void:
	# 100, 110 and 120 XP: 330 in all, past level 3 (300).
	_item.gold_value = 200
	var session := _start_session()
	for _i in range(3):
		await _fulfil_next(session)
	await _await_session_end(session)
	assert_int(session.summary_data["level_before"]).is_equal(1)
	assert_int(session.summary_data["level_after"]).is_equal(3)


func test_crossing_a_level_mid_session_adds_its_crate_button_once() -> void:
	set_definition(DefinitionLibrary.crates, _crate("__test_crate_l2", "Level Two Crate", 2, null))
	_item.gold_value = 200
	var session := _start_session()
	await _await_crate_buttons_settled(session)
	var before := [_crate_buttons_named(session, "Level One Crate"), _crate_buttons_named(session, "Level Two Crate")]
	# 100 XP reaches level 2.
	await _fulfil_next(session)
	await _await_crate_buttons_settled(session)
	var after := [_crate_buttons_named(session, "Level One Crate"), _crate_buttons_named(session, "Level Two Crate")]
	assert_array(before).is_equal([1, 0])
	assert_int(GameManager.get_shop_level()).is_equal(2)
	assert_array(after).is_equal([1, 1])
	assert_int(_crate_buttons(session).get_child_count()).is_equal(2)


func test_shop_signage_raises_what_an_order_pays() -> void:
	var signage := UpgradeDefinition.new()
	signage.id = "__test_signage"
	signage.effect = "order_price"
	var level := UpgradeLevel.new()
	level.value = 1.5
	signage.levels = [level]
	set_definition(DefinitionLibrary.upgrades, signage)
	GameManager.raise_upgrade_level("__test_signage")
	var session := _start_session()
	var gold_before := GameManager.gold
	await _fulfil_next(session)
	# 60 x 1.5
	assert_int(GameManager.gold - gold_before).is_equal(90)


func test_freeing_the_session_drops_its_shop_level_connection() -> void:
	var before := GameManager.shop_level_changed.get_connections().size()
	var session: Control = SHOP_SESSION.instantiate()
	add_child(session)
	# Guards against a vacuous pass: the session does listen while it is up.
	assert_int(GameManager.shop_level_changed.get_connections().size()).is_equal(before + 1)
	session.queue_free()
	var frames := 0
	while is_instance_valid(session) and frames < MAX_FRAMES:
		await get_tree().process_frame
		frames += 1
	assert_bool(is_instance_valid(session)).is_false()
	assert_int(GameManager.shop_level_changed.get_connections().size()).is_equal(before)


func test_an_order_is_filled_from_the_shelf() -> void:
	_give_shelf(2)
	var session := _start_session()
	var shelf: Control = session.board.get_shelf_grid()
	shelf.place_item(RecipeResolver.make_item(_item), Vector2i(1, 0))
	session.try_fulfill_order(0)
	assert_int(session.current_index).is_equal(1)
	assert_int(shelf.count_items_on_board("__test_item")).is_equal(0)


func test_a_fulfil_is_saved_with_the_board_it_emptied() -> void:
	GameManager.shop_board_state = [{"col": 0, "row": 0, "item_id": "__test_item", "quality": 0}]
	var session := _start_session()
	session.try_fulfill_order(0)
	var saved: Dictionary = SaveManager.load_game_ex()["data"]
	assert_array(saved["shop_board_state"]).is_empty()
	assert_int(int(saved["gold"])).is_equal(110)


func test_a_crate_purchase_saves_its_gold_and_board_items_together() -> void:
	var session := _start_session()
	assert_bool(session.try_buy_crate("__test_crate_l1")).is_true()
	var saved: Dictionary = SaveManager.load_game_ex()["data"]
	assert_int(int(saved["gold"])).is_equal(40)
	var saved_board: Array = saved["shop_board_state"]
	assert_int(saved_board.size()).is_equal(1)
	if saved_board.is_empty():
		return
	assert_str(saved_board[0]["item_id"]).is_equal("__test_item")
	assert_int(session.board.get_staging_area().get_child_count()).is_equal(0)


func test_the_shelf_is_saved_at_the_end_of_the_session() -> void:
	set_definition(DefinitionLibrary.shop_rules, _rules(1))
	_give_shelf(2)
	var session := _start_session()
	session.board.get_shelf_grid().place_item(RecipeResolver.make_item(_item), Vector2i(1, 0))
	session.reject_customer()
	await _await_session_end(session)
	assert_array(GameManager.shop_shelf_state).is_equal([{"col": 1, "row": 0, "item_id": "__test_item", "quality": 0}])


# Spec Task 6: the shelf survives a save round trip and is back on the shelf
# when the next session starts.
func test_a_saved_shelf_is_restored_after_a_reload() -> void:
	_give_shelf(2)
	GameManager.shop_shelf_state = [{"col": 0, "row": 0, "item_id": "__test_item", "quality": 0}]
	var saved := GameManager.serialize()
	reset_game_state()
	GameManager.deserialize(saved)
	var session := _start_session()
	var shelf: Control = session.board.get_shelf_grid()
	assert_int(shelf.grid_cols).is_equal(2)
	assert_str(shelf.grid[0][0]["item_id"]).is_equal("__test_item")
	assert_int(session.board.count_sellable("__test_item")).is_equal(1)


func test_without_the_upgrade_the_shop_has_no_shelf() -> void:
	var session := _start_session()
	assert_int(session.board.get_shelf_grid().grid_cols).is_equal(0)


func test_a_fine_order_refuses_a_normal_item() -> void:
	set_definition(DefinitionLibrary.customers, _customer(_item, 1))
	var session := _start_session()
	session.board.get_board_grid().place_or_stage(RecipeResolver.make_item(_item, 0))
	session.try_fulfill_order(0)
	assert_int(session.current_index).is_equal(0)
	assert_int(session.board.count_sellable("__test_item")).is_equal(1)


func test_a_fine_order_takes_the_fine_item_and_keeps_the_masterwork() -> void:
	set_definition(DefinitionLibrary.customers, _customer(_item, 1))
	var session := _start_session()
	var grid: Control = session.board.get_board_grid()
	grid.grid[0][0] = RecipeResolver.make_item(_item, 2)
	grid.grid[2][2] = RecipeResolver.make_item(_item, 1)
	session.try_fulfill_order(0)
	assert_int(session.current_index).is_equal(1)
	assert_int(session.board.count_sellable("__test_item", 2)).is_equal(1)
	assert_int(session.board.count_sellable("__test_item")).is_equal(1)


func _start_session() -> Control:
	var session: Control = auto_free(SHOP_SESSION.instantiate())
	add_child(session)
	return session


# Puts the current order's item on the board, fulfils it and returns the XP
# it earned. Waits out the deferred advance so the next customer is up.
func _fulfil_next(session: Control) -> int:
	session.board.get_board_grid().place_or_stage(RecipeResolver.make_item(_item))
	var xp_before := GameManager.shop_xp
	var index_before: int = session.current_index
	session.try_fulfill_order(0)
	assert_int(session.current_index).is_equal(index_before + 1)
	await get_tree().process_frame
	return GameManager.shop_xp - xp_before


func _await_session_end(session: Control) -> void:
	var frames := 0
	while not session.summary_data.has("level_after") and frames < MAX_FRAMES:
		await get_tree().process_frame
		frames += 1
	assert_bool(session.summary_data.has("level_after")).is_true()


# A rebuild queue_frees the old buttons; wait until they are gone so a count
# sees only live ones.
func _await_crate_buttons_settled(session: Control) -> void:
	var frames := 0
	while _has_queued_child(_crate_buttons(session)) and frames < MAX_FRAMES:
		await get_tree().process_frame
		frames += 1
	assert_bool(_has_queued_child(_crate_buttons(session))).is_false()


func _has_queued_child(parent: Node) -> bool:
	for child in parent.get_children():
		if child.is_queued_for_deletion():
			return true
	return false


func _crate_buttons(session: Control) -> Container:
	return session.get_node(CRATE_BUTTONS_PATH)


func _crate_buttons_named(session: Control, crate_name: String) -> int:
	var count := 0
	for child: Button in _crate_buttons(session).get_children():
		if child.text.begins_with(crate_name + " ("):
			count += 1
	return count


# Level 2 at 100 XP, level 3 at 300.
func _rules(session_size: int) -> ShopRulesDefinition:
	var rules := ShopRulesDefinition.new()
	rules.id = "default"
	rules.session_size = session_size
	rules.xp_per_gold = 0.5
	rules.streak_step = 0.1
	rules.streak_cap = 0.5
	rules.level_xp_base = 100
	rules.level_xp_exponent = 1.0
	rules.max_level = 5
	return rules


func _crate(id: String, crate_name: String, level: int, item: ItemDefinition) -> CrateDefinition:
	var crate := CrateDefinition.new()
	crate.id = id
	crate.name = crate_name
	crate.cost = 10
	crate.min_shop_level = level
	if item != null:
		var entry := WeightedItem.new()
		entry.item = item
		crate.pool = [entry]
	return crate


func _customer(item: ItemDefinition, min_quality: int = 0) -> CustomerDefinition:
	var want := OrderTemplate.new()
	want.item = item
	want.min_quality = min_quality
	var customer := CustomerDefinition.new()
	customer.id = "__test_customer"
	customer.name = "Tester"
	customer.wants = [want]
	return customer


func _give_shelf(slots: int) -> void:
	var shelf := UpgradeDefinition.new()
	shelf.id = "__test_shelf"
	shelf.effect = "shelf_slots"
	var level := UpgradeLevel.new()
	level.value = slots
	shelf.levels = [level]
	set_definition(DefinitionLibrary.upgrades, shelf)
	GameManager.raise_upgrade_level("__test_shelf")


# --- towns ---

func test_a_crate_outside_the_town_gets_no_button() -> void:
	var away := _crate("__test_away_crate", "Away Crate", 1, _item)
	set_definition(DefinitionLibrary.crates, away)
	test_town.crates.erase(away)
	var session := _start_session()
	await _await_crate_buttons_settled(session)
	assert_int(_crate_buttons_named(session, "Away Crate")).is_equal(0)
	assert_int(_crate_buttons_named(session, "Level One Crate")).is_equal(1)


func test_the_shop_shows_the_towns_background() -> void:
	var backdrop := PlaceholderTexture2D.new()
	test_town.background = backdrop
	var session := _start_session()
	assert_object(session.get_node("%BG").texture).is_same(backdrop)
