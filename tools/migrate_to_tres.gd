@tool
extends SceneTree

func _init() -> void:
	print("Starting migration from JSON to .tres definitions...")
	_ensure_dirs()
	_migrate_items()
	_migrate_party()
	_migrate_enemies()
	print("Migration complete!")
	quit(0)


func _ensure_dirs() -> void:
	var dirs := [
		"res://resources/definitions",
		"res://resources/definitions/items",
		"res://resources/definitions/party",
		"res://resources/definitions/enemies",
		"res://resources/definitions/attacks",
		"res://resources/definitions/effects",
	]
	for d in dirs:
		if not DirAccess.dir_exists_absolute(d):
			DirAccess.make_dir_recursive_absolute(d)


func _migrate_items() -> void:
	var items_data: Dictionary = _load_json("res://data/items.json")
	for item_id in items_data:
		var data: Dictionary = items_data[item_id]
		var item_def := ItemDefinition.new()
		item_def.id = item_id
		item_def.name = data.get("name", item_id)
		item_def.family = data.get("family", "")
		item_def.gold_value = data.get("gold_value", 0)
		item_def.dungeon_usable = data.get("dungeon_usable", false)
		item_def.dungeon_use_target = data.get("dungeon_use_target", "") if data.get("dungeon_use_target") != null else ""
		
		var icon_path: String = data.get("icon", "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			item_def.sprite = load(icon_path) as Texture2D
		
		var eff_data = data.get("effect")
		if eff_data is Dictionary and not eff_data.is_empty():
			var eff_def := EffectDefinition.new()
			eff_def.type = eff_data.get("type", "")
			eff_def.value = eff_data.get("power", 0)
			eff_def.duration = eff_data.get("duration", 0)
			item_def.effect = eff_def
		
		var save_path := "res://resources/definitions/items/%s.tres" % item_id
		var err := ResourceSaver.save(item_def, save_path)
		if err == OK:
			print("Saved item: %s" % save_path)
		else:
			printerr("Failed to save item %s: %d" % [save_path, err])


func _migrate_party() -> void:
	var party_data: Dictionary = _load_json("res://data/party.json")
	var members: Array = party_data.get("party_members", [])
	for idx in range(members.size()):
		var data: Dictionary = members[idx]
		var id: String = data.get("id", "")
		var pm_def := PartyMemberDefinition.new()
		pm_def.id = id
		pm_def.name = data.get("name", id)
		pm_def.max_hp = data.get("max_hp", 50)
		pm_def.attack = data.get("attack", 10)
		pm_def.slot_order = idx
		
		var sprite_path: String = data.get("sprite", "")
		if sprite_path != "" and ResourceLoader.exists(sprite_path):
			pm_def.sprite = load(sprite_path) as Texture2D
		
		var save_path := "res://resources/definitions/party/%s.tres" % id
		var err := ResourceSaver.save(pm_def, save_path)
		if err == OK:
			print("Saved party member: %s" % save_path)
		else:
			printerr("Failed to save party member %s: %d" % [save_path, err])


func _migrate_enemies() -> void:
	var enemies_data: Dictionary = _load_json("res://data/enemies.json")
	for enemy_id in enemies_data:
		var data: Dictionary = enemies_data[enemy_id]
		var enemy_def := EnemyDefinition.new()
		enemy_def.id = enemy_id
		enemy_def.name = data.get("name", enemy_id)
		enemy_def.max_hp = data.get("max_hp", 30)
		enemy_def.attack_type = data.get("attack_type", "melee")
		enemy_def.attack = data.get("attack", 5)
		enemy_def.drop_count = data.get("drop_count", {"min": 1, "max": 1})
		var drop_pool_data = data.get("drop_pool", [])
		var typed_pool: Array[Dictionary] = []
		for dp in drop_pool_data:
			if dp is Dictionary:
				typed_pool.append(dp)
		enemy_def.drop_pool = typed_pool
		
		var sprite_path: String = data.get("sprite", "")
		if sprite_path != "" and ResourceLoader.exists(sprite_path):
			enemy_def.sprite = load(sprite_path) as Texture2D
		
		var heavy_data = data.get("heavy_attack")
		if heavy_data is Dictionary and not heavy_data.is_empty():
			var atk_def := AttackDefinition.new()
			atk_def.name = heavy_data.get("name", "Attack")
			atk_def.interval = heavy_data.get("interval", 4)
			atk_def.windup = heavy_data.get("windup", 2)
			atk_def.damage = heavy_data.get("damage", 10)
			atk_def.type = heavy_data.get("type", "damage")
			enemy_def.heavy_attack = atk_def
		
		var save_path := "res://resources/definitions/enemies/%s.tres" % enemy_id
		var err := ResourceSaver.save(enemy_def, save_path)
		if err == OK:
			print("Saved enemy: %s" % save_path)
		else:
			printerr("Failed to save enemy %s: %d" % [save_path, err])


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
