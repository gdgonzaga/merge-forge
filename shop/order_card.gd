extends PanelContainer

signal order_tapped(order_index: int)

var order_data: Dictionary = {}
var order_index: int = -1

@onready var _icon: TextureRect = $HBox/Icon
@onready var _qty_label: Label = $HBox/QtyLabel
@onready var _reward_label: Label = $HBox/RewardLabel

var _flash_tween: Tween
var _pending_setup: bool = false


func setup(data: Dictionary, index: int) -> void:
	order_data = data
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
	var item_id: String = order_data.get("item_id", "")
	var item_info: Dictionary = RecipeResolver.get_item_data(item_id)
	var spr = item_info.get("sprite", item_info.get("icon", null))
	if spr is Texture2D:
		_icon.texture = spr
	elif spr is String and spr != "" and ResourceLoader.exists(spr):
		_icon.texture = load(spr)
	_qty_label.text = "x%d" % order_data.get("quantity", 1)
	_reward_label.text = "%dg" % order_data.get("gold_reward", 0)


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
