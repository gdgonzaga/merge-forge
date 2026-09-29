class_name AttackBadge
extends Control

# Idle sword/bow badge showing whether a unit's attacks are melee or missile,
# with a background that fills from below as a windup gauge and pulses on full.

const PARTY_COLOR := Color(0.45, 0.72, 0.96)
const ENEMY_COLOR := Color(0.96, 0.64, 0.42)
const CRIT_COLOR := Color(1.0, 0.78, 0.1)

@export var bg_texture: Texture2D = preload("res://resources/sprites/ui/badge_bg.png")
@export var melee_icon: Texture2D = preload("res://resources/sprites/ui/badge_icon_melee.png")
@export var missile_icon: Texture2D = preload("res://resources/sprites/ui/badge_icon_missile.png")

@onready var _slot_backing: TextureRect = %SlotBacking
@onready var _gauge_progress: TextureProgressBar = %GaugeProgress
@onready var _icon: TextureRect = %Icon
@onready var _glow_overlay: TextureRect = %GlowOverlay

var _progress: float = 0.0
var _is_crit: bool = false
var _side: int = 0
var _attack_type: String = "melee"


func _ready() -> void:
	if _slot_backing and bg_texture:
		_slot_backing.texture = bg_texture
	if _gauge_progress and bg_texture:
		_gauge_progress.texture_progress = bg_texture
	if _glow_overlay and bg_texture:
		_glow_overlay.texture = bg_texture
	set_attack_type(_attack_type)
	set_empty()


func set_attack_type(attack_type: String) -> void:
	_attack_type = attack_type
	if not is_node_ready():
		return
	if _icon:
		_icon.texture = melee_icon if attack_type == "melee" else missile_icon


func set_fill_progress(progress: float, is_crit: bool = false, side: int = 0) -> void:
	_progress = clampf(progress, 0.0, 1.0)
	_is_crit = is_crit
	_side = side
	if not is_node_ready():
		return
	_gauge_progress.value = _progress * 1000.0
	if is_crit:
		_gauge_progress.modulate = CRIT_COLOR
	elif side == 0:
		_gauge_progress.modulate = PARTY_COLOR
	else:
		_gauge_progress.modulate = ENEMY_COLOR


func get_fill_progress() -> float:
	return _progress


func is_crit_active() -> bool:
	return _is_crit


func set_empty() -> void:
	_progress = 0.0
	_is_crit = false
	if not is_node_ready():
		return
	_gauge_progress.value = 0.0


func play_glow_pulse() -> void:
	if not is_node_ready():
		return
	_glow_overlay.modulate = Color(1.0, 1.0, 1.0, 1.0) if not _is_crit else Color(1.0, 0.95, 0.6, 1.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_glow_overlay, "modulate:a", 0.0, 0.12)
	tween.tween_property(_icon, "scale", Vector2(1.15, 1.15), 0.06)
	tween.chain().tween_property(_icon, "scale", Vector2(1.0, 1.0), 0.06)


func get_badge_center() -> Vector2:
	return get_global_rect().get_center()
