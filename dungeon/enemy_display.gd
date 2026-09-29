extends PanelContainer

@onready var _unit = %Unit
@onready var _badge: AttackBadge = %AttackBadge


func setup(data: Dictionary) -> void:
	_unit.sprite.texture = data["sprite"]
	_badge.set_attack_type(data["attack_type"])
	_badge.set_crit_icon(data.get("crit_sprite", null))
	_unit.update_hp(data.get("current_hp", 30), data.get("max_hp", 30))


func get_badge() -> AttackBadge:
	return _badge


func get_badge_center() -> Vector2:
	return _badge.get_badge_center() if _badge else get_global_rect().get_center()


func set_windup_progress(progress: float, is_crit: bool = false) -> void:
	if _badge:
		_badge.set_fill_progress(progress, is_crit, 1)


func play_badge_glow() -> void:
	if _badge:
		_badge.play_glow_pulse()


func clear_badge_gauge() -> void:
	if _badge:
		_badge.set_empty()


func update_hp(current: int, max_hp: int) -> void:
	_unit.update_hp(current, max_hp)


func get_displayed_hp() -> int:
	return _unit.get_displayed_hp()


func get_unit() -> Control:
	return _unit


func play_spawn() -> void:
	_unit.play_spawn()


func play_lunge(direction: Vector2, distance: float) -> void:
	_unit.play_lunge(direction, distance)


func play_cast() -> void:
	_unit.play_cast()


func play_hit(is_crit: bool) -> void:
	_unit.play_hit(is_crit)


# Fades out but keeps its slot, so the surviving enemies don't slide over; the
# controller frees every display when the encounter ends.
func play_death() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.4)
