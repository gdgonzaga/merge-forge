extends Control

@onready var _gold_label: Label = $HBox/GoldLabel
@onready var _level_label: Label = $HBox/LevelLabel


func _ready() -> void:
	_gold_label.text = "Gold: %d" % GameManager.gold
	_level_label.text = "Lv %d" % GameManager.get_shop_level()
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.shop_xp_changed.connect(_on_shop_xp_changed)


func _on_gold_changed(new_amount: int) -> void:
	_gold_label.text = "Gold: %d" % new_amount


func _on_shop_xp_changed(_xp: int) -> void:
	_level_label.text = "Lv %d" % GameManager.get_shop_level()
