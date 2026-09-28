extends Node

# Rules over the definitions in DefinitionLibrary: which merge results and
# reagent variants are available, blueprint gates and weighted rolls. Holds no
# content of its own.


# The dictionary a board cell holds. item_id is load-bearing: board cells,
# merge detection, shop fulfillment and saves all read it. Drag and drop adds
# transient _source_* keys to copies of it.
func make_item(def: ItemDefinition) -> Dictionary:
	return {"item_id": def.id, "definition": def}


func get_options(item_id: String) -> Array[MergeResult]:
	var available: Array[MergeResult] = []
	var item := DefinitionLibrary.get_item(item_id)
	if item == null:
		return available
	for option in item.merge_results:
		if is_unlocked(option.blueprint):
			available.append(option)
	return available


func get_variant_options(item_id: String) -> Array[ReagentVariant]:
	var available: Array[ReagentVariant] = []
	var item := DefinitionLibrary.get_item(item_id)
	if item == null:
		return available
	for variant in item.reagent_variants:
		if is_unlocked(variant.blueprint) and GameManager.reagent_inventory.get(variant.reagent.id, 0) >= 1:
			available.append(variant)
	return available


# A null blueprint gates nothing.
func is_unlocked(blueprint: BlueprintDefinition) -> bool:
	return blueprint == null or has_blueprint(blueprint.id)


func has_blueprint(bp_id: String) -> bool:
	return bp_id in GameManager.unlocked_blueprints


func are_dependencies_met(blueprint: BlueprintDefinition) -> bool:
	for dep in blueprint.dependencies:
		if not has_blueprint(dep.id):
			return false
	return true


# True when the player can make `item` today: a crate sells it, or a merge they
# hold the blueprint for makes it from something craftable. A reagent variant
# counts when the reagent is for sale or in stock.
func is_craftable(item: ItemDefinition) -> bool:
	return _is_craftable(item, {})


# `visited` holds ids already on the path or already disproven, so a cycle in
# content can't recurse forever.
func _is_craftable(item: ItemDefinition, visited: Dictionary) -> bool:
	if item == null or visited.has(item.id):
		return false
	if _sold_in_a_crate(item):
		return true
	visited[item.id] = true
	for source: ItemDefinition in DefinitionLibrary.get_all_items().values():
		if _makes(source, item) and _is_craftable(source, visited):
			return true
	return false


func _sold_in_a_crate(item: ItemDefinition) -> bool:
	for crate in DefinitionLibrary.get_all_crates():
		for entry in crate.pool:
			if entry.item != null and entry.item.id == item.id:
				return true
	return false


# Whether merging `source` can give `target` with what the player owns.
func _makes(source: ItemDefinition, target: ItemDefinition) -> bool:
	for option in source.merge_results:
		if option.result == target and is_unlocked(option.blueprint):
			return true
	for variant in source.reagent_variants:
		if variant.result == target and is_unlocked(variant.blueprint) and _can_get_reagent(variant.reagent):
			return true
	return false


func _can_get_reagent(reagent: ReagentDefinition) -> bool:
	return reagent.cost > 0 or GameManager.reagent_inventory.get(reagent.id, 0) > 0


static func roll_weighted_pool(pool: Array[WeightedItem], min_rolls: int, max_rolls: int) -> Array[ItemDefinition]:
	var results: Array[ItemDefinition] = []
	var total_weight := 0
	for entry in pool:
		total_weight += entry.weight
	if total_weight <= 0:
		return results
	for _i in range(randi_range(min_rolls, max_rolls)):
		var roll := randf() * total_weight
		var accumulated := 0
		for entry in pool:
			accumulated += entry.weight
			if roll < accumulated:
				results.append(entry.item)
				break
	return results
