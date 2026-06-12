extends RefCounted

var merge_queue: Array[Dictionary] = []
var is_processing: bool = false
var board: Control
var _popup_callback: Callable
var _detector: RefCounted
var _merge_board: Control
var _last_group_positions: Array[Vector2i] = []
var _last_group_item_id: String = ""
var _last_group_count: int = 0
var _pending_options: Array[Dictionary] = []
var _result_center: Vector2i = Vector2i(-1, -1)


func setup(board_ref: Control, popup_cb: Callable, detector: RefCounted, merge_board: Control) -> void:
	board = board_ref
	_popup_callback = popup_cb
	_detector = detector
	_merge_board = merge_board


func enqueue(groups: Array[Dictionary]) -> void:
	for group in groups:
		merge_queue.append(group)
	if not is_processing:
		process_next()


func process_next() -> void:
	if merge_queue.is_empty():
		is_processing = false
		_try_chain()
		return
	is_processing = true
	var group: Dictionary = merge_queue.pop_front()
	var item_id: String = group.get("item_id", "")
	var positions: Array = group.get("positions", [])
	_dbg("process_next: item=%s positions=%d" % [item_id, positions.size()])
	var all_options := _build_options(item_id)
	_dbg("process_next: options=%d %s" % [all_options.size(), str(all_options)])
	if all_options.size() == 0:
		_dbg("process_next: SKIP (0 options)")
		is_processing = false
		process_next()
		return
	_last_group_positions.clear()
	for pos in positions:
		_last_group_positions.append(pos)
	_last_group_item_id = item_id
	_last_group_count = positions.size()
	_pending_options = all_options
	_result_center = _resolve_result_position()
	_dbg("process_next: starting merge animation, result_center=%s" % str(_result_center))
	_merge_board.animate_merge(_last_group_positions, _result_center, _on_animation_done)


func _on_animation_done() -> void:
	board.remove_items(_last_group_positions)
	_dbg("_on_animation_done: removed %d items from board" % _last_group_positions.size())
	if _pending_options.size() == 1:
		_dbg("_on_animation_done: auto-pick single option -> %s" % _pending_options[0].get("item_id", "?"))
		_place_results(_pending_options[0])
	else:
		_dbg("_on_animation_done: showing popup with %d options" % _pending_options.size())
		_popup_callback.call(_pending_options, handle_choice)


func handle_choice(item_id: String, is_variant: bool, reagent_id: String) -> void:
	_place_results({"item_id": item_id, "is_variant": is_variant, "reagent_id": reagent_id})


func _try_chain() -> void:
	if _detector == null or board == null:
		return
	var groups: Array[Dictionary] = _detector.scan(board.grid)
	if groups.is_empty():
		_dbg("_try_chain: no new groups found")
		return
	_dbg("_try_chain: found %d new groups" % groups.size())
	enqueue(groups)


func _resolve_result_position() -> Vector2i:
	var center := calculate_center_of_mass(_last_group_positions)
	var is_merge_pos := false
	for pos in _last_group_positions:
		if pos == center:
			is_merge_pos = true
			break
	if is_merge_pos:
		return center
	var saved: Dictionary = {}
	for pos in _last_group_positions:
		saved[pos] = board.grid[pos.y][pos.x]
		board.grid[pos.y][pos.x] = null
	var result_pos: Vector2i
	if center.x >= 0 and center.y >= 0 and center.x < board.grid_cols and center.y < board.grid_rows and board.grid[center.y][center.x] == null:
		result_pos = center
	else:
		result_pos = board.find_nearest_empty(center)
	for pos in saved:
		board.grid[pos.y][pos.x] = saved[pos]
	return result_pos


func _build_options(item_id: String) -> Array[Dictionary]:
	var all_options: Array[Dictionary] = []
	for opt in RecipeResolver.get_options(item_id):
		var result_id: String = opt.get("result_id", "")
		var data: Dictionary = RecipeResolver.get_item_data(result_id)
		all_options.append({
			"item_id": result_id,
			"display_name": data.get("name", result_id),
			"icon": data.get("icon", ""),
			"is_variant": false,
			"reagent_id": "",
			"reagent_cost": 0,
		})
	for combo in RecipeResolver.get_variant_options(item_id):
		var variant_id: String = combo.get("variant_item_id", "")
		var vdata: Dictionary = RecipeResolver.get_item_data(variant_id)
		var reagent_id: String = combo.get("reagent_id", "")
		var rdata: Dictionary = RecipeResolver.get_reagent_data(reagent_id)
		all_options.append({
			"item_id": variant_id,
			"display_name": vdata.get("name", variant_id),
			"icon": vdata.get("icon", ""),
			"is_variant": true,
			"reagent_id": reagent_id,
			"reagent_cost": rdata.get("cost", 0),
		})
	return all_options


func _place_results(option: Dictionary) -> void:
	var result_id: String = option.get("item_id", "")
	_dbg("_place_results: result_id=%s" % result_id)
	if option.get("is_variant", false):
		var rid: String = option.get("reagent_id", "")
		if rid != "":
			GameManager.consume_reagent(rid)
	var result_data: Dictionary = RecipeResolver.get_item_data(result_id)
	var result_count := _last_group_count / 3
	var refund_count := _last_group_count % 3
	var source_data: Dictionary = RecipeResolver.get_item_data(_last_group_item_id)
	var gold_value: int = result_data.get("gold_value", 0)
	var bonus: int = calculate_bonus_gold(_last_group_count, gold_value)
	_dbg("_place_results: result_count=%d refund_count=%d bonus=%d result_data_empty=%s" % [result_count, refund_count, bonus, str(result_data.is_empty())])
	if bonus > 0:
		_merge_board.spawn_bonus_coin(bonus, _result_center)
	_spawn_results(result_data, result_count)
	_refund_source_items(source_data, refund_count)
	EventBus.merge_completed.emit(result_id, bonus)
	process_next()


func _spawn_results(result_data: Dictionary, count: int) -> void:
	_dbg("_spawn_results: count=%d data_empty=%s" % [count, str(result_data.is_empty())])
	if count <= 0:
		return
	var center := _result_center
	var flash_positions: Array[Vector2i] = []
	if center.x >= 0:
		_dbg("_spawn_results: placing at %s" % str(center))
		board.place_item(result_data, center)
		flash_positions.append(center)
	else:
		_dbg("_spawn_results: NO empty cell found for result!")
	for i in range(1, count):
		var pos: Vector2i = board.find_nearest_empty(center)
		_dbg("_spawn_results: extra #%d nearest_empty=%s" % [i, str(pos)])
		if pos.x >= 0:
			board.place_item(result_data, pos)
			flash_positions.append(pos)
	board.flash_cells(flash_positions)


func _refund_source_items(source_data: Dictionary, count: int) -> void:
	if count <= 0 or source_data.is_empty():
		return
	var spawned := 0
	for pos in _last_group_positions:
		if spawned >= count:
			break
		if board.grid[pos.y][pos.x] == null:
			board.place_item(source_data, pos)
			spawned += 1


func calculate_center_of_mass(positions: Array[Vector2i]) -> Vector2i:
	if positions.is_empty():
		return Vector2i.ZERO
	var sum_x := 0
	var sum_y := 0
	for pos in positions:
		sum_x += pos.x
		sum_y += pos.y
	return Vector2i(sum_x / positions.size(), sum_y / positions.size())


func calculate_bonus_gold(count: int, item_value: int) -> int:
	return (count - 3) * int(floor(item_value * 0.5))


func _dbg(msg: String) -> void:
	if GameManager.debug_mode:
		print("[MergeResolver] %s" % msg)
