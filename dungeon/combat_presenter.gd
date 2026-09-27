extends Node

# Plays combat for the dungeon view: attacker motions, impacts and floating
# numbers, crit call-outs, and HP, KO and death visuals. The attack lines
# themselves are CombatLines.
#
# Every attack lands when its windup line fills. Party hits play on the tick;
# enemy hits play ENEMY_VOLLEY_DELAY later, so each side's attacks read as a
# beat. Unit HP bars change when a hit plays rather than when the engine
# resolves it, so bars, numbers and impacts stay in step. Engine state is
# already final for the tick, so a bar refreshed then always shows the truth.

const ENGINE := preload("res://dungeon/combat_engine.gd")

const ENEMY_VOLLEY_DELAY := 0.3
const MELEE := "melee"
const LUNGE_DISTANCE := 20.0
const CRIT_LUNGE_DISTANCE := 30.0
const PARTY_NUMBER_COLOR := Color(0.55, 0.85, 1.0)
const ENEMY_NUMBER_COLOR := Color(1.0, 0.3, 0.3)
const CRIT_NUMBER_COLOR := Color(1.0, 0.82, 0.15)
const CRIT_NAME_COLOR := Color(1.0, 0.6, 0.15)
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
	engine.windup_changed.connect(_on_windup_changed)
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


# --- Hits ---

func _on_party_attacked(member_index: int, target: int, damage: int, is_crit: bool) -> void:
	if not _valid(_party_units, member_index):
		return
	var data: Dictionary = _engine.get_member_data(member_index)
	_play_attack(_party_units[member_index], data, _enemy_units, target, is_crit)
	if _valid(_enemy_units, target):
		var number_color := CRIT_NUMBER_COLOR if is_crit else PARTY_NUMBER_COLOR
		_vfx.spawn_floating_text(_number_pos(_enemy_units[target], member_index, _party_units.size()),
			str(damage), number_color, is_crit)
		_refresh_enemy(target)


func _on_enemy_attacked(enemy_index: int, target: int, damage: int, is_crit: bool) -> void:
	var windup_ticks: int = _engine.get_enemy_data(enemy_index)["windup_ticks"]
	_lines.hold(enemy_index, target, damage, is_crit, windup_ticks)
	get_tree().create_timer(ENEMY_VOLLEY_DELAY).timeout.connect(
		_play_enemy_hit.bind(enemy_index, target, damage, is_crit))


func _play_enemy_hit(enemy_index: int, target: int, damage: int, is_crit: bool) -> void:
	if not _valid(_enemy_units, enemy_index):
		return
	var data: Dictionary = _engine.get_enemy_data(enemy_index)
	_play_attack(_enemy_units[enemy_index], data, _party_units, target, is_crit)
	if _valid(_party_units, target):
		var number_color := CRIT_NUMBER_COLOR if is_crit else ENEMY_NUMBER_COLOR
		_vfx.spawn_floating_text(_number_pos(_party_units[target], enemy_index, _enemy_units.size()),
			"-%d" % damage, number_color, is_crit)
		_refresh_member(target)


# The attacker's motion and the impact on the target; a crit adds its name over
# the attacker and a screen shake.
func _play_attack(attacker: Control, attacker_data: Dictionary, targets: Array, target: int, is_crit: bool) -> void:
	var melee: bool = attacker_data["attack_type"] == MELEE
	_play_attacker_motion(attacker, melee, targets, target, CRIT_LUNGE_DISTANCE if is_crit else LUNGE_DISTANCE)
	if is_crit:
		_vfx.screen_shake(8.0, 0.25)
		_vfx.spawn_floating_text(attacker.global_position + Vector2(attacker.size.x * 0.5, 0.0),
			attacker_data["crit_name"], CRIT_NAME_COLOR, true)
	if _valid(targets, target):
		targets[target].play_hit(is_crit)
		_play_impact(targets[target], melee, is_crit)


# --- Shared visuals ---

# Melee attackers lunge toward their target; missile attackers pulse in place.
func _play_attacker_motion(attacker: Control, melee: bool, targets: Array, target: int, distance: float) -> void:
	if not melee:
		attacker.play_cast()
	elif _valid(targets, target):
		attacker.play_lunge(_center(targets[target]) - _center(attacker), distance)


# Melee hits add a slash across the impact; missile hits are a burst only.
func _play_impact(unit: Control, melee: bool, is_crit: bool) -> void:
	var pos := _center(unit)
	if melee:
		_vfx.spawn_slash(pos, Vector2.RIGHT.rotated(randf_range(-0.6, 0.6)))
	_vfx.spawn_impact(pos, is_crit)


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
	if not _valid(_enemy_units, enemy_index):
		return
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


func _on_windup_changed(side: int, attacker_index: int, target_index: int, is_crit: bool) -> void:
	var units := _party_units if side == ENGINE.SIDE_PARTY else _enemy_units
	if _valid(units, attacker_index):
		units[attacker_index].get_unit().play_crit_charge(target_index >= 0 and is_crit)


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
