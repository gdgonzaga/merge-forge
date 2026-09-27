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

# Pause after an encounter is won or lost, so the final volley's hits,
# numbers and death fades play out before the scene moves on.
const END_BEAT := 0.8

var _presenter: Node
var _dungeon_data: Dictionary = {}
var _walk_timer: Timer
var _walk_phase: float = 0.0

@onready var board: Control = $VBox/Board
@onready var vfx: Control = $AnimOverlay
@onready var _progress_bar: ProgressBar = $VBox/TopBar/ProgressBar
@onready var _encounter_label: Label = $VBox/TopBar/EncounterLabel
@onready var _party_container: HBoxContainer = $VBox/PartyContainer
@onready var _enemy_container: HBoxContainer = $VBox/EnemyContainer
@onready var _lines: Control = %CombatLines


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
	combat_engine.party_wiped.connect(_on_party_wiped)
	combat_engine.encounter_ended.connect(end_encounter)
	add_child(combat_engine)
	_presenter = load("res://dungeon/combat_presenter.gd").new()
	add_child(_presenter)
	_presenter.setup(combat_engine, party_members, vfx, _lines)

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
			"name": data.get("name", data["id"]),
			"sprite": data["sprite"],
			"max_hp": data.get("max_hp", 50),
			"attack": data.get("attack", 10),
			"attack_type": data["attack_type"],
			"windup": data["windup"],
			"crit_chance": data["crit_chance"],
			"crit_name": data["crit_name"],
			"member_index": idx,
		})


func start_walking() -> void:
	_walk_timer.start()
	_encounter_label.text = "Walking..."


func stop_walking() -> void:
	_walk_timer.stop()
	for pm in party_members:
		if is_instance_valid(pm):
			pm.play_walk(0.0)


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
			ed.play_spawn()

	combat_engine.start_combat(encounter)
	_presenter.set_enemy_units(enemy_displays)

	for i in range(combat_engine.enemies.size()):
		if i < enemy_displays.size() and is_instance_valid(enemy_displays[i]):
			enemy_displays[i].setup(combat_engine.enemies[i])


func end_encounter() -> void:
	get_tree().create_timer(END_BEAT).timeout.connect(_finish_encounter)


func _finish_encounter() -> void:
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
			_presenter.refresh_member(member_index)


func end_dungeon_cleared() -> void:
	stop_walking()
	_dbg("DUNGEON CLEARED")
	for pm in party_members:
		if is_instance_valid(pm):
			pm.play_victory()
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
	_walk_phase += 0.5
	for pm in party_members:
		if is_instance_valid(pm):
			pm.play_walk(sin(_walk_phase) * 3.0)

	if next_encounter_idx < encounter_points.size():
		if progress >= encounter_points[next_encounter_idx]:
			start_encounter(next_encounter_idx)
			next_encounter_idx += 1
			return

	if progress >= 1.0:
		stop_walking()
		if encounters_cleared >= encounter_points.size():
			end_dungeon_cleared()


# Drops land at once; the death itself is shown when the killing hit arrives
# (CombatPresenter).
func _on_enemy_died(enemy_index: int) -> void:
	var drops: Array[Dictionary] = drop_mgr.spawn_drops(combat_engine.get_enemy_data(enemy_index))
	if board:
		drop_mgr.add_drops_to_board(drops, board)


func _on_party_wiped() -> void:
	get_tree().create_timer(END_BEAT).timeout.connect(end_dungeon_failed)


func _clear_enemy_displays() -> void:
	for ed in enemy_displays:
		if ed and is_instance_valid(ed):
			ed.queue_free()
	enemy_displays.clear()
	_presenter.set_enemy_units(enemy_displays)


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
