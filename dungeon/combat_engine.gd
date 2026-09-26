extends Node

signal enemy_died(enemy_index: int)
signal member_ko(member_index: int)
signal party_wiped()
signal encounter_ended()
# Fired once a tick's damage has landed, so views can refresh HP and telegraphs.
signal tick_resolved()
signal party_attacked(member_index: int, target_indices: Array[int], damage_per_target: int)
signal enemy_attacked(enemy_index: int, attack_type: String, is_heavy: bool, target_indices: Array[int], damage: int)
signal telegraph_changed(enemy_index: int, target_index: int, turns_remaining: int)
signal effect_applied(member_index: int, effect_type: String, amount: int)

# Ticks between heavy attacks of neighbouring enemies. At 1, a pair lands on
# back-to-back ticks and can one-shot a full-HP member with no window to heal.
const HEAVY_STAGGER_TICKS := 2

# One rule for both sides: melee reaches only the front of the other side (the
# lowest standing slot), missile reaches all of it.
const ATTACK_MELEE := "melee"
const ATTACK_MISSILE := "missile"

var party_members: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var tick_timer: Timer


func _ready() -> void:
	tick_timer = Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.one_shot = false
	tick_timer.timeout.connect(tick)
	add_child(tick_timer)


func start_combat(enemy_definitions: Array) -> void:
	enemies.clear()
	for edef in enemy_definitions:
		var enemy_id: String = edef.get("enemy_id", "")
		var count: int = edef.get("count", 1)
		for _i in range(count):
			enemies.append(_make_enemy(enemy_id, enemies.size()))
	_dbg("start_combat: %d enemies" % enemies.size())
	tick_timer.start()


func stop_combat() -> void:
	tick_timer.stop()


func init_party(party_data: Array[Dictionary]) -> void:
	party_members.clear()
	for data in party_data:
		var attack_type: String = data["attack_type"]
		assert(attack_type in [ATTACK_MELEE, ATTACK_MISSILE], "%s: unknown attack_type '%s'" % [data.get("name", "?"), attack_type])
		party_members.append({
			"name": data.get("name", ""),
			"attack_type": attack_type,
			"max_hp": data.get("max_hp", 50),
			"current_hp": data.get("max_hp", 50),
			"attack": data.get("attack", 10),
			"active_buffs": [],
			"is_ko": false,
		})


func tick() -> void:
	if party_members.is_empty() or enemies.is_empty():
		return

	var alive_enemies := get_alive_enemy_count()
	var active_members := get_active_member_count()
	if alive_enemies == 0 or active_members == 0:
		return

	_dbg("tick: alive_enemies=%d active_members=%d" % [alive_enemies, active_members])

	for idx in range(party_members.size()):
		if not party_members[idx].get("is_ko", false):
			_land_party_attack(idx)

	var deaths: Array[int] = []
	for i in range(enemies.size()):
		if enemies[i].get("alive", false) and enemies[i].get("current_hp", 0) <= 0:
			enemies[i]["alive"] = false
			deaths.append(i)

	for idx in deaths:
		_dbg("enemy %d died: %s" % [idx, enemies[idx].get("name", "?")])
		if enemies[idx].get("heavy_target", -1) >= 0:
			telegraph_changed.emit(idx, -1, 0)
		enemy_died.emit(idx)

	if get_alive_enemy_count() == 0:
		_dbg("all enemies dead — encounter ended")
		encounter_ended.emit()
		stop_combat()
		return

	_resolve_enemy_attacks()

	var kos: Array[int] = []
	for i in range(party_members.size()):
		if not party_members[i].get("is_ko", false) and party_members[i].get("current_hp", 0) <= 0:
			party_members[i]["is_ko"] = true
			party_members[i]["current_hp"] = 0
			kos.append(i)

	for idx in kos:
		_dbg("member %d KO'd" % idx)
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

	tick_resolved.emit()


func apply_effect(member_index: int, effect: Variant) -> void:
	if member_index < 0 or member_index >= party_members.size():
		return
	var member: Dictionary = party_members[member_index]
	if member.get("is_ko", false):
		return
	var etype: String = ""
	var power: int = 0
	var duration: int = 0
	if effect is EffectDefinition:
		etype = effect.type
		power = effect.value
		duration = effect.duration
	elif effect is Dictionary:
		etype = effect.get("type", "")
		power = int(effect.get("power", effect.get("value", 0)))
		duration = int(effect.get("duration", 10 if etype == "buff_attack" else 0))
	
	if etype == "heal":
		member["current_hp"] = mini(member.get("current_hp", 0) + power, member.get("max_hp", 50))
		effect_applied.emit(member_index, "heal", power)
	elif etype == "buff_attack":
		member.get("active_buffs").append({
			"effect": "buff_attack",
			"power": power,
			"duration": duration,
		})
		effect_applied.emit(member_index, "buff_attack", power)


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


# Which of the candidate slots (ordered front to back) an attack reaches.
static func reach(attack_type: String, candidates: Array[int]) -> Array[int]:
	if attack_type == ATTACK_MELEE and not candidates.is_empty():
		return [candidates[0]]
	return candidates.duplicate()


func is_combat_running() -> bool:
	return not tick_timer.is_stopped()


# 0 when the windup starts (end of the tick that locked the target), 1 when the
# heavy attack plays. The view plays enemy hits `landing_delay` seconds after
# the tick that resolves them, so the countdown stretches to end on that beat.
# Pure so views and tests don't depend on a running timer.
static func windup_progress(heavy_in: int, windup: int, tick_time_left: float, tick_wait: float, landing_delay: float) -> float:
	var total := windup * tick_wait + landing_delay
	if total <= 0.0:
		return 1.0
	var remaining := (heavy_in - 1) * tick_wait + tick_time_left + landing_delay
	return clampf(1.0 - remaining / total, 0.0, 1.0)


# -1 when the enemy isn't winding up a heavy attack or combat is stopped.
func get_windup_progress(enemy_index: int, landing_delay: float) -> float:
	if not is_combat_running() or not _is_winding_up(enemy_index):
		return -1.0
	var enemy: Dictionary = enemies[enemy_index]
	return windup_progress(enemy["heavy_in"], int(enemy["heavy_attack"]["windup"]), tick_timer.time_left, tick_timer.wait_time, landing_delay)


# Total heavy damage currently telegraphed at this member.
func get_incoming_heavy_damage(member_index: int) -> int:
	var total := 0
	for i in range(enemies.size()):
		if _is_winding_up(i) and enemies[i]["heavy_target"] == member_index:
			total += int(enemies[i]["heavy_attack"]["damage"])
	return total


# heavy_target is set only once the windup starts and cleared when the hit
# lands, but a dead enemy keeps its last target.
func _is_winding_up(enemy_index: int) -> bool:
	if enemy_index < 0 or enemy_index >= enemies.size():
		return false
	var enemy: Dictionary = enemies[enemy_index]
	return enemy.get("alive", false) and enemy["heavy_target"] >= 0


func _land_party_attack(member_index: int) -> void:
	var member: Dictionary = party_members[member_index]
	var targets := reach(member["attack_type"], _alive_enemies())
	if targets.is_empty():
		return
	var atk: int = member.get("attack", 10)
	for buff in member.get("active_buffs", []):
		if buff.get("effect", "") == "buff_attack":
			atk += int(buff.get("power", 0))
	var dmg_per_enemy := maxi(floori(atk / targets.size()), 1)
	_dbg("  %s atk=%d -> %d dmg to enemies %s" % [member.get("name", "?"), atk, dmg_per_enemy, str(targets)])
	for i in targets:
		enemies[i]["current_hp"] -= dmg_per_enemy
	party_attacked.emit(member_index, targets, dmg_per_enemy)


# Alive and not already dropped to 0 this tick (deaths are marked only after
# the whole party has attacked), mirroring _standing_members.
func _alive_enemies() -> Array[int]:
	var alive: Array[int] = []
	for i in range(enemies.size()):
		if enemies[i].get("alive", false) and enemies[i].get("current_hp", 0) > 0:
			alive.append(i)
	return alive


func _resolve_enemy_attacks() -> void:
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		if not enemy.get("alive", false):
			continue
		enemy["heavy_in"] = int(enemy["heavy_in"]) - 1
		if enemy["heavy_in"] <= 0:
			_land_heavy_attack(enemy, i)
		else:
			_land_basic_attack(enemy, i)
	# Targets are picked after every hit has landed, so none locks onto a member
	# a later enemy drops this same tick.
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		if enemy.get("alive", false):
			_update_heavy_target(enemy, i)


func _land_basic_attack(enemy: Dictionary, enemy_index: int) -> void:
	var eatk: int = enemy.get("attack", 5)
	var targets := reach(enemy["attack_type"], _standing_members())
	if targets.is_empty():
		return
	var dmg_per_member := maxi(floori(eatk / targets.size()), 1)
	_dbg("  %s atk=%d -> %d dmg to members %s" % [enemy.get("name", "?"), eatk, dmg_per_member, str(targets)])
	for i in targets:
		party_members[i]["current_hp"] -= dmg_per_member
	enemy_attacked.emit(enemy_index, enemy["attack_type"], false, targets, dmg_per_member)


# The telegraphed hit lands on one member, locked in when the windup starts so
# the player knows whom to protect.
func _land_heavy_attack(enemy: Dictionary, enemy_index: int) -> void:
	var heavy: Dictionary = enemy["heavy_attack"]
	var target: int = enemy["heavy_target"]
	if not _is_standing(target):
		target = _pick_target(enemy)
	var dmg: int = int(heavy["damage"])
	var hit_targets: Array[int] = []
	if target >= 0:
		party_members[target]["current_hp"] -= dmg
		_dbg("  %s %s -> member %d for %d" % [enemy.get("name", "?"), heavy.get("name", "?"), target, dmg])
		hit_targets.append(target)
	enemy["heavy_in"] = int(heavy["interval"])
	enemy["heavy_target"] = -1
	enemy_attacked.emit(enemy_index, enemy["attack_type"], true, hit_targets, dmg)
	telegraph_changed.emit(enemy_index, -1, enemy["heavy_in"])


func _update_heavy_target(enemy: Dictionary, enemy_index: int) -> void:
	if enemy["heavy_in"] > int(enemy["heavy_attack"]["windup"]):
		return
	if not _is_standing(enemy["heavy_target"]):
		enemy["heavy_target"] = _pick_target(enemy)
	telegraph_changed.emit(enemy_index, enemy["heavy_target"], enemy["heavy_in"])


# Standing = not KO'd and not already dropped to 0 this tick (KOs are marked
# only after every enemy has acted).
func _is_standing(member_index: int) -> bool:
	if member_index < 0 or member_index >= party_members.size():
		return false
	var member: Dictionary = party_members[member_index]
	return not member.get("is_ko", false) and member.get("current_hp", 0) > 0


func _pick_target(enemy: Dictionary) -> int:
	if enemy["attack_type"] == ATTACK_MELEE:
		return _front_member()
	return _weakest_standing_member()


# Party order is slot order, so the front member is the first one standing.
func _front_member() -> int:
	var standing := _standing_members()
	return standing[0] if not standing.is_empty() else -1


func _standing_members() -> Array[int]:
	var standing: Array[int] = []
	for i in range(party_members.size()):
		if _is_standing(i):
			standing.append(i)
	return standing


func _weakest_standing_member() -> int:
	var best := -1
	for i in range(party_members.size()):
		if _is_standing(i) and (best < 0 or party_members[i]["current_hp"] < party_members[best]["current_hp"]):
			best = i
	return best


func _make_enemy(enemy_id: String, slot: int) -> Dictionary:
	var base: Dictionary = RecipeResolver.enemies.get(enemy_id, {})
	var heavy: Dictionary = base["heavy_attack"].duplicate()
	var attack_type: String = base["attack_type"]
	assert(attack_type in [ATTACK_MELEE, ATTACK_MISSILE], "%s: unknown attack_type '%s'" % [enemy_id, attack_type])
	return {
		"enemy_id": enemy_id,
		"name": base.get("name", enemy_id),
		"max_hp": base.get("max_hp", 30),
		"current_hp": base.get("max_hp", 30),
		"attack_type": attack_type,
		"attack": base.get("attack", 5),
		"sprite": base["sprite"],
		"drop_count": base.get("drop_count", {"min": 1, "max": 1}),
		"drop_pool": base.get("drop_pool", []),
		"heavy_attack": heavy,
		"heavy_in": int(heavy["interval"]) + slot * HEAVY_STAGGER_TICKS,
		"heavy_target": -1,
		"alive": true,
	}


func _dbg(msg: String) -> void:
	if GameManager.debug_mode:
		print("[CombatEngine] %s" % msg)
