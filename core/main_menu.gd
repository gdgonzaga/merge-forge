extends Control

@onready var _new_game_btn: Button = $VBox/NewGameBtn
@onready var _continue_btn: Button = $VBox/ContinueBtn


func _ready() -> void:
	_continue_btn.disabled = not SaveManager.has_save()
	_new_game_btn.pressed.connect(func(): EventBus.new_game_started.emit())
	_continue_btn.pressed.connect(func(): EventBus.continue_game.emit())
