extends TestBase

# The forecast panel shows a SessionPlan: the modifier card, demand by family
# and the first customers. Plans are built from fixtures.

const PANEL := preload("res://core/forecast_panel.tscn")

var _panel: VBoxContainer


func before_test() -> void:
	super.before_test()
	_panel = auto_free(PANEL.instantiate())
	add_child(_panel)


func test_a_rolled_modifier_shows_its_card() -> void:
	var modifier := SessionModifierDefinition.new()
	modifier.id = "__test_fair"
	modifier.name = "Test Fair"
	modifier.description = "Everything is cheap."
	_panel.setup(SessionPlan.new().setup(_customers(1), modifier), 3)
	assert_bool(_panel.get_node("%ModifierCard").visible).is_true()
	assert_str(_panel.get_node("%ModifierName").text).is_equal("Test Fair")
	assert_str(_panel.get_node("%ModifierDescription").text).is_equal("Everything is cheap.")


func test_no_modifier_hides_the_card() -> void:
	_panel.setup(SessionPlan.new().setup(_customers(1), null), 3)
	assert_bool(_panel.get_node("%ModifierCard").visible).is_false()


func test_demand_rows_read_family_and_percent_largest_first() -> void:
	var herb := _item("__test_herb", "herb")
	var ore := _item("__test_ore", "metal")
	var customers: Array[ShopCustomer] = [_customer_wanting([herb, ore]), _customer_wanting([herb]), _customer_wanting([herb])]
	_panel.setup(SessionPlan.new().setup(customers, null), 3)
	await get_tree().process_frame
	var rows: Array[String] = []
	for row: Label in _panel.get_node("%DemandList").get_children():
		rows.append(row.text)
	assert_array(rows).is_equal(["Herb 75%", "Metal 25%"])


func test_reveals_at_most_the_reveal_count() -> void:
	_panel.setup(SessionPlan.new().setup(_customers(5), null), 3)
	await get_tree().process_frame
	assert_int(_panel.get_node("%CustomerPortraits").get_child_count()).is_equal(3)
	_panel.setup(SessionPlan.new().setup(_customers(2), null), 3)
	await get_tree().process_frame
	assert_int(_panel.get_node("%CustomerPortraits").get_child_count()).is_equal(2)


func test_empty_plan_shows_the_empty_message() -> void:
	_panel.setup(SessionPlan.new().setup(_customers(0), null), 3)
	await get_tree().process_frame
	assert_bool(_panel.get_node("%EmptyLabel").visible).is_true()
	assert_int(_panel.get_node("%CustomerPortraits").get_child_count()).is_equal(0)
	assert_int(_panel.get_node("%DemandList").get_child_count()).is_equal(0)


func _item(id: String, family: String) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = id
	item.family = family
	return item


func _customer_wanting(items: Array) -> ShopCustomer:
	var orders: Array[OrderDefinition] = []
	for item: ItemDefinition in items:
		var order := OrderDefinition.new()
		order.item = item
		order.quantity = 1
		orders.append(order)
	var archetype := CustomerDefinition.new()
	archetype.name = "Test"
	return ShopCustomer.new().setup(archetype, orders)


func _customers(count: int) -> Array[ShopCustomer]:
	var result: Array[ShopCustomer] = []
	for _i in range(count):
		result.append(_customer_wanting([_item("__test_ore", "metal")]))
	return result
