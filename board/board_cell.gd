extends Control

signal cell_drag_started(from_pos: Vector2i, item: Dictionary)
signal cell_drag_ended(to_pos: Vector2i, drag_data: Dictionary)

const QUALITY_STARS := preload("res://ui/quality_stars.tscn")
const DRAGGED_TINT := Color(1.0, 0.65, 0.1, 0.75)

var grid_pos: Vector2i = Vector2i(-1, -1)
var item: Dictionary = {}
# The BoardGrid this cell belongs to; drags carry it so a drop on another grid
# (board to shelf) knows where the item came from.
var grid_owner: Control = null
var _is_dragging: bool = false

@onready var _icon: TextureRect = $Icon
@onready var _bg: TextureRect = $BG
@onready var _stars: Control = %QualityStars

var bg_texture_override: Texture2D = null


func _ready() -> void:
	if bg_texture_override != null and _bg != null:
		_bg.texture = bg_texture_override


func set_bg_texture(tex: Texture2D) -> void:
	bg_texture_override = tex
	if _bg != null:
		_bg.texture = tex


func set_item(item_data: Dictionary) -> void:
	_is_dragging = false
	item = item_data
	if _icon == null:
		return
	if item_data.is_empty():
		_icon.visible = false
		_icon.modulate = Color.WHITE
		_stars.set_quality(0)
		return
	_apply_icon()


func clear_item() -> void:
	_is_dragging = false
	item = {}
	if _icon != null:
		_icon.visible = false
		_icon.modulate = Color.WHITE
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


func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_DRAG_END:
		if _is_dragging:
			_is_dragging = false
			if _icon != null:
				_icon.modulate = Color.WHITE


func _apply_icon() -> void:
	_icon.texture = item["definition"].sprite
	_icon.visible = true
	_icon.modulate = DRAGGED_TINT if _is_dragging else Color.WHITE
	_stars.set_quality(item["quality"])


func _get_drag_data(at_position: Vector2) -> Variant:
	if item.is_empty():
		return null
	_is_dragging = true
	if _icon != null:
		_icon.modulate = DRAGGED_TINT
	var preview_root := Control.new()
	var preview := TextureRect.new()
	preview.size = Vector2(96, 96)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.texture = item["definition"].sprite
	preview_root.add_child(preview)
	_add_quality_preview(preview, item["quality"])
	# Godot moves the preview root to the pointer; offset its child instead.
	preview.position = Vector2(-48, -112)
	set_drag_preview(preview_root)
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
