extends Control

var _gold_label: Label
var _rep_label: Label


func _ready() -> void:
	_gold_label = Label.new()
	_gold_label.text = "Gold: %d" % GameManager.gold
	_gold_label.add_theme_font_size_override("font_size", 24)
	_gold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gold_label)

	_rep_label = Label.new()
	_rep_label.text = "Rep: %d" % GameManager.reputation_points
	_rep_label.position = Vector2(300, 0)
	_rep_label.add_theme_font_size_override("font_size", 24)
	_rep_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rep_label)

	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.reputation_changed.connect(_on_reputation_changed)


func _on_gold_changed(new_amount: int) -> void:
	_gold_label.text = "Gold: %d" % new_amount


func _on_reputation_changed(new_points: int) -> void:
	_rep_label.text = "Rep: %d" % new_points
