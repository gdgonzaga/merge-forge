extends Node

@onready var scene_container: Node = $SceneContainer
@onready var hud: Control = $CanvasLayer/HUD

var scene_map: Dictionary = {
	"session_ended": "res://core/session_summary.tscn",
	"session_summary_dismissed": "res://core/prep_phase.tscn",
	"prep_start_session": "res://shop/shop_session.tscn",
	"prep_enter_dungeon": "res://dungeon/dungeon_run.tscn",
	"dungeon_cleared": "res://dungeon/dungeon_summary.tscn",
	"dungeon_failed": "res://dungeon/dungeon_summary.tscn",
	"dungeon_summary_dismissed": "res://core/prep_phase.tscn",
	"prep_quit_to_menu": "res://core/main_menu.tscn",
	"new_game_started": "res://shop/shop_session.tscn",
	"continue_game": "res://core/prep_phase.tscn",
}


func _ready() -> void:
	_transition_to("res://core/main_menu.tscn")
	EventBus.new_game_started.connect(_on_new_game)
	EventBus.continue_game.connect(_on_continue_game)
	EventBus.session_ended.connect(func(_s): _on_scene_signal("session_ended"))
	EventBus.session_summary_dismissed.connect(func(): _on_scene_signal("session_summary_dismissed"))
	EventBus.prep_start_session.connect(func(): _on_scene_signal("prep_start_session"))
	EventBus.prep_enter_dungeon.connect(func(): _on_scene_signal("prep_enter_dungeon"))
	EventBus.dungeon_cleared.connect(func(_r): _on_scene_signal("dungeon_cleared"))
	EventBus.dungeon_failed.connect(func(_s): _on_scene_signal("dungeon_failed"))
	EventBus.dungeon_summary_dismissed.connect(func(): _on_scene_signal("dungeon_summary_dismissed"))
	EventBus.prep_quit_to_menu.connect(func(): _on_scene_signal("prep_quit_to_menu"))


func _on_scene_signal(signal_name: String) -> void:
	var scene_path: String = scene_map.get(signal_name, "")
	if scene_path != "":
		_transition_to(scene_path)


func _on_new_game() -> void:
	SaveManager.delete_save()
	GameManager.deserialize({})
	_transition_to(scene_map["new_game_started"])


func _on_continue_game() -> void:
	var data: Dictionary = SaveManager.load_game()
	if not data.is_empty():
		GameManager.deserialize(data)
	_transition_to(scene_map["continue_game"])


func _transition_to(scene_path: String) -> void:
	for child in scene_container.get_children():
		child.queue_free()
	var scene: PackedScene = load(scene_path)
	if scene:
		var instance := scene.instantiate()
		scene_container.add_child(instance)
