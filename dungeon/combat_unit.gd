extends VBoxContainer

@onready var sprite: TextureRect = $Sprite
@onready var hp_bar: ProgressBar = $HPBar
@onready var target_marker: TextureRect = $TargetMarker

var _charge_tween: Tween


func update_hp(current: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current
	var ratio := float(current) / float(max(1, max_hp))
	hp_bar.modulate = Color(0.2, 0.8, 0.2) if ratio > 0.6 else Color(0.9, 0.7, 0.2) if ratio > 0.3 else Color(0.9, 0.2, 0.2)


func set_target_marker(active: bool) -> void:
	target_marker.visible = active


# Brief lunge toward opponent; on_impact fires at the apex so VFX can spawn there.
func play_lunge(on_impact: Callable, offset_x: float = 20.0) -> void:
	var start_x := sprite.position.x
	var tween := create_tween()
	tween.tween_property(sprite, "position:x", start_x + offset_x, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(on_impact)
	tween.tween_property(sprite, "position:x", start_x, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# Scale pulse used for ranged / cast attacks.
func play_cast() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2.ONE * 1.1, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_IN)


# Flash red on hit; heavier blow also squishes the sprite briefly.
func play_hit(is_heavy: bool) -> void:
	var original_mod := sprite.modulate
	sprite.modulate = Color(1.0, 0.0, 0.0)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", original_mod, 0.2)
	if is_heavy:
		tween.tween_property(sprite, "scale", Vector2.ONE * 0.9, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(sprite, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# Pulsating highlight while charging a telegraphed heavy attack.
func play_heavy_charge(charging: bool) -> void:
	if _charge_tween and _charge_tween.is_valid():
		_charge_tween.kill()
	if charging:
		_charge_tween = create_tween().set_loops()
		_charge_tween.tween_property(sprite, "modulate", Color(1.3, 0.6, 0.6, 1.0), 0.3)
		_charge_tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	else:
		sprite.modulate = Color.WHITE


# Vertical bob used during walking.
func play_walk(offset_y: float) -> void:
	sprite.position.y = offset_y


# Entrance bounce when appearing in an encounter.
func play_spawn() -> void:
	sprite.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Little jump when completing the dungeon.
func play_victory() -> void:
	var tween := create_tween()
	var start_y := sprite.position.y
	tween.tween_property(sprite, "position:y", start_y - 14.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position:y", start_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# Fade to transparent then free the node.
func play_death() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(0.0, 0.0, 0.0, 0.0), 0.4)
	tween.finished.connect(queue_free)
