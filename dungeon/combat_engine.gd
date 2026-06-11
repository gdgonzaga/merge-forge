extends Node

signal enemy_died(enemy_index: int)
signal member_ko(member_index: int)
signal party_wiped()
signal encounter_ended()

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
			enemies.append(_make_enemy(enemy_id))
	_dbg("start_combat: %d enemies" % enemies.size())
	tick_timer.start()


func stop_combat() -> void:
	tick_timer.stop()


func init_party(party_data: Array[Dictionary]) -> void:
	party_members.clear()
	for data in party_data:
		party_members.append({
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

	for member in party_members:
		if member.get("is_ko", false):
			continue
		var atk: int = member.get("attack", 10)
		for buff in member.get("active_buffs", []):
			if buff.get("effect", "") == "buff_attack":
				atk += int(buff.get("power", 0))
		var dmg_per_enemy := maxi(floori(atk / alive_enemies), 1)
		_dbg("  %s atk=%d -> %d dmg to each of %d enemies" % [member.get("name", "?"), atk, dmg_per_enemy, alive_enemies])
		for i in range(enemies.size()):
			if enemies[i].get("alive", false):
				enemies[i]["current_hp"] = enemies[i].get("current_hp", 0) - dmg_per_enemy
				_dbg("    enemy[%d] %s hp now %d/%d" % [i, enemies[i].get("name", "?"), enemies[i].get("current_hp", 0), enemies[i].get("max_hp", 30)])

	var deaths: Array[int] = []
	for i in range(enemies.size()):
		if enemies[i].get("alive", false) and enemies[i].get("current_hp", 0) <= 0:
			enemies[i]["alive"] = false
			deaths.append(i)

	for idx in deaths:
		_dbg("enemy %d died: %s" % [idx, enemies[idx].get("name", "?")])
		enemy_died.emit(idx)

	if get_alive_enemy_count() == 0:
		_dbg("all enemies dead — encounter ended")
		encounter_ended.emit()
		stop_combat()
		return

	for enemy in enemies:
		if not enemy.get("alive", false):
			continue
		var eatk: int = enemy.get("attack", 5)
		var dmg_per_member := maxi(floori(eatk / active_members), 1)
		_dbg("  %s atk=%d -> %d dmg to each of %d members" % [enemy.get("name", "?"), eatk, dmg_per_member, active_members])
		for member in party_members:
			if not member.get("is_ko", false):
				member["current_hp"] = member.get("current_hp", 0) - dmg_per_member
				_dbg("    %s hp now %d/%d" % [member.get("name", "?"), member.get("current_hp", 0), member.get("max_hp", 50)])

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


func apply_effect(member_index: int, effect: Dictionary) -> void:
	if member_index < 0 or member_index >= party_members.size():
		return
	var member: Dictionary = party_members[member_index]
	if member.get("is_ko", false):
		return
	var etype: String = effect.get("type", "")
	if etype == "heal":
		var power: int = int(effect.get("power", 0))
		member["current_hp"] = mini(member.get("current_hp", 0) + power, member.get("max_hp", 50))
	elif etype == "buff_attack":
		member.get("active_buffs").append({
			"effect": "buff_attack",
			"power": effect.get("power", 0),
			"duration": int(effect.get("duration", 10)),
		})


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


func _make_enemy(enemy_id: String) -> Dictionary:
	var base: Dictionary = RecipeResolver.enemies.get(enemy_id, {})
	return {
		"enemy_id": enemy_id,
		"name": base.get("name", enemy_id),
		"max_hp": base.get("max_hp", 30),
		"current_hp": base.get("max_hp", 30),
		"attack": base.get("attack", 5),
		"sprite": base.get("sprite", ""),
		"drop_count": base.get("drop_count", {"min": 1, "max": 1}),
		"drop_pool": base.get("drop_pool", []),
		"alive": true,
	}


func _dbg(msg: String) -> void:
	if GameManager.debug_mode:
		print("[CombatEngine] %s" % msg)
