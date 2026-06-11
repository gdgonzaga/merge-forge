extends PopupPanel

signal choice_made(item_id: String, is_variant: bool, reagent_id: String)

@onready var _vbox: VBoxContainer = $Margin/VBox
@onready var _title_label: Label = $Margin/VBox/TitleLabel


func show_options(options: Array[Dictionary]) -> void:
	_clear_buttons()
	for opt in options:
		var btn := Button.new()
		var display_name: String = opt.get("display_name", opt.get("item_id", "?"))
		var is_variant: bool = opt.get("is_variant", false)
		var reagent_cost: int = opt.get("reagent_cost", 0)
		if is_variant and reagent_cost > 0:
			btn.text = "%s (%dg)" % [display_name, reagent_cost]
		else:
			btn.text = display_name
		btn.custom_minimum_size = Vector2(220, 48)
		var item_id: String = opt.get("item_id", "")
		var reagent_id: String = opt.get("reagent_id", "")
		btn.pressed.connect(_on_button_pressed.bind(item_id, is_variant, reagent_id))
		_vbox.add_child(btn)
	popup_centered()


func _on_button_pressed(item_id: String, is_variant: bool, reagent_id: String) -> void:
	hide()
	choice_made.emit(item_id, is_variant, reagent_id)


func _clear_buttons() -> void:
	for child in _vbox.get_children():
		if child == _title_label:
			continue
		child.queue_free()
