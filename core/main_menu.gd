extends Control

var _new_game_btn: Button
var _continue_btn: Button


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.1, 0.2)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = "MergeForge"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(340, 500)
	title.size = Vector2(400, 60)
	title.add_theme_font_size_override("font_size", 48)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	_new_game_btn = Button.new()
	_new_game_btn.text = "New Game"
	_new_game_btn.position = Vector2(340, 700)
	_new_game_btn.size = Vector2(400, 80)
	_new_game_btn.add_theme_font_size_override("font_size", 32)
	_new_game_btn.pressed.connect(_on_new_game)
	add_child(_new_game_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.position = Vector2(340, 820)
	_continue_btn.size = Vector2(400, 80)
	_continue_btn.add_theme_font_size_override("font_size", 32)
	_continue_btn.disabled = not SaveManager.has_save()
	_continue_btn.pressed.connect(_on_continue)
	add_child(_continue_btn)


func _on_new_game() -> void:
	EventBus.new_game_started.emit()


func _on_continue() -> void:
	EventBus.continue_game.emit()
