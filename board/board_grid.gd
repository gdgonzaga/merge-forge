extends GridContainer

signal item_placed(item: Dictionary, pos: Vector2i)
signal item_removed(pos: Vector2i)
# Fires only for a move whose source was the staging area (from_grid == null),
# never for a board/shelf move or swap. The only reliable way to tell a
# staging placement apart: item dicts have no identity, so two different
# items with the same item_id are dict-equal.
signal staging_item_placed(item: Dictionary, pos: Vector2i)

var grid: Array[Array] = []
var grid_cols: int = 5
var grid_rows: int = 5
var despawn_time: float = 12.0
var merges_enabled: bool = true
@export var cell_bg_texture: Texture2D

var _cell_scene: PackedScene
var _move_callback: Callable
var _drop_guard: Callable


func set_move_callback(cb: Callable) -> void:
	_move_callback = cb


# With no guard set, drops are always allowed (the dungeon board and
# bare-grid tests never call this).
func set_drop_guard(guard: Callable) -> void:
	_drop_guard = guard


func setup(config: Dictionary) -> void:
	grid_cols = config.get("cols", 5)
	grid_rows = config.get("rows", 5)
	merges_enabled = config.get("merges_enabled", true)
	# A GridContainer needs at least one column, and the shelf may have 0 slots.
	columns = maxi(grid_cols, 1)
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
			if cell_bg_texture != null and cell.has_method("set_bg_texture"):
				cell.set_bg_texture(cell_bg_texture)
			cell.grid_pos = Vector2i(c, r)
			cell.grid_owner = self
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
	refresh_cell(pos)
	AudioManager.play_sfx("item_place")
	item_placed.emit(item, pos)
	return true


func remove_items(positions: Array[Vector2i]) -> void:
	for pos in positions:
		if pos.x < 0 or pos.x >= grid_cols or pos.y < 0 or pos.y >= grid_rows:
			continue
		grid[pos.y][pos.x] = null
		refresh_cell(pos)
		item_removed.emit(pos)


func swap_items(pos_a: Vector2i, pos_b: Vector2i) -> void:
	var item_a = grid[pos_a.y][pos_a.x]
	var item_b = grid[pos_b.y][pos_b.x]
	grid[pos_a.y][pos_a.x] = item_b
	grid[pos_b.y][pos_b.x] = item_a
	refresh_cell(pos_a)
	refresh_cell(pos_b)
	item_placed.emit(item_b, pos_a)
	item_placed.emit(item_a, pos_b)


func discard_item(pos: Vector2i) -> void:
	if pos.x < 0 or pos.x >= grid_cols or pos.y < 0 or pos.y >= grid_rows:
		return
	grid[pos.y][pos.x] = null
	refresh_cell(pos)
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
		refresh_cell(safe_pos)
		return true
	return false


func count_items_on_board(item_id: String, min_quality: int = 0) -> int:
	var count := 0
	for r in range(grid_rows):
		for c in range(grid_cols):
			var cell = grid[r][c]
			if cell != null and cell is Dictionary and cell.get("item_id", "") == item_id and cell["quality"] >= min_quality:
				count += 1
	return count


# Lowest quality first, so a Masterwork is never spent where a Normal would do.
func remove_items_by_id(item_id: String, count: int, min_quality: int = 0) -> void:
	var removed := 0
	for quality in range(min_quality, ItemDefinition.MAX_QUALITY + 1):
		for r in range(grid_rows):
			for c in range(grid_cols):
				if removed >= count:
					return
				var cell = grid[r][c]
				if cell != null and cell is Dictionary and cell.get("item_id", "") == item_id and cell["quality"] == quality:
					grid[r][c] = null
					refresh_cell(Vector2i(c, r))
					item_removed.emit(Vector2i(c, r))
					removed += 1


func clear_board() -> void:
	for r in range(grid_rows):
		for c in range(grid_cols):
			grid[r][c] = null
			refresh_cell(Vector2i(c, r))


# Saves hold ids and quality only. The definition (including its sprite texture,
# which JSON can't carry) is looked up again on load.
func get_board_state() -> Array:
	var state: Array = []
	for r in range(grid_rows):
		for c in range(grid_cols):
			if grid[r][c] != null:
				state.append({"col": c, "row": r, "item_id": grid[r][c]["item_id"], "quality": grid[r][c]["quality"]})
	return state


# Returns the items that fall outside this grid (a smaller shelf), so the
# caller can put them somewhere instead of losing them.
func load_board_state(state: Array) -> Array[Dictionary]:
	_initialize_grid()
	var overflow: Array[Dictionary] = []
	for entry in state:
		var def := DefinitionLibrary.get_item(entry["item_id"])
		if def == null:
			push_error("BoardGrid: saved item '%s' is not in the catalog" % entry["item_id"])
			continue
		var c := int(entry["col"])
		var r := int(entry["row"])
		var item := RecipeResolver.make_item(def, int(entry["quality"]))
		if c < 0 or c >= grid_cols or r < 0 or r >= grid_rows:
			overflow.append(item)
			continue
		grid[r][c] = item
		refresh_cell(Vector2i(c, r))
	return overflow


func flash_cells(positions: Array[Vector2i]) -> void:
	for pos in positions:
		var cell := get_cell_at(pos)
		if cell and cell.has_method("flash"):
			cell.flash()


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


func refresh_cell(pos: Vector2i) -> void:
	var cell := get_cell_at(pos)
	if cell == null:
		return
	var item = grid[pos.y][pos.x]
	if item != null and item is Dictionary:
		cell.call("set_item", item)
	else:
		cell.call("clear_item")


# The source grid may be this grid, the other grid (board <-> shelf), or none
# (an item dragged from the staging area). Dropping onto an occupied cell
# swaps, except from staging, which only fills empty cells.
func _on_cell_drop(to_pos: Vector2i, drag_data: Dictionary) -> void:
	# A merge in progress still owns the grid model between the burst
	# animation and remove_items(), so a drop mid-merge could lose or
	# duplicate an item. Refuse every drop until the merge settles.
	if _drop_guard.is_valid() and not _drop_guard.call():
		return
	var source: Control = drag_data.get("_source_grid")
	var from_pos: Vector2i = drag_data.get("_source_pos", Vector2i(-1, -1))
	if source == self and from_pos == to_pos:
		return
	var target_item = grid[to_pos.y][to_pos.x]
	var moves: Array[Dictionary] = []
	if source == null:
		if target_item != null:
			return
		grid[to_pos.y][to_pos.x] = drag_data
		moves.append({
			"item_data": drag_data,
			"from_grid": null,
			"from_pos": Vector2i(-1, -1),
			"from_screen": _get_drag_source_screen(drag_data),
			"to_grid": self,
			"to_pos": to_pos,
		})
	else:
		var moved_item = source.grid[from_pos.y][from_pos.x]
		if moved_item == null:
			return
		source.grid[from_pos.y][from_pos.x] = target_item
		grid[to_pos.y][to_pos.x] = moved_item
		moves.append({
			"item_data": moved_item,
			"from_grid": source,
			"from_pos": from_pos,
			"to_grid": self,
			"to_pos": to_pos,
		})
		if target_item != null:
			moves.append({
				"item_data": target_item,
				"from_grid": self,
				"from_pos": to_pos,
				"to_grid": source,
				"to_pos": from_pos,
			})
	if _move_callback.is_valid():
		_move_callback.call(moves)
	else:
		finalize_move(moves)


# Moves may cross grids, so each one names the grids it leaves and lands on.
func finalize_move(moves: Array[Dictionary]) -> void:
	for m in moves:
		var from_grid: Control = m.get("from_grid")
		if from_grid != null:
			from_grid.refresh_cell(m["from_pos"])
		m["to_grid"].refresh_cell(m["to_pos"])
	for m in moves:
		AudioManager.play_sfx("item_place")
		var to_grid: Control = m["to_grid"]
		to_grid.item_placed.emit(m["item_data"], m["to_pos"])
		if m.get("from_grid") == null:
			to_grid.staging_item_placed.emit(m["item_data"], m["to_pos"])


func _get_drag_source_screen(drag_data: Dictionary) -> Vector2:
	if drag_data.has("_source_screen"):
		return drag_data["_source_screen"]
	return Vector2.ZERO
