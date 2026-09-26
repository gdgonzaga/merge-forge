extends Node

# Plays combat for the dungeon view: attacker motions, a tracer along each
# attack's lane, impacts and floating numbers, and HP, KO and death visuals.
#
# Hits land in two volleys per tick: the party's on the tick, the enemies'
# ENEMY_VOLLEY_DELAY later, so each side's attacks read as a beat. Unit HP
# bars change when a hit arrives rather than when the engine resolves it, so
# bars, numbers and impacts stay in step. Engine state is already final for the
# tick, so a bar refreshed on arrival always shows the truth.

const LINES := preload("res://dungeon/combat_lines.gd")

const ENEMY_VOLLEY_DELAY := 0.3
const MELEE := "melee"
const LUNGE_DISTANCE := 20.0
const HEAVY_LUNGE_DISTANCE := 30.0
const PARTY_NUMBER_COLOR := Color(0.55, 0.85, 1.0)
const ENEMY_NUMBER_COLOR := Color(1.0, 0.3, 0.3)
const HEAVY_NUMBER_COLOR := Color(1.0, 0.2, 0.2)
const HEAVY_NAME_COLOR := Color(1.0, 0.6, 0.15)
# Several attackers can hit one unit in the same volley; each attacker's number
# is offset by its slot so they don't print on top of each other.
const NUMBER_SPREAD := 40.0

var _engine: Node
var _party_units: Array = []
var _enemy_units: Array = []
var _vfx: Control
var _lines: Control
# Enemy indices whose death has been shown this encounter.
var _dead_shown: Dictionary = {}


func setup(engine: Node, party_units: Array, vfx: Control, lines: Control) -> void:
	_engine = engine
	_party_units = party_units
	_vfx = vfx
	_lines = lines
	_lines.setup(engine, party_units, ENEMY_VOLLEY_DELAY)
	engine.party_attacked.connect(_on_party_attacked)
	engine.enemy_attacked.connect(_on_enemy_attacked)
	engine.telegraph_changed.connect(_on_telegraph_changed)
	engine.effect_applied.connect(_on_effect_applied)
	engine.tick_resolved.connect(_on_tick_resolved)


# Called at each encounter start (and with an empty array when it's cleared),
# index aligned with the engine's enemies.
func set_enemy_units(enemy_units: Array) -> void:
	_enemy_units = enemy_units
	_dead_shown.clear()
	_lines.set_enemy_units(enemy_units)


# For changes that don't arrive as a hit, such as a potion.
func refresh_member(member_index: int) -> void:
	_refresh_member(member_index)


# --- Party volley ---

func _on_party_attacked(member_index: int, targets: Array[int], damage: int) -> void:
	if not _valid(_party_units, member_index) or targets.is_empty():
		return
	var melee: bool = _engine.get_member_data(member_index)["attack_type"] == MELEE
	_play_attacker_motion(_party_units[member_index], melee, _enemy_units, targets[0], LUNGE_DISTANCE)
	for t in targets:
		_lines.spawn_tracer(LINES.SIDE_PARTY, member_index, t, not melee,
			_on_party_hit_arrived.bind(t, member_index, damage, melee))


func _on_party_hit_arrived(enemy_index: int, member_index: int, damage: int, melee: bool) -> void:
	if not _valid(_enemy_units, enemy_index):
		return
	var ed: Control = _enemy_units[enemy_index]
	ed.play_hit(false)
	_play_impact(ed, melee)
	_vfx.spawn_floating_text(_number_pos(ed, member_index, _party_units.size()), str(damage), PARTY_NUMBER_COLOR)
	_refresh_enemy(enemy_index)


# --- Enemy volley ---

func _on_enemy_attacked(enemy_index: int, attack_type: String, is_heavy: bool, targets: Array[int], damage: int) -> void:
	if is_heavy and not targets.is_empty():
		_lines.hold_heavy(enemy_index, targets[0], damage)
	get_tree().create_timer(ENEMY_VOLLEY_DELAY).timeout.connect(
		_play_enemy_attack.bind(enemy_index, attack_type == MELEE, is_heavy, targets, damage))


func _play_enemy_attack(enemy_index: int, melee: bool, is_heavy: bool, targets: Array[int], damage: int) -> void:
	if not _valid(_enemy_units, enemy_index) or targets.is_empty():
		return
	if is_heavy:
		_play_heavy_attack(enemy_index, targets[0], damage)
		return
	_play_attacker_motion(_enemy_units[enemy_index], melee, _party_units, targets[0], LUNGE_DISTANCE)
	for t in targets:
		_lines.spawn_tracer(LINES.SIDE_ENEMY, enemy_index, t, not melee,
			_on_enemy_hit_arrived.bind(t, enemy_index, damage, melee))


func _on_enemy_hit_arrived(member_index: int, enemy_index: int, damage: int, melee: bool) -> void:
	if not _valid(_party_units, member_index):
		return
	var pm: Control = _party_units[member_index]
	pm.play_hit(false)
	_play_impact(pm, melee)
	_vfx.spawn_floating_text(_number_pos(pm, enemy_index, _enemy_units.size()), "-%d" % damage, ENEMY_NUMBER_COLOR)
	_refresh_member(member_index)


# The heavy line has just filled to its target, so the hit lands at once.
func _play_heavy_attack(enemy_index: int, target: int, damage: int) -> void:
	var ed: Control = _enemy_units[enemy_index]
	var heavy_name: String = _engine.get_enemy_data(enemy_index)["heavy_attack"]["name"]
	_vfx.screen_shake(8.0, 0.25)
	_vfx.spawn_floating_text(ed.global_position + Vector2(ed.size.x * 0.5, 0.0), heavy_name, HEAVY_NAME_COLOR, true)
	_play_attacker_motion(ed, true, _party_units, target, HEAVY_LUNGE_DISTANCE)
	if not _valid(_party_units, target):
		return
	var pm: Control = _party_units[target]
	pm.play_hit(true)
	_vfx.spawn_impact(_center(pm), true)
	_vfx.spawn_floating_text(_center(pm), "-%d" % damage, HEAVY_NUMBER_COLOR, true)
	_refresh_member(target)


# --- Shared visuals ---

# Melee attackers lunge toward their target; missile attackers pulse in place.
func _play_attacker_motion(attacker: Control, melee: bool, targets: Array, target: int, distance: float) -> void:
	if not melee:
		attacker.play_cast()
	elif _valid(targets, target):
		attacker.play_lunge(_center(targets[target]) - _center(attacker), distance)


# Melee hits add a slash across the impact; missile hits are a burst only.
func _play_impact(unit: Control, melee: bool) -> void:
	var pos := _center(unit)
	if melee:
		_vfx.spawn_slash(pos, Vector2.RIGHT.rotated(randf_range(-0.6, 0.6)))
	_vfx.spawn_impact(pos, false)


func _refresh_member(member_index: int) -> void:
	if not _valid(_party_units, member_index):
		return
	var data: Dictionary = _engine.get_member_data(member_index)
	var pm: Control = _party_units[member_index]
	pm.update_hp(data.get("current_hp", 0), data.get("max_hp", 50))
	pm.update_buffs(data.get("active_buffs", []))
	if data.get("is_ko", false):
		pm.set_ko()


func _refresh_enemy(enemy_index: int) -> void:
	var data: Dictionary = _engine.get_enemy_data(enemy_index)
	var ed: Control = _enemy_units[enemy_index]
	ed.update_hp(data.get("current_hp", 0), data.get("max_hp", 30))
	if not data.get("alive", true) and not _dead_shown.has(enemy_index):
		_dead_shown[enemy_index] = true
		_vfx.spawn_death_poof(_center(ed))
		ed.play_death()


# --- Engine events that aren't hits ---

# HP waits for hits to arrive; buff timers tick with the engine.
func _on_tick_resolved() -> void:
	for i in range(_party_units.size()):
		if _valid(_party_units, i):
			_party_units[i].update_buffs(_engine.get_member_data(i).get("active_buffs", []))


func _on_telegraph_changed(enemy_index: int, target_index: int, turns_remaining: int) -> void:
	if _valid(_enemy_units, enemy_index):
		_enemy_units[enemy_index].get_unit().play_heavy_charge(target_index >= 0 and turns_remaining > 0)


func _on_effect_applied(member_index: int, effect_type: String, amount: int) -> void:
	if not _valid(_party_units, member_index):
		return
	var pos := _center(_party_units[member_index])
	if effect_type == "heal":
		_vfx.spawn_heal_fx(pos)
		_vfx.spawn_floating_text(pos, "+%d HP" % amount, Color(0.2, 1.0, 0.3))
	elif effect_type == "buff_attack":
		_vfx.spawn_buff_fx(pos)
		_vfx.spawn_floating_text(pos, "ATK +%d" % amount, Color(1.0, 0.8, 0.2))


func _number_pos(unit: Control, attacker_slot: int, attacker_count: int) -> Vector2:
	return _center(unit) + Vector2((attacker_slot - (attacker_count - 1) * 0.5) * NUMBER_SPREAD, 0.0)


func _center(unit: Control) -> Vector2:
	return unit.global_position + unit.size * 0.5


func _valid(units: Array, index: int) -> bool:
	return index >= 0 and index < units.size() and is_instance_valid(units[index])
