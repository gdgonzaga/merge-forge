extends Node

var items: Dictionary = {}
var party: Dictionary = {}
var enemies: Dictionary = {}
var attacks: Dictionary = {}
var effects: Dictionary = {}


func _ready() -> void:
	load_all_definitions()


func load_all_definitions() -> void:
	items.clear()
	party.clear()
	enemies.clear()
	attacks.clear()
	effects.clear()

	_load_directory("res://resources/definitions/items", items)
	_load_directory("res://resources/definitions/party", party)
	_load_directory("res://resources/definitions/enemies", enemies)
	_load_directory("res://resources/definitions/attacks", attacks)
	_load_directory("res://resources/definitions/effects", effects)


func _load_directory(path: String, target: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := path.path_join(file_name)
			var res := load(full_path)
			if res:
				var res_id: String = ""
				if "id" in res and res.id != "":
					res_id = res.id
				elif "name" in res and res.name != "":
					res_id = res.name
				else:
					res_id = file_name.get_basename()
				target[res_id] = res
		file_name = dir.get_next()
	dir.list_dir_end()


func get_item(id: String) -> ItemDefinition:
	return items.get(id, null)


func get_all_items() -> Dictionary:
	return items


func get_party_member(id: String) -> PartyMemberDefinition:
	return party.get(id, null)


func get_all_party_members() -> Array[PartyMemberDefinition]:
	var result: Array[PartyMemberDefinition] = []
	for member in party.values():
		if member is PartyMemberDefinition:
			result.append(member)
	result.sort_custom(func(a: PartyMemberDefinition, b: PartyMemberDefinition) -> bool:
		return a.slot_order < b.slot_order
	)
	return result


func get_enemy(id: String) -> EnemyDefinition:
	return enemies.get(id, null)


func get_all_enemies() -> Dictionary:
	return enemies


func get_attack(id: String) -> AttackDefinition:
	return attacks.get(id, null)
