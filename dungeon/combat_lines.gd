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
# Lines are pixel art: the lane is traced block by block on a PIXEL grid, in
# whole-block thicknesses, from a three-shade ramp with no alpha, and effects
# step between shades instead of fading.
#
# - Thickness grows with the hit's share of the target's displayed HP; a hit
#   that would finish the target (with everything else aimed at it) gets a ring
#   at the target end, and enemy lines turn red.
# - Normal lines are thin, in their side's colour. Crit lines are gold,
#   outlined over a dark track, flash while they fill and pulse just before
#   landing, with a "!" on the attacker.
# - Melee fills are solid with a slash head; missile fills are dashed with an
#   arrow head.
#
# Also feeds each party member's HP ghost with the damage aimed at it.

const ENGINE := preload("res://dungeon/combat_engine.gd")
const LANE := preload("res://dungeon/combat_lane.gd")

# One art pixel on the 1080 canvas.
const PIXEL := 4.0
# Ramps are dark (track), mid (fill), light (flash).
const RAMP_DARK := 0
const RAMP_MID := 1
const RAMP_LIGHT := 2
const PARTY_RAMP: Array[Color] = [Color(0.11, 0.22, 0.38), Color(0.45, 0.72, 0.96), Color(0.82, 0.94, 1.0)]
const ENEMY_RAMP: Array[Color] = [Color(0.36, 0.18, 0.1), Color(0.96, 0.64, 0.42), Color(1.0, 0.89, 0.76)]
const CRIT_RAMP: Array[Color] = [Color(0.42, 0.26, 0.02), Color(1.0, 0.78, 0.1), Color(1.0, 0.96, 0.62)]
const LETHAL_RAMP: Array[Color] = [Color(0.36, 0.02, 0.02), Color(0.9, 0.12, 0.12), Color(1.0, 0.56, 0.46)]
const OUTLINE_COLOR := Color(0.06, 0.04, 0.08)
# Thickness in blocks, by damage as a share of the target's displayed HP.
const MAX_THICKNESS := 4
const CRIT_MIN_THICKNESS := 3
const SEGMENTS := 16
# Enough blocks for a lane corner to corner on a tall 9:21 canvas.
const MAX_CELLS := 1024
const RING_CELLS := 5
const LETHAL_RING_CELLS := 7
const FINAL_PULSE_SECONDS := 0.3
const FINAL_PULSE_HZ := 8.0
const FLASH_FPS := 8.0
# The crit flashes light for one frame in this many.
const FLASH_CYCLE := 4
# Blocks back from the fill's head used to aim the head sprite.
const HEAD_LOOKBACK := 3
# Crit mark top-left, from the attacker's top-right corner.
const MARK_OFFSET := Vector2(-48.0, 4.0)
# Arrivals on one unit are spread along its edge by the attacker's slot.
const ARRIVAL_SPREAD := 20.0

# Heads are authored pointing right (straight) and down-right (diagonal);
# quarter turns cover the other six directions without resampling a pixel.
# Without a diagonal, the straight head is turned 45 degrees instead, which
# resamples its pixels.
@export var melee_head: Texture2D
@export var melee_head_diagonal: Texture2D
@export var missile_head: Texture2D
@export var missile_head_diagonal: Texture2D
# Blocks per head-sprite pixel.
@export_range(1, 6) var head_scale := 2
@export_range(1, 6) var crit_head_scale := 3
# Tinted like the heads; drawn upright, so it needs no diagonal.
@export var crit_mark: Texture2D
@export_range(1, 6) var crit_mark_scale := 2

var _engine: Node
var _party_units: Array = []
var _enemy_units: Array = []
var _landing_delay := 0.0
var _incoming := PackedInt32Array()
var _points := PackedVector2Array()
# The lane's blocks in grid coordinates, attacker end first. Fixed size so
# tracing never allocates; only the first _cell_count entries are live.
var _cells := PackedVector2Array()
var _cell_count := 0
var _drew_last_frame := false

# Landed enemy attacks held at full until their hit plays, indexed by enemy.
var _held_target := PackedInt32Array()
var _held_damage := PackedInt32Array()
var _held_crit := PackedByteArray()
var _held_since := PackedFloat64Array()
var _held_total := PackedFloat64Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_points.resize(SEGMENTS + 1)
	_cells.resize(MAX_CELLS)


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


# Thickness in blocks by the hit's share of the target's HP, one block per
# quarter, so a line that would finish its target is as thick as lines get.
static func line_thickness(damage: int, target_hp: int) -> int:
	var share := clampf(float(damage) / float(maxi(target_hp, 1)), 0.0, 1.0)
	return mini(1 + floori(share * MAX_THICKNESS), MAX_THICKNESS)


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
	_trace_lane()

	var target_hp: int = targets[target].get_displayed_hp()
	var incoming: int = _incoming_on_enemy(target) if party_side else _incoming[target]
	var lethal := incoming >= target_hp
	var thickness := line_thickness(damage, target_hp)
	var ramp := PARTY_RAMP if party_side else ENEMY_RAMP
	if is_crit:
		ramp = CRIT_RAMP
		thickness = maxi(thickness, CRIT_MIN_THICKNESS)
	if lethal and not party_side:
		ramp = LETHAL_RAMP
	var color := ramp[RAMP_MID]
	var missile: bool = _unit_data(side, attacker)["attack_type"] == ENGINE.ATTACK_MISSILE

	if is_crit:
		var pulse := _final_pulse_on(remaining)
		if pulse:
			thickness += 1
		if pulse or _flash_on():
			color = ramp[RAMP_LIGHT]
		_draw_blocks(_cell_count, OUTLINE_COLOR, thickness + 2, 0)
		_draw_blocks(_cell_count, ramp[RAMP_DARK], thickness, 0)
	# Dashes outlast the brush's overlap, so a gap still shows.
	var dash := thickness + 2 if missile else 0
	var reach := clampi(ceili(progress * _cell_count), 1, _cell_count)
	_draw_blocks(reach, color, thickness, dash)
	_draw_head(_block_center(reach - 1), _aim(reach - 1), color, missile, crit_head_scale if is_crit else head_scale)
	if is_crit or lethal:
		var end := _cells[_cell_count - 1]
		var radius := LETHAL_RING_CELLS if lethal else RING_CELLS
		_draw_ring(end, radius + 1, OUTLINE_COLOR)
		_draw_ring(end, radius, color)
	if is_crit:
		_draw_crit_mark(attackers[attacker], color)


# Samples the lane from `from` to `to` into _points.
func _fill_curve(from: Vector2, to: Vector2) -> void:
	var a := LANE.start(from, to)
	var c := LANE.control(from, to)
	var b := LANE.end(from, to)
	for s in range(SEGMENTS + 1):
		_points[s] = LANE.point(a, c, b, float(s) / SEGMENTS)


# Traces the sampled lane onto the block grid, segment by segment, so the
# line is 8-connected stair steps rather than a smooth stroke.
func _trace_lane() -> void:
	_cell_count = 0
	var prev := _to_cell(_points[0])
	_push_cell(prev)
	for s in range(1, SEGMENTS + 1):
		var next := _to_cell(_points[s])
		_trace_segment(prev, next)
		prev = next


# Bresenham from a (already pushed) to b.
func _trace_segment(a: Vector2i, b: Vector2i) -> void:
	var d := (b - a).abs()
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var err := d.x - d.y
	var p := a
	while p != b:
		var e2 := err * 2
		if e2 > -d.y:
			err -= d.y
			p.x += step.x
		if e2 < d.x:
			err += d.x
			p.y += step.y
		_push_cell(p)


func _push_cell(cell: Vector2i) -> void:
	if _cell_count < MAX_CELLS:
		_cells[_cell_count] = Vector2(cell)
		_cell_count += 1


func _to_cell(point: Vector2) -> Vector2i:
	return Vector2i((point / PIXEL).floor())


# Stamps a thickness x thickness square of blocks on each of the first `count`
# cells. With dash > 0, runs of `dash` cells alternate on and off.
func _draw_blocks(count: int, color: Color, thickness: int, dash: int) -> void:
	var size := Vector2.ONE * thickness * PIXEL
	# An outline (thickness + 2) sits exactly one block out from its line.
	var offset := Vector2.ONE * floorf((thickness - 1) * 0.5)
	for i in range(count):
		if dash > 0 and i % (dash * 2) >= dash:
			continue
		draw_rect(Rect2((_cells[i] - offset) * PIXEL, size), color)


func _block_center(index: int) -> Vector2:
	return (_cells[index] + Vector2(0.5, 0.5)) * PIXEL


# Direction of the lane at a block, from a few blocks back.
func _aim(index: int) -> Vector2:
	var back := _cells[maxi(index - HEAD_LOOKBACK, 0)]
	if back == _cells[index]:
		return _points[1] - _points[0]
	return _cells[index] - back


# Heads face one of eight directions and sit on the block grid, so their
# pixels line up with the line's.
func _draw_head(pos: Vector2, dir: Vector2, color: Color, missile: bool, scale_blocks: int) -> void:
	var octant := posmod(roundi(dir.angle() / (PI * 0.25)), 8)
	var tex := missile_head if missile else melee_head
	var diagonal := missile_head_diagonal if missile else melee_head_diagonal
	var angle := floori(octant / 2.0) * PI * 0.5
	if octant % 2 == 1:
		if diagonal != null:
			tex = diagonal
		else:
			angle += PI * 0.25
	if tex == null:
		return
	var size := tex.get_size() * PIXEL * scale_blocks
	# Snap the corner, not the centre: quarter turns about the centre of a
	# grid-aligned square keep it grid-aligned.
	var center := ((pos - size * 0.5) / PIXEL).floor() * PIXEL + size * 0.5
	draw_set_transform(center, angle)
	draw_texture_rect(tex, Rect2(-size * 0.5, size), false, color)
	draw_set_transform(Vector2.ZERO, 0.0)


# One-block midpoint circle around a grid cell.
func _draw_ring(center: Vector2, radius: int, color: Color) -> void:
	var x := radius
	var y := 0
	var err := 1 - radius
	while x >= y:
		_plot_octants(center, x, y, color)
		y += 1
		if err < 0:
			err += 2 * y + 1
		else:
			x -= 1
			err += 2 * (y - x) + 1


func _plot_octants(center: Vector2, x: int, y: int, color: Color) -> void:
	_plot(center + Vector2(x, y), color)
	_plot(center + Vector2(-x, y), color)
	_plot(center + Vector2(x, -y), color)
	_plot(center + Vector2(-x, -y), color)
	_plot(center + Vector2(y, x), color)
	_plot(center + Vector2(-y, x), color)
	_plot(center + Vector2(y, -x), color)
	_plot(center + Vector2(-y, -x), color)


func _plot(cell: Vector2, color: Color) -> void:
	draw_rect(Rect2(cell * PIXEL, Vector2.ONE * PIXEL), color)


# "!" at the attacker's top-right corner for the whole crit windup.
func _draw_crit_mark(attacker: Control, color: Color) -> void:
	if crit_mark == null:
		return
	var rect: Rect2 = attacker.get_global_rect()
	var corner := _to_local_point(Vector2(rect.end.x, rect.position.y)) + MARK_OFFSET
	var size := crit_mark.get_size() * PIXEL * crit_mark_scale
	draw_texture_rect(crit_mark, Rect2((corner / PIXEL).floor() * PIXEL, size), false, color)


# Off until the last FINAL_PULSE_SECONDS, then toggles at FINAL_PULSE_HZ.
func _final_pulse_on(remaining: float) -> bool:
	return remaining <= FINAL_PULSE_SECONDS and floori(_now() * FINAL_PULSE_HZ * 2.0) % 2 == 0


func _flash_on() -> bool:
	return floori(_now() * FLASH_FPS) % FLASH_CYCLE == 0


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
