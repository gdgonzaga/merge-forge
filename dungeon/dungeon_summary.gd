extends Control

var _title_label: Label
var _gold_label: Label
var _rep_label: Label
var _bp_label: Label


func display_results(data: Dictionary) -> void:
	var cleared: bool = data.get("cleared", false)
	if cleared:
		_title_label.text = "Dungeon Cleared!"
		_title_label.modulate = Color(0.5, 1, 0.5)
		_gold_label.text = "Gold: +%d" % data.get("gold_reward", 0)
		_rep_label.text = "Reputation: +25"
		var bp = data.get("blueprint_reward")
		if bp and bp != null:
			_bp_label.text = "Blueprint: %s" % str(bp)
		else:
			_bp_label.text = ""
	else:
		_title_label.text = "Dungeon Failed"
		_title_label.modulate = Color(1, 0.5, 0.5)
		_gold_label.text = ""
		_rep_label.text = "Reputation: -20"
		_bp_label.text = ""


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.14)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_top)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 40)
	vbox.add_child(_title_label)

	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 28)
	_gold_label.modulate = Color(1, 0.84, 0)
	vbox.add_child(_gold_label)

	_rep_label = Label.new()
	_rep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rep_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_rep_label)

	_bp_label = Label.new()
	_bp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bp_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_bp_label)

	var spacer_mid := Control.new()
	spacer_mid.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(spacer_mid)

	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.add_theme_font_size_override("font_size", 28)
	continue_btn.custom_minimum_size = Vector2(400, 80)
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_btn.pressed.connect(func(): EventBus.dungeon_summary_dismissed.emit())
	vbox.add_child(continue_btn)

	var spacer_bot := Control.new()
	spacer_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bot)

	var main_node := get_tree().root.find_child("Main", true, false)
	var data: Dictionary = {}
	if main_node and main_node.pending_dungeon_summary != null:
		data = main_node.pending_dungeon_summary
	display_results(data)
