class_name SplashScreen
extends Control

signal finished

@onready var _video_player: VideoStreamPlayer = %VideoPlayer
@onready var _splash_timer: Timer = %SplashTimer

var _is_finished := false


func _ready() -> void:
	_video_player.finished.connect(_finish)
	_splash_timer.timeout.connect(_finish)
	_video_player.play()
	_splash_timer.start()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		_finish()


func _finish() -> void:
	if _is_finished:
		return
	_is_finished = true
	_splash_timer.stop()
	_video_player.stop()
	finished.emit()
