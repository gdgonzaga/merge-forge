extends TestBase

# C3 — Save integrity tests. Covers MISSING / CORRUPT / OK status, quarantine,
# version field, and atomic schema validation. Each test writes/cleans real files
# under user:// (inherent to testing save/load); before/after_test keep it hermetic.

const SAVE_PATH := "user://save_data.json"


func before_test() -> void:
	super.before_test()
	_clean_save_dir()


func after_test() -> void:
	_clean_save_dir()
	super.after_test()


func _clean_save_dir() -> void:
	# Remove the save plus any quarantined .corrupt.*.json backups.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	var dir := DirAccess.open("user://")
	if dir:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if name.begins_with("save_data.corrupt") and name.ends_with(".json"):
				DirAccess.remove_absolute("user://%s" % name)
			name = dir.get_next()


func _write_save_file(text: String) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	assert(f != null, "could not open %s for write" % SAVE_PATH)
	f.store_string(text)
	f.close()


# --- load: MISSING ---

func test_load_missing_returns_MISSING() -> void:
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.MISSING)
	assert_dict(r["data"]).is_empty()


# --- load: CORRUPT ---

func test_load_corrupt_json_returns_CORRUPT_and_quarantines() -> void:
	_write_save_file("{not valid json")
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)
	# Quarantine: original gone, a .corrupt.*.json backup exists.
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_false()
	assert_bool(_has_quarantine_backup()).is_true()


func test_load_non_dict_top_level_returns_CORRUPT() -> void:
	_write_save_file("[1, 2, 3]")
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_bad_field_type_returns_CORRUPT() -> void:
	# Atomic policy: one bad field -> whole save is CORRUPT.
	var bad := GameManager.serialize()
	bad["gold"] = "oops"  # int expected
	_write_save_file(JSON.stringify(bad))
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_wrong_version_returns_CORRUPT() -> void:
	var v := GameManager.serialize()
	v["version"] = 99
	_write_save_file(JSON.stringify(v))
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_bool_in_numeric_field_returns_CORRUPT() -> void:
	# GDScript bools are int subtypes; the validator must still reject them
	# (a saved "gold": true must not pass as a number).
	var bad := GameManager.serialize()
	bad["gold"] = true
	_write_save_file(JSON.stringify(bad))
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


# --- load: OK ---

func test_save_then_load_returns_OK_and_round_trips() -> void:
	GameManager.add_gold(30)
	GameManager.add_blueprint("bp_x")
	GameManager.add_reagent("fire", 4)
	var before := GameManager.serialize()

	SaveManager.save_game()
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.OK)
	# JSON round-trips whole numbers to floats and drops typed-array tags, so we
	# compare logical values field-by-field rather than the whole dict by identity.
	var after: Dictionary = r["data"]
	assert_int(int(after["gold"])).is_equal(int(before["gold"]))
	assert_int(int(after["reputation_points"])).is_equal(int(before["reputation_points"]))
	assert_int(int(after["grid_cols"])).is_equal(int(before["grid_cols"]))
	assert_int(int(after["grid_rows"])).is_equal(int(before["grid_rows"]))
	assert_int(int(after["version"])).is_equal(int(before["version"]))
	# Reagent values are also numbers -> compare as int.
	assert_int(int(after["reagent_inventory"]["fire"])).is_equal(4)
	# Arrays lose their String type tag through JSON but keep contents/order.
	assert_array(after["unlocked_blueprints"]).is_equal(["bp_x"])


# --- serialize: version field ---

func test_serialize_includes_version() -> void:
	var s := GameManager.serialize()
	assert(s.has("version"))
	assert_int(int(s["version"])).is_equal(GameManager.SAVE_VERSION)


# --- helpers ---

func _has_quarantine_backup() -> bool:
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("save_data.corrupt") and name.ends_with(".json"):
			return true
		name = dir.get_next()
	return false
