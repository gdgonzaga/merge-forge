extends Control

var _board: Control
var _detector: RefCounted
var _resolver: RefCounted
var _staging_container: HBoxContainer
var _cell_scene: PackedScene
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
	_cell_scene = config.get("cell_scene", null)
	_popup_callback = config.get("popup_callback", Callable())
	var despawn: float = config.get("despawn_time", 12.0)
	if _board:
		if _cell_scene:
			_board.set_cell_scene(_cell_scene)
		_board.despawn_time = despawn
		_board.setup(config)
		_resolver.setup(_board, _on_merge_choice_requested)


func buy_crate(crate_id: String) -> void:
	var crate_data: Dictionary = RecipeResolver.get_crate_data(crate_id)
	if crate_data.is_empty():
		return
	var cost: int = crate_data.get("cost", 0)
	if not GameManager.deduct_gold(cost):
		return
	for item_data in _roll_crate_loot(crate_data):
		_spawn_staging_item(item_data)


func _roll_crate_loot(crate_data: Dictionary) -> Array[Dictionary]:
	var pool: Array = crate_data.get("pool", [])
	var item_count: Dictionary = crate_data.get("item_count", {"min": 1, "max": 1})
	var count := randi_range(item_count.get("min", 1), item_count.get("max", 1))
	var results: Array[Dictionary] = []
	for _i in range(count):
		var total_weight := 0
		for entry in pool:
			total_weight += entry.get("weight", 1)
		var roll := randf() * total_weight
		var accumulated := 0
		for entry in pool:
			accumulated += entry.get("weight", 1)
			if roll < accumulated:
				var id: String = entry.get("item_id", "")
				var data: Dictionary = RecipeResolver.get_item_data(id)
				if not data.is_empty():
					results.append(data)
				break
	return results


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
