extends Control

var _board: Control
var _detector: RefCounted
var _resolver: RefCounted
var _staging_container: HBoxContainer
var _popup_callback: Callable


func _ready() -> void:
	_board = _find_node_by_name("BoardGrid")
	_staging_container = _find_node_by_name("StagingArea")
	_detector = load("res://board/merge_detector.gd").new()
	_resolver = load("res://board/merge_resolver.gd").new()
	_resolver.setup(_board, _on_merge_choice_requested)
	if _board:
		_board.item_placed.connect(_on_item_placed)


func setup(config: Dictionary) -> void:
	_popup_callback = config.get("popup_callback", Callable())
	var despawn: float = config.get("despawn_time", 12.0)
	if _board:
		var cell_scene: PackedScene = config.get("cell_scene", null)
		if cell_scene:
			_board.set_cell_scene(cell_scene)
		_board.despawn_time = despawn
		_board.setup(config)
		_resolver.setup(_board, _on_merge_choice_requested)


func buy_crate(crate_id: String) -> bool:
	var crate_data: Dictionary = RecipeResolver.get_crate_data(crate_id)
	if crate_data.is_empty():
		return false
	var cost: int = int(crate_data.get("cost", 0) * GameManager.get_crate_discount())
	if not GameManager.deduct_gold(cost):
		return false
	var pool: Array = crate_data.get("pool", [])
	var item_count: Dictionary = crate_data.get("item_count", {"min": 1, "max": 1})
	for entry in RecipeResolver.roll_weighted_pool(pool, item_count):
		var data: Dictionary = RecipeResolver.get_item_data(entry.get("item_id", ""))
		if not data.is_empty():
			place_drop(data)
	EventBus.save_requested.emit()
	return true


func place_drop(item_data: Dictionary) -> void:
	if _board and is_instance_valid(_board):
		if not _board.place_or_stage(item_data):
			_spawn_staging_item(item_data)
	else:
		_spawn_staging_item(item_data)


func _spawn_staging_item(item_data: Dictionary) -> void:
	if _staging_container == null:
		return
	var fi: Control = load("res://board/floating_item.tscn").instantiate()
	fi.setup(item_data, _board.despawn_time if _board else 12.0)
	fi.despawn_timeout.connect(fi.queue_free)
	_staging_container.add_child(fi)


func _remove_staging_item(item_data: Dictionary) -> void:
	if _staging_container == null:
		return
	for child in _staging_container.get_children():
		if child.item_data == item_data:
			child.queue_free()
			return


func _on_item_placed(item: Dictionary, _pos: Vector2i) -> void:
	if GameManager.debug_mode:
		print("[MergeBoard] item_placed: item=%s pos=%s is_processing=%s" % [item.get("item_id", "?"), str(_pos), str(_resolver.is_processing if _resolver else "no_resolver")])
	if not (_resolver and _resolver.is_processing):
		_remove_staging_item(item)
	_run_merge_detection()


func _run_merge_detection() -> void:
	if _resolver and _resolver.is_processing:
		return
	if _board == null:
		return
	var groups: Array[Dictionary] = _detector.scan(_board.grid)
	if groups.is_empty():
		return
	_resolver.enqueue(groups)


func _on_merge_choice_requested(options: Array[Dictionary], callback: Callable) -> void:
	if _popup_callback.is_valid():
		_popup_callback.call(options, callback)


func _find_node_by_name(node_name: String) -> Control:
	return _find_recursive(self, node_name)


func _find_recursive(node: Node, node_name: String) -> Control:
	if node.name == node_name:
		return node as Control
	for child in node.get_children():
		var found = _find_recursive(child, node_name)
		if found:
			return found
	return null
