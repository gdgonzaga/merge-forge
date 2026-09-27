extends PanelContainer

signal order_tapped(order_index: int)

var order: OrderDefinition
var order_index: int = -1

@onready var _icon: TextureRect = $HBox/Icon
@onready var _qty_label: Label = $HBox/QtyLabel
@onready var _reward_label: Label = $HBox/RewardLabel

var _flash_tween: Tween
var _pending_setup: bool = false


func setup(order_def: OrderDefinition, index: int) -> void:
	order = order_def
	order_index = index
	if _qty_label == null:
		_pending_setup = true
		return
	_apply_data()


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	if _pending_setup:
		_apply_data()


func _apply_data() -> void:
	_icon.texture = order.item.sprite
	_qty_label.text = "x%d" % order.quantity
	_reward_label.text = "%dg" % order.gold_reward


func flash_red() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color(1, 0.3, 0.3), 0.15)
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	_flash_tween.tween_property(self, "modulate", Color(1, 0.3, 0.3), 0.15)
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.15)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		order_tapped.emit(order_index)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		order_tapped.emit(order_index)
