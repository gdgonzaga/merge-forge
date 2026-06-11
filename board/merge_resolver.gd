extends RefCounted

var merge_queue: Array[Dictionary] = []
var is_processing: bool = false
var board: Control
var _popup_callback: Callable
var _last_group_positions: Array[Vector2i] = []
var _last_group_item_id: String = ""
var _last_group_count: int = 0


func setup(board_ref: Control, popup_cb: Callable) -> void:
	board = board_ref
	_popup_callback = popup_cb


func enqueue(groups: Array[Dictionary]) -> void:
	for group in groups:
		merge_queue.append(group)
	if not is_processing:
		process_next()


func process_next() -> void:
	if merge_queue.is_empty():
		is_processing = false
		return
	is_processing = true
	var group: Dictionary = merge_queue.pop_front()
	var item_id: String = group.get("item_id", "")
	var positions: Array = group.get("positions", [])
	var all_options := _build_options(item_id)
	if all_options.size() == 0:
		is_processing = false
		process_next()
		return
	_last_group_positions.clear()
	for pos in positions:
		_last_group_positions.append(pos)
	_last_group_item_id = item_id
	_last_group_count = positions.size()
	board.remove_items(positions)
	if all_options.size() == 1:
		_place_results(all_options[0])
	else:
		_popup_callback.call(all_options, handle_choice)


func handle_choice(item_id: String, is_variant: bool, reagent_id: String) -> void:
	_place_results({"item_id": item_id, "is_variant": is_variant, "reagent_id": reagent_id})


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
	GameManager.add_gold(bonus)
	_spawn_results(result_data, result_count)
	_refund_source_items(source_data, refund_count)
	EventBus.merge_completed.emit(result_id, bonus)
	process_next()


func _spawn_results(result_data: Dictionary, count: int) -> void:
	if count <= 0:
		return
	var center := calculate_center_of_mass(_last_group_positions)
	board.place_item(result_data, center)
	for i in range(1, count):
		var pos: Vector2i = board.find_nearest_empty(center)
		if pos.x >= 0:
			board.place_item(result_data, pos)


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
