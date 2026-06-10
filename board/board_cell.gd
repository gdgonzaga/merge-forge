extends Control

signal cell_drag_started(from_pos: Vector2i, item: Dictionary)
signal cell_drag_ended(from_pos: Vector2i, to_pos: Vector2i)

var grid_pos: Vector2i = Vector2i(-1, -1)
var item: Dictionary = {}

var _icon: TextureRect
var _bg: ColorRect


func _ready() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.2, 0.2, 0.25)
	_bg.size = size
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_icon = TextureRect.new()
	_icon.size = size * 0.8
	_icon.position = size * 0.1
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.visible = false
	add_child(_icon)


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
