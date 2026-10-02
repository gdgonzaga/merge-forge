extends TestBase

const SHOP_SESSION := preload("res://shop/shop_session.tscn")

var _item: ItemDefinition


func before_test() -> void:
	super.before_test()
	set_definition(DefinitionLibrary.shop_rules, _rules(4))
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


func test_a_normal_order_earns_one_point_and_a_quality_order_two() -> void:
	set_definition(DefinitionLibrary.customers, _customer(0, [_gift(9, "Friend", 40)]))
	var session := _start_session()
	await _fulfil_next(session, 0)
	assert_int(GameManager.get_loyalty("__test_customer")).is_equal(1)
	set_definition(DefinitionLibrary.customers, _customer(1, [_gift(9, "Friend", 40)]))
	var quality_session := _start_session()
	await _fulfil_next(quality_session, 1)
	assert_int(GameManager.get_loyalty("__test_customer")).is_equal(3)


func test_reaching_a_threshold_gives_its_gift_once() -> void:
	set_definition(DefinitionLibrary.customers, _customer(0, [_gift(2, "Friend", 40)]))
	var session := _start_session()
	await _fulfil_next(session, 0)
	var gold_before := GameManager.gold
	await _fulfil_next(session, 0)
	assert_int(GameManager.gold - gold_before).is_equal(100)
	gold_before = GameManager.gold
	await _fulfil_next(session, 0)
	assert_int(GameManager.gold - gold_before).is_equal(60)
	assert_array(session.summary_data["notes"]).is_equal(["Tester gives you: 40 gold"])


func test_an_archetype_without_a_track_earns_no_loyalty() -> void:
	set_definition(DefinitionLibrary.customers, _customer(0, []))
	var session := _start_session()
	await _fulfil_next(session, 0)
	assert_dict(GameManager.regular_loyalty).is_empty()
	assert_bool(session.get_node("%LoyaltyLabel").visible).is_false()


func test_the_loyalty_line_shows_progress_then_the_title() -> void:
	set_definition(DefinitionLibrary.customers, _customer(0, [_gift(1, "Friend", 40), _gift(3, "Old Friend", 40)]))
	var session := _start_session()
	var label: Label = session.get_node("%LoyaltyLabel")
	assert_str(label.text).is_equal("Loyalty 0/1")
	await _fulfil_next(session, 0)
	assert_str(label.text).is_equal("Friend · Loyalty 1/3")
	await _fulfil_next(session, 0)
	await _fulfil_next(session, 0)
	assert_str(label.text).is_equal("Old Friend · Loyalty max")


# The gift check must read the loyalty after the perk multiplies it.
func test_a_loyalty_perk_reaches_gifts_sooner() -> void:
	var perk := PerkDefinition.new()
	perk.id = "__test_good_name"
	perk.effect = "loyalty_multiplier"
	var level := PerkLevel.new()
	level.cost_points = 1
	level.value = 2.0
	perk.levels = [level]
	set_definition(DefinitionLibrary.perks, perk)
	GameManager.perk_levels["__test_good_name"] = 1
	set_definition(DefinitionLibrary.customers, _customer(0, [_gift(2, "Friend", 40)]))
	var session := _start_session()
	var gold_before := GameManager.gold
	await _fulfil_next(session, 0)
	# One normal order: 1 point x 2.0 reaches the gift at 2. Order 60 + gift 40.
	assert_int(GameManager.get_loyalty("__test_customer")).is_equal(2)
	assert_int(GameManager.gold - gold_before).is_equal(100)


func _start_session() -> Control:
	var session: Control = auto_free(SHOP_SESSION.instantiate())
	add_child(session)
	return session


func _fulfil_next(session: Control, quality: int) -> void:
	session.board.get_board_grid().place_or_stage(RecipeResolver.make_item(_item, quality))
	var index_before: int = session.current_index
	session.try_fulfill_order(0)
	assert_int(session.current_index).is_equal(index_before + 1)
	await get_tree().process_frame


func _customer(min_quality: int, gifts: Array) -> CustomerDefinition:
	var want := OrderTemplate.new()
	want.item = _item
	want.min_quality = min_quality
	var customer := CustomerDefinition.new()
	customer.id = "__test_customer"
	customer.name = "Tester"
	customer.wants = [want]
	customer.loyalty_rewards.assign(gifts)
	return customer


func _gift(points: int, title: String, gold: int) -> LoyaltyReward:
	var gift := LoyaltyReward.new()
	gift.points = points
	gift.title = title
	gift.gold = gold
	return gift


func _rules(session_size: int) -> ShopRulesDefinition:
	var rules := ShopRulesDefinition.new()
	rules.id = "default"
	rules.session_size = session_size
	rules.level_xp_base = 100000
	rules.level_xp_exponent = 1.0
	rules.max_level = 5
	return rules
