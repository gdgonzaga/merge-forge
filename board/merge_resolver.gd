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
var _pending_quality: Dictionary = {}

const QUALITY_RULES := preload("res://board/quality_rules.gd")


func setup(board_ref: Control, popup_cb: Callable, detector: RefCounted, merge_board: Control) -> void:
	board = board_ref
	_popup_callback = popup_cb
	_detector = detector
	_merge_board = merge_board


# A group with no merge options (blueprint not owned, or a final item) stays
# on the board untouched. Queueing it, or starting processing with nothing
# queued, would loop: process_next rescans the board via _try_chain, finds
# the same group and enqueues it again.
func enqueue(groups: Array[Dictionary]) -> void:
	for group in groups:
		if not _build_options(group.get("item_id", "")).is_empty():
			merge_queue.append(group)
	if not is_processing and not merge_queue.is_empty():
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
	_pending_quality = QUALITY_RULES.resolve(_group_qualities(_last_group_positions), _last_group_count)
	_pending_options = all_options
	for option in _pending_options:
		option["result_quality"] = _pending_quality["result_quality"]
	_result_center = _resolve_result_position()
	_dbg("process_next: starting merge animation, result_center=%s" % str(_result_center))
	_merge_board.animate_merge(_last_group_positions, _result_center, _on_animation_done)


# Read from the board when the group starts resolving, so a chain merge sees
# the quality a previous merge just placed.
func _group_qualities(positions: Array[Vector2i]) -> Array[int]:
	var qualities: Array[int] = []
	for pos in positions:
		var cell = board.grid[pos.y][pos.x]
		if cell != null:
			qualities.append(cell["quality"])
	return qualities


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
	for option in RecipeResolver.get_options(item_id):
		all_options.append({
			"item_id": option.result.id,
			"display_name": option.result.name,
			"is_variant": false,
			"reagent_id": "",
			"reagent_cost": 0,
		})
	for variant in RecipeResolver.get_variant_options(item_id):
		all_options.append({
			"item_id": variant.result.id,
			"display_name": variant.result.name,
			"is_variant": true,
			"reagent_id": variant.reagent.id,
			"reagent_cost": variant.reagent.cost,
		})
	return all_options


func _place_results(option: Dictionary) -> void:
	var result_id: String = option.get("item_id", "")
	_dbg("_place_results: result_id=%s" % result_id)
	if option.get("is_variant", false):
		var rid: String = option.get("reagent_id", "")
		if rid != "":
			GameManager.consume_reagent(rid)
	var result_def := DefinitionLibrary.get_item(result_id)
	var source_def := DefinitionLibrary.get_item(_last_group_item_id)
	var quality: int = _pending_quality["result_quality"]
	_dbg("_place_results: result_count=%d quality=%d" % [_last_group_count / 3, quality])
	_spawn_results(RecipeResolver.make_item(result_def, quality), _last_group_count / 3)
	_refund_source_items(source_def, _pending_quality["refund_qualities"])
	if quality > 0 and _result_center.x >= 0:
		_merge_board.show_quality_sparkle(quality, _result_center)
	EventBus.merge_completed.emit(result_id, quality)
	process_next()


func _spawn_results(result_data: Dictionary, count: int) -> void:
	_dbg("_spawn_results: count=%d" % count)
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


func _refund_source_items(source_def: ItemDefinition, qualities: Array) -> void:
	if qualities.is_empty():
		return
	var spawned := 0
	for pos in _last_group_positions:
		if spawned >= qualities.size():
			break
		if board.grid[pos.y][pos.x] == null:
			board.place_item(RecipeResolver.make_item(source_def, qualities[spawned]), pos)
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


func _dbg(msg: String) -> void:
	if GameManager.debug_mode:
		print("[MergeResolver] %s" % msg)
