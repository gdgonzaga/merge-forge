extends Control

var _gold_label: Label
var _sold_label: Label
var _fulfilled_label: Label
var _rejected_label: Label
var _gold_count: int = 0
var _target_gold: int = 0
var _countup_tween: Tween


func display_summary(data: Dictionary) -> void:
	_target_gold = data.get("gold_earned", 0)
	_gold_count = 0
	_sold_label.text = "Items Sold: %d" % data.get("items_sold", 0)
	_fulfilled_label.text = "Fulfilled: %d" % data.get("fulfilled", 0)
	_rejected_label.text = "Rejected: %d" % data.get("rejected", 0)

	if _target_gold > 0:
		_gold_label.text = "Gold Earned: 0"
		_countup_tween = create_tween()
		_countup_tween.tween_method(_set_gold_count, 0, _target_gold, 1.5)
		_countup_tween.tween_callback(func(): _gold_label.text = "Gold Earned: %d" % _target_gold)
	else:
		_gold_label.text = "Gold Earned: 0"


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.14)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_top)

	var title := Label.new()
	title.text = "Session Summary"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 32)
	_gold_label.modulate = Color(1, 0.84, 0)
	vbox.add_child(_gold_label)

	_sold_label = Label.new()
	_sold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sold_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_sold_label)

	_fulfilled_label = Label.new()
	_fulfilled_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fulfilled_label.add_theme_font_size_override("font_size", 24)
	_fulfilled_label.modulate = Color(0.5, 1, 0.5)
	vbox.add_child(_fulfilled_label)

	_rejected_label = Label.new()
	_rejected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rejected_label.add_theme_font_size_override("font_size", 24)
	_rejected_label.modulate = Color(1, 0.5, 0.5)
	vbox.add_child(_rejected_label)

	var spacer_mid := Control.new()
	spacer_mid.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(spacer_mid)

	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.add_theme_font_size_override("font_size", 28)
	continue_btn.custom_minimum_size = Vector2(400, 80)
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_btn.pressed.connect(func(): EventBus.session_summary_dismissed.emit())
	vbox.add_child(continue_btn)

	var spacer_bot := Control.new()
	spacer_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bot)

	var summary_data: Dictionary = {}
	var main_node := get_tree().root.find_child("Main", true, false)
	if main_node and main_node.pending_summary != null:
		summary_data = main_node.pending_summary

	display_summary(summary_data)


func _set_gold_count(value: int) -> void:
	_gold_count = value
	_gold_label.text = "Gold Earned: %d" % value
