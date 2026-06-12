extends Control

const BURST_DISTANCE: float = 120.0
const BURST_TIME: float = 0.3
const BURST_ARC_HEIGHT: float = -30.0
const PULSE_PERIOD: float = 0.8
const PULSE_SCALE: float = 1.15
const FLOAT_TIME: float = 0.6
const SHRINK_TIME: float = 0.2
const FLOAT_DISTANCE: float = -60.0
const ICON_SIZE: float = 48.0
const COIN_ICON := "res://resources/sprites/items/gold_coin.png"

var _amount: int = 0
var _pulse_tween: Tween
var _pending_pos: Vector2 = Vector2.ZERO
var _pending: bool = false

@onready var _icon: TextureRect = $Icon
@onready var _label: Label = $Label


func setup(amount: int, spawn_local_pos: Vector2) -> void:
	_amount = amount
	_pending_pos = spawn_local_pos
	_pending = true
	if _icon != null:
		_apply_setup()


func _ready() -> void:
	if _pending:
		_apply_setup()
	AudioManager.play_sfx("item_place")
	_start_burst()


func _apply_setup() -> void:
	_pending = false
	_label.text = "+%d" % _amount
	_label.visible = false
	_icon.texture = load(COIN_ICON)
	_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	position = _pending_pos - Vector2(ICON_SIZE / 2.0, ICON_SIZE / 2.0)
	size = Vector2(ICON_SIZE, ICON_SIZE)


func _start_burst() -> void:
	var angle := randf() * TAU
	var dir := Vector2(cos(angle), sin(angle))
	var start_pos := position
	var end_pos := start_pos + dir * BURST_DISTANCE
	var tween := create_tween()
	tween.tween_method(func(t: float):
		var pos := start_pos.lerp(end_pos, t)
		pos.y += BURST_ARC_HEIGHT * 4.0 * t * (1.0 - t)
		position = pos
	, 0.0, 1.0, BURST_TIME)
	tween.tween_callback(_start_pulse)


func _start_pulse() -> void:
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "scale", Vector2(PULSE_SCALE, PULSE_SCALE), PULSE_PERIOD * 0.5)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, PULSE_PERIOD * 0.5)


func _on_icon_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_collect()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_collect()


func _collect() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	GameManager.add_gold(_amount)
	AudioManager.play_sfx("gold_earn")
	_label.visible = true
	var start_pos := position
	var tween := create_tween()
	tween.tween_method(func(t: float):
		position = start_pos + Vector2(0, FLOAT_DISTANCE * t)
	, 0.0, 1.0, FLOAT_TIME)
	tween.parallel().tween_property(self, "scale", Vector2.ZERO, SHRINK_TIME).set_delay(FLOAT_TIME - SHRINK_TIME)
	tween.tween_callback(queue_free)
