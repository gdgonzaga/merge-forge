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


func add_drops_to_board(drops: Array[Dictionary], board: Node) -> void:
	for drop_data in drops:
		if board and is_instance_valid(board) and board.has_method("place_drop"):
			board.place_drop(drop_data)
