extends Control

var progress: float = 0.0
var walk_speed: float = 0.02
var encounter_points: Array = []
var encounters_data: Array = []
var encounters_cleared: int = 0
var next_encounter_idx: int = 0
var is_walking: bool = false

var combat_engine: Node
var drop_mgr: Node
var board: Control
var party_data: Array[Dictionary] = []
var party_members: Array = []
var enemy_displays: Array = []

var _dungeon_data: Dictionary = {}
var _walk_timer: Timer
var _progress_bar: ProgressBar
var _encounter_label: Label
var _party_container: HBoxContainer
var _enemy_container: HBoxContainer
var _popup: PopupPanel
var _choice_callback: Callable


func _ready() -> void:
	var dungeon_id := "goblin_cave"
	_dungeon_data = RecipeResolver.dungeons.get(dungeon_id, {})
	_dbg("dungeon_data: %s" % str(_dungeon_data))
	walk_speed = _dungeon_data.get("walk_speed", 0.02)
	encounter_points = _dungeon_data.get("encounter_points", [])
	encounters_data = _dungeon_data.get("encounters", [])
	_dbg("walk_speed=%s encounter_points=%s encounters_count=%d" % [str(walk_speed), str(encounter_points), encounters_data.size()])

	_load_party()
	_build_layout()

	combat_engine = load("res://dungeon/combat_engine.gd").new()
	combat_engine.init_party(party_data)
	combat_engine.enemy_died.connect(_on_enemy_died)
	combat_engine.member_ko.connect(_on_member_ko)
	combat_engine.party_wiped.connect(_on_party_wiped)
	combat_engine.encounter_ended.connect(_on_encounter_ended)
	add_child(combat_engine)

	drop_mgr = load("res://dungeon/drop_manager.gd").new()
	add_child(drop_mgr)

	var popup_scene: PackedScene = load("res://board/merge_choice_popup.tscn")
	_popup = popup_scene.instantiate()
	add_child(_popup)
	_popup.choice_made.connect(_on_choice_from_popup)

	_walk_timer = Timer.new()
	_walk_timer.wait_time = 0.1
	_walk_timer.timeout.connect(_on_walk_tick)
	add_child(_walk_timer)

	start_walking()


func _load_party() -> void:
	var members: Dictionary = RecipeResolver.party.get("party_members", {})
	var idx := 0
	for role in ["fighter", "mage", "healer"]:
		var data: Dictionary = members.get(role, {})
		party_data.append({
			"role": role,
			"name": data.get("name", role),
			"sprite": data.get("sprite", ""),
			"max_hp": data.get("max_hp", 50),
			"attack": data.get("attack", 10),
			"member_index": idx,
		})
		idx += 1


func _build_layout() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	root.add_child(top_bar)

	_progress_bar = ProgressBar.new()
	_progress_bar.max_value = 100
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(_progress_bar)

	_encounter_label = Label.new()
	_encounter_label.add_theme_font_size_override("font_size", 18)
	_encounter_label.text = "Walking..."
	top_bar.add_child(_encounter_label)

	_party_container = HBoxContainer.new()
	_party_container.add_theme_constant_override("separation", 8)
	_party_container.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_party_container)

	var pm_scene: PackedScene = load("res://dungeon/party_member.tscn")
	for i in range(party_data.size()):
		var pm: Control = pm_scene.instantiate()
		_party_container.add_child(pm)
		pm.setup(party_data[i])
		party_members.append(pm)

	_enemy_container = HBoxContainer.new()
	_enemy_container.add_theme_constant_override("separation", 8)
	_enemy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_enemy_container)

	var merge_board_scene: PackedScene = load("res://board/merge_board.tscn")
	board = merge_board_scene.instantiate()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(board)

	var cell_scene: PackedScene = load("res://board/board_cell.tscn")
	board.setup({
		"cols": GameManager.grid_cols,
		"rows": GameManager.grid_rows,
		"cell_scene": cell_scene,
		"popup_callback": _on_merge_choice_requested,
		"despawn_time": GameManager.get_despawn_time(),
	})


func start_walking() -> void:
	is_walking = true
	_walk_timer.start()
	_encounter_label.text = "Walking..."


func stop_walking() -> void:
	is_walking = false
	_walk_timer.stop()


func start_encounter(encounter_idx: int) -> void:
	stop_walking()
	_encounter_label.text = "Encounter %d!" % (encounter_idx + 1)
	_dbg("start_encounter: idx=%d" % encounter_idx)

	if encounter_idx >= encounters_data.size():
		_dbg("start_encounter: idx out of range")
		return

	var encounter: Array = encounters_data[encounter_idx]
	_dbg("encounter data: %s" % str(encounter))
	_clear_enemy_displays()

	var ed_scene: PackedScene = load("res://dungeon/enemy_display.tscn")
	for entry in encounter:
		var enemy_id: String = entry.get("enemy_id", "")
		var count: int = entry.get("count", 1)
		for _i in range(count):
			var ed: Control = ed_scene.instantiate()
			_enemy_container.add_child(ed)
			enemy_displays.append(ed)

	combat_engine.start_combat(encounter)

	for i in range(combat_engine.enemies.size()):
		if i < enemy_displays.size() and is_instance_valid(enemy_displays[i]):
			enemy_displays[i].setup(combat_engine.enemies[i])


func end_encounter() -> void:
	_clear_enemy_displays()
	encounters_cleared += 1

	if progress >= 1.0 and encounters_cleared >= encounter_points.size():
		end_dungeon_cleared()
	else:
		start_walking()


func apply_usable_item(member_index: int, item_data: Dictionary) -> void:
	if not combat_engine:
		return
	var source_pos = item_data.get("_source_pos", Vector2i(-1, -1))
	var board_grid = _get_board_grid()
	if board_grid and source_pos.x >= 0:
		board_grid.discard_item(source_pos)
	var effect: Dictionary = item_data.get("effect", {})
	if not effect.is_empty():
		combat_engine.apply_effect(member_index, effect)
		var md: Dictionary = combat_engine.get_member_data(member_index)
		if member_index < party_members.size() and is_instance_valid(party_members[member_index]):
			party_members[member_index].update_hp(md.get("current_hp", 0), md.get("max_hp", 50))
			party_members[member_index].update_buffs(md.get("active_buffs", []))


func end_dungeon_cleared() -> void:
	stop_walking()
	_dbg("DUNGEON CLEARED")
	var gold_reward: int = _dungeon_data.get("gold_reward", 0)
	var bp_reward = _dungeon_data.get("blueprint_reward")
	GameManager.add_gold(gold_reward)
	GameManager.add_reputation(25)
	if bp_reward and bp_reward != null:
		GameManager.add_blueprint(bp_reward)
	EventBus.dungeon_cleared.emit({
		"cleared": true,
		"gold_reward": gold_reward,
		"blueprint_reward": bp_reward,
		"reputation_change": 25,
	})


func end_dungeon_failed() -> void:
	stop_walking()
	_dbg("DUNGEON FAILED")
	GameManager.add_reputation(-20)
	EventBus.dungeon_failed.emit({
		"cleared": false,
		"gold_reward": 0,
		"blueprint_reward": null,
		"reputation_change": -20,
	})


func _on_walk_tick() -> void:
	progress += walk_speed * 0.1
	_progress_bar.value = progress * 100

	if next_encounter_idx < encounter_points.size():
		if progress >= encounter_points[next_encounter_idx]:
			start_encounter(next_encounter_idx)
			next_encounter_idx += 1
			return

	if progress >= 1.0:
		stop_walking()
		if encounters_cleared >= encounter_points.size():
			end_dungeon_cleared()


func _on_enemy_died(enemy_index: int) -> void:
	if enemy_index < enemy_displays.size() and is_instance_valid(enemy_displays[enemy_index]):
		var ed = enemy_displays[enemy_index]
		var data: Dictionary = combat_engine.get_enemy_data(enemy_index)
		var drops: Array[Dictionary] = drop_mgr.spawn_drops(data)
		if board:
			drop_mgr.add_drops_to_board(drops, board)
		ed.play_death()
		enemy_displays[enemy_index] = null


func _on_member_ko(member_index: int) -> void:
	if member_index < party_members.size() and is_instance_valid(party_members[member_index]):
		party_members[member_index].set_ko()


func _on_party_wiped() -> void:
	end_dungeon_failed()


func _on_encounter_ended() -> void:
	end_encounter()


func _clear_enemy_displays() -> void:
	for ed in enemy_displays:
		if ed and is_instance_valid(ed):
			ed.queue_free()
	enemy_displays.clear()


func _get_board_grid() -> Node:
	if board == null:
		return null
	return board.get_node_or_null("VBox/BoardArea/CenterContainer/BoardGrid")


func _on_merge_choice_requested(options: Array[Dictionary], callback: Callable) -> void:
	_choice_callback = callback
	_popup.call("show_options", options)
	_popup.popup_centered()


func _on_choice_from_popup(item_id: String, is_variant: bool, reagent_id: String) -> void:
	if _choice_callback.is_valid():
		_choice_callback.call(item_id, is_variant, reagent_id)


func _dbg(msg: String) -> void:
	if GameManager.debug_mode:
		print("[DungeonController] %s" % msg)
