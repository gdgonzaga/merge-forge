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
	_last_group_positions.clear()
	for pos in positions:
		_last_group_positions.append(pos)
	_last_group_item_id = item_id
	_last_group_count = positions.size()
	board.remove_items(positions)
	var options: Array[Dictionary] = RecipeResolver.get_options(item_id)
	var variant_options: Array[Dictionary] = RecipeResolver.get_variant_options(item_id)
	var all_options: Array[Dictionary] = []
	for opt in options:
		var result_id: String = opt.get("result_id", "")
		var item_data: Dictionary = RecipeResolver.get_item_data(result_id)
		all_options.append({
			"item_id": result_id,
			"display_name": item_data.get("name", result_id),
			"icon": item_data.get("icon", ""),
			"is_variant": false,
			"reagent_id": "",
			"reagent_cost": 0,
		})
	for combo in variant_options:
		var variant_id: String = combo.get("variant_item_id", "")
		var variant_data: Dictionary = RecipeResolver.get_item_data(variant_id)
		var reagent_id: String = combo.get("reagent_id", "")
		var reagent_data: Dictionary = RecipeResolver.get_reagent_data(reagent_id)
		all_options.append({
			"item_id": variant_id,
			"display_name": variant_data.get("name", variant_id),
			"icon": variant_data.get("icon", ""),
			"is_variant": true,
			"reagent_id": reagent_id,
			"reagent_cost": reagent_data.get("cost", 0),
		})
	if all_options.size() == 1:
		_place_result(all_options[0], item_id, positions.size())
	elif all_options.size() >= 2:
		_popup_callback.call(all_options, handle_choice)
	else:
		is_processing = false
		process_next()


func handle_choice(item_id: String, is_variant: bool, reagent_id: String) -> void:
	var source_data: Dictionary = RecipeResolver.get_item_data(_last_group_item_id)
	var fake_opt := {"item_id": item_id, "is_variant": is_variant, "reagent_id": reagent_id}
	_place_result(fake_opt, _last_group_item_id, _last_group_count)


func _place_result(option: Dictionary, source_item_id: String, count: int) -> void:
	var result_id: String = option.get("item_id", "")
	var is_variant: bool = option.get("is_variant", false)
	var reagent_id: String = option.get("reagent_id", "")
	if is_variant and reagent_id != "":
		GameManager.consume_reagent(reagent_id)
	var result_data: Dictionary = RecipeResolver.get_item_data(result_id)
	var gold_value: int = result_data.get("gold_value", 0)
	var bonus: int = calculate_bonus_gold(_last_group_count, gold_value)
	GameManager.add_gold(bonus)
	var center := calculate_center_of_mass(_last_group_positions)
	board.place_item({"item_id": result_id, "name": result_data.get("name", ""), "family": result_data.get("family", ""), "gold_value": gold_value, "icon": result_data.get("icon", ""), "dungeon_usable": result_data.get("dungeon_usable", false), "effect": result_data.get("effect")}, center)
	EventBus.merge_completed.emit(result_id, bonus)
	process_next()




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
