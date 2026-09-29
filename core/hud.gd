extends Control

@onready var _gold_label: Label = $HBox/GoldLabel
@onready var _level_label: Label = $HBox/LevelLabel
@onready var _xp_bar: ProgressBar = $HBox/XpBar


func _ready() -> void:
	_gold_label.text = "%d" % GameManager.gold
	_refresh_level()
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.shop_xp_changed.connect(_on_shop_xp_changed)


func _on_gold_changed(new_amount: int) -> void:
	_gold_label.text = "%d" % new_amount


func _on_shop_xp_changed(_xp: int) -> void:
	_refresh_level()


func _refresh_level() -> void:
	var rules := DefinitionLibrary.get_shop_rules()
	var level := GameManager.get_shop_level()
	_level_label.text = "Lv %d" % level
	if level >= rules.max_level:
		# At the cap the bar stays full; XP past it has nowhere to go.
		_xp_bar.max_value = 1
		_xp_bar.value = 1
		return
	var start := rules.xp_for_level(level)
	_xp_bar.max_value = rules.xp_for_level(level + 1) - start
	_xp_bar.value = GameManager.shop_xp - start
