extends Control

const MERGE_BURST_DISTANCE: float = 30.0
const MERGE_BURST_TIME: float = 0.20
const MERGE_CONVERGE_TIME: float = 0.25
const MOVE_ANIM_TIME: float = 0.15
const MOVE_ARC_HEIGHT: float = -40.0

var _board: Control
var _detector: RefCounted
var _resolver: RefCounted
var _staging_container: FlowContainer
var _popup: PopupPanel
var _choice_callback: Callable
var _anim_overlay: Control


func _ready() -> void:
	_board = find_child("BoardGrid", true, false) as Control
	_staging_container = find_child("StagingArea", true, false) as FlowContainer
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
	var center_local := _get_cell_screen_center(center) - overlay_global
	var icons: Array = []
	for pos in positions:
		var tex: Texture2D = _get_cell_texture(pos)
		if tex == null:
			continue
		var from_local := _get_cell_screen_center(pos) - overlay_global
		var fi := _spawn_icon(tex, from_local)
		icons.append({"node": fi, "start": fi.position, "end": center_local - fi.size / 2.0})
		_board.get_cell_at(pos).clear_item()
	if icons.is_empty():
		callback.call()
		return
	var tween := _anim_overlay.create_tween()
	tween.set_parallel(true)
	for entry in icons:
		var fi: TextureRect = entry.node
		var fi_center := fi.position + fi.size / 2.0
		var dir := (fi_center - center_local).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		tween.tween_property(fi, "position", fi.position + dir * MERGE_BURST_DISTANCE, MERGE_BURST_TIME)
	tween.set_parallel(false)
	tween.tween_property(icons[0].node, "position", icons[0].end, MERGE_CONVERGE_TIME)
	tween.set_parallel(true)
	for i in range(1, icons.size()):
		tween.tween_property(icons[i].node, "position", icons[i].end, MERGE_CONVERGE_TIME)
	tween.set_parallel(false)
	tween.tween_callback(_make_cleanup(icons, callback))


func animate_move(moves: Array[Dictionary], _callback: Callable) -> void:
	if _anim_overlay == null or _board == null or moves.is_empty():
		if not moves.is_empty():
			_board.finalize_move(moves)
		return
	var overlay_global := _anim_overlay.global_position
	var icons: Array = []
	for m in moves:
		var from_pos: Vector2i = m.get("from_pos", Vector2i(-1, -1))
		var to_pos: Vector2i = m["to_pos"]
		var to_local := _get_cell_screen_center(to_pos) - overlay_global
		var fi: TextureRect
		if from_pos.x >= 0:
			var tex: Texture2D = _get_cell_texture(from_pos)
			if tex == null:
				continue
			fi = _spawn_icon(tex, _get_cell_screen_center(from_pos) - overlay_global)
			_board.get_cell_at(from_pos).clear_item()
		else:
			var from_screen: Vector2 = m.get("from_screen", Vector2.ZERO)
			var icon_path: String = m["item_data"].get("icon", "")
			if icon_path == "":
				continue
			var tex: Texture2D = load(icon_path)
			if tex == null:
				continue
			fi = _spawn_icon(tex, from_screen - overlay_global)
		icons.append({"node": fi, "start": fi.position, "end": to_local - fi.size / 2.0})
	if icons.is_empty():
		_board.finalize_move(moves)
		return
	var tween := _anim_overlay.create_tween()
	tween.set_parallel(true)
	for entry in icons:
		var s: Vector2 = entry.start
		var e: Vector2 = entry.end
		var n: TextureRect = entry.node
		tween.tween_method(func(t: float): _apply_arc_pos(n, s, e, t), 0.0, 1.0, MOVE_ANIM_TIME)
	tween.set_parallel(false)
	tween.tween_callback(func():
		for entry in icons:
			if is_instance_valid(entry.node):
				entry.node.queue_free()
		_board.finalize_move(moves)
	)


func _spawn_icon(tex: Texture2D, center: Vector2) -> TextureRect:
	var fi := TextureRect.new()
	fi.texture = tex
	fi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fi.custom_minimum_size = Vector2(64, 64)
	fi.size = Vector2(64, 64)
	fi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fi.position = center - fi.size / 2.0
	_anim_overlay.add_child(fi)
	return fi


func spawn_bonus_coin(amount: int, grid_pos: Vector2i) -> void:
	if _anim_overlay == null or _board == null or amount <= 0:
		return
	var overlay_global := _anim_overlay.global_position
	var screen_pos := _get_cell_screen_center(grid_pos) - overlay_global
	var coin: Control = load("res://board/bonus_coin.tscn").instantiate()
	coin.setup(amount, screen_pos)
	_anim_overlay.add_child(coin)


func show_gold_text(amount: int, grid_pos: Vector2i) -> void:
	if _anim_overlay == null or _board == null or amount <= 0:
		return
	var overlay_global := _anim_overlay.global_position
	var cell_center := _get_cell_screen_center(grid_pos) - overlay_global
	var label := Label.new()
	label.text = "+%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 0.99, 0, 1))
	label.add_theme_font_override("font", load("res://resources/fonts/RobotoCondensed-VariableFont_wght.ttf"))
	label.add_theme_font_size_override("font_size", 32)
	label.position = cell_center - Vector2(40, 16)
	label.size = Vector2(80, 32)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anim_overlay.add_child(label)
	var start_pos := label.position
	var tween := _anim_overlay.create_tween()
	tween.tween_method(func(t: float):
		label.position = start_pos + Vector2(0, -60.0 * t)
	, 0.0, 1.0, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tween.tween_callback(label.queue_free)


func _get_cell_texture(pos: Vector2i) -> Texture2D:
	var cell: Control = _board.get_cell_at(pos)
	if cell:
		return cell.get_icon_texture()
	return null


func _make_cleanup(icons: Array, callback: Callable) -> Callable:
	return func():
		for entry in icons:
			if is_instance_valid(entry.node):
				entry.node.queue_free()
		callback.call()


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


func get_staging_area() -> FlowContainer:
	return _staging_container


func _on_merge_choice_requested(options: Array[Dictionary], callback: Callable) -> void:
	_choice_callback = callback
	_popup.call("show_options", options)
	_popup.popup_centered()


func _on_choice_from_popup(item_id: String, is_variant: bool, reagent_id: String) -> void:
	if _choice_callback.is_valid():
		_choice_callback.call(item_id, is_variant, reagent_id)
