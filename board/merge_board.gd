extends Control

signal quality_lost(best_quality: int, grid_pos: Vector2i)

const MERGE_BURST_DISTANCE: float = 30.0
const MERGE_BURST_TIME: float = 0.20
const MERGE_CONVERGE_TIME: float = 0.25
const MOVE_ANIM_TIME: float = 0.15
const MOVE_ARC_HEIGHT: float = -40.0
const QUALITY_STARS := preload("res://ui/quality_stars.tscn")

@onready var _shelf: GridContainer = %ShelfGrid
@onready var _shelf_area: Control = %ShelfArea
@onready var _shelf_gap: Control = %ShelfGap

var _board: Control
var _detector: RefCounted
var _resolver: RefCounted
var _staging_container: FlowContainer
var _popup: PopupPanel
var _choice_callback: Callable
var _anim_overlay: Control
var _crate_cost_multipliers: Dictionary = {}


func _ready() -> void:
	_board = find_child("BoardGrid", true, false) as Control
	_staging_container = find_child("StagingArea", true, false) as FlowContainer
	_anim_overlay = find_child("AnimOverlay", true, false) as Control
	_detector = load("res://board/merge_detector.gd").new()
	_resolver = load("res://board/merge_resolver.gd").new()
	if _board:
		_board.item_placed.connect(_on_item_placed)
		_board.staging_item_placed.connect(_on_staging_item_placed)
	# A staging item dropped on the shelf must leave staging, and detection
	# only scans the board, so this is safe.
	_shelf.item_placed.connect(_on_item_placed)
	_shelf.staging_item_placed.connect(_on_staging_item_placed)
	var popup_scene: PackedScene = load("res://board/merge_choice_popup.tscn")
	_popup = popup_scene.instantiate()
	add_child(_popup)
	_popup.choice_made.connect(_on_choice_from_popup)


func setup(config: Dictionary) -> void:
	var cell_scene: PackedScene = config.get("cell_scene", load("res://board/board_cell.tscn"))
	var despawn: float = config.get("despawn_time", GameManager.get_despawn_time())
	_crate_cost_multipliers = config.get("crate_cost_multipliers", {})
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
		_board.set_drop_guard(_drops_allowed)
	# Only the shop passes shelf_slots; the dungeon's board has no shelf.
	var shelf_slots: int = config.get("shelf_slots", 0)
	_shelf.set_cell_scene(cell_scene)
	_shelf.setup({"cols": shelf_slots, "rows": 1, "merges_enabled": false})
	_shelf.set_move_callback(_on_board_move)
	_shelf.set_drop_guard(_drops_allowed)
	_shelf_area.visible = shelf_slots > 0
	_shelf_gap.visible = shelf_slots > 0


func buy_crate(crate_id: String) -> bool:
	var crate := DefinitionLibrary.get_crate(crate_id)
	if crate == null or not crate in GameManager.get_current_town().crates:
		return false
	if not GameManager.meets_level(crate.min_shop_level):
		return false
	var cost := get_crate_cost(crate)
	if not GameManager.deduct_gold(cost):
		return false
	AudioManager.play_sfx("crate_open")
	for item in RecipeResolver.roll_weighted_pool(crate.pool, crate.min_items, crate.max_items):
		place_drop(RecipeResolver.make_item(item))
	return true


# Market modifier x crate discount, rounded down once. The epsilon keeps float
# error from losing a gold (30 x 0.7 is 20.999... in floats), and a crate is
# never free.
func get_crate_cost(crate: CrateDefinition) -> int:
	var multiplier: float = _crate_cost_multipliers.get(crate.id, 1.0)
	return maxi(floori(crate.cost * multiplier * GameManager.get_crate_discount() + 0.0001), 1)


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
	var center_local := _get_cell_screen_center(_board, center) - overlay_global
	var icons: Array = []
	for pos in positions:
		var tex: Texture2D = _get_cell_texture(_board, pos)
		if tex == null:
			continue
		var from_local := _get_cell_screen_center(_board, pos) - overlay_global
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
		var from_grid: Control = m.get("from_grid")
		var to_grid: Control = m["to_grid"]
		var to_pos: Vector2i = m["to_pos"]
		var to_local := _get_cell_screen_center(to_grid, to_pos) - overlay_global
		var fi: TextureRect
		if from_grid != null:
			var from_pos: Vector2i = m["from_pos"]
			var tex: Texture2D = _get_cell_texture(from_grid, from_pos)
			if tex == null:
				continue
			fi = _spawn_icon(tex, _get_cell_screen_center(from_grid, from_pos) - overlay_global)
			from_grid.get_cell_at(from_pos).clear_item()
		else:
			var from_screen: Vector2 = m.get("from_screen", Vector2.ZERO)
			fi = _spawn_icon(m["item_data"]["definition"].sprite, from_screen - overlay_global)
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


# A Fine or Masterwork result pops its stars over the cell, so a quality
# upgrade is never silent.
func show_quality_sparkle(quality: int, grid_pos: Vector2i) -> void:
	if _anim_overlay == null or _board == null or quality <= 0:
		return
	var stars: Control = QUALITY_STARS.instantiate()
	_anim_overlay.add_child(stars)
	stars.set_quality(quality)
	stars.size = stars.custom_minimum_size
	stars.pivot_offset = stars.size / 2.0
	stars.position = _get_cell_screen_center(_board, grid_pos) - _anim_overlay.global_position - stars.size / 2.0
	stars.scale = Vector2(0.4, 0.4)
	var tween := _anim_overlay.create_tween()
	tween.tween_property(stars, "scale", Vector2(1.6, 1.6), 0.25)
	tween.tween_property(stars, "modulate:a", 0.0, 0.35)
	tween.tween_callback(stars.queue_free)


# A merge that settles below the group's best quality (a mixed group like
# [1,0,0] making Normal) floats a text cue, since the words (not color) carry
# the meaning and the star sparkle only shows an upgrade, never a downgrade.
func show_quality_lost(best_quality: int, grid_pos: Vector2i) -> void:
	if _anim_overlay == null or _board == null or best_quality <= 0:
		return
	var overlay_global := _anim_overlay.global_position
	var cell_center := _get_cell_screen_center(_board, grid_pos) - overlay_global
	var label := Label.new()
	label.text = "%s lost" % ItemDefinition.QUALITY_NAMES[best_quality]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 0.99, 0, 1))
	label.add_theme_font_override("font", load("res://resources/fonts/RobotoCondensed-VariableFont_wght.ttf"))
	label.position = cell_center - Vector2(60, 16)
	label.size = Vector2(120, 32)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anim_overlay.add_child(label)
	var start_pos := label.position
	var tween := _anim_overlay.create_tween()
	tween.tween_method(func(t: float):
		label.position = start_pos + Vector2(0, -60.0 * t)
	, 0.0, 1.0, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tween.tween_callback(label.queue_free)
	quality_lost.emit(best_quality, grid_pos)


func _get_cell_texture(grid: Control, pos: Vector2i) -> Texture2D:
	var cell: Control = grid.get_cell_at(pos)
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


func _get_cell_screen_center(grid: Control, pos: Vector2i) -> Vector2:
	var cell: Control = grid.get_cell_at(pos)
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
	# The drag path stamps the item dict with _source_* keys (see floating_item's
	# and board_cell's _get_drag_data), so by the time this is called from
	# _on_item_placed the incoming item_data no longer equals the staging
	# child's clean item_data. Compare against a copy with those transient
	# drag-metadata keys stripped, otherwise the source stays on screen and can
	# be dropped again (duplication bug).
	var clean := item_data.duplicate()
	clean.erase("_source_screen")
	clean.erase("_source_pos")
	clean.erase("_source_grid")
	for child in _staging_container.get_children():
		if child.item_data == clean:
			child.queue_free()
			return


func _on_item_placed(item: Dictionary, _pos: Vector2i) -> void:
	if GameManager.debug_mode:
		print("[MergeBoard] item_placed: item=%s pos=%s is_processing=%s" % [item.get("item_id", "?"), str(_pos), str(_resolver.is_processing if _resolver else "no_resolver")])
	_run_merge_detection()


# Only a move that actually left the staging area should remove a staging
# item; a board/shelf move or swap must never touch staging just because an
# item there happens to share an id (dicts have no identity of their own).
func _on_staging_item_placed(item: Dictionary, _pos: Vector2i) -> void:
	_remove_staging_item(item)


func _on_board_move(moves: Array[Dictionary]) -> void:
	animate_move(moves, func(): pass)


# The grid model between the merge burst and remove_items() still holds the
# merging items, so a drop mid-merge (board or shelf) could lose or
# duplicate one.
func _drops_allowed() -> bool:
	return not (_resolver and _resolver.is_processing)


func _run_merge_detection() -> void:
	if _resolver and _resolver.is_processing:
		return
	if _board == null:
		return
	var groups: Array[Dictionary] = _detector.scan_grid(_board)
	if groups.is_empty():
		return
	_resolver.enqueue(groups)


func get_board_grid() -> Control:
	return _board


func get_shelf_grid() -> Control:
	return _shelf


func count_sellable(item_id: String, min_quality: int = 0) -> int:
	return _board.count_items_on_board(item_id, min_quality) + _shelf.count_items_on_board(item_id, min_quality)


# The lowest qualifying quality goes first, so a Masterwork is never spent on
# a Normal order. Within one quality the shelf goes first: shelf stock is what
# the player set aside to sell.
func take_sellable(item_id: String, count: int, min_quality: int = 0) -> void:
	var remaining := count
	for quality in range(min_quality, ItemDefinition.MAX_QUALITY + 1):
		for grid: Control in [_shelf, _board]:
			var available: int = grid.count_items_on_board(item_id, quality) - grid.count_items_on_board(item_id, quality + 1)
			var taken := mini(remaining, available)
			grid.remove_items_by_id(item_id, taken, quality)
			remaining -= taken


func get_shelf_state() -> Array:
	return _shelf.get_board_state()


# Saved items past the shelf's end go to the board or staging, never lost.
# Must run after the board is loaded: load_board_state wipes the board, which
# would erase any overflow this placed there.
func load_shelf_state(state: Array) -> void:
	for item in _shelf.load_board_state(state):
		place_drop(item)


func get_staging_area() -> FlowContainer:
	return _staging_container


func _on_merge_choice_requested(options: Array[Dictionary], callback: Callable) -> void:
	_choice_callback = callback
	# show_options() already calls popup_centered() internally, so we don't
	# call it again here (previously this popped the popup twice).
	_popup.call("show_options", options)


func _on_choice_from_popup(item_id: String, is_variant: bool, reagent_id: String) -> void:
	if _choice_callback.is_valid():
		_choice_callback.call(item_id, is_variant, reagent_id)
