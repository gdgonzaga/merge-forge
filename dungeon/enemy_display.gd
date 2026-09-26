extends PanelContainer

@onready var _unit = %Unit


func setup(data: Dictionary) -> void:
	var spr = data.get("sprite", null)
	if spr is Texture2D:
		_unit.sprite.texture = spr
	elif spr is String and spr != "" and ResourceLoader.exists(spr):
		_unit.sprite.texture = load(spr)
	_unit.update_hp(data.get("current_hp", 30), data.get("max_hp", 30))


func update_hp(current: int, max_hp: int) -> void:
	_unit.update_hp(current, max_hp)


func get_unit() -> Control:
	return _unit


func play_spawn() -> void:
	_unit.play_spawn()


func play_lunge(on_impact: Callable, offset_x: float = -20.0) -> void:
	_unit.play_lunge(on_impact, offset_x)


func play_cast() -> void:
	_unit.play_cast()


func play_hit(is_heavy: bool) -> void:
	_unit.play_hit(is_heavy)


# Fades out but keeps its slot, so the surviving enemies don't slide over; the
# controller frees every display when the encounter ends.
func play_death() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.4)
