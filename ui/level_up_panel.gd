extends VBoxContainer

# "Level N!" and what it unlocked. Shared by the shop and dungeon summaries.

@onready var _banner: Label = %LevelBanner
@onready var _list: Label = %UnlockList


func setup(old_level: int, new_level: int) -> void:
	visible = new_level > old_level
	if not visible:
		return
	_banner.text = "Level %d!" % new_level
	var names: PackedStringArray = []
	for definition in DefinitionLibrary.get_unlocks_between(old_level, new_level):
		names.append("Unlocked: %s" % definition.name)
	_list.text = "\n".join(names)
	_list.visible = not names.is_empty()
