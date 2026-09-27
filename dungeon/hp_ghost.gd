extends Control

# Drawn over a CombatUnit's HP bar: the pulsing chunk the attacks winding up at
# it will take (the ghost), and the pale chunk of HP just lost draining away (the
# trail). A sibling of the bar, not a child, because the bar is tinted with
# modulate and a child would inherit that tint.

const GHOST_COLOR := Color(1.0, 1.0, 1.0)
const TRAIL_COLOR := Color(1.0, 0.95, 0.8, 0.7)
const PULSE_PERIOD := 0.6
const LETHAL_PULSE_PERIOD := 0.3
const PULSE_ALPHA_LOW := 0.35
const PULSE_ALPHA_HIGH := 0.8
const TRAIL_HOLD := 0.15
const TRAIL_DRAIN := 0.4

var _current := 0
var _max_hp := 0
var _incoming := 0
var _ghost_alpha := PULSE_ALPHA_HIGH:
	set(value):
		_ghost_alpha = value
		queue_redraw()
# HP value the trail reaches up to; nothing is drawn while it's <= _current.
var _trail_hp := 0.0:
	set(value):
		_trail_hp = value
		queue_redraw()
var _pulse_tween: Tween
var _pulse_lethal := false
var _trail_tween: Tween


# (start, end) of the ghost as fractions of the bar. Empty (start == end) when
# nothing is incoming; start is 0 when the hit is lethal.
static func ghost_span(current: int, max_hp: int, incoming: int) -> Vector2:
	if max_hp <= 0 or incoming <= 0 or current <= 0:
		var at := clampf(float(current) / float(maxi(max_hp, 1)), 0.0, 1.0)
		return Vector2(at, at)
	var start := float(maxi(current - incoming, 0)) / float(max_hp)
	var end := float(mini(current, max_hp)) / float(max_hp)
	return Vector2(start, end)


func set_hp(current: int, max_hp: int) -> void:
	# The first call sets up the bar; only later drops leave a trail.
	if _max_hp > 0 and current < _current:
		_start_trail(_current, current)
	elif current > _trail_hp:
		_stop_trail(current)
	_current = current
	_max_hp = max_hp
	_update_pulse()
	queue_redraw()


func set_incoming(amount: int) -> void:
	if amount == _incoming:
		return
	_incoming = amount
	_update_pulse()
	queue_redraw()


func _draw() -> void:
	if _max_hp <= 0:
		return
	if _trail_hp > _current:
		_draw_span(float(_current) / _max_hp, _trail_hp / _max_hp, TRAIL_COLOR)
	var span := ghost_span(_current, _max_hp, _incoming)
	if span.y > span.x:
		var color := GHOST_COLOR
		color.a = _ghost_alpha
		_draw_span(span.x, span.y, color)


func _draw_span(from_ratio: float, to_ratio: float, color: Color) -> void:
	var x0 := clampf(from_ratio, 0.0, 1.0) * size.x
	var x1 := clampf(to_ratio, 0.0, 1.0) * size.x
	draw_rect(Rect2(x0, 0.0, x1 - x0, size.y), color)


func _start_trail(from_hp: int, to_hp: int) -> void:
	# A hit landing mid-drain extends the trail from where it already reaches.
	var trail_from := maxf(_trail_hp, float(from_hp))
	if _trail_tween and _trail_tween.is_valid():
		_trail_tween.kill()
	_trail_hp = trail_from
	_trail_tween = create_tween()
	_trail_tween.tween_interval(TRAIL_HOLD)
	_trail_tween.tween_property(self, "_trail_hp", float(to_hp), TRAIL_DRAIN).set_ease(Tween.EASE_IN)


func _stop_trail(hp: int) -> void:
	if _trail_tween and _trail_tween.is_valid():
		_trail_tween.kill()
	_trail_hp = float(hp)


func _update_pulse() -> void:
	var span := ghost_span(_current, _max_hp, _incoming)
	var active := span.y > span.x
	var lethal := active and span.x <= 0.0
	var running := _pulse_tween != null and _pulse_tween.is_valid()
	if running and active and lethal == _pulse_lethal:
		return
	if running:
		_pulse_tween.kill()
	if not active:
		return
	_pulse_lethal = lethal
	var half := (LETHAL_PULSE_PERIOD if lethal else PULSE_PERIOD) * 0.5
	_ghost_alpha = PULSE_ALPHA_HIGH
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "_ghost_alpha", PULSE_ALPHA_LOW, half)
	_pulse_tween.tween_property(self, "_ghost_alpha", PULSE_ALPHA_HIGH, half)
