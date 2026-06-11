extends Control

var _quit_btn: Button
var _start_btn: Button
var _dungeon_btn: Button


func _ready() -> void:
	_quit_btn = Button.new()
	_quit_btn.text = "Quit to Menu"
	_quit_btn.position = Vector2(340, 1200)
	_quit_btn.size = Vector2(400, 80)
	_quit_btn.add_theme_font_size_override("font_size", 28)
	_quit_btn.pressed.connect(_on_quit)
	add_child(_quit_btn)

	_start_btn = Button.new()
	_start_btn.text = "Start Session"
	_start_btn.position = Vector2(340, 1400)
	_start_btn.size = Vector2(400, 80)
	_start_btn.add_theme_font_size_override("font_size", 28)
	_start_btn.pressed.connect(_on_start_session)
	add_child(_start_btn)

	_dungeon_btn = Button.new()
	_dungeon_btn.text = "Enter Dungeon"
	_dungeon_btn.position = Vector2(340, 1520)
	_dungeon_btn.size = Vector2(400, 80)
	_dungeon_btn.add_theme_font_size_override("font_size", 28)
	_dungeon_btn.pressed.connect(_on_enter_dungeon)
	add_child(_dungeon_btn)


func _on_quit() -> void:
	EventBus.prep_quit_to_menu.emit()


func _on_start_session() -> void:
	EventBus.prep_start_session.emit()


func _on_enter_dungeon() -> void:
	EventBus.prep_enter_dungeon.emit()
