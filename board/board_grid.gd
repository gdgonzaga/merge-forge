extends GridContainer

signal item_placed(item: Dictionary, pos: Vector2i)
signal item_removed(pos: Vector2i)

var grid: Array[Array] = []
var grid_cols: int = 5
var grid_rows: int = 5
var despawn_time: float = 12.0

var _cell_scene: PackedScene


func setup(config: Dictionary) -> void:
	grid_cols = config.get("cols", 5)
	grid_rows = config.get("rows", 5)
	columns = grid_cols
	_initialize_grid()
	_create_cells()


func _initialize_grid() -> void:
	grid.clear()
	for r in range(grid_rows):
		var row: Array = []
		row.resize(grid_cols)
		row.fill(null)
		grid.append(row)


func _create_cells() -> void:
	for child in get_children():
		child.queue_free()
	
	if _cell_scene == null:
		return
	for r in range(grid_rows):
		for c in range(grid_cols):
			var cell: Control = _cell_scene.instantiate()
			cell.set_meta("is_board_cell", true)
			cell.grid_pos = Vector2i(c, r)
			cell.cell_drag_ended.connect(_on_cell_drop)
			add_child(cell)



func set_cell_scene(scene: PackedScene) -> void:
	_cell_scene = scene


func place_item(item: Dictionary, pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= grid_cols or pos.y < 0 or pos.y >= grid_rows:
		return false
	if grid[pos.y][pos.x] != null:
		return false
	grid[pos.y][pos.x] = item
	_update_cell_visual(pos)
	AudioManager.play_sfx("item_place")
	item_placed.emit(item, pos)
	return true


func remove_items(positions: Array[Vector2i]) -> void:
	for pos in positions:
		if pos.x < 0 or pos.x >= grid_cols or pos.y < 0 or pos.y >= grid_rows:
			continue
		grid[pos.y][pos.x] = null
		_update_cell_visual(pos)
		item_removed.emit(pos)


func swap_items(pos_a: Vector2i, pos_b: Vector2i) -> void:
	var item_a = grid[pos_a.y][pos_a.x]
	var item_b = grid[pos_b.y][pos_b.x]
	grid[pos_a.y][pos_a.x] = item_b
	grid[pos_b.y][pos_b.x] = item_a
	_update_cell_visual(pos_a)
	_update_cell_visual(pos_b)
	item_placed.emit(item_b, pos_a)
	item_placed.emit(item_a, pos_b)


func discard_item(pos: Vector2i) -> void:
	if pos.x < 0 or pos.x >= grid_cols or pos.y < 0 or pos.y >= grid_rows:
		return
	grid[pos.y][pos.x] = null
	_update_cell_visual(pos)
	item_removed.emit(pos)


func find_safe_cell(item_id: String) -> Vector2i:
	for r in range(grid_rows):
		for c in range(grid_cols):
			if grid[r][c] != null:
				continue
			var pos := Vector2i(c, r)
			grid[r][c] = {"item_id": item_id, "_temp": true}
			var group_size := _count_connected(pos, item_id)
			grid[r][c] = null
			if group_size < 3:
				return pos
	return Vector2i(-1, -1)


func _count_connected(start: Vector2i, item_id: String) -> int:
	var visited: Dictionary = {}
	var stack: Array[Vector2i] = [start]
	var count := 0
	while stack.size() > 0:
		var pos: Vector2i = stack.pop_back()
		var key := pos.x + pos.y * 10000
		if visited.has(key):
			continue
		if pos.x < 0 or pos.x >= grid_cols or pos.y < 0 or pos.y >= grid_rows:
			continue
		var cell = grid[pos.y][pos.x]
		if cell == null or cell.get("item_id", "") != item_id:
			continue
		visited[key] = true
		count += 1
		stack.append(Vector2i(pos.x + 1, pos.y))
		stack.append(Vector2i(pos.x - 1, pos.y))
		stack.append(Vector2i(pos.x, pos.y + 1))
		stack.append(Vector2i(pos.x, pos.y - 1))
	return count


func place_or_stage(item: Dictionary) -> bool:
	var item_id: String = item.get("item_id", "")
	var safe_pos := find_safe_cell(item_id)
	if GameManager.debug_mode:
		print("[BoardGrid] place_or_stage: item=%s safe_pos=%s" % [item_id, str(safe_pos)])
	if safe_pos.x >= 0:
		grid[safe_pos.y][safe_pos.x] = item
		_update_cell_visual(safe_pos)
		return true
	return false


func count_items_on_board(item_id: String) -> int:
	var count := 0
	for r in range(grid_rows):
		for c in range(grid_cols):
			var cell = grid[r][c]
			if cell != null and cell is Dictionary and cell.get("item_id", "") == item_id:
				count += 1
	return count


func remove_items_by_id(item_id: String, count: int) -> void:
	var removed := 0
	for r in range(grid_rows):
		if removed >= count:
			break
		for c in range(grid_cols):
			if removed >= count:
				break
			var cell = grid[r][c]
			if cell != null and cell is Dictionary and cell.get("item_id", "") == item_id:
				grid[r][c] = null
				_update_cell_visual(Vector2i(c, r))
				item_removed.emit(Vector2i(c, r))
				removed += 1


func clear_board() -> void:
	for r in range(grid_rows):
		for c in range(grid_cols):
			grid[r][c] = null
			_update_cell_visual(Vector2i(c, r))


func get_board_state() -> Array:
	var state: Array = []
	for r in range(grid_rows):
		for c in range(grid_cols):
			if grid[r][c] != null:
				state.append({"col": c, "row": r, "item": grid[r][c]})
	return state


func load_board_state(state: Array) -> void:
	_initialize_grid()
	for entry in state:
		var c: int = entry.get("col", -1)
		var r: int = entry.get("row", -1)
		var item: Dictionary = entry.get("item", {})
		if c >= 0 and c < grid_cols and r >= 0 and r < grid_rows and not item.is_empty():
			var pos := Vector2i(c, r)
			grid[r][c] = item
			_update_cell_visual(pos)


func get_cell_at(pos: Vector2i) -> Control:
	for child in get_children():
		if child.has_meta("is_board_cell") and child.grid_pos == pos:
			return child
	return null


func find_nearest_empty(from: Vector2i) -> Vector2i:
	if grid[from.y][from.x] == null:
		return from
	var max_dist := maxi(grid_cols, grid_rows)
	for dist in range(1, max_dist + 1):
		for dy in range(-dist, dist + 1):
			for dx in range(-dist, dist + 1):
				if absi(dx) != dist and absi(dy) != dist:
					continue
				var pos := Vector2i(from.x + dx, from.y + dy)
				if pos.x < 0 or pos.x >= grid_cols or pos.y < 0 or pos.y >= grid_rows:
					continue
				if grid[pos.y][pos.x] == null:
					return pos
	return Vector2i(-1, -1)


func _update_cell_visual(pos: Vector2i) -> void:
	var cell := get_cell_at(pos)
	if cell == null:
		return
	var item = grid[pos.y][pos.x]
	if item != null and item is Dictionary:
		cell.call("set_item", item)
	else:
		cell.call("clear_item")


func _on_cell_drop(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var drag_data = get_viewport().gui_get_drag_data()
	if drag_data == null or not (drag_data is Dictionary) or not drag_data.has("item_id"):
		return
	var is_from_board: bool = from_pos.x >= 0 and from_pos.y >= 0
	if is_from_board and from_pos == to_pos:
		return
	if grid[to_pos.y][to_pos.x] == null:
		if is_from_board:
			grid[from_pos.y][from_pos.x] = null
			_update_cell_visual(from_pos)
		place_item(drag_data, to_pos)
	else:
		if is_from_board:
			swap_items(from_pos, to_pos)
