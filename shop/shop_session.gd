extends Control

var customers: Array[Dictionary] = []
var current_index: int = 0
var board: Control
var summary_data: Dictionary = {}

var _customer_display: VBoxContainer
var _portrait_rect: TextureRect
var _customer_label: Label
var _orders_container: VBoxContainer
var _crate_panel: VBoxContainer
var _reject_btn: Button
var _remaining_label: Label
var _popup: PopupPanel
var _choice_callback: Callable
var _generator: RefCounted


func _ready() -> void:
	summary_data = {
		"gold_earned": 0,
		"items_sold": 0,
		"fulfilled": 0,
		"rejected": 0,
		"portraits": [],
	}

	_generator = load("res://shop/customer_generator.gd").new()
	customers = _generator.generate_customers(GameManager.reputation_points)

	_build_layout()

	var popup_scene: PackedScene = load("res://board/merge_choice_popup.tscn")
	_popup = popup_scene.instantiate()
	add_child(_popup)
	_popup.choice_made.connect(_on_choice_from_popup)

	advance_customer()


func _build_layout() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	_customer_display = VBoxContainer.new()
	_customer_display.custom_minimum_size = Vector2(220, 0)
	_customer_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_customer_display)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(200, 200)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_customer_display.add_child(_portrait_rect)

	_customer_label = Label.new()
	_customer_label.add_theme_font_size_override("font_size", 20)
	_customer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_customer_display.add_child(_customer_label)

	_remaining_label = Label.new()
	_remaining_label.add_theme_font_size_override("font_size", 16)
	_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_remaining_label.modulate = Color(0.7, 0.7, 0.7)
	_customer_display.add_child(_remaining_label)

	_orders_container = VBoxContainer.new()
	_orders_container.add_theme_constant_override("separation", 8)
	_orders_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_customer_display.add_child(_orders_container)

	_reject_btn = Button.new()
	_reject_btn.text = "Reject (-2 rep)"
	_reject_btn.add_theme_font_size_override("font_size", 18)
	_reject_btn.pressed.connect(reject_customer)
	_customer_display.add_child(_reject_btn)

	var merge_board_scene: PackedScene = load("res://board/merge_board.tscn")
	board = merge_board_scene.instantiate()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(board)

	var cell_scene: PackedScene = load("res://board/board_cell.tscn")
	board.setup({
		"cols": GameManager.grid_cols,
		"rows": GameManager.grid_rows,
		"cell_scene": cell_scene,
		"popup_callback": _on_merge_choice_requested,
		"despawn_time": GameManager.get_despawn_time(),
	})

	if not GameManager.shop_board_state.is_empty():
		var board_grid = _get_board_grid()
		if board_grid:
			board_grid.load_board_state(GameManager.shop_board_state)

	_crate_panel = VBoxContainer.new()
	_crate_panel.custom_minimum_size = Vector2(220, 0)
	_crate_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_crate_panel)

	var crate_title := Label.new()
	crate_title.text = "Crates"
	crate_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crate_title.add_theme_font_size_override("font_size", 20)
	_crate_panel.add_child(crate_title)

	var crate_ids: Array[String] = RecipeResolver.get_all_crate_ids()
	for crate_id in crate_ids:
		var crate_data: Dictionary = RecipeResolver.get_crate_data(crate_id)
		var btn := Button.new()
		var cost: int = int(crate_data.get("cost", 0) * GameManager.get_crate_discount())
		btn.text = "%s (%dg)" % [crate_data.get("name", crate_id), cost]
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(try_buy_crate.bind(crate_id))
		_crate_panel.add_child(btn)


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
	var crate_data: Dictionary = RecipeResolver.get_crate_data(crate_id)
	if crate_data.is_empty():
		return false
	var cost: int = int(crate_data.get("cost", 0) * GameManager.get_crate_discount())
	if not GameManager.deduct_gold(cost):
		return false

	var board_grid = _get_board_grid()
	var staging = _get_staging()
	var pool: Array = crate_data.get("pool", [])
	var item_count: Dictionary = crate_data.get("item_count", {"min": 1, "max": 1})
	for entry in RecipeResolver.roll_weighted_pool(pool, item_count):
		var data: Dictionary = RecipeResolver.get_item_data(entry.get("item_id", ""))
		if data.is_empty():
			continue
		if board_grid and is_instance_valid(board_grid):
			if not board_grid.place_or_stage(data):
				_spawn_to_staging(data, staging)
		elif staging and is_instance_valid(staging):
			_spawn_to_staging(data, staging)
	EventBus.save_requested.emit()
	return true


func _display_customer(customer: Dictionary) -> void:
	var portrait_path: String = customer.get("portrait_id", "")
	if portrait_path != "" and FileAccess.file_exists(portrait_path):
		_portrait_rect.texture = load(portrait_path)
	else:
		_portrait_rect.texture = null

	_customer_label.text = customer.get("id", "Customer")
	var remaining := customers.size() - current_index
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
		child.queue_free()


func _get_board_grid() -> Node:
	if board == null:
		return null
	return board.get_node_or_null("VBox/BoardArea/CenterContainer/BoardGrid")


func _get_staging() -> Node:
	if board == null:
		return null
	return board.get_node_or_null("VBox/StagingArea")


func _spawn_to_staging(data: Dictionary, staging: Node) -> void:
	if staging == null or not is_instance_valid(staging):
		return
	var fi: Control = load("res://board/floating_item.tscn").instantiate()
	fi.setup(data, GameManager.get_despawn_time())
	fi.despawn_timeout.connect(fi.queue_free)
	staging.add_child(fi)


func _on_merge_choice_requested(options: Array[Dictionary], callback: Callable) -> void:
	_choice_callback = callback
	_popup.call("show_options", options)
	_popup.popup_centered()


func _on_choice_from_popup(item_id: String, is_variant: bool, reagent_id: String) -> void:
	if _choice_callback.is_valid():
		_choice_callback.call(item_id, is_variant, reagent_id)
