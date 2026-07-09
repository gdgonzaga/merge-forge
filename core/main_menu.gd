extends Control

@onready var _new_game_btn: Button = $VBox/NewGameBtn
@onready var _continue_btn: Button = $VBox/ContinueBtn
@onready var _corrupt_label: Label = $VBox/CorruptLabel


func _ready() -> void:
	_refresh_continue_state()
	_new_game_btn.pressed.connect(func(): EventBus.new_game_started.emit())
	_continue_btn.pressed.connect(func(): EventBus.continue_game.emit())
	EventBus.save_corrupt_detected.connect(_on_save_corrupt)


# Continue is available iff a (loadable) save exists. We re-check on ready and
# again whenever a corrupt save is detected (SaveManager quarantines the bad
# file, so has_save() flips to false on the next call).
func _refresh_continue_state() -> void:
	_continue_btn.disabled = not SaveManager.has_save()


func _on_save_corrupt() -> void:
	_refresh_continue_state()
	_corrupt_label.visible = true
