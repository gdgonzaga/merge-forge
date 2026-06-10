extends Control

var _merge_board: Control
var _gold_label: Label
var _popup: PopupPanel
var _choice_callback: Callable


func _ready() -> void:
	var merge_board_scene: PackedScene = load("res://board/merge_board.tscn")
	_merge_board = merge_board_scene.instantiate()
	_merge_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_merge_board)

	_gold_label = Label.new()
	_gold_label.text = "Gold: %d" % GameManager.gold
	_gold_label.position = Vector2(10, 10)
	_gold_label.add_theme_font_size_override("font_size", 24)
	_gold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gold_label)
	GameManager.gold_changed.connect(_on_gold_changed)

	var crate_btn := Button.new()
	crate_btn.text = "Buy Basic Crate (10g)"
	crate_btn.position = Vector2(10, 40)
	crate_btn.size = Vector2(300, 50)
	crate_btn.add_theme_font_size_override("font_size", 20)
	crate_btn.pressed.connect(_on_buy_crate)
	add_child(crate_btn)

	var cell_scene: PackedScene = load("res://board/board_cell.tscn")
	_merge_board.setup({
		"cols": 5,
		"rows": 5,
		"cell_scene": cell_scene,
		"popup_callback": _on_merge_choice_requested,
		"despawn_time": 12.0,
	})

	var popup_scene: PackedScene = load("res://board/merge_choice_popup.tscn")
	_popup = popup_scene.instantiate()
	add_child(_popup)
	_popup.choice_made.connect(_on_choice_from_popup)


func _on_buy_crate() -> void:
	_merge_board.buy_crate("basic")


func _on_gold_changed(new_amount: int) -> void:
	_gold_label.text = "Gold: %d" % new_amount


func _on_merge_choice_requested(options: Array[Dictionary], callback: Callable) -> void:
	_choice_callback = callback
	_popup.call("show_options", options)
	_popup.popup_centered()


func _on_choice_from_popup(item_id: String, is_variant: bool, reagent_id: String) -> void:
	if _choice_callback.is_valid():
		_choice_callback.call(item_id, is_variant, reagent_id)
