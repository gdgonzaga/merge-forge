extends RefCounted

func scan(grid: Array[Array]) -> Array[Dictionary]:
	var rows := grid.size()
	if rows == 0:
		return []
	var cols: int = grid[0].size()
	var visited: Array[Array] = []
	for r in range(rows):
		var row: Array = []
		row.resize(cols)
		row.fill(false)
		visited.append(row)
	var groups: Array[Dictionary] = []
	for r in range(rows):
		for c in range(cols):
			if visited[r][c]:
				continue
			var cell = grid[r][c]
			if cell == null or not cell is Dictionary:
				continue
			var item_id: String = cell.get("item_id", "")
			if item_id == "":
				continue
			var positions: Array[Vector2i] = []
			_flood_fill(grid, visited, Vector2i(c, r), item_id, positions)
			if positions.size() >= 3:
				groups.append({"item_id": item_id, "positions": positions})
	return groups


func _flood_fill(grid: Array[Array], visited: Array[Array], start: Vector2i, target_id: String, out_positions: Array[Vector2i]) -> void:
	var rows := grid.size()
	var cols: int = grid[0].size()
	var stack: Array[Vector2i] = [start]
	while stack.size() > 0:
		var pos: Vector2i = stack.pop_back()
		if pos.y < 0 or pos.y >= rows or pos.x < 0 or pos.x >= cols:
			continue
		if visited[pos.y][pos.x]:
			continue
		var cell = grid[pos.y][pos.x]
		if cell == null or not cell is Dictionary:
			continue
		if cell.get("item_id", "") != target_id:
			continue
		visited[pos.y][pos.x] = true
		out_positions.append(pos)
		stack.append(Vector2i(pos.x + 1, pos.y))
		stack.append(Vector2i(pos.x - 1, pos.y))
		stack.append(Vector2i(pos.x, pos.y + 1))
		stack.append(Vector2i(pos.x, pos.y - 1))
