extends Node

signal save_completed()
signal save_loaded(data: Dictionary)

enum LoadStatus { OK, MISSING, CORRUPT }

const SAVE_PATH := "user://save_data.json"
const CORRUPT_PREFIX := "save_data.corrupt"


func _ready() -> void:
	EventBus.save_requested.connect(_on_save_requested)


func save_game() -> void:
	var data := GameManager.serialize()
	var json_text := JSON.stringify(data, "\t")
	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] could not open tmp for write: %s" % tmp_path)
		return
	file.store_string(json_text)
	file.close()
	# Remove any prior save first (rename may refuse to overwrite on some platforms).
	# It's fine if the file doesn't exist yet.
	DirAccess.remove_absolute(SAVE_PATH)
	var rn_err := DirAccess.rename_absolute(tmp_path, SAVE_PATH)
	if rn_err != OK:
		push_error("[SaveManager] save rename failed: %s (tmp left at %s)" % [str(rn_err), tmp_path])
		DirAccess.remove_absolute(tmp_path)
		return
	save_completed.emit()


# Returns { "status": LoadStatus, "data": Dictionary }.
# On CORRUPT, quarantines the file (renames it to a timestamped .corrupt.*.json)
# so a subsequent save can't overwrite the only copy of the player's progress.
func load_game_ex() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"status": LoadStatus.MISSING, "data": {}}

	var text := _read_text(SAVE_PATH)
	if text == "":
		_quarantine()
		push_error("[SaveManager] corrupt save (unreadable/empty): %s" % SAVE_PATH)
		return {"status": LoadStatus.CORRUPT, "data": {}}

	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		_quarantine()
		push_error("[SaveManager] corrupt save (parse failed): %s" % SAVE_PATH)
		return {"status": LoadStatus.CORRUPT, "data": {}}

	var data: Dictionary = json.data
	if not GameManager.is_valid_save(data):
		_quarantine()
		push_error("[SaveManager] corrupt save (schema/version invalid): %s" % SAVE_PATH)
		return {"status": LoadStatus.CORRUPT, "data": {}}

	save_loaded.emit(data)
	return {"status": LoadStatus.OK, "data": data}


# Backwards-compatible wrapper for existing callers (returns just the data).
func load_game() -> Dictionary:
	return load_game_ex()["data"]


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


# Rename the corrupt save to a timestamped backup so it's preserved (and so a
# subsequent save can't overwrite it). The collision guard handles two corruptions
# happening within the same wall-clock second.
func _quarantine() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d := Time.get_datetime_dict_from_system()
	var ts := "%04d%02d%02d-%02d%02d%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"], d["second"]]
	var target := "user://%s.%s.json" % [CORRUPT_PREFIX, ts]
	var suffix := 2
	while FileAccess.file_exists(target):
		target = "user://%s.%s_%d.json" % [CORRUPT_PREFIX, ts, suffix]
		suffix += 1
	var err := DirAccess.rename_absolute(SAVE_PATH, target)
	if err != OK:
		push_error("[SaveManager] failed to quarantine corrupt save: %s" % str(err))


func _on_save_requested() -> void:
	save_game()
