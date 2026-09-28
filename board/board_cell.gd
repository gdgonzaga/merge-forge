extends Control

signal cell_drag_started(from_pos: Vector2i, item: Dictionary)
signal cell_drag_ended(to_pos: Vector2i, drag_data: Dictionary)

const QUALITY_STARS := preload("res://ui/quality_stars.tscn")

var grid_pos: Vector2i = Vector2i(-1, -1)
var item: Dictionary = {}
# The BoardGrid this cell belongs to; drags carry it so a drop on another grid
# (board to shelf) knows where the item came from.
var grid_owner: Control = null

@onready var _icon: TextureRect = $Icon
@onready var _bg: TextureRect = $BG
@onready var _stars: Control = %QualityStars


func set_item(item_data: Dictionary) -> void:
	item = item_data
	if _icon == null:
		return
	if item_data.is_empty():
		_icon.visible = false
		_stars.set_quality(0)
		return
	_apply_icon()


func clear_item() -> void:
	item = {}
	if _icon != null:
		_icon.visible = false
	if _stars != null:
		_stars.set_quality(0)


func get_icon_texture() -> Texture2D:
	if _icon != null and _icon.visible:
		return _icon.texture
	return null


func flash() -> void:
	if _bg:
		var orig := _bg.modulate
		_bg.modulate = Color(0.9, 0.85, 0.3)
		var tween := create_tween()
		tween.tween_property(_bg, "modulate", orig, 0.35)


func _apply_icon() -> void:
	_icon.texture = item["definition"].sprite
	_icon.visible = true
	_stars.set_quality(item["quality"])


func _get_drag_data(at_position: Vector2) -> Variant:
	if item.is_empty():
		return null
	var preview := TextureRect.new()
	preview.size = Vector2(96, 96)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.texture = item["definition"].sprite
	_add_quality_preview(preview, item["quality"])
	set_drag_preview(preview)
	preview.position = Vector2(-14, -100)
	cell_drag_started.emit(grid_pos, item)
	return make_drag_data()


# Mirrors the cell's own top-right star badge, so a Fine or Masterwork item
# doesn't look Normal while it's being dragged.
func _add_quality_preview(preview: TextureRect, quality: int) -> void:
	if quality <= 0:
		return
	var stars: Control = QUALITY_STARS.instantiate()
	preview.add_child(stars)
	stars.set_quality(quality)
	stars.set_anchors_preset(Control.PRESET_TOP_RIGHT)


func make_drag_data() -> Dictionary:
	var drag_info := item.duplicate()
	drag_info["_source_pos"] = grid_pos
	drag_info["_source_grid"] = grid_owner
	drag_info["_source_screen"] = global_position + size / 2.0
	return drag_info


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("item_id")


# The data travels with the signal: get_viewport().gui_get_drag_data() is null
# outside a live OS drag.
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("item_id"):
		cell_drag_ended.emit(grid_pos, data)
