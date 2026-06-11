extends Control

@onready var _gold_label: Label = $HBox/GoldLabel
@onready var _rep_label: Label = $HBox/RepLabel


func _ready() -> void:
	_gold_label.text = "Gold: %d" % GameManager.gold
	_rep_label.text = "Rep: %d" % GameManager.reputation_points
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.reputation_changed.connect(_on_reputation_changed)


func _on_gold_changed(new_amount: int) -> void:
	_gold_label.text = "Gold: %d" % new_amount


func _on_reputation_changed(new_points: int) -> void:
	_rep_label.text = "Rep: %d" % new_points
