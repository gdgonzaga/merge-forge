extends Node

@onready var scene_container: Node = $SceneContainer
@onready var hud: Control = $CanvasLayer/HUD
@onready var _splash_screen: SplashScreen = %SplashScreen

var scene_map: Dictionary = {
	"session_ended": "res://shop/session_summary.tscn",
	"session_summary_dismissed": "res://core/prep_phase.tscn",
	"prep_start_session": "res://shop/shop_session.tscn",
	"prep_enter_dungeon": "res://dungeon/dungeon_run.tscn",
	"dungeon_cleared": "res://dungeon/dungeon_summary.tscn",
	"dungeon_failed": "res://dungeon/dungeon_summary.tscn",
	"dungeon_summary_dismissed": "res://core/prep_phase.tscn",
	"prep_quit_to_menu": "res://core/main_menu.tscn",
	"prep_open_charter": "res://core/charter_screen.tscn",
	"charter_closed": "res://core/prep_phase.tscn",
	"charter_founded": "res://core/prep_phase.tscn",
	"new_game_started": "res://core/prep_phase.tscn",
	"continue_game": "res://core/prep_phase.tscn",
	"intro": "res://core/intro.tscn",
	"intro_finished": "res://core/prep_phase.tscn",
}

var pending_summary: Dictionary = {}
var pending_dungeon_summary: Dictionary = {}


func _ready() -> void:
	_splash_screen.finished.connect(_on_splash_finished)
	_transition_to("res://core/main_menu.tscn")
	EventBus.new_game_started.connect(_on_new_game)
	EventBus.continue_game.connect(_on_continue_game)
	EventBus.intro_finished.connect(_go_to.bind("intro_finished"))
	EventBus.session_ended.connect(_on_session_ended)
	EventBus.session_summary_dismissed.connect(_go_to.bind("session_summary_dismissed"))
	EventBus.prep_start_session.connect(_go_to.bind("prep_start_session"))
	EventBus.prep_enter_dungeon.connect(_on_prep_enter_dungeon)
	EventBus.dungeon_cleared.connect(_on_dungeon_cleared)
	EventBus.dungeon_failed.connect(_on_dungeon_failed)
	EventBus.dungeon_summary_dismissed.connect(_go_to.bind("dungeon_summary_dismissed"))
	EventBus.prep_quit_to_menu.connect(_go_to.bind("prep_quit_to_menu"))
	EventBus.prep_open_charter.connect(_go_to.bind("prep_open_charter"))
	EventBus.charter_closed.connect(_go_to.bind("charter_closed"))
	EventBus.charter_founded.connect(_on_charter_founded)


func _on_splash_finished() -> void:
	$SplashLayer.queue_free()


func _go_to(_data = null, scene_key: String = "") -> void:
	var key: String = scene_key if scene_key != "" else str(_data)
	_transition_to(scene_map.get(key, ""))


func _on_session_ended(summary: Dictionary) -> void:
	pending_summary = summary
	_go_to(null, "session_ended")


func _on_dungeon_cleared(rewards: Dictionary) -> void:
	pending_dungeon_summary = rewards
	_go_to(null, "dungeon_cleared")


func _on_dungeon_failed(summary: Dictionary) -> void:
	pending_dungeon_summary = summary
	_go_to(null, "dungeon_failed")


func _on_prep_enter_dungeon(dungeon_id: String) -> void:
	# Set before add_child so DungeonRun's _ready can read it.
	_transition_to(scene_map["prep_enter_dungeon"], func(run: Node) -> void: run.dungeon_id = dungeon_id)


# A charter is not an ad break (README principle 6): straight to the new
# town's prep.
func _on_charter_founded(_town_id: String) -> void:
	_go_to(null, "charter_founded")


func _on_new_game() -> void:
	SaveManager.delete_save()
	GameManager.deserialize({})
	# Fresh save: deserialize({}) resets seen_intro to false, so the intro
	# plays. Once it has played (seen_intro true), skip straight to prep.
	if GameManager.seen_intro:
		_go_to(null, "new_game_started")
	else:
		_go_to(null, "intro")


func _on_continue_game() -> void:
	var result: Dictionary = SaveManager.load_game_ex()
	var status: int = result.get("status", SaveManager.LoadStatus.MISSING)
	if status == SaveManager.LoadStatus.OK:
		GameManager.deserialize(result["data"])
		_go_to(null, "continue_game")
	else:
		# MISSING: no save (Continue shouldn't have been tappable).
		# CORRUPT: SaveManager already quarantined + push_error'd. Don't load,
		#           don't transition — stay on the menu. Tell the menu to surface
		#           the problem so the player knows to start a new game.
		if status == SaveManager.LoadStatus.CORRUPT:
			EventBus.save_corrupt_detected.emit()
		push_warning("[Main] continue aborted: save status %d" % status)


# configure, when valid, gets the new scene before it enters the tree.
func _transition_to(scene_path: String, configure: Callable = Callable()) -> void:
	if scene_path == "":
		return
	for child in scene_container.get_children():
		child.queue_free()
	var scene: PackedScene = load(scene_path)
	if scene:
		var instance := scene.instantiate()
		if configure.is_valid():
			configure.call(instance)
		scene_container.add_child(instance)
	else:
		push_error("[Main] FAILED to load scene: " + scene_path)
	_play_scene_music(scene_path)


func _play_scene_music(scene_path: String) -> void:
	print("[Main] _play_scene_music: path='%s'" % scene_path)
	if "dungeon" in scene_path:
		AudioManager.play_music("dungeon_theme")
	elif "main_menu" in scene_path:
		AudioManager.stop_music()
	else:
		AudioManager.play_music("shop_theme")
