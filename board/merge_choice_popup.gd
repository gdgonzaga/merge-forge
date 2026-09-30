extends PopupPanel

signal choice_made(item_id: String, is_variant: bool, reagent_id: String)
signal cancelled

@onready var _vbox: VBoxContainer = $Margin/VBox
@onready var _title_label: Label = $Margin/VBox/TitleLabel

# Options for the currently shown choice. We keep them so that if the popup is
# dismissed without a pick (Esc / tap-outside) we can fall back to the first
# option via the normal `choice_made` path instead of deadlocking the merge.
var _options: Array[Dictionary] = []
# True once the user picked an option (so a hide triggered by that pick is not
# also treated as a cancel).
var _answered: bool = false


func _ready() -> void:
	popup_hide.connect(_on_popup_hide)


func show_options(options: Array[Dictionary]) -> void:
	_answered = false
	_options = options
	_clear_buttons()
	for opt in options:
		var btn := Button.new()
		var display_name: String = opt.get("display_name", opt.get("item_id", "?"))
		var is_variant: bool = opt.get("is_variant", false)
		var reagent_cost: int = opt.get("reagent_cost", 0)
		var details: Array[String] = []
		var quality: int = opt.get("result_quality", 0)
		if quality > 0:
			details.append(ItemDefinition.QUALITY_NAMES[quality])
		if is_variant:
			details.append("%d %s left" % [opt["reagent_left"], opt["reagent_name"]])
			if reagent_cost > 0:
				details.append("%dg" % reagent_cost)
		btn.text = display_name if details.is_empty() else "%s (%s)" % [display_name, ", ".join(details)]
		btn.custom_minimum_size = Vector2(220, 120)
		btn.add_theme_font_size_override("font_size", 32)
		var item_id: String = opt.get("item_id", "")
		var reagent_id: String = opt.get("reagent_id", "")
		btn.pressed.connect(_on_button_pressed.bind(item_id, is_variant, reagent_id))
		_vbox.add_child(btn)
	popup_centered()


func _on_button_pressed(item_id: String, is_variant: bool, reagent_id: String) -> void:
	_answered = true
	hide()
	choice_made.emit(item_id, is_variant, reagent_id)


func _on_popup_hide() -> void:
	# A real choice hides the popup with `_answered == true`; only an external
	# dismissal (Esc / tap-outside) reaches here. The merge is already committed
	# by then, so we resolve it with the first option rather than leaving the
	# resolver blocked. `cancelled` is the safety net for the (unreachable)
	# empty-options case.
	if _answered:
		return
	if not _options.is_empty():
		choice_made.emit(
			_options[0].get("item_id", ""),
			_options[0].get("is_variant", false),
			_options[0].get("reagent_id", ""),
		)
	else:
		cancelled.emit()


func _clear_buttons() -> void:
	for child in _vbox.get_children():
		if child == _title_label:
			continue
		child.queue_free()
