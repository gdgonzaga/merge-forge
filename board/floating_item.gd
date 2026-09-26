extends Control

signal despawn_timeout()

var item_data: Dictionary = {}
var despawn_time: float = 12.0
var time_remaining: float = 12.0

@onready var _icon: TextureRect = $Icon
@onready var _timer_bar: ColorRect = $TimerBar


func _ready() -> void:
	if not item_data.is_empty():
		_apply_icon()


func setup(data: Dictionary, time: float) -> void:
	item_data = data
	despawn_time = time
	time_remaining = time
	_apply_icon()


func _apply_icon() -> void:
	if _icon == null:
		return
	_icon.texture = item_data["sprite"]
	_icon.visible = true


func _process(delta: float) -> void:
	time_remaining -= delta
	if time_remaining <= 0.0:
		time_remaining = 0.0
		AudioManager.play_sfx("despawn")
		despawn_timeout.emit()
		queue_free()
		return
	var ratio := time_remaining / despawn_time
	_timer_bar.size.x = 52.0 * ratio
	if ratio < 0.3:
		_timer_bar.color = Color(0.9, 0.2, 0.2)
	elif ratio < 0.6:
		_timer_bar.color = Color(0.9, 0.7, 0.2)
	if time_remaining < 3.0:
		modulate.a = time_remaining / 3.0


func _get_drag_data(at_position: Vector2) -> Variant:
	if item_data.is_empty():
		return null
	var preview := TextureRect.new()
	preview.size = Vector2(96, 96)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.texture = item_data["sprite"]
	set_drag_preview(preview)
	preview.position = Vector2(-14, -100)
	var drag_info := item_data.duplicate()
	drag_info["_source_screen"] = global_position + size / 2.0
	return drag_info
