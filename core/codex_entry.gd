extends VBoxContainer

# One codex item: its sprite and name once made, with a star per quality
# reached; a nameless black silhouette until then, so a town the player
# hasn't visited gives nothing away.

const UNKNOWN_NAME := "???"

var item_id: String = ""

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %NameLabel
@onready var _stars: Control = %Stars


# `best_quality` is -1 for an item not made yet.
func show_item(item: ItemDefinition, best_quality: int) -> void:
	item_id = item.id
	var made := best_quality >= 0
	_icon.texture = item.sprite
	_icon.modulate = Color.WHITE if made else Color.BLACK
	_name.text = item.name if made else UNKNOWN_NAME
	_stars.set_quality(best_quality + 1 if made else 0)
