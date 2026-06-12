extends Control

signal cell_drag_started(from_pos: Vector2i, item: Dictionary)
signal cell_drag_ended(from_pos: Vector2i, to_pos: Vector2i)

var grid_pos: Vector2i = Vector2i(-1, -1)
var item: Dictionary = {}

@onready var _icon: TextureRect = $Icon
@onready var _bg: ColorRect = $BG


func set_item(item_data: Dictionary) -> void:
	item = item_data
	if _icon == null:
		return
	if item_data.is_empty():
		_icon.visible = false
		return
	_apply_icon()


func clear_item() -> void:
	item = {}
	if _icon != null:
		_icon.visible = false


func get_icon_texture() -> Texture2D:
	if _icon != null and _icon.visible:
		return _icon.texture
	return null


func flash() -> void:
	if _bg:
		var orig := _bg.color
		_bg.color = Color(0.9, 0.85, 0.3)
		var tween := create_tween()
		tween.tween_property(_bg, "color", orig, 0.35)


func _apply_icon() -> void:
	var icon_path: String = item.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_icon.texture = load(icon_path)
		_icon.visible = true
	else:
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
	var drag_info := item.duplicate()
	drag_info["_source_pos"] = grid_pos
	return drag_info


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("item_id")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("item_id"):
		var from_pos: Vector2i = data.get("_source_pos", Vector2i(-1, -1))
		cell_drag_ended.emit(from_pos, grid_pos)
