extends Control

@onready var _title_label: Label = $VBox/TitleLabel
@onready var _gold_label: Label = $VBox/GoldLabel
@onready var _xp_label: Label = $VBox/XpLabel
@onready var _bp_label: Label = $VBox/BpLabel

var _target_gold: int = 0
var _countup_tween: Tween


func _ready() -> void:
	$VBox/ContinueBtn.pressed.connect(func(): EventBus.dungeon_summary_dismissed.emit())
	var main_node := get_tree().root.find_child("Main", true, false)
	var data: Dictionary = {}
	if main_node and main_node.pending_dungeon_summary != null:
		data = main_node.pending_dungeon_summary
	display_results(data)


func display_results(data: Dictionary) -> void:
	var cleared: bool = data.get("cleared", false)
	if cleared:
		_title_label.text = "Dungeon Cleared!"
		_title_label.modulate = Color(0.5, 1, 0.5)
		_target_gold = data.get("gold_reward", 0)
		if _target_gold > 0:
			_gold_label.text = "Gold: +0"
			_countup_tween = create_tween()
			_countup_tween.tween_method(_set_gold_count, 0, _target_gold, 1.5)
			_countup_tween.tween_callback(func(): _gold_label.text = "Gold: +%d" % _target_gold)
		else:
			_gold_label.text = "Gold: +0"
		_xp_label.text = "XP: +%d" % int(data.get("xp_gained", 0))
		var bp = data.get("blueprint_reward")
		if bp and bp != null:
			_bp_label.text = "Blueprint: %s" % str(bp)
		else:
			_bp_label.text = ""
	else:
		_title_label.text = "Dungeon Failed"
		_title_label.modulate = Color(1, 0.5, 0.5)
		_gold_label.text = ""
		_xp_label.text = "No XP"
		_bp_label.text = ""


func _set_gold_count(value: int) -> void:
	_gold_label.text = "Gold: +%d" % value
