extends Node

var items: Dictionary = {}
var recipes: Dictionary = {}
var blueprints: Dictionary = {}
var reagent_combos: Dictionary = {}
var crates: Dictionary = {}
var upgrades: Dictionary = {}
var reagents: Dictionary = {}
var enemies: Dictionary = {}
var dungeons: Dictionary = {}
var party: Dictionary = {}


func _ready() -> void:
	_load_from_definitions()
	recipes = _load_json("res://data/recipes.json")
	blueprints = _load_json("res://data/blueprints.json")
	reagent_combos = _load_json("res://data/reagent_combos.json")
	crates = _load_json("res://data/crates.json")
	upgrades = _load_json("res://data/upgrades.json")
	reagents = _load_json("res://data/reagents.json")
	dungeons = _load_json("res://data/dungeons.json")


# Items, party and enemies come only from the .tres definitions; the other
# catalogs are configuration JSON.
func _load_from_definitions() -> void:
	items.clear()
	for item_id in DefinitionLibrary.items:
		items[item_id] = _item_to_dict(DefinitionLibrary.items[item_id])

	party.clear()
	var party_list: Array = []
	for pdef in DefinitionLibrary.get_all_party_members():
		party_list.append(_party_member_to_dict(pdef))
	party["party_members"] = party_list

	enemies.clear()
	for enemy_id in DefinitionLibrary.enemies:
		enemies[enemy_id] = _enemy_to_dict(DefinitionLibrary.enemies[enemy_id])


func _item_to_dict(def: ItemDefinition) -> Dictionary:
	var eff_dict = null
	if def.effect != null:
		eff_dict = {
			"type": def.effect.type,
			"power": def.effect.value,
			"duration": def.effect.duration,
		}
	return {
		"id": def.id,
		"name": def.name,
		"family": def.family,
		"gold_value": def.gold_value,
		"dungeon_usable": def.dungeon_usable,
		"dungeon_use_target": def.dungeon_use_target,
		"effect": eff_dict,
		"sprite": def.sprite,
	}


func _party_member_to_dict(def: PartyMemberDefinition) -> Dictionary:
	return {
		"id": def.id,
		"name": def.name,
		"sprite": def.sprite,
		"max_hp": def.max_hp,
		"attack": def.attack,
		"slot_order": def.slot_order,
	}


func _enemy_to_dict(def: EnemyDefinition) -> Dictionary:
	var heavy_dict: Dictionary = {}
	if def.heavy_attack != null:
		heavy_dict = {
			"name": def.heavy_attack.name,
			"interval": def.heavy_attack.interval,
			"windup": def.heavy_attack.windup,
			"damage": def.heavy_attack.damage,
			"type": def.heavy_attack.type,
		}
	return {
		"id": def.id,
		"name": def.name,
		"max_hp": def.max_hp,
		"attack_type": def.attack_type,
		"attack": def.attack,
		"heavy_attack": heavy_dict,
		"sprite": def.sprite,
		"drop_count": def.drop_count,
		"drop_pool": def.drop_pool,
	}


func get_options(item_id: String) -> Array[Dictionary]:
	var recipe: Dictionary = recipes.get(item_id, {})
	var results: Array = recipe.get("results", [])
	var available: Array[Dictionary] = []
	for result in results:
		var bp_required: String = result.get("blueprint_required", "")
		if bp_required == "" or has_blueprint(bp_required):
			available.append(result.duplicate(true))
	return available


func get_variant_options(base_item_id: String) -> Array[Dictionary]:
	var combos: Array = reagent_combos.get(base_item_id, [])
	var available: Array[Dictionary] = []
	for combo in combos:
		var bp_required: String = combo.get("blueprint_required", "")
		var reagent_id: String = combo.get("reagent_id", "")
		if bp_required == "" or has_blueprint(bp_required):
			if GameManager.reagent_inventory.get(reagent_id, 0) >= 1:
				available.append(combo.duplicate(true))
	return available


func get_item_data(item_id: String) -> Dictionary:
	# Return a COPY, not the cached entry: the item_id stamp below must not
	# mutate the shared items catalog. The stamped id is load-bearing — board
	# cells, merge detection, and shop fulfillment all read it off items that
	# were placed via this lookup.
	var data: Dictionary = items.get(item_id, {}).duplicate(true)
	if not data.is_empty():
		data["item_id"] = item_id
	return data


func get_blueprint_cost(bp_id: String) -> int:
	return blueprints.get(bp_id, {}).get("cost", 0)


func get_blueprint_dependencies(bp_id: String) -> Array[String]:
	var deps: Array = blueprints.get(bp_id, {}).get("dependencies", [])
	var typed: Array[String] = []
	typed.assign(deps)
	return typed


func has_blueprint(bp_id: String) -> bool:
	return bp_id in GameManager.unlocked_blueprints


# Catalog getters return deep copies so no caller can mutate the shared,
# load-once catalogs (same invariant as get_item_data).
func get_crate_data(crate_id: String) -> Dictionary:
	return crates.get(crate_id, {}).duplicate(true)


func get_all_crate_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(crates.keys())
	return ids


func get_upgrade_data(upgrade_id: String) -> Dictionary:
	return upgrades.get(upgrade_id, {}).duplicate(true)


func get_reagent_data(reagent_id: String) -> Dictionary:
	return reagents.get(reagent_id, {}).duplicate(true)


static func roll_weighted_pool(pool: Array, count: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var rolls := randi_range(count.get("min", 1), count.get("max", 1))
	for _i in range(rolls):
		var total_weight := 0
		for entry in pool:
			total_weight += entry.get("weight", 1)
		var roll := randf() * total_weight
		var accumulated := 0
		for entry in pool:
			accumulated += entry.get("weight", 1)
			if roll < accumulated:
				results.append(entry)
				break
	return results


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
