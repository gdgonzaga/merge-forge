extends Control


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.2)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = "Prep Phase"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(340, 400)
	title.size = Vector2(400, 60)
	title.add_theme_font_size_override("font_size", 36)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	_make_button("Quit to Menu", Vector2(340, 1200), func(): EventBus.prep_quit_to_menu.emit())
	_make_button("Start Session", Vector2(340, 1400), func(): EventBus.prep_start_session.emit())
	_make_button("Enter Dungeon", Vector2(340, 1520), func(): EventBus.prep_enter_dungeon.emit())


func _make_button(text: String, pos: Vector2, on_press: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = Vector2(400, 80)
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(on_press)
	add_child(btn)
