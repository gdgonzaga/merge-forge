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


func test_revealing_everyone_shows_every_customer_with_their_orders() -> void:
	var herb := _item("__test_herb", "herb")
	herb.name = "Test Herb"
	var customers: Array[ShopCustomer] = []
	for _i in range(5):
		customers.append(_customer_wanting([herb]))
	customers[0].orders[0].quantity = 2
	_panel.setup(SessionPlan.new().setup(customers, null), 0)
	await get_tree().process_frame
	var columns: Array[Node] = _panel.get_node("%CustomerPortraits").get_children()
	assert_int(columns.size()).is_equal(5)
	assert_array(_labels_in(columns[0])).contains(["2x Test Herb"])
	assert_array(_labels_in(columns[4])).contains(["1x Test Herb"])


func test_revealed_orders_name_the_required_quality() -> void:
	var sword := _item("__test_sword", "weapon")
	sword.name = "Sword"
	var fine_order := OrderDefinition.new()
	fine_order.item = sword
	fine_order.quantity = 2
	fine_order.min_quality = 1
	var normal_order := OrderDefinition.new()
	normal_order.item = sword
	normal_order.quantity = 2
	var archetype := CustomerDefinition.new()
	archetype.name = "Test"
	var customers: Array[ShopCustomer] = [
		ShopCustomer.new().setup(archetype, [fine_order]),
		ShopCustomer.new().setup(archetype, [normal_order]),
	]
	_panel.setup(SessionPlan.new().setup(customers, null), 0)
	await get_tree().process_frame
	var columns: Array[Node] = _panel.get_node("%CustomerPortraits").get_children()
	assert_array(_labels_in(columns[0])).contains(["2x Fine Sword"])
	assert_array(_labels_in(columns[1])).contains(["2x Sword"])


func test_a_partial_reveal_shows_no_orders() -> void:
	var herb := _item("__test_herb", "herb")
	herb.name = "Test Herb"
	_panel.setup(SessionPlan.new().setup([_customer_wanting([herb])], null), 3)
	await get_tree().process_frame
	var column: Node = _panel.get_node("%CustomerPortraits").get_child(0)
	assert_array(_labels_in(column)).not_contains(["1x Test Herb"])


func _labels_in(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for label in node.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	return texts


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
