extends Control

@onready var _gold_label: Label = $VBox/GoldLabel
@onready var _xp_label: Label = $VBox/XpLabel
@onready var _sold_label: Label = $VBox/SoldLabel
@onready var _fulfilled_label: Label = $VBox/FulfilledLabel
@onready var _rejected_label: Label = $VBox/RejectedLabel
@onready var _level_up_panel: VBoxContainer = $VBox/LevelUpPanel

var _target_gold: int = 0
var _countup_tween: Tween


func _ready() -> void:
	$VBox/ContinueBtn.pressed.connect(func(): EventBus.session_summary_dismissed.emit())
	var summary_data: Dictionary = {}
	var main_node := get_tree().root.find_child("Main", true, false)
	if main_node and main_node.pending_summary != null:
		summary_data = main_node.pending_summary
	display_summary(summary_data)


func display_summary(data: Dictionary) -> void:
	_target_gold = data.get("gold_earned", 0)
	_sold_label.text = "Items Sold: %d" % data.get("items_sold", 0)
	_fulfilled_label.text = "Fulfilled: %d" % data.get("fulfilled", 0)
	_rejected_label.text = "Rejected: %d" % data.get("rejected", 0)
	_xp_label.text = "XP Earned: %d" % data.get("xp_earned", 0)
	_level_up_panel.setup(data.get("level_before", 1), data.get("level_after", 1))

	if _target_gold > 0:
		_gold_label.text = "Gold Earned: 0"
		_countup_tween = create_tween()
		_countup_tween.tween_method(_set_gold_count, 0, _target_gold, 1.5)
		_countup_tween.tween_callback(func(): _gold_label.text = "Gold Earned: %d" % _target_gold)
	else:
		_gold_label.text = "Gold Earned: 0"


func _set_gold_count(value: int) -> void:
	_gold_label.text = "Gold Earned: %d" % value
