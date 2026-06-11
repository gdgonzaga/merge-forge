extends Node


func spawn_drops(enemy_data: Dictionary) -> Array[Dictionary]:
	var pool: Array = enemy_data.get("drop_pool", [])
	var drop_count: Dictionary = enemy_data.get("drop_count", {"min": 1, "max": 1})
	var results: Array[Dictionary] = []
	for entry in RecipeResolver.roll_weighted_pool(pool, drop_count):
		var id: String = entry.get("item_id", "")
		var data: Dictionary = RecipeResolver.get_item_data(id)
		if not data.is_empty():
			results.append(data)
	return results


func add_drops_to_staging(drops: Array[Dictionary], board: Node) -> void:
	var staging = board.get_node_or_null("VBox/StagingArea")
	if staging == null:
		return
	for drop_data in drops:
		var fi: Control = load("res://board/floating_item.tscn").instantiate()
		fi.setup(drop_data, 18.0)
		fi.despawn_timeout.connect(fi.queue_free)
		staging.add_child(fi)
