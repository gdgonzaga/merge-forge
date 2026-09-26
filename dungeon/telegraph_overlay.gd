extends Control

# Heavy-attack telegraphs. A line runs from each enemy winding up a heavy attack
# to its target, and a bright fill travels along it from the enemy; the hit lands
# when the fill arrives. Colour says whether the hit is lethal, thickness how
# heavy it is. Also feeds each party member's HP ghost.
#
# Engine state is read every frame rather than mirrored from signals, so
# retargets, heals and deaths mid-windup need no bookkeeping. Drawn on the
# overlay so nothing here can move the layout.

const SURVIVABLE_COLOR := Color(1.0, 0.6, 0.15)
const LETHAL_COLOR := Color(1.0, 0.15, 0.15)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.6)
const OUTLINE_EXTRA := 4.0
const TRACK_ALPHA := 0.25
# Damage as a fraction of the target's max HP -> line width on the 1080 canvas.
const WIDTH_THRESHOLDS: Array[float] = [0.2, 0.4]
const WIDTHS: Array[float] = [8.0, 14.0, 20.0]
const SEGMENTS := 16
# Sideways bow per enemy slot, so lines converging on one target stay apart.
const BOW_PER_SLOT := 40.0
const RING_RADIUS := 18.0
const FINAL_PULSE_SECONDS := 0.3
const FINAL_PULSE_HZ := 8.0

var _engine: Node
var _party_units: Array = []
var _enemy_units: Array = []
var _incoming := PackedInt32Array()
var _points := PackedVector2Array()
var _drew_last_frame := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_points.resize(SEGMENTS + 1)


func setup(engine: Node, party_units: Array) -> void:
	_engine = engine
	_party_units = party_units
	_incoming.resize(party_units.size())
	# -1 never matches a real amount, so the first frame pushes every ghost.
	_incoming.fill(-1)


# Called at each encounter start with that encounter's enemy displays, index
# aligned with the engine's enemies.
func set_enemy_units(enemy_units: Array) -> void:
	_enemy_units = enemy_units


# Width step for a heavy hit, by its damage relative to the target's max HP.
static func line_width(damage: int, target_max_hp: int) -> float:
	var ratio := float(damage) / float(maxi(target_max_hp, 1))
	for i in range(WIDTH_THRESHOLDS.size()):
		if ratio < WIDTH_THRESHOLDS[i]:
			return WIDTHS[i]
	return WIDTHS[WIDTHS.size() - 1]


func _process(_delta: float) -> void:
	if _engine == null:
		return
	var running: bool = _engine.is_combat_running()
	_push_incoming(running)
	var active := running and _any_windup()
	if active or _drew_last_frame:
		queue_redraw()
	_drew_last_frame = active


func _push_incoming(running: bool) -> void:
	for i in range(_party_units.size()):
		var amount: int = _engine.get_incoming_heavy_damage(i) if running else 0
		if amount == _incoming[i]:
			continue
		_incoming[i] = amount
		if is_instance_valid(_party_units[i]):
			_party_units[i].set_incoming_damage(amount)


func _any_windup() -> bool:
	for i in range(_engine.enemies.size()):
		if _engine.get_windup_progress(i) >= 0.0:
			return true
	return false


func _draw() -> void:
	if _engine == null or not _engine.is_combat_running():
		return
	for i in range(_engine.enemies.size()):
		var progress: float = _engine.get_windup_progress(i)
		if progress < 0.0 or i >= _enemy_units.size() or not is_instance_valid(_enemy_units[i]):
			continue
		var enemy: Dictionary = _engine.get_enemy_data(i)
		var target: int = enemy["heavy_target"]
		if target >= _party_units.size() or not is_instance_valid(_party_units[target]):
			continue
		_draw_telegraph(i, enemy, target, progress)


func _draw_telegraph(enemy_index: int, enemy: Dictionary, target: int, progress: float) -> void:
	var heavy: Dictionary = enemy["heavy_attack"]
	var member: Dictionary = _engine.get_member_data(target)
	var from := _to_local_point(_top_center(_enemy_units[enemy_index]))
	var to := _to_local_point(_bottom_center(_party_units[target]))
	var bow := (enemy_index - (_enemy_units.size() - 1) * 0.5) * BOW_PER_SLOT
	_fill_curve(from, to, bow)

	var lethal: bool = _incoming[target] >= int(member["current_hp"])
	var color := LETHAL_COLOR if lethal else SURVIVABLE_COLOR
	var width := line_width(int(heavy["damage"]), int(member["max_hp"]))
	var remaining: float = (1.0 - progress) * int(heavy["windup"]) * _engine.tick_timer.wait_time
	var pulse := _final_pulse(remaining)
	width *= 1.0 + 0.3 * pulse
	color = color.lightened(0.35 * pulse)

	draw_polyline(_points, OUTLINE_COLOR, width + OUTLINE_EXTRA, true)
	var track := color
	track.a = TRACK_ALPHA
	draw_polyline(_points, track, width, true)
	var head := _draw_fill(progress, color, width)
	draw_circle(head, width * 0.8, Color.WHITE)
	draw_arc(to, RING_RADIUS * (1.0 + 0.3 * pulse), 0.0, TAU, 24, color, 4.0, true)


# Writes a quadratic curve into _points; bow pushes the midpoint sideways.
func _fill_curve(from: Vector2, to: Vector2, bow: float) -> void:
	var control := (from + to) * 0.5 + (to - from).orthogonal().normalized() * bow
	for s in range(SEGMENTS + 1):
		var t := float(s) / SEGMENTS
		_points[s] = from.lerp(control, t).lerp(control.lerp(to, t), t)


# Draws the filled part of the curve up to progress; returns the fill's head.
func _draw_fill(progress: float, color: Color, width: float) -> Vector2:
	var reach := progress * SEGMENTS
	var whole := mini(floori(reach), SEGMENTS)
	for s in range(whole):
		draw_line(_points[s], _points[s + 1], color, width, true)
	if whole >= SEGMENTS:
		return _points[SEGMENTS]
	var head := _points[whole].lerp(_points[whole + 1], reach - whole)
	draw_line(_points[whole], head, color, width, true)
	return head


# 0 until the last FINAL_PULSE_SECONDS, then oscillates 0..1.
func _final_pulse(remaining: float) -> float:
	if remaining > FINAL_PULSE_SECONDS:
		return 0.0
	var t := Time.get_ticks_msec() / 1000.0
	return 0.5 + 0.5 * sin(t * TAU * FINAL_PULSE_HZ)


func _top_center(node: Control) -> Vector2:
	var rect := node.get_global_rect()
	return Vector2(rect.get_center().x, rect.position.y)


func _bottom_center(node: Control) -> Vector2:
	var rect := node.get_global_rect()
	return Vector2(rect.get_center().x, rect.end.y)


func _to_local_point(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point
