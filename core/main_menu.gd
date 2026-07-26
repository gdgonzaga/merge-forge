extends Control

const CONFIRM_DIALOG := preload("res://ui/confirm_dialog.tscn")

@onready var _new_game_btn: Button = $VBox/NewGameBtn
@onready var _continue_btn: Button = $VBox/ContinueBtn
@onready var _corrupt_label: Label = $VBox/CorruptLabel


func _ready() -> void:
	_refresh_continue_state()
	_new_game_btn.pressed.connect(_on_new_game_pressed)
	_continue_btn.pressed.connect(func(): EventBus.continue_game.emit())
	EventBus.save_corrupt_detected.connect(_on_save_corrupt)


# New Game wipes the save (main._on_new_game calls delete_save + deserialize({})).
# When no save exists it's harmless, so fire immediately. When a save exists,
# confirm before destroying it.
func _on_new_game_pressed() -> void:
	if not SaveManager.has_save():
		EventBus.new_game_started.emit()
		return
	var dialog := CONFIRM_DIALOG.instantiate()
	add_child(dialog)
	dialog.setup(
		"Start a new game and erase current progress?",
		EventBus.new_game_started.emit,
		Callable(),
		"Erase",
	)


# Continue is available iff a (loadable) save exists. We re-check on ready and
# again whenever a corrupt save is detected (SaveManager quarantines the bad
# file, so has_save() flips to false on the next call).
func _refresh_continue_state() -> void:
	_continue_btn.disabled = not SaveManager.has_save()


func _on_save_corrupt() -> void:
	_refresh_continue_state()
	_corrupt_label.visible = true
