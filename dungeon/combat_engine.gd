extends Node

# Combat on a fixed tick, one rule for both sides. Every standing unit runs one
# attack at a time: a windup of `windup` ticks aimed at one target, then the
# hit. The crit roll happens when the windup starts, so views can show it for
# the whole windup: a crit winds up CRIT_WINDUP_MULT times longer and hits
# CRIT_DAMAGE_MULT times harder.

signal enemy_died(enemy_index: int)
signal member_ko(member_index: int)
signal party_wiped()
signal encounter_ended()
# Fired once a tick's damage has landed, so views can refresh HP and buffs.
signal tick_resolved()
signal party_attacked(member_index: int, target_index: int, damage: int, is_crit: bool)
signal enemy_attacked(enemy_index: int, target_index: int, damage: int, is_crit: bool)
# A windup started or retargeted; target -1 when it ended (it landed, or the
# attacker fell).
signal windup_changed(side: int, attacker_index: int, target_index: int, is_crit: bool)
signal effect_applied(member_index: int, effect_type: String, amount: int)

const SIDE_PARTY := 0
const SIDE_ENEMY := 1

# Melee hits the front of the other side (the lowest standing slot); missile
# hits its weakest unit (lowest current HP), reaching past the front.
const ATTACK_MELEE := "melee"
const ATTACK_MISSILE := "missile"

# A crit deals 2x the damage per second of a normal attack, and its longer
# windup is the player's window to react.
const CRIT_WINDUP_MULT := 2
const CRIT_DAMAGE_MULT := 4

var party_members: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var tick_timer: Timer
# Tests swap in a seeded generator or use crit chances of 0 and 1.
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	tick_timer = Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.one_shot = false
	tick_timer.timeout.connect(tick)
	add_child(tick_timer)


func start_combat(spawns: Array[EnemySpawn]) -> void:
	enemies.clear()
	for spawn in spawns:
		for _i in range(spawn.count):
			enemies.append(_make_enemy(spawn.enemy))
	_dbg("start_combat: %d enemies" % enemies.size())
	_start_windups()
	tick_timer.start()


func stop_combat() -> void:
	tick_timer.stop()


# Array order is slot order: index 0 is the front member melee enemies hit.
func init_party(members: Array[PartyMemberDefinition]) -> void:
	party_members.clear()
	for def in members:
		var member := _attack_state(def)
		member.merge({
			"name": def.name,
			"max_hp": def.max_hp,
			"current_hp": def.max_hp,
			"active_buffs": [],
			"is_ko": false,
		})
		party_members.append(member)


func tick() -> void:
	if party_members.is_empty() or enemies.is_empty():
		return
	if get_alive_enemy_count() == 0 or get_active_member_count() == 0:
		return

	for i in range(party_members.size()):
		_advance_windup(SIDE_PARTY, i)

	var deaths: Array[int] = []
	for i in range(enemies.size()):
		if enemies[i].get("alive", false) and enemies[i].get("current_hp", 0) <= 0:
			enemies[i]["alive"] = false
			deaths.append(i)

	for idx in deaths:
		_dbg("enemy %d died: %s" % [idx, enemies[idx].get("name", "?")])
		_clear_windup(SIDE_ENEMY, idx)
		enemy_died.emit(idx)

	if get_alive_enemy_count() == 0:
		_dbg("all enemies dead — encounter ended")
		for i in range(party_members.size()):
			_clear_windup(SIDE_PARTY, i)
		encounter_ended.emit()
		stop_combat()
		return

	for i in range(enemies.size()):
		_advance_windup(SIDE_ENEMY, i)

	var kos: Array[int] = []
	for i in range(party_members.size()):
		if not party_members[i].get("is_ko", false) and party_members[i].get("current_hp", 0) <= 0:
			party_members[i]["is_ko"] = true
			party_members[i]["current_hp"] = 0
			kos.append(i)

	for idx in kos:
		_dbg("member %d KO'd" % idx)
		_clear_windup(SIDE_PARTY, idx)
		AudioManager.play_sfx("ko")
		member_ko.emit(idx)

	if get_active_member_count() == 0:
		_dbg("party wiped!")
		tick_resolved.emit()
		party_wiped.emit()
		stop_combat()
		return

	for member in party_members:
		var buffs: Array = member.get("active_buffs", [])
		var remaining: Array = []
		for buff in buffs:
			buff["duration"] = buff.get("duration", 0) - 1
			if buff.get("duration", 0) > 0:
				remaining.append(buff)
		member["active_buffs"] = remaining

	# New windups start only after every hit has landed, so none locks onto a
	# unit dropped this tick.
	_start_windups()
	tick_resolved.emit()


func apply_effect(member_index: int, effect: EffectDefinition) -> void:
	if member_index < 0 or member_index >= party_members.size():
		return
	var member: Dictionary = party_members[member_index]
	if member.get("is_ko", false):
		return
	if effect.type == "heal":
		member["current_hp"] = mini(member.get("current_hp", 0) + effect.value, member.get("max_hp", 50))
		effect_applied.emit(member_index, "heal", effect.value)
	elif effect.type == "buff_attack":
		member.get("active_buffs").append({
			"effect": "buff_attack",
			"value": effect.value,
			"duration": effect.duration,
		})
		effect_applied.emit(member_index, "buff_attack", effect.value)


func get_active_member_count() -> int:
	var count := 0
	for member in party_members:
		if not member.get("is_ko", false):
			count += 1
	return count


func get_alive_enemy_count() -> int:
	var count := 0
	for enemy in enemies:
		if enemy.get("alive", false):
			count += 1
	return count


func get_enemy_data(index: int) -> Dictionary:
	if index < 0 or index >= enemies.size():
		return {}
	return enemies[index]


func get_member_data(index: int) -> Dictionary:
	if index < 0 or index >= party_members.size():
		return {}
	return party_members[index]


func is_combat_running() -> bool:
	return not tick_timer.is_stopped()


# True while the unit is winding up an attack.
func is_winding_up(side: int, index: int) -> bool:
	return _is_up(side, index) and _units(side)[index]["target"] >= 0


# What the unit's current windup will deal when it lands, attack buffs and the
# crit multiplier included. 0 when it isn't winding up.
func get_pending_damage(side: int, index: int) -> int:
	if not is_winding_up(side, index):
		return 0
	var unit: Dictionary = _units(side)[index]
	var damage: int = unit["attack"]
	for buff in unit.get("active_buffs", []):
		if buff.get("effect", "") == "buff_attack":
			damage += int(buff.get("value", 0))
	if unit["is_crit"]:
		damage *= CRIT_DAMAGE_MULT
	return damage


# Total damage enemies are winding up at this member.
func get_incoming_damage(member_index: int) -> int:
	var total := 0
	for i in range(enemies.size()):
		if is_winding_up(SIDE_ENEMY, i) and enemies[i]["target"] == member_index:
			total += get_pending_damage(SIDE_ENEMY, i)
	return total


# 0 when a windup starts (end of the tick that started it), 1 when its hit
# plays. A side's hits can play `landing_delay` seconds after the tick that
# resolves them, so the countdown stretches to end on that beat. Pure so views
# and tests don't depend on a running timer.
static func windup_progress(ticks_left: int, windup_ticks: int, tick_time_left: float, tick_wait: float, landing_delay: float) -> float:
	var total := windup_ticks * tick_wait + landing_delay
	if total <= 0.0:
		return 1.0
	var remaining := (ticks_left - 1) * tick_wait + tick_time_left + landing_delay
	return clampf(1.0 - remaining / total, 0.0, 1.0)


# -1 when the unit isn't winding up or combat is stopped.
func get_windup_progress(side: int, index: int, landing_delay: float) -> float:
	if not is_combat_running() or not is_winding_up(side, index):
		return -1.0
	var unit: Dictionary = _units(side)[index]
	return windup_progress(unit["ticks_left"], unit["windup_ticks"], tick_timer.time_left, tick_timer.wait_time, landing_delay)


func _advance_windup(side: int, index: int) -> void:
	if not is_winding_up(side, index):
		return
	var unit: Dictionary = _units(side)[index]
	unit["ticks_left"] -= 1
	if unit["ticks_left"] <= 0:
		_land(side, index)


func _land(side: int, index: int) -> void:
	var unit: Dictionary = _units(side)[index]
	var foe_side := _other(side)
	var target: int = unit["target"]
	if not _is_up(foe_side, target):
		target = _pick_target(unit["attack_type"], foe_side)
	var damage := get_pending_damage(side, index)
	var is_crit: bool = unit["is_crit"]
	unit["target"] = -1
	unit["is_crit"] = false
	if target >= 0:
		_units(foe_side)[target]["current_hp"] -= damage
		_dbg("  %s -> %d for %d%s" % [unit.get("name", "?"), target, damage, " (crit)" if is_crit else ""])
		if side == SIDE_PARTY:
			party_attacked.emit(index, target, damage, is_crit)
		else:
			enemy_attacked.emit(index, target, damage, is_crit)
	windup_changed.emit(side, index, -1, false)


func _start_windups() -> void:
	for side in [SIDE_PARTY, SIDE_ENEMY]:
		for i in range(_units(side).size()):
			if _is_up(side, i):
				_refresh_windup(side, i)


# Starts a windup for an idle unit; a winding one keeps its target unless that
# target has fallen.
func _refresh_windup(side: int, index: int) -> void:
	var unit: Dictionary = _units(side)[index]
	var foe_side := _other(side)
	if unit["target"] >= 0:
		if not _is_up(foe_side, unit["target"]):
			unit["target"] = _pick_target(unit["attack_type"], foe_side)
			windup_changed.emit(side, index, unit["target"], unit["is_crit"])
		return
	var target := _pick_target(unit["attack_type"], foe_side)
	if target < 0:
		return
	unit["is_crit"] = _roll_crit(unit["crit_chance"])
	unit["windup_ticks"] = unit["crit_windup"] if unit["is_crit"] else unit["windup"]
	unit["ticks_left"] = unit["windup_ticks"]
	unit["target"] = target
	windup_changed.emit(side, index, target, unit["is_crit"])


func _clear_windup(side: int, index: int) -> void:
	var unit: Dictionary = _units(side)[index]
	if unit["target"] < 0:
		return
	unit["target"] = -1
	unit["is_crit"] = false
	windup_changed.emit(side, index, -1, false)


func _roll_crit(chance: float) -> bool:
	return chance >= 1.0 or (chance > 0.0 and rng.randf() < chance)


# Slot order is index order, so the front unit is the first one standing.
func _pick_target(attack_type: String, side: int) -> int:
	var units := _units(side)
	var best := -1
	for i in range(units.size()):
		if not _is_up(side, i):
			continue
		if attack_type == ATTACK_MELEE:
			return i
		if best < 0 or units[i]["current_hp"] < units[best]["current_hp"]:
			best = i
	return best


# Up = not KO'd or dead, and not already dropped to 0 this tick (KOs and deaths
# are marked only after a whole side has attacked).
func _is_up(side: int, index: int) -> bool:
	var units := _units(side)
	if index < 0 or index >= units.size():
		return false
	var unit: Dictionary = units[index]
	var down: bool = unit["is_ko"] if side == SIDE_PARTY else not unit["alive"]
	return not down and unit["current_hp"] > 0


func _units(side: int) -> Array[Dictionary]:
	return party_members if side == SIDE_PARTY else enemies


func _other(side: int) -> int:
	return SIDE_ENEMY if side == SIDE_PARTY else SIDE_PARTY


# The attack fields both sides share, plus the state of the current windup.
# `def` is a PartyMemberDefinition or an EnemyDefinition; both carry these
# fields.
func _attack_state(def: Resource) -> Dictionary:
	var attack_type: String = def.attack_type
	assert(attack_type in [ATTACK_MELEE, ATTACK_MISSILE], "%s: unknown attack_type '%s'" % [def.id, attack_type])
	var windup: int = def.windup
	assert(windup >= 1, "%s: windup must be at least 1 tick" % def.id)
	var crit_windup: int = def.crit_windup if ("crit_windup" in def and def.crit_windup > 0) else windup * CRIT_WINDUP_MULT
	var crit_sprite: Texture2D = def.crit_sprite if "crit_sprite" in def else null
	return {
		"attack_type": attack_type,
		"attack": def.attack,
		"windup": windup,
		"crit_windup": crit_windup,
		"crit_chance": def.crit_chance,
		"crit_name": def.crit_name,
		"crit_sprite": crit_sprite,
		"target": -1,
		"ticks_left": 0,
		"windup_ticks": 0,
		"is_crit": false,
	}


func _make_enemy(def: EnemyDefinition) -> Dictionary:
	var enemy := _attack_state(def)
	enemy.merge({
		"definition": def,
		"name": def.name,
		"max_hp": def.max_hp,
		"current_hp": def.max_hp,
		"sprite": def.sprite,
		"alive": true,
	})
	return enemy


func _dbg(msg: String) -> void:
	if GameManager.debug_mode:
		print("[CombatEngine] %s" % msg)
