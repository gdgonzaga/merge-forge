extends VBoxContainer

@onready var sprite: TextureRect = $Sprite
@onready var hp_bar: ProgressBar = $HPBar


func update_hp(current: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current
	var ratio := float(current) / float(max(1, max_hp))
	hp_bar.modulate = Color(0.2, 0.8, 0.2) if ratio > 0.6 else Color(0.9, 0.7, 0.2) if ratio > 0.3 else Color(0.9, 0.2, 0.2)
