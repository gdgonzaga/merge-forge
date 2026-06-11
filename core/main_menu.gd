extends Control


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.1, 0.2)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	add_child(vbox)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_top)

	var title := Label.new()
	title.text = "MergeForge"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var spacer_mid := Control.new()
	spacer_mid.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer_mid)

	var new_game_btn := Button.new()
	new_game_btn.text = "New Game"
	new_game_btn.custom_minimum_size = Vector2(400, 80)
	new_game_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	new_game_btn.add_theme_font_size_override("font_size", 32)
	new_game_btn.pressed.connect(func(): EventBus.new_game_started.emit())
	vbox.add_child(new_game_btn)

	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(400, 80)
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_btn.add_theme_font_size_override("font_size", 32)
	continue_btn.disabled = not SaveManager.has_save()
	continue_btn.pressed.connect(func(): EventBus.continue_game.emit())
	vbox.add_child(continue_btn)

	var spacer_bot := Control.new()
	spacer_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bot)
