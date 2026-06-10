extends PopupPanel

signal choice_made(item_id: String, is_variant: bool, reagent_id: String)

var _vbox: VBoxContainer
var _title_label: Label


func _ready() -> void:
	_title_label = Label.new()
	_title_label.text = "Choose Merge Result"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.custom_minimum_size = Vector2(240, 36)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 8)
	_vbox.add_child(_title_label)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_top", 12)
	margin_container.add_theme_constant_override("margin_bottom", 12)
	margin_container.add_child(_vbox)
	add_child(margin_container)


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
