extends PanelContainer

var member_index: int = -1
var _max_hp: int = 50

@onready var _unit = $VBox/Unit
@onready var _buff_label: Label = $VBox/BuffLabel


func setup(data: Dictionary) -> void:
	member_index = data.get("member_index", -1)
	_max_hp = data.get("max_hp", 50)
	var sprite_path: String = data.get("sprite", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		_unit.sprite.texture = load(sprite_path)
	_unit.update_hp(_max_hp, _max_hp)


func update_hp(current: int, max_hp: int) -> void:
	_unit.update_hp(current, max_hp)


func update_buffs(buffs: Array) -> void:
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
