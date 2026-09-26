extends PanelContainer

@onready var _unit = %Unit
@onready var _badge: TextureRect = %AttackBadge


func setup(data: Dictionary) -> void:
	_unit.sprite.texture = data["sprite"]
	_badge.set_attack_type(data["attack_type"])
	_unit.update_hp(data.get("current_hp", 30), data.get("max_hp", 30))


func update_hp(current: int, max_hp: int) -> void:
	_unit.update_hp(current, max_hp)


func get_unit() -> Control:
	return _unit


func play_spawn() -> void:
	_unit.play_spawn()


func play_lunge(direction: Vector2, distance: float) -> void:
	_unit.play_lunge(direction, distance)


func play_cast() -> void:
	_unit.play_cast()


func play_hit(is_heavy: bool) -> void:
	_unit.play_hit(is_heavy)


# Fades out but keeps its slot, so the surviving enemies don't slide over; the
# controller frees every display when the encounter ends.
func play_death() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.4)
