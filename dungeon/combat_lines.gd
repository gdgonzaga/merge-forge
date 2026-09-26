extends Control

# Every attack line in combat, drawn on the overlay so nothing here can move the
# layout. Lines follow CombatLane lanes (each keeps to its attacker's right).
#
# - Heavy telegraphs: a line from each enemy winding up a heavy attack to its
#   target, filling from the enemy; the hit plays when the fill arrives. Red if
#   the telegraphed damage would KO the target, orange otherwise; width steps
#   by damage. Engine state is read every frame, so retargets, heals and deaths
#   mid-windup need no bookkeeping. Enemy hits play `landing_delay` after their
#   tick, so a landed heavy line is held at full until then.
# - Tracers: a short comet along the lane for every basic attack. Melee comets
#   are short, fast and solid with a slash head; missile comets are longer,
#   slower and dotted with an arrow head. Party comets are cool, enemy comets
#   warm. `on_arrive` fires when the head reaches the target.
#
# Also feeds each party member's HP ghost with the heavy damage aimed at it.

const LANE := preload("res://dungeon/combat_lane.gd")
const MELEE_HEAD := preload("res://resources/sprites/vfx/slash.png")
const MISSILE_HEAD := preload("res://resources/sprites/vfx/arrow.png")

const SIDE_PARTY := 0
const SIDE_ENEMY := 1

const SURVIVABLE_COLOR := Color(1.0, 0.6, 0.15)
const LETHAL_COLOR := Color(1.0, 0.15, 0.15)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.6)
const OUTLINE_EXTRA := 4.0
const TRACK_ALPHA := 0.25
# Damage as a fraction of the target's max HP -> line width on the 1080 canvas.
const WIDTH_THRESHOLDS: Array[float] = [0.2, 0.4]
const WIDTHS: Array[float] = [8.0, 14.0, 20.0]
const SEGMENTS := 16
const RING_RADIUS := 18.0
const FINAL_PULSE_SECONDS := 0.3
const FINAL_PULSE_HZ := 8.0
# Arrivals on one unit are spread along its edge by the attacker's slot.
const ARRIVAL_SPREAD := 20.0

const PARTY_TRACER_COLOR := Color(0.8, 0.92, 1.0)
const ENEMY_TRACER_COLOR := Color(1.0, 0.9, 0.8)
const MELEE_DURATION := 0.16
const MELEE_LENGTH := 0.12
const MELEE_WIDTH := 5.0
const MISSILE_DURATION := 0.24
const MISSILE_LENGTH := 0.22
const MISSILE_WIDTH := 3.0
const TRACER_OUTLINE := 2.0
const TRACER_SUBSEGMENTS := 6
const HEAD_SIZE := 44.0
const TRACER_POOL := 24

var _engine: Node
var _party_units: Array = []
var _enemy_units: Array = []
var _landing_delay := 0.0
var _incoming := PackedInt32Array()
var _points := PackedVector2Array()
var _drew_last_frame := false

# Landed heavy attacks held at full until their hit plays, indexed by enemy.
var _held_target := PackedInt32Array()
var _held_damage := PackedInt32Array()
var _held_since := PackedFloat64Array()
var _held_total := PackedFloat64Array()

# Tracer pool: fixed size, so spawning and drawing never allocate.
var _tr_active := PackedByteArray()
var _tr_arrived := PackedByteArray()
var _tr_side := PackedByteArray()
var _tr_missile := PackedByteArray()
var _tr_from := PackedInt32Array()
var _tr_to := PackedInt32Array()
var _tr_start := PackedFloat64Array()
var _tr_on_arrive: Array[Callable] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_points.resize(SEGMENTS + 1)
	# Packed arrays are values in GDScript, so each is resized by name.
	_tr_active.resize(TRACER_POOL)
	_tr_arrived.resize(TRACER_POOL)
	_tr_side.resize(TRACER_POOL)
	_tr_missile.resize(TRACER_POOL)
	_tr_from.resize(TRACER_POOL)
	_tr_to.resize(TRACER_POOL)
	_tr_start.resize(TRACER_POOL)
	_tr_active.fill(0)
	_tr_on_arrive.resize(TRACER_POOL)


func setup(engine: Node, party_units: Array, landing_delay: float) -> void:
	_engine = engine
	_party_units = party_units
	_landing_delay = landing_delay
	_incoming.resize(party_units.size())
	# -1 never matches a real amount, so the first frame pushes every ghost.
	_incoming.fill(-1)


# Called at each encounter start with that encounter's enemy displays, index
# aligned with the engine's enemies.
func set_enemy_units(enemy_units: Array) -> void:
	_enemy_units = enemy_units
	_held_target.resize(enemy_units.size())
	_held_damage.resize(enemy_units.size())
	_held_since.resize(enemy_units.size())
	_held_total.resize(enemy_units.size())
	_held_target.fill(-1)


# Keeps a heavy attack's line at full after its tick, until its hit plays.
func hold_heavy(enemy_index: int, target: int, damage: int) -> void:
	if enemy_index < 0 or enemy_index >= _held_target.size():
		return
	var windup := int(_engine.get_enemy_data(enemy_index)["heavy_attack"]["windup"])
	_held_target[enemy_index] = target
	_held_damage[enemy_index] = damage
	_held_since[enemy_index] = _now()
	_held_total[enemy_index] = windup * _engine.tick_timer.wait_time + _landing_delay


func spawn_tracer(side: int, from_index: int, to_index: int, missile: bool, on_arrive: Callable) -> void:
	var k := _free_tracer_slot()
	_tr_active[k] = 1
	_tr_arrived[k] = 0
	_tr_side[k] = side
	_tr_missile[k] = 1 if missile else 0
	_tr_from[k] = from_index
	_tr_to[k] = to_index
	_tr_start[k] = _now()
	_tr_on_arrive[k] = on_arrive


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
	var now := _now()
	var tracers := _advance_tracers(now)
	var running: bool = _engine.is_combat_running()
	_push_incoming(running, now)
	var active := tracers or _any_held(now) or (running and _any_windup())
	if active or _drew_last_frame:
		queue_redraw()
	_drew_last_frame = active


# --- Tracer pool ---

func _free_tracer_slot() -> int:
	var oldest := 0
	for k in range(TRACER_POOL):
		if _tr_active[k] == 0:
			return k
		if _tr_start[k] < _tr_start[oldest]:
			oldest = k
	# Pool full (not reachable at current volumes): recycle the oldest, landing
	# its hit first so no HP refresh or number is lost.
	_arrive(oldest)
	return oldest


func _advance_tracers(now: float) -> bool:
	var any := false
	for k in range(TRACER_POOL):
		if _tr_active[k] == 0:
			continue
		if not _tracer_units_valid(k):
			_arrive(k)
			_tr_active[k] = 0
			continue
		var duration := MISSILE_DURATION if _tr_missile[k] == 1 else MELEE_DURATION
		var length := MISSILE_LENGTH if _tr_missile[k] == 1 else MELEE_LENGTH
		var elapsed := now - _tr_start[k]
		if LANE.tracer_span(elapsed, duration, length).y >= 1.0:
			_arrive(k)
		if elapsed >= duration:
			_tr_active[k] = 0
		else:
			any = true
	return any


func _arrive(k: int) -> void:
	if _tr_arrived[k] == 1:
		return
	_tr_arrived[k] = 1
	var cb := _tr_on_arrive[k]
	_tr_on_arrive[k] = Callable()
	if cb.is_valid():
		cb.call()


func _tracer_units_valid(k: int) -> bool:
	var attackers := _party_units if _tr_side[k] == SIDE_PARTY else _enemy_units
	var targets := _enemy_units if _tr_side[k] == SIDE_PARTY else _party_units
	return _unit_valid(attackers, _tr_from[k]) and _unit_valid(targets, _tr_to[k])


# --- Heavy telegraphs and HP ghosts ---

func _push_incoming(running: bool, now: float) -> void:
	for i in range(_party_units.size()):
		var amount: int = _engine.get_incoming_heavy_damage(i) if running else 0
		amount += _held_damage_on(i, now)
		if amount == _incoming[i]:
			continue
		_incoming[i] = amount
		if is_instance_valid(_party_units[i]):
			_party_units[i].set_incoming_damage(amount)


func _held_damage_on(member_index: int, now: float) -> int:
	var total := 0
	for e in range(_held_target.size()):
		if _held_target[e] == member_index and _held_progress(e, now) < 1.0:
			total += _held_damage[e]
	return total


func _held_progress(enemy_index: int, now: float) -> float:
	if _held_target[enemy_index] < 0:
		return 1.0
	var remaining := _landing_delay - (now - _held_since[enemy_index])
	if remaining <= 0.0:
		_held_target[enemy_index] = -1
		return 1.0
	return 1.0 - remaining / _held_total[enemy_index]


func _any_held(now: float) -> bool:
	for e in range(_held_target.size()):
		if _held_progress(e, now) < 1.0:
			return true
	return false


func _any_windup() -> bool:
	for i in range(_engine.enemies.size()):
		if _engine.get_windup_progress(i, _landing_delay) >= 0.0:
			return true
	return false


# --- Drawing ---

func _draw() -> void:
	if _engine == null:
		return
	var now := _now()
	var running: bool = _engine.is_combat_running()
	for i in range(_enemy_units.size()):
		if not _unit_valid(_enemy_units, i):
			continue
		var held := _held_progress(i, now)
		if held < 1.0:
			_draw_heavy(i, _held_target[i], _held_damage[i], held, (1.0 - held) * _held_total[i])
		elif running:
			_draw_engine_heavy(i)
	for k in range(TRACER_POOL):
		if _tr_active[k] == 1 and _tracer_units_valid(k):
			_draw_tracer(k, now)


func _draw_engine_heavy(enemy_index: int) -> void:
	var progress: float = _engine.get_windup_progress(enemy_index, _landing_delay)
	if progress < 0.0:
		return
	var enemy: Dictionary = _engine.get_enemy_data(enemy_index)
	var heavy: Dictionary = enemy["heavy_attack"]
	var total: float = int(heavy["windup"]) * _engine.tick_timer.wait_time + _landing_delay
	_draw_heavy(enemy_index, enemy["heavy_target"], int(heavy["damage"]), progress, (1.0 - progress) * total)


func _draw_heavy(enemy_index: int, target: int, damage: int, progress: float, remaining: float) -> void:
	if not _unit_valid(_party_units, target):
		return
	var from := _enemy_anchor(enemy_index)
	var to := _party_anchor(target, enemy_index, _enemy_units.size())
	_fill_curve(from, to)

	var lethal: bool = _incoming[target] >= _party_units[target].get_displayed_hp()
	var color := LETHAL_COLOR if lethal else SURVIVABLE_COLOR
	var width := line_width(damage, int(_engine.get_member_data(target)["max_hp"]))
	var pulse := _final_pulse(remaining)
	width *= 1.0 + 0.3 * pulse
	color = color.lightened(0.35 * pulse)

	draw_polyline(_points, OUTLINE_COLOR, width + OUTLINE_EXTRA, true)
	var track := color
	track.a = TRACK_ALPHA
	draw_polyline(_points, track, width, true)
	var head := _draw_fill(progress, color, width)
	draw_circle(head, width * 0.8, Color.WHITE)
	draw_arc(_points[SEGMENTS], RING_RADIUS * (1.0 + 0.3 * pulse), 0.0, TAU, 24, color, 4.0, true)


func _draw_tracer(k: int, now: float) -> void:
	var missile := _tr_missile[k] == 1
	var span := LANE.tracer_span(now - _tr_start[k],
		MISSILE_DURATION if missile else MELEE_DURATION,
		MISSILE_LENGTH if missile else MELEE_LENGTH)
	if span.y <= span.x:
		return
	var from: Vector2
	var to: Vector2
	if _tr_side[k] == SIDE_PARTY:
		from = _party_anchor(_tr_from[k], -1, 0)
		to = _enemy_anchor(_tr_to[k], _tr_from[k], _party_units.size())
	else:
		from = _enemy_anchor(_tr_from[k])
		to = _party_anchor(_tr_to[k], _tr_from[k], _enemy_units.size())
	var a := LANE.start(from, to)
	var c := LANE.control(from, to)
	var b := LANE.end(from, to)
	var color := PARTY_TRACER_COLOR if _tr_side[k] == SIDE_PARTY else ENEMY_TRACER_COLOR
	_draw_comet(a, c, b, span, color, missile)
	_draw_head(a, c, b, span.y, color, missile)


# The comet body fades in from its tail; missile bodies are dotted.
func _draw_comet(a: Vector2, c: Vector2, b: Vector2, span: Vector2, color: Color, missile: bool) -> void:
	var width := MISSILE_WIDTH if missile else MELEE_WIDTH
	for s in range(TRACER_SUBSEGMENTS):
		if missile and s % 2 == 1:
			continue
		var t0 := lerpf(span.x, span.y, float(s) / TRACER_SUBSEGMENTS)
		var t1 := lerpf(span.x, span.y, float(s + 1) / TRACER_SUBSEGMENTS)
		var p0 := LANE.point(a, c, b, t0)
		var p1 := LANE.point(a, c, b, t1)
		var seg := color
		seg.a = float(s + 1) / TRACER_SUBSEGMENTS
		if not missile:
			var outline := OUTLINE_COLOR
			outline.a *= seg.a
			draw_line(p0, p1, outline, width + TRACER_OUTLINE * 2.0, true)
		draw_line(p0, p1, seg, width, true)


# Arrow heads point along the lane; slash heads lie across it, like a swing.
func _draw_head(a: Vector2, c: Vector2, b: Vector2, t: float, color: Color, missile: bool) -> void:
	var angle := LANE.tangent(a, c, b, t).angle()
	if not missile:
		angle += PI * 0.5
	draw_set_transform(LANE.point(a, c, b, t), angle)
	var tex := MISSILE_HEAD if missile else MELEE_HEAD
	draw_texture_rect(tex, Rect2(Vector2.ONE * -HEAD_SIZE * 0.5, Vector2.ONE * HEAD_SIZE), false, color)
	draw_set_transform(Vector2.ZERO, 0.0)


# Samples the lane from `from` to `to` into _points.
func _fill_curve(from: Vector2, to: Vector2) -> void:
	var a := LANE.start(from, to)
	var c := LANE.control(from, to)
	var b := LANE.end(from, to)
	for s in range(SEGMENTS + 1):
		_points[s] = LANE.point(a, c, b, float(s) / SEGMENTS)


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
	return 0.5 + 0.5 * sin(_now() * TAU * FINAL_PULSE_HZ)


# --- Anchors: enemy panels meet party cards at their facing edges ---

# Top centre of an enemy panel, spread by the attacker's slot when it's the
# arrival end (attacker_slot >= 0).
func _enemy_anchor(enemy_index: int, attacker_slot: int = -1, attacker_count: int = 0) -> Vector2:
	var rect: Rect2 = _enemy_units[enemy_index].get_global_rect()
	var point := Vector2(rect.get_center().x, rect.position.y)
	return _to_local_point(point + Vector2(_spread(attacker_slot, attacker_count), 0.0))


# Bottom centre of a party card, spread the same way.
func _party_anchor(member_index: int, attacker_slot: int, attacker_count: int) -> Vector2:
	var rect: Rect2 = _party_units[member_index].get_global_rect()
	var point := Vector2(rect.get_center().x, rect.end.y)
	return _to_local_point(point + Vector2(_spread(attacker_slot, attacker_count), 0.0))


func _spread(attacker_slot: int, attacker_count: int) -> float:
	if attacker_slot < 0:
		return 0.0
	return (attacker_slot - (attacker_count - 1) * 0.5) * ARRIVAL_SPREAD


func _unit_valid(units: Array, index: int) -> bool:
	return index >= 0 and index < units.size() and is_instance_valid(units[index])


func _to_local_point(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
