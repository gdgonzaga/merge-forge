extends Control

var customers: Array[Dictionary] = []
var current_index: int = 0
var summary_data: Dictionary = {}

@onready var board: Control = $VBox/Board
@onready var _portrait_rect: TextureRect = $VBox/Customers/CurrentCustomer/PortraitWrapper/PortraitRect
@onready var _customer_label: Label = $VBox/Customers/CurrentCustomer/CustomerLabel
@onready var _remaining_label: Label = $VBox/RemainingLabel
@onready var _orders_container: VBoxContainer = $VBox/ActionPanel/OrderActionsContainer/OrdersContainer
@onready var _crate_panel: VBoxContainer = $VBox/ActionPanel/CratePanel
@onready var _crate_buttons: FlowContainer = $VBox/ActionPanel/CratePanel/CrateButtonsPanel
@onready var _reject_btn: Button = $VBox/ActionPanel/OrderActionsContainer/RejectBtn


func _ready() -> void:
	summary_data = {
		"gold_earned": 0,
		"items_sold": 0,
		"fulfilled": 0,
		"rejected": 0,
		"portraits": [],
	}

	var generator: RefCounted = load("res://shop/customer_generator.gd").new()
	customers = generator.generate_customers()

	AudioManager.play_sfx("session_start")

	for child in _orders_container.get_children():
		if child == _reject_btn:
			continue
		child.queue_free()
	for child in _crate_buttons.get_children():
		child.queue_free()

	board.setup({})
	if not GameManager.shop_board_state.is_empty():
		var board_grid = _get_board_grid()
		if board_grid:
			board_grid.load_board_state(GameManager.shop_board_state)

	_build_crate_buttons()
	_reject_btn.pressed.connect(reject_customer)
	advance_customer()


func _build_crate_buttons() -> void:
	var crate_ids: Array[String] = RecipeResolver.get_all_crate_ids()
	var crate_scene: PackedScene = load("res://shop/crate_button.tscn")
	for crate_id in crate_ids:
		var crate_data: Dictionary = RecipeResolver.get_crate_data(crate_id)
		var btn: Button = crate_scene.instantiate()
		var cost: int = int(crate_data.get("cost", 0) * GameManager.get_crate_discount())
		btn.text = "%s (%dg)" % [crate_data.get("name", crate_id), cost]
		btn.pressed.connect(try_buy_crate.bind(crate_id))
		_crate_buttons.add_child(btn)


func advance_customer() -> void:
	_clear_orders()

	if current_index >= customers.size():
		end_session()
		return

	var customer: Dictionary = customers[current_index]
	_display_customer(customer)


func try_fulfill_order(order_index: int) -> void:
	if current_index >= customers.size():
		return

	var customer: Dictionary = customers[current_index]
	var orders: Array = customer.get("orders", [])
	if order_index < 0 or order_index >= orders.size():
		return

	var order: Dictionary = orders[order_index]
	var item_id: String = order.get("item_id", "")
	var needed: int = order.get("quantity", 1)
	var board_ref = _get_board_grid()

	if board_ref == null:
		return

	var have: int = board_ref.count_items_on_board(item_id)
	if have < needed:
		for child in _orders_container.get_children():
			if child.has_method("flash_red") and child.get("order_index") == order_index:
				child.flash_red()
		return

	board_ref.remove_items_by_id(item_id, needed)
	var reward: int = order.get("gold_reward", 0)
	GameManager.add_gold(reward)
	GameManager.add_reputation(10)
	EventBus.customer_fulfilled.emit(order.get("item_id", ""))
	EventBus.save_requested.emit()

	summary_data["gold_earned"] = summary_data.get("gold_earned", 0) + reward
	summary_data["items_sold"] = summary_data.get("items_sold", 0) + needed
	summary_data["fulfilled"] = summary_data.get("fulfilled", 0) + 1
	summary_data["portraits"].append(customer.get("portrait_id", ""))

	current_index += 1
	advance_customer.call_deferred()


func reject_customer() -> void:
	if current_index >= customers.size():
		return

	GameManager.add_reputation(-2)
	var customer: Dictionary = customers[current_index]
	EventBus.customer_rejected.emit(customer.get("id", ""))
	EventBus.save_requested.emit()

	summary_data["rejected"] = summary_data.get("rejected", 0) + 1

	current_index += 1
	advance_customer()


func end_session() -> void:
	_clear_orders()
	if is_instance_valid(_customer_label):
		_customer_label.text = "Session Complete!"
	if is_instance_valid(_remaining_label):
		_remaining_label.text = ""
	if is_instance_valid(_portrait_rect):
		_portrait_rect.texture = null
	if is_instance_valid(_reject_btn):
		_reject_btn.disabled = true
		_reject_btn.visible = false

	var board_ref = _get_board_grid()
	if board_ref and is_instance_valid(board_ref):
		GameManager.shop_board_state = board_ref.get_board_state()

	EventBus.session_ended.emit(summary_data)


func try_buy_crate(crate_id: String) -> bool:
	if board and is_instance_valid(board):
		return board.buy_crate(crate_id)
	return false


func _display_customer(customer: Dictionary) -> void:
	var portrait_path: String = customer.get("portrait_id", "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		_portrait_rect.texture = load(portrait_path)
	else:
		_portrait_rect.texture = null

	# `name` would shadow Node.name, so use cust_name. Fall back to id, then a
	# literal, so a customer missing the new field still renders something.
	var cust_name: String = customer.get("name", customer.get("id", "Customer"))
	var role: String = customer.get("role", "")
	_customer_label.text = cust_name if role.is_empty() else "%s the %s" % [cust_name, role]
	_remaining_label.text = "Customer %d of %d" % [current_index + 1, customers.size()]

	_clear_orders()
	var orders: Array = customer.get("orders", [])
	var order_card_scene: PackedScene = load("res://shop/order_card.tscn")
	for i in range(orders.size()):
		var card: Control = order_card_scene.instantiate()
		_orders_container.add_child(card)
		card.setup(orders[i], i)
		card.order_tapped.connect(try_fulfill_order)

	_reject_btn.disabled = false
	_reject_btn.visible = true


func _clear_orders() -> void:
	for child in _orders_container.get_children():
		if child == _reject_btn:
			continue
		child.queue_free()


func _get_board_grid() -> Node:
	if board == null:
		return null
	return board.get_board_grid()
