extends Node

var items: Dictionary = {}
var party: Dictionary = {}
var enemies: Dictionary = {}
var effects: Dictionary = {}


func _ready() -> void:
	load_all_definitions()


func load_all_definitions() -> void:
	items.clear()
	party.clear()
	enemies.clear()
	effects.clear()

	_load_directory("res://resources/definitions/items", items)
	_load_directory("res://resources/definitions/party", party)
	_load_directory("res://resources/definitions/enemies", enemies)
	_load_directory("res://resources/definitions/effects", effects)
	_check_required_loaded()


# An empty catalog means the definitions weren't packaged (export filter) or
# couldn't be listed. There's no fallback content, so say so loudly.
func _check_required_loaded() -> void:
	var required := {"items": items, "party": party, "enemies": enemies}
	for category: String in required:
		if (required[category] as Dictionary).is_empty():
			push_error("DefinitionLibrary: no %s definitions loaded" % category)
			assert(false, "DefinitionLibrary: no %s definitions loaded" % category)


func _load_directory(path: String, target: Dictionary) -> void:
	# Not DirAccess: in exports, text resources are remapped to binary and a raw
	# listing shows "x.tres.remap". ResourceLoader lists the original names.
	for file_name in ResourceLoader.list_directory(path):
		if not file_name.ends_with(".tres"):
			continue
		var full_path := path.path_join(file_name)
		var res: Resource = load(full_path)
		if res == null or not "id" in res or res.id == "":
			push_error("DefinitionLibrary: %s has no id" % full_path)
			assert(false, "DefinitionLibrary: %s has no id" % full_path)
			continue
		target[res.id] = res


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
