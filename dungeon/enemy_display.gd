extends PanelContainer

@onready var _unit = %Unit
@onready var _telegraph: Label = %Telegraph


func setup(data: Dictionary) -> void:
	var spr = data.get("sprite", null)
	if spr is Texture2D:
		_unit.sprite.texture = spr
	elif spr is String and spr != "" and ResourceLoader.exists(spr):
		_unit.sprite.texture = load(spr)
	_unit.update_hp(data.get("current_hp", 30), data.get("max_hp", 30))


func update_hp(current: int, max_hp: int) -> void:
	_unit.update_hp(current, max_hp)


# Empty text hides the telegraph; the label keeps its line so the layout doesn't jump.
func show_telegraph(text: String) -> void:
	_telegraph.text = text


func play_death() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.4)
	tween.tween_callback(queue_free)
