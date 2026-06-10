extends Node

signal save_completed()
signal save_loaded(data: Dictionary)

const SAVE_PATH := "user://save_data.json"


func _ready() -> void:
	EventBus.save_requested.connect(_on_save_requested)


func save_game() -> void:
	var data := GameManager.serialize()
	var json_text := JSON.stringify(data, "\t")
	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		return
	file.store_string(json_text)
	file.close()
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.rename_absolute(tmp_path, SAVE_PATH)
	save_completed.emit()


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Dictionary = json.data if json.data is Dictionary else {}
	save_loaded.emit(data)
	return data


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _on_save_requested() -> void:
	save_game()
