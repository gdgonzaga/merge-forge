extends Control

# Every attack line in combat, drawn on the overlay so nothing here can move the
# layout. Lines follow CombatLane lanes (each keeps to its attacker's right).
#
# Every unit winding up an attack has a line to its target that fills from the
# attacker; the hit plays when the fill arrives, so the line is both the aim
# and the countdown. Engine state is read every frame, so retargets, heals and
# deaths mid-windup need no bookkeeping. Enemy hits play `landing_delay` after
# their tick, so a landed enemy line is held at full until then.
#
# - Width grows with the hit's share of the target's displayed HP; a hit that
#   would finish the target (with everything else aimed at it) gets a ring at
#   the target end, and enemy lines turn red.
# - Normal lines are thin and translucent in their side's colour. Crit lines
#   are gold, outlined, shimmer while they fill and pulse just before landing,
#   with a "!" on the attacker.
# - Melee fills are solid with a slash head; missile fills are dashed with an
#   arrow head.
#
# Also feeds each party member's HP ghost with the damage aimed at it.

const ENGINE := preload("res://dungeon/combat_engine.gd")
const LANE := preload("res://dungeon/combat_lane.gd")
const MELEE_HEAD := preload("res://resources/sprites/vfx/slash.png")
const MISSILE_HEAD := preload("res://resources/sprites/vfx/arrow.png")
const MARK_FONT := preload("res://resources/fonts/RobotoCondensed-VariableFont_wght.ttf")

const PARTY_COLOR := Color(0.7, 0.88, 1.0, 0.6)
const ENEMY_COLOR := Color(1.0, 0.82, 0.7, 0.6)
const CRIT_COLOR := Color(1.0, 0.82, 0.15)
const LETHAL_COLOR := Color(1.0, 0.15, 0.15)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.6)
const OUTLINE_EXTRA := 4.0
const TRACK_ALPHA := 0.25
# Damage as a share of the target's displayed HP -> width on the 1080 canvas.
const MIN_WIDTH := 4.0
const MAX_WIDTH := 18.0
const CRIT_MIN_WIDTH := 10.0
const SEGMENTS := 16
const RING_RADIUS := 18.0
const FINAL_PULSE_SECONDS := 0.3
const FINAL_PULSE_HZ := 8.0
const SHIMMER_HZ := 3.0
const SHIMMER_AMOUNT := 0.3
const HEAD_SIZE := 36.0
const CRIT_HEAD_SIZE := 52.0
const MARK_SIZE := 56
const MARK_OFFSET := Vector2(-28.0, 52.0)
# Arrivals on one unit are spread along its edge by the attacker's slot.
const ARRIVAL_SPREAD := 20.0

var _engine: Node
var _party_units: Array = []
var _enemy_units: Array = []
var _landing_delay := 0.0
var _incoming := PackedInt32Array()
var _points := PackedVector2Array()
var _head_dir := Vector2.RIGHT
var _drew_last_frame := false

# Landed enemy attacks held at full until their hit plays, indexed by enemy.
var _held_target := PackedInt32Array()
var _held_damage := PackedInt32Array()
var _held_crit := PackedByteArray()
var _held_since := PackedFloat64Array()
var _held_total := PackedFloat64Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_points.resize(SEGMENTS + 1)


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
	# Packed arrays are values in GDScript, so each is resized by name.
	_held_target.resize(enemy_units.size())
	_held_damage.resize(enemy_units.size())
	_held_crit.resize(enemy_units.size())
	_held_since.resize(enemy_units.size())
	_held_total.resize(enemy_units.size())
	_held_target.fill(-1)


# Keeps a landed enemy attack's line at full after its tick, until its hit
# plays.
func hold(enemy_index: int, target: int, damage: int, is_crit: bool, windup_ticks: int) -> void:
	if enemy_index < 0 or enemy_index >= _held_target.size():
		return
	_held_target[enemy_index] = target
	_held_damage[enemy_index] = damage
	_held_crit[enemy_index] = 1 if is_crit else 0
	_held_since[enemy_index] = _now()
	_held_total[enemy_index] = windup_ticks * _engine.tick_timer.wait_time + _landing_delay


# Width by the hit's share of the target's HP, so a line that would finish its
# target is as wide as lines get.
static func line_width(damage: int, target_hp: int) -> float:
	var share := clampf(float(damage) / float(maxi(target_hp, 1)), 0.0, 1.0)
	return lerpf(MIN_WIDTH, MAX_WIDTH, share)


func _process(_delta: float) -> void:
	if _engine == null:
		return
	var now := _now()
	var running: bool = _engine.is_combat_running()
	_push_incoming(running, now)
	var active := running or _any_held(now)
	if active or _drew_last_frame:
		queue_redraw()
	_drew_last_frame = active


# --- Held enemy lines and HP ghosts ---

func _push_incoming(running: bool, now: float) -> void:
	for i in range(_party_units.size()):
		var amount: int = _engine.get_incoming_damage(i) if running else 0
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


# Damage aimed at an enemy by the whole party, for the lethal check.
func _incoming_on_enemy(enemy_index: int) -> int:
	var total := 0
	for m in range(_party_units.size()):
		if _engine.is_winding_up(ENGINE.SIDE_PARTY, m) and _engine.get_member_data(m)["target"] == enemy_index:
			total += _engine.get_pending_damage(ENGINE.SIDE_PARTY, m)
	return total


# --- Drawing ---

func _draw() -> void:
	if _engine == null:
		return
	var now := _now()
	if _engine.is_combat_running():
		for m in range(_party_units.size()):
			_draw_windup(ENGINE.SIDE_PARTY, m)
		for e in range(_enemy_units.size()):
			_draw_windup(ENGINE.SIDE_ENEMY, e)
	for e in range(_enemy_units.size()):
		var held := _held_progress(e, now)
		if held < 1.0:
			_draw_attack(ENGINE.SIDE_ENEMY, e, _held_target[e], _held_damage[e], _held_crit[e] == 1,
				held, (1.0 - held) * _held_total[e])


func _draw_windup(side: int, index: int) -> void:
	var delay := 0.0 if side == ENGINE.SIDE_PARTY else _landing_delay
	var progress: float = _engine.get_windup_progress(side, index, delay)
	if progress < 0.0:
		return
	var unit: Dictionary = _unit_data(side, index)
	var total: float = int(unit["windup_ticks"]) * _engine.tick_timer.wait_time + delay
	_draw_attack(side, index, unit["target"], _engine.get_pending_damage(side, index), unit["is_crit"],
		progress, (1.0 - progress) * total)


func _draw_attack(side: int, attacker: int, target: int, damage: int, is_crit: bool, progress: float, remaining: float) -> void:
	var party_side := side == ENGINE.SIDE_PARTY
	var attackers := _party_units if party_side else _enemy_units
	var targets := _enemy_units if party_side else _party_units
	if not _unit_valid(attackers, attacker) or not _unit_valid(targets, target):
		return
	var from: Vector2
	var to: Vector2
	if party_side:
		from = _party_anchor(attacker, -1, 0)
		to = _enemy_anchor(target, attacker, _party_units.size())
	else:
		from = _enemy_anchor(attacker)
		to = _party_anchor(target, attacker, _enemy_units.size())
	_fill_curve(from, to)

	var target_hp: int = targets[target].get_displayed_hp()
	var incoming: int = _incoming_on_enemy(target) if party_side else _incoming[target]
	var lethal := incoming >= target_hp
	var width := line_width(damage, target_hp)
	var color := PARTY_COLOR if party_side else ENEMY_COLOR
	if is_crit:
		color = CRIT_COLOR
		width = maxf(width, CRIT_MIN_WIDTH)
	if lethal and not party_side:
		color = LETHAL_COLOR
	var missile: bool = _unit_data(side, attacker)["attack_type"] == ENGINE.ATTACK_MISSILE

	if is_crit:
		var pulse := _final_pulse(remaining)
		width *= 1.0 + 0.3 * pulse
		color = color.lightened(SHIMMER_AMOUNT * _shimmer() + 0.35 * pulse)
		draw_polyline(_points, OUTLINE_COLOR, width + OUTLINE_EXTRA, true)
		var track := color
		track.a = TRACK_ALPHA
		draw_polyline(_points, track, width, true)
	var head := _draw_fill(progress, color, width, missile)
	_draw_head(head, color, missile, CRIT_HEAD_SIZE if is_crit else HEAD_SIZE)
	if is_crit or lethal:
		draw_arc(_points[SEGMENTS], RING_RADIUS * (1.5 if lethal else 1.0), 0.0, TAU, 24, color, 4.0, true)
	if is_crit:
		_draw_crit_mark(attackers[attacker], color)


# Samples the lane from `from` to `to` into _points.
func _fill_curve(from: Vector2, to: Vector2) -> void:
	var a := LANE.start(from, to)
	var c := LANE.control(from, to)
	var b := LANE.end(from, to)
	for s in range(SEGMENTS + 1):
		_points[s] = LANE.point(a, c, b, float(s) / SEGMENTS)


# Draws the filled part of the curve up to progress (every other segment for a
# dashed missile line); returns the fill's head and leaves its direction in
# _head_dir.
func _draw_fill(progress: float, color: Color, width: float, dashed: bool) -> Vector2:
	var reach := progress * SEGMENTS
	var whole := mini(floori(reach), SEGMENTS)
	for s in range(whole):
		if not dashed or s % 2 == 0:
			draw_line(_points[s], _points[s + 1], color, width, true)
	if whole >= SEGMENTS:
		_head_dir = _points[SEGMENTS] - _points[SEGMENTS - 1]
		return _points[SEGMENTS]
	_head_dir = _points[whole + 1] - _points[whole]
	var head := _points[whole].lerp(_points[whole + 1], reach - whole)
	if not dashed or whole % 2 == 0:
		draw_line(_points[whole], head, color, width, true)
	return head


# Arrow heads point along the lane; slash heads lie across it, like a swing.
func _draw_head(pos: Vector2, color: Color, missile: bool, head_size: float) -> void:
	var angle := _head_dir.angle()
	if not missile:
		angle += PI * 0.5
	var tint := color
	tint.a = 1.0
	draw_set_transform(pos, angle)
	var tex := MISSILE_HEAD if missile else MELEE_HEAD
	draw_texture_rect(tex, Rect2(Vector2.ONE * -head_size * 0.5, Vector2.ONE * head_size), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0)


# "!" at the attacker's top-right corner for the whole crit windup.
func _draw_crit_mark(attacker: Control, color: Color) -> void:
	var rect: Rect2 = attacker.get_global_rect()
	var pos := _to_local_point(Vector2(rect.end.x, rect.position.y)) + MARK_OFFSET
	draw_string_outline(MARK_FONT, pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, MARK_SIZE, 8, Color.BLACK)
	draw_string(MARK_FONT, pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, MARK_SIZE, color)


# 0 until the last FINAL_PULSE_SECONDS, then oscillates 0..1.
func _final_pulse(remaining: float) -> float:
	if remaining > FINAL_PULSE_SECONDS:
		return 0.0
	return 0.5 + 0.5 * sin(_now() * TAU * FINAL_PULSE_HZ)


func _shimmer() -> float:
	return 0.5 + 0.5 * sin(_now() * TAU * SHIMMER_HZ)


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


func _unit_data(side: int, index: int) -> Dictionary:
	return _engine.get_member_data(index) if side == ENGINE.SIDE_PARTY else _engine.get_enemy_data(index)


func _unit_valid(units: Array, index: int) -> bool:
	return index >= 0 and index < units.size() and is_instance_valid(units[index])


func _to_local_point(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
