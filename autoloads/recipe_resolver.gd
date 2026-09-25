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
	items = _load_json("res://data/items.json")
	recipes = _load_json("res://data/recipes.json")
	blueprints = _load_json("res://data/blueprints.json")
	reagent_combos = _load_json("res://data/reagent_combos.json")
	crates = _load_json("res://data/crates.json")
	upgrades = _load_json("res://data/upgrades.json")
	reagents = _load_json("res://data/reagents.json")
	enemies = _load_json("res://data/enemies.json")
	dungeons = _load_json("res://data/dungeons.json")
	party = _load_json("res://data/party.json")


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
