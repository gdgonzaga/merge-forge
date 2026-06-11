extends Control

signal order_tapped(order_index: int)

var order_data: Dictionary = {}
var order_index: int = -1

var _icon: TextureRect
var _qty_label: Label
var _reward_label: Label
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
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(48, 48)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_icon)

	_qty_label = Label.new()
	_qty_label.add_theme_font_size_override("font_size", 20)
	_qty_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_qty_label)

	_reward_label = Label.new()
	_reward_label.add_theme_font_size_override("font_size", 20)
	_reward_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reward_label.modulate = Color(1, 0.84, 0)
	hbox.add_child(_reward_label)

	gui_input.connect(_on_gui_input)

	if _pending_setup:
		_apply_data()


func _apply_data() -> void:
	var item_id: String = order_data.get("item_id", "")
	var item_info: Dictionary = RecipeResolver.get_item_data(item_id)
	var icon_path: String = item_info.get("icon", "")
	if icon_path != "" and FileAccess.file_exists(icon_path):
		_icon.texture = load(icon_path)
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
