extends Control


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

	var new_game_btn := Button.new()
	new_game_btn.text = "New Game"
	new_game_btn.position = Vector2(340, 700)
	new_game_btn.size = Vector2(400, 80)
	new_game_btn.add_theme_font_size_override("font_size", 32)
	new_game_btn.pressed.connect(func(): EventBus.new_game_started.emit())
	add_child(new_game_btn)

	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.position = Vector2(340, 820)
	continue_btn.size = Vector2(400, 80)
	continue_btn.add_theme_font_size_override("font_size", 32)
	continue_btn.disabled = not SaveManager.has_save()
	continue_btn.pressed.connect(func(): EventBus.continue_game.emit())
	add_child(continue_btn)
