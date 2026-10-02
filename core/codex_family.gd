extends VBoxContainer

# One family in the codex: how many of its items are made, whether finishing
# it has paid out, and an entry per item.

const ENTRY := preload("res://core/codex_entry.tscn")

var family: String = ""

@onready var _title: Label = %FamilyLabel
@onready var _status: Label = %StatusLabel
@onready var _grid: GridContainer = %Grid


func show_family(family_key: String, items: Array[ItemDefinition], status_text: String) -> void:
	family = family_key
	var made := 0
	for item in items:
		var entry: VBoxContainer = ENTRY.instantiate()
		_grid.add_child(entry)
		var best := int(GameManager.codex.get(item.id, -1))
		entry.show_item(item, best)
		if best >= 0:
			made += 1
	_title.text = "%s · %d/%d made" % [family_key.capitalize(), made, items.size()]
	_status.text = status_text
	_status.visible = not status_text.is_empty()
