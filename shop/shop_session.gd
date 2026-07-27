extends Control

const PORTRAIT_SIZE := 200
# Per-position shadow alpha step. Denominator is the INITIAL pending count
# (session_count - 1), fixed for the whole session: position 0 (next customer)
# gets no shadow, the back gets ~(step * initial_pending) which tops out
# near-but-not-100% (e.g. 8 * 11.1% = 89%). The whole stack fades lighter as
# the queue shrinks, since position is the renumbered (current) index.
const SHADOW_ALPHA_STEP := 100.0 / 9.0 / 100.0  # 0.0..1.0 scale, ~= 0.111

var customers: Array[Dictionary] = []
var current_index: int = 0
var summary_data: Dictionary = {}

@onready var board: Control = $CustomerBox/Board
@onready var _portrait_rect: TextureRect = $CustomerBox/CustomerAndLabels/Customers/CurrentCustomer/PortraitWrapper/PortraitRect
@onready var _customer_label: Label = $CustomerBox/CustomerAndLabels/CustomerLabels/CustomerLabel
@onready var _remaining_label: Label = $CustomerBox/CustomerAndLabels/CustomerLabels/RemainingLabel
@onready var _orders_container: VBoxContainer = $CustomerBox/ActionPanel/OrderActionsContainer/OrdersContainer
@onready var _crate_panel: VBoxContainer = $CustomerBox/ActionPanel/CratePanel
@onready var _crate_buttons: FlowContainer = $CustomerBox/ActionPanel/CratePanel/CrateButtonsPanel
@onready var _reject_btn: Button = $CustomerBox/ActionPanel/OrderActionsContainer/RejectBtn
@onready var _pending_content: Control = $CustomerBox/CustomerAndLabels/Customers/PendingCustomers/Content


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
	# PendingCustomers lays out after _ready, so its Content.size.x is 0 here.
	# The resized signal fires once layout assigns a real width, and again on
	# any viewport resize — both reposition the portrait stack. advance_customer
	# also calls _populate_queue directly so the stack updates the instant a
	# customer is dealt with, not waiting for a resize.
	_pending_content.resized.connect(_populate_queue)
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
	# Refresh the pending-portrait stack on every advance (fulfill/reject/end).
	# Safe to call before the end-of-session branch: an empty pending slice
	# just clears the stack.
	_populate_queue()

	if current_index >= customers.size():
		end_session()
		return

	var customer: Dictionary = customers[current_index]
	_display_customer(customer)


# Pending customer portrait stack: shows customers[current_index+1 ..] as
# overlapping 200x200 portraits. Position 0 (next customer) sits at x=0 and
# renders on top; the back of the queue recedes to the right, peeking out
# behind. The whole stack contracts leftward as customers are dealt with
# (the right edge marches left while the left edge stays anchored at 0).
func _populate_queue() -> void:
	if _pending_content == null:
		return
	# Idempotent: clear previous portraits before rebuilding. Safe to call
	# repeatedly (resized signal, advance_customer) without duplicating.
	for child in _pending_content.get_children():
		child.queue_free()

	# Pending = everyone after the current customer (excludes current + past).
	var pending := customers.slice(current_index + 1)
	if pending.is_empty():
		return
	# Width is 0 until the container's first layout pass; the resized signal
	# re-invokes us once a real width exists.
	var width: float = _pending_content.size.x
	if width <= 0.0:
		return

	# Spacing is constant across the session (denominator is total session
	# size, not pending size), so the right edge contracts as the queue empties.
	var total_in_session: int = customers.size()
	var spacing: float = (width - float(PORTRAIT_SIZE)) / float(total_in_session)

	# Add back-of-queue first so the front (position 0) is added last and thus
	# drawn on top — gives the "stacked behind" depth.
	var n: int = pending.size()
	for i in range(n - 1, -1, -1):
		var customer: Dictionary = pending[i]
		# i is the index into `pending`; position 0 == next customer.
		var portrait: TextureRect = _build_queue_portrait(customer, i)
		portrait.position = Vector2(spacing * float(i), 0.0)
		_pending_content.add_child(portrait)


func _build_queue_portrait(customer: Dictionary, position: int) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	var portrait_path: String = customer.get("portrait_id", "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Shadow: same texture as the portrait, tinted black, alpha-scaled by
	# position. Because it uses the SAME texture, its alpha channel exactly
	# matches the character's silhouette — the shadow is portrait-shaped
	# automatically, no shader needed. Child of the portrait at position (0,0)
	# with explicit size (anchors_preset in code corrupts the node and the
	# shadow never renders; explicit size is the reliable path). mouse_filter
	# IGNORE so it doesn't eat taps.
	if portrait.texture != null and position > 0:
		var shadow := TextureRect.new()
		shadow.texture = portrait.texture
		shadow.stretch_mode = portrait.stretch_mode
		shadow.expand_mode = portrait.expand_mode
		shadow.modulate = Color.BLACK
		shadow.modulate.a = SHADOW_ALPHA_STEP * float(position)
		shadow.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
		shadow.position = Vector2.ZERO
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.add_child(shadow)
	return portrait


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
