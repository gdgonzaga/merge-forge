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
	var board_grid = board.get_node_or_null("VBox/BoardArea/CenterContainer/BoardGrid")
	var staging = board.get_node_or_null("VBox/StagingArea")
	for drop_data in drops:
		if board_grid and is_instance_valid(board_grid):
			if not board_grid.place_or_stage(drop_data):
				_spawn_to_staging(drop_data, staging)
		elif staging and is_instance_valid(staging):
			_spawn_to_staging(drop_data, staging)


func _spawn_to_staging(data: Dictionary, staging: Node) -> void:
	if staging == null or not is_instance_valid(staging):
		return
	var fi: Control = load("res://board/floating_item.tscn").instantiate()
	fi.setup(data, GameManager.get_despawn_time())
	fi.despawn_timeout.connect(fi.queue_free)
	staging.add_child(fi)
