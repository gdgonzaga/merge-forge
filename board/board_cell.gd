extends Control

signal cell_drag_started(from_pos: Vector2i, item: Dictionary)
signal cell_drag_ended(from_pos: Vector2i, to_pos: Vector2i)

var grid_pos: Vector2i = Vector2i(-1, -1)
var item: Dictionary = {}

@onready var _icon: TextureRect = $Icon
@onready var _bg: ColorRect = $BG


func set_item(item_data: Dictionary) -> void:
	item = item_data
	if item_data.is_empty():
		_icon.visible = false
		return
	var icon_path: String = item_data.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_icon.texture = load(icon_path)
		_icon.visible = true
	else:
		_icon.visible = false


func clear_item() -> void:
	item = {}
	_icon.visible = false


func _get_drag_data(at_position: Vector2) -> Variant:
	if item.is_empty():
		return null
	var preview := ColorRect.new()
	preview.size = Vector2(48, 48)
	preview.color = Color(0.6, 0.6, 0.7, 0.8)
	var label := Label.new()
	label.text = item.get("name", "?")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = preview.size
	preview.add_child(label)
	set_drag_preview(preview)
	preview.position = Vector2(0, -50)
	cell_drag_started.emit(grid_pos, item)
	return item


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("item_id"):
		return true
	return false


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("item_id"):
		cell_drag_ended.emit(Vector2i(-1, -1), grid_pos)
