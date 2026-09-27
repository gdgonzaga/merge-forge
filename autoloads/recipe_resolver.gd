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
