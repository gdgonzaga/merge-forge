extends Control

signal despawn_timeout()
signal drag_completed()

var item_data: Dictionary = {}
var despawn_time: float = 12.0
var time_remaining: float = 12.0

var _icon: TextureRect
var _timer_bar: ColorRect
var _bg: ColorRect


func _ready() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.15, 0.25, 0.15)
	_bg.size = Vector2(56, 56)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_icon = TextureRect.new()
	_icon.size = Vector2(44, 44)
	_icon.position = Vector2(6, 2)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.visible = false
	add_child(_icon)

	_timer_bar = ColorRect.new()
	_timer_bar.size = Vector2(52, 4)
	_timer_bar.position = Vector2(2, 52)
	_timer_bar.color = Color(0.3, 0.8, 0.3)
	_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_timer_bar)
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
	var icon_path: String = item_data.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_icon.texture = load(icon_path)
		_icon.visible = true


func _process(delta: float) -> void:
	time_remaining -= delta
	if time_remaining <= 0.0:
		time_remaining = 0.0
		despawn_timeout.emit()
		queue_free()
		return
	var ratio := time_remaining / despawn_time
	_timer_bar.size.x = 52.0 * ratio
	if ratio < 0.3:
		_timer_bar.color = Color(0.9, 0.2, 0.2)
	elif ratio < 0.6:
		_timer_bar.color = Color(0.9, 0.7, 0.2)


func _get_drag_data(at_position: Vector2) -> Variant:
	if item_data.is_empty():
		return null
	var preview := ColorRect.new()
	preview.size = Vector2(48, 48)
	preview.color = Color(0.4, 0.6, 0.4, 0.8)
	var label := Label.new()
	label.text = item_data.get("name", "?")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = preview.size
	preview.add_child(label)
	set_drag_preview(preview)
	preview.position = Vector2(0, -50)
	return item_data


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if is_queued_for_deletion():
			return
		drag_completed.emit()
		queue_free()
