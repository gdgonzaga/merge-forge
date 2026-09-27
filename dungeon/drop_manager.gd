extends Node


func spawn_drops(enemy: EnemyDefinition) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for item in RecipeResolver.roll_weighted_pool(enemy.drop_pool, enemy.min_drops, enemy.max_drops):
		results.append(RecipeResolver.make_item(item))
	return results


func add_drops_to_board(drops: Array[Dictionary], board: Node) -> void:
	for drop_data in drops:
		if board and is_instance_valid(board) and board.has_method("place_drop"):
			board.place_drop(drop_data)
