extends Control

var _sprite: TextureRect
var _hp_bar: ProgressBar


func setup(data: Dictionary) -> void:
	var sprite_path: String = data.get("sprite", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		_sprite.texture = load(sprite_path)
	update_hp(data.get("current_hp", 30), data.get("max_hp", 30))


func update_hp(current: int, max_hp: int) -> void:
	if _hp_bar:
		_hp_bar.max_value = max_hp
		_hp_bar.value = current
		var ratio := float(current) / float(max(1, max_hp))
		_hp_bar.modulate = Color(0.2, 0.8, 0.2) if ratio > 0.6 else Color(0.9, 0.7, 0.2) if ratio > 0.3 else Color(0.9, 0.2, 0.2)


func play_death() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.4)
	tween.tween_callback(queue_free)


func _ready() -> void:
	_sprite = TextureRect.new()
	_sprite.custom_minimum_size = Vector2(80, 80)
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_sprite)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(80, 12)
	_hp_bar.show_percentage = false
	_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_hp_bar)
