extends Control

var member_index: int = -1
var _sprite: TextureRect
var _hp_bar: ProgressBar
var _buff_label: Label
var _max_hp: int = 50


func setup(data: Dictionary) -> void:
	member_index = data.get("member_index", -1)
	_max_hp = data.get("max_hp", 50)
	var sprite_path: String = data.get("sprite", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		_sprite.texture = load(sprite_path)
	update_hp(_max_hp, _max_hp)


func update_hp(current: int, max_hp: int) -> void:
	if _hp_bar:
		_hp_bar.max_value = max_hp
		_hp_bar.value = current
		var ratio := float(current) / float(max(1, max_hp))
		_hp_bar.modulate = Color(0.2, 0.8, 0.2) if ratio > 0.6 else Color(0.9, 0.7, 0.2) if ratio > 0.3 else Color(0.9, 0.2, 0.2)


func update_buffs(buffs: Array) -> void:
	if _buff_label:
		if buffs.is_empty():
			_buff_label.text = ""
		else:
			var parts: Array = []
			for b in buffs:
				var e: String = b.get("effect", "")
				var d: int = int(b.get("duration", 0))
				if e == "buff_attack":
					parts.append("ATK+%ds" % d)
			_buff_label.text = " ".join(parts)


func set_ko() -> void:
	modulate = Color(0.4, 0.4, 0.4, 1.0)


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

	_buff_label = Label.new()
	_buff_label.add_theme_font_size_override("font_size", 12)
	_buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_buff_label)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary:
		if data.get("dungeon_usable", false) and "party" in str(data.get("dungeon_use_target", "")):
			return true
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var ctrl = _find_controller()
	if ctrl and ctrl.has_method("apply_usable_item"):
		ctrl.apply_usable_item(member_index, data)


func _find_controller() -> Node:
	var node = get_parent()
	while node:
		if node.has_method("apply_usable_item"):
			return node
		node = node.get_parent()
	return null
