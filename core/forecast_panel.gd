extends VBoxContainer

# The next shop session as prep sees it: the market modifier, the share of
# orders per item family and the first customers in the queue.

const PORTRAIT_SIZE := 200
const ROW_FONT_SIZE := 40
const NAME_FONT_SIZE := 32
const ORDER_FONT_SIZE := 32
const BODY_FONT := preload("res://resources/fonts/ModernAntiqua-Regular.ttf")

@onready var _modifier_card: PanelContainer = %ModifierCard
@onready var _modifier_icon: TextureRect = %ModifierIcon
@onready var _modifier_name: Label = %ModifierName
@onready var _modifier_description: Label = %ModifierDescription
@onready var _demand_list: VBoxContainer = %DemandList
@onready var _customers_title: Label = %CustomersTitle
@onready var _portraits: HFlowContainer = %CustomerPortraits
@onready var _empty_label: Label = %EmptyLabel


# reveal_count <= 0 reveals every customer, with their orders (Town Crier's
# top level).
func setup(plan: SessionPlan, reveal_count: int) -> void:
	_show_modifier(plan.modifier)
	_show_demand(plan.family_demand())
	var reveal_all := reveal_count <= 0
	_customers_title.text = "All customers" if reveal_all else "First customers"
	var revealed: Array[ShopCustomer] = plan.customers if reveal_all else plan.customers.slice(0, reveal_count)
	_show_customers(revealed, reveal_all)
	_empty_label.visible = plan.customers.is_empty()


func _show_modifier(modifier: SessionModifierDefinition) -> void:
	_modifier_card.visible = modifier != null
	if modifier == null:
		return
	_modifier_icon.texture = modifier.sprite
	_modifier_icon.visible = modifier.sprite != null
	_modifier_name.text = modifier.name
	_modifier_description.text = modifier.description


func _show_demand(demand: Array[Dictionary]) -> void:
	_clear(_demand_list)
	for entry in demand:
		var family: String = entry["family"]
		var row := _label("%s %d%%" % ["Other" if family.is_empty() else family.capitalize(), roundi(entry["share"] * 100.0)], ROW_FONT_SIZE)
		_demand_list.add_child(row)


func _show_customers(customers: Array[ShopCustomer], show_orders: bool) -> void:
	_clear(_portraits)
	for customer in customers:
		var column := VBoxContainer.new()
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
		portrait.texture = customer.definition.sprite
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		column.add_child(portrait)
		var name_label := _label(customer.definition.name, NAME_FONT_SIZE)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name_label)
		if show_orders:
			for order in customer.orders:
				var order_label := _label("%dx %s" % [order.quantity, order.item.name_at_quality(order.min_quality)], ORDER_FONT_SIZE)
				order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				order_label.custom_minimum_size.x = PORTRAIT_SIZE
				order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				column.add_child(order_label)
		_portraits.add_child(column)


func _label(text: String, _font_size: int = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", BODY_FONT)
	return label


# queue_free, so rows vanish at the end of the frame; remove_child first so a
# setup() in the same frame doesn't count or show the old ones.
func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
