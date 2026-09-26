extends Control

var progress: float = 0.0
var walk_speed: float = 0.02
var encounter_points: Array = []
var encounters_data: Array = []
var encounters_cleared: int = 0
var next_encounter_idx: int = 0

var combat_engine: Node
var drop_mgr: Node
var party_data: Array[Dictionary] = []
var party_members: Array = []
var enemy_displays: Array = []

var _dungeon_data: Dictionary = {}
var _walk_timer: Timer

@onready var board: Control = $VBox/Board
@onready var _progress_bar: ProgressBar = $VBox/TopBar/ProgressBar
@onready var _encounter_label: Label = $VBox/TopBar/EncounterLabel
@onready var _party_container: HBoxContainer = $VBox/PartyContainer
@onready var _enemy_container: HBoxContainer = $VBox/EnemyContainer


func _ready() -> void:
	var dungeon_id := "goblin_cave"
	_dungeon_data = RecipeResolver.dungeons.get(dungeon_id, {})
	_dbg("dungeon_data: %s" % str(_dungeon_data))
	walk_speed = _dungeon_data.get("walk_speed", 0.02)
	encounter_points = _dungeon_data.get("encounter_points", [])
	encounters_data = _dungeon_data.get("encounters", [])
	_dbg("walk_speed=%s encounter_points=%s encounters_count=%d" % [str(walk_speed), str(encounter_points), encounters_data.size()])

	_load_party()
	AudioManager.play_sfx("dungeon_start")

	for child in _party_container.get_children():
		child.queue_free()

	var pm_scene: PackedScene = load("res://dungeon/party_member.tscn")
	for i in range(party_data.size()):
		var pm: Control = pm_scene.instantiate()
		_party_container.add_child(pm)
		pm.setup(party_data[i])
		party_members.append(pm)

	board.setup({})
	if not GameManager.dungeon_board_state.is_empty():
		var board_grid = _get_board_grid()
		if board_grid:
			board_grid.load_board_state(GameManager.dungeon_board_state)

	combat_engine = load("res://dungeon/combat_engine.gd").new()
	combat_engine.init_party(party_data)
	combat_engine.enemy_died.connect(_on_enemy_died)
	combat_engine.member_ko.connect(_on_member_ko)
	combat_engine.party_wiped.connect(end_dungeon_failed)
	combat_engine.encounter_ended.connect(end_encounter)
	combat_engine.tick_resolved.connect(_refresh_combat_displays)
	add_child(combat_engine)

	drop_mgr = load("res://dungeon/drop_manager.gd").new()
	add_child(drop_mgr)

	_walk_timer = Timer.new()
	_walk_timer.wait_time = 0.1
	_walk_timer.timeout.connect(_on_walk_tick)
	add_child(_walk_timer)

	start_walking()


func _load_party() -> void:
	# Array order is slot order: index 0 is the front member melee enemies hit.
	var members: Array = RecipeResolver.party["party_members"]
	for idx in range(members.size()):
		var data: Dictionary = members[idx]
		party_data.append({
			"role": data["id"],
			"name": data.get("name", data["id"]),
			"sprite": data.get("sprite", ""),
			"max_hp": data.get("max_hp", 50),
			"attack": data.get("attack", 10),
			"member_index": idx,
		})


func start_walking() -> void:
	_walk_timer.start()
	_encounter_label.text = "Walking..."


func stop_walking() -> void:
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
	var effect = item_data.get("effect", null)
	if effect != null:
		if effect is EffectDefinition or (effect is Dictionary and not effect.is_empty()):
			combat_engine.apply_effect(member_index, effect)
			_refresh_combat_displays()


func end_dungeon_cleared() -> void:
	stop_walking()
	_dbg("DUNGEON CLEARED")
	var gold_reward: int = _dungeon_data.get("gold_reward", 0)
	var bp_reward = _dungeon_data.get("blueprint_reward")
	GameManager.add_gold(gold_reward)
	GameManager.add_reputation(25)
	if bp_reward and bp_reward != null:
		GameManager.add_blueprint(bp_reward)
	_save_board_state()
	EventBus.save_requested.emit()
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
	_save_board_state()
	EventBus.save_requested.emit()
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


func _refresh_combat_displays() -> void:
	for i in range(party_members.size()):
		if is_instance_valid(party_members[i]):
			var md: Dictionary = combat_engine.get_member_data(i)
			party_members[i].update_hp(md.get("current_hp", 0), md.get("max_hp", 50))
			party_members[i].update_buffs(md.get("active_buffs", []))
	for i in range(enemy_displays.size()):
		if enemy_displays[i] and is_instance_valid(enemy_displays[i]):
			var ed_data: Dictionary = combat_engine.get_enemy_data(i)
			enemy_displays[i].update_hp(ed_data.get("current_hp", 0), ed_data.get("max_hp", 30))
			enemy_displays[i].show_telegraph(_telegraph_text(ed_data))


func _telegraph_text(enemy: Dictionary) -> String:
	var heavy: Dictionary = enemy["heavy_attack"]
	var target: int = enemy["heavy_target"]
	if enemy["heavy_in"] > int(heavy["windup"]) or target < 0:
		return ""
	return "%s: %s in %d" % [heavy["name"], party_data[target]["name"], enemy["heavy_in"]]


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


func _clear_enemy_displays() -> void:
	for ed in enemy_displays:
		if ed and is_instance_valid(ed):
			ed.queue_free()
	enemy_displays.clear()


func _get_board_grid() -> Node:
	if board == null:
		return null
	return board.get_board_grid()


func _dbg(msg: String) -> void:
	if GameManager.debug_mode:
		print("[DungeonController] %s" % msg)


func _save_board_state() -> void:
	var board_grid = _get_board_grid()
	if board_grid and is_instance_valid(board_grid):
		GameManager.dungeon_board_state = board_grid.get_board_state()
