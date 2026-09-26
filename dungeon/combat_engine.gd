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

# Melee reaches only the front member (lowest standing party slot); missile
# reaches the whole party.
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
		party_members.append({
			"name": data.get("name", ""),
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
		var member: Dictionary = party_members[idx]
		if member.get("is_ko", false):
			continue
		var atk: int = member.get("attack", 10)
		for buff in member.get("active_buffs", []):
			if buff.get("effect", "") == "buff_attack":
				atk += int(buff.get("power", 0))
		var dmg_per_enemy := maxi(floori(atk / alive_enemies), 1)
		_dbg("  %s atk=%d -> %d dmg to each of %d enemies" % [member.get("name", "?"), atk, dmg_per_enemy, alive_enemies])
		var hit_enemies: Array[int] = []
		for i in range(enemies.size()):
			if enemies[i].get("alive", false):
				enemies[i]["current_hp"] = enemies[i].get("current_hp", 0) - dmg_per_enemy
				_dbg("    enemy[%d] %s hp now %d/%d" % [i, enemies[i].get("name", "?"), enemies[i].get("current_hp", 0), enemies[i].get("max_hp", 30)])
				hit_enemies.append(i)
		party_attacked.emit(idx, hit_enemies, dmg_per_enemy)

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
	var targets := _standing_members()
	if targets.is_empty():
		return
	if enemy["attack_type"] == ATTACK_MELEE:
		targets = [targets[0]]
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
		"sprite": base.get("sprite", ""),
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
