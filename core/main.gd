extends Node

@onready var scene_container: Node = $SceneContainer
@onready var hud: Control = $CanvasLayer/HUD

var scene_map: Dictionary = {
	"session_ended": "res://shop/session_summary.tscn",
	"session_summary_dismissed": "res://core/prep_phase.tscn",
	"prep_start_session": "res://shop/shop_session.tscn",
	"prep_enter_dungeon": "res://dungeon/dungeon_run.tscn",
	"dungeon_cleared": "res://dungeon/dungeon_summary.tscn",
	"dungeon_failed": "res://dungeon/dungeon_summary.tscn",
	"dungeon_summary_dismissed": "res://core/prep_phase.tscn",
	"prep_quit_to_menu": "res://core/main_menu.tscn",
	"new_game_started": "res://core/prep_phase.tscn",
	"continue_game": "res://core/prep_phase.tscn",
}

var pending_summary: Dictionary = {}
var pending_dungeon_summary: Dictionary = {}


func _ready() -> void:
	_transition_to("res://core/main_menu.tscn")
	EventBus.new_game_started.connect(_on_new_game)
	EventBus.continue_game.connect(_on_continue_game)
	EventBus.session_ended.connect(_on_session_ended)
	EventBus.session_summary_dismissed.connect(_go_to.bind("session_summary_dismissed"))
	EventBus.prep_start_session.connect(_go_to.bind("prep_start_session"))
	EventBus.prep_enter_dungeon.connect(_go_to.bind("prep_enter_dungeon"))
	EventBus.dungeon_cleared.connect(_on_dungeon_cleared)
	EventBus.dungeon_failed.connect(_on_dungeon_failed)
	EventBus.dungeon_summary_dismissed.connect(_go_to.bind("dungeon_summary_dismissed"))
	EventBus.prep_quit_to_menu.connect(_go_to.bind("prep_quit_to_menu"))


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


func _on_new_game() -> void:
	SaveManager.delete_save()
	GameManager.deserialize({})
	_go_to(null, "new_game_started")


func _on_continue_game() -> void:
	var data: Dictionary = SaveManager.load_game()
	if not data.is_empty():
		GameManager.deserialize(data)
	_go_to(null, "continue_game")


func _transition_to(scene_path: String) -> void:
	if scene_path == "":
		return
	for child in scene_container.get_children():
		child.queue_free()
	var scene: PackedScene = load(scene_path)
	if scene:
		scene_container.add_child(scene.instantiate())
	else:
		push_error("[Main] FAILED to load scene: " + scene_path)
	_play_scene_music(scene_path)


func _play_scene_music(scene_path: String) -> void:
	if "dungeon" in scene_path:
		AudioManager.play_music("dungeon_theme")
	elif "main_menu" in scene_path:
		AudioManager.stop_music()
	else:
		AudioManager.play_music("shop_theme")
