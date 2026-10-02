extends Button

signal order_tapped(order_index: int)

var order: OrderDefinition
var order_index: int = -1

@onready var _hbox: HBoxContainer = $HBox
@onready var _icon: TextureRect = $HBox/Icon
@onready var _stars: Control = %QualityStars
@onready var _qty_label: Label = $HBox/QtyLabel
@onready var _reward_label: Label = $HBox/RewardLabel

var _flash_tween: Tween
var _glow_tween: Tween
var _pending_setup: bool = false


func setup(order_def: OrderDefinition, index: int) -> void:
	order = order_def
	order_index = index
	if _qty_label == null:
		_pending_setup = true
		return
	_apply_data()


func _ready() -> void:
	pressed.connect(_on_pressed)
	if _pending_setup:
		_apply_data()
	_update_disabled_visuals()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW:
		_update_disabled_visuals()


func _update_disabled_visuals() -> void:
	if _hbox != null and is_instance_valid(_hbox):
		_hbox.modulate = Color(0.7, 0.7, 0.7, 0.85) if disabled else Color.WHITE
	if disabled:
		if _glow_tween != null:
			_glow_tween.kill()
			_glow_tween = null
		self_modulate = Color.WHITE


func update_disabled_state() -> void:
	_update_disabled_visuals()


func play_glow() -> void:
	if not is_inside_tree():
		return
	if _glow_tween != null:
		_glow_tween.kill()
	self_modulate = Color(1.35, 1.3, 0.75)
	_glow_tween = create_tween()
	_glow_tween.tween_property(self, "self_modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _apply_data() -> void:
	_icon.texture = order.item.sprite
	_stars.set_quality(order.min_quality)
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


func _gui_input(event: InputEvent) -> void:
	if disabled:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			flash_red()


func _on_pressed() -> void:
	order_tapped.emit(order_index)
