extends Control

const MERGE_BURST_DISTANCE: float = 30.0
const MERGE_BURST_TIME: float = 0.20
const MERGE_CONVERGE_TIME: float = 0.25
const MOVE_ANIM_TIME: float = 0.15
const MOVE_ARC_HEIGHT: float = -40.0

var _board: Control
var _detector: RefCounted
var _resolver: RefCounted
var _staging_container: HBoxContainer
var _popup: PopupPanel
var _choice_callback: Callable
var _anim_overlay: Control


func _ready() -> void:
	_board = find_child("BoardGrid", true, false) as Control
	_staging_container = find_child("StagingArea", true, false) as HBoxContainer
	_anim_overlay = find_child("AnimOverlay", true, false) as Control
	_detector = load("res://board/merge_detector.gd").new()
	_resolver = load("res://board/merge_resolver.gd").new()
	if _board:
		_board.item_placed.connect(_on_item_placed)
	var popup_scene: PackedScene = load("res://board/merge_choice_popup.tscn")
	_popup = popup_scene.instantiate()
	add_child(_popup)
	_popup.choice_made.connect(_on_choice_from_popup)


func setup(config: Dictionary) -> void:
	var cell_scene: PackedScene = config.get("cell_scene", load("res://board/board_cell.tscn"))
	var despawn: float = config.get("despawn_time", GameManager.get_despawn_time())
	if _board:
		if cell_scene:
			_board.set_cell_scene(cell_scene)
		_board.despawn_time = despawn
		_board.setup({
			"cols": config.get("cols", GameManager.grid_cols),
			"rows": config.get("rows", GameManager.grid_rows),
		})
		_resolver.setup(_board, _on_merge_choice_requested, _detector, self)
		_board.set_move_callback(_on_board_move)


func buy_crate(crate_id: String) -> bool:
	var crate_data: Dictionary = RecipeResolver.get_crate_data(crate_id)
	if crate_data.is_empty():
		return false
	var cost: int = int(crate_data.get("cost", 0) * GameManager.get_crate_discount())
	if not GameManager.deduct_gold(cost):
		return false
	AudioManager.play_sfx("crate_open")
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


func animate_merge(positions: Array[Vector2i], center: Vector2i, callback: Callable) -> void:
	if _anim_overlay == null or _board == null:
		callback.call()
		return
	var overlay_global := _anim_overlay.global_position
	var center_screen := _get_cell_screen_center(center) - overlay_global
	var icons: Array = []
	for pos in positions:
		var cell: Control = _board.get_cell_at(pos)
		if cell == null:
			continue
		var tex: Texture2D = cell.get_icon_texture()
		if tex == null:
			continue
		var fi := TextureRect.new()
		fi.texture = tex
		fi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_size := Vector2(64, 64)
		fi.custom_minimum_size = icon_size
		fi.size = icon_size
		fi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cell_center := _get_cell_screen_center(pos) - overlay_global
		fi.position = cell_center - icon_size / 2.0
		_anim_overlay.add_child(fi)
		icons.append({"node": fi, "start": fi.position})
		cell.clear_item()
	if icons.is_empty():
		callback.call()
		return
	var tween := _anim_overlay.create_tween()
	for i in range(icons.size()):
		var fi: TextureRect = icons[i].node
		var fi_center := fi.position + fi.size / 2.0
		var dir := (fi_center - center_screen).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		var burst_target := fi.position + dir * MERGE_BURST_DISTANCE
		if i == 0:
			tween.tween_property(fi, "position", burst_target, MERGE_BURST_TIME)
		else:
			tween.parallel().tween_property(fi, "position", burst_target, MERGE_BURST_TIME)
	for i in range(icons.size()):
		var fi: TextureRect = icons[i].node
		var converge_target := center_screen - fi.size / 2.0
		if i == 0:
			tween.tween_property(fi, "position", converge_target, MERGE_CONVERGE_TIME)
		else:
			tween.parallel().tween_property(fi, "position", converge_target, MERGE_CONVERGE_TIME)
	tween.tween_callback(func():
		for entry in icons:
			if is_instance_valid(entry.node):
				entry.node.queue_free()
		callback.call()
	)


func animate_move(moves: Array[Dictionary], callback: Callable) -> void:
	if _anim_overlay == null or _board == null or moves.is_empty():
		if not moves.is_empty():
			_board.finalize_move(moves)
		return
	var overlay_global := _anim_overlay.global_position
	var icons: Array = []
	for m in moves:
		var item_data: Dictionary = m["item_data"]
		var from_pos: Vector2i = m.get("from_pos", Vector2i(-1, -1))
		var to_pos: Vector2i = m["to_pos"]
		var from_screen: Vector2
		if from_pos.x >= 0:
			var from_cell: Control = _board.get_cell_at(from_pos)
			if from_cell:
				var tex: Texture2D = from_cell.get_icon_texture()
				if tex == null:
					continue
				from_screen = _get_cell_screen_center(from_pos)
				from_cell.clear_item()
				var fi := _make_float_icon(tex, from_screen - overlay_global)
				_anim_overlay.add_child(fi)
				icons.append({"node": fi, "target_screen": _get_cell_screen_center(to_pos) - overlay_global})
			else:
				continue
		else:
			from_screen = m.get("from_screen", Vector2.ZERO)
			var icon_path: String = item_data.get("icon", "")
			if icon_path == "":
				continue
			var tex: Texture2D = load(icon_path)
			if tex == null:
				continue
			var fi := _make_float_icon(tex, from_screen - overlay_global)
			_anim_overlay.add_child(fi)
			icons.append({"node": fi, "target_screen": _get_cell_screen_center(to_pos) - overlay_global})
	if icons.is_empty():
		_board.finalize_move(moves)
		return
	var tween := _anim_overlay.create_tween()
	for i in range(icons.size()):
		var fi: TextureRect = icons[i].node
		var start_pos := fi.position
		var end_pos: Vector2 = icons[i].target_screen - fi.size / 2.0
		var idx := i
		if i == 0:
			tween.tween_method(func(val: float):
				_apply_arc_pos(icons[idx].node, start_pos, end_pos, val)
			, 0.0, 1.0, MOVE_ANIM_TIME)
		else:
			tween.parallel().tween_method(func(val: float):
				_apply_arc_pos(icons[idx].node, start_pos, end_pos, val)
			, 0.0, 1.0, MOVE_ANIM_TIME)
	tween.tween_callback(func():
		for entry in icons:
			if is_instance_valid(entry.node):
				entry.node.queue_free()
		_board.finalize_move(moves)
	)


func _make_float_icon(tex: Texture2D, center: Vector2) -> TextureRect:
	var fi := TextureRect.new()
	fi.texture = tex
	fi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_size := Vector2(64, 64)
	fi.custom_minimum_size = icon_size
	fi.size = icon_size
	fi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fi.position = center - icon_size / 2.0
	return fi


func _apply_arc_pos(node: TextureRect, start: Vector2, end: Vector2, t: float) -> void:
	if not is_instance_valid(node):
		return
	var pos := start.lerp(end, t)
	pos.y += MOVE_ARC_HEIGHT * 4.0 * t * (1.0 - t)
	node.position = pos


func _get_cell_screen_center(pos: Vector2i) -> Vector2:
	var cell: Control = _board.get_cell_at(pos)
	if cell:
		return cell.global_position + cell.size / 2.0
	return Vector2.ZERO


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


func _on_board_move(moves: Array[Dictionary]) -> void:
	animate_move(moves, func(): pass)


func _run_merge_detection() -> void:
	if _resolver and _resolver.is_processing:
		return
	if _board == null:
		return
	var groups: Array[Dictionary] = _detector.scan(_board.grid)
	if groups.is_empty():
		return
	_resolver.enqueue(groups)


func get_board_grid() -> Control:
	return _board


func get_staging_area() -> HBoxContainer:
	return _staging_container


func _on_merge_choice_requested(options: Array[Dictionary], callback: Callable) -> void:
	_choice_callback = callback
	_popup.call("show_options", options)
	_popup.popup_centered()


func _on_choice_from_popup(item_id: String, is_variant: bool, reagent_id: String) -> void:
	if _choice_callback.is_valid():
		_choice_callback.call(item_id, is_variant, reagent_id)
