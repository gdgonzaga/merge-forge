extends TestBase

# C3 — Save integrity tests. Covers MISSING / CORRUPT / OK status, quarantine,
# version field, and atomic schema validation. Each test writes/cleans real files
# under TestBase.TEST_SAVE_DIR (SaveManager is redirected there before each test
# and the dir is removed after), so the real user://save_data.json is never touched.


func _write_save_file(text: String) -> void:
	var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	assert(f != null, "could not open %s for write" % SaveManager.save_path)
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
	assert_bool(FileAccess.file_exists(SaveManager.save_path)).is_false()
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


func test_load_board_entry_without_item_id_returns_CORRUPT() -> void:
	# Board entries carry an item id, never the item's data.
	var bad := GameManager.serialize()
	bad["shop_board_state"] = [{"col": 0, "row": 0, "item": {"name": "Ore"}}]
	_write_save_file(JSON.stringify(bad))
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_board_entry_with_non_numeric_position_returns_CORRUPT() -> void:
	var bad := GameManager.serialize()
	bad["dungeon_board_state"] = [{"col": "a", "row": 0, "item_id": "ore"}]
	_write_save_file(JSON.stringify(bad))
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


func test_board_state_entries_survive_save_and_load() -> void:
	GameManager.shop_board_state = [{"col": 1, "row": 2, "item_id": "ore"}]
	SaveManager.save_game()
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.OK)
	var entry: Dictionary = r["data"]["shop_board_state"][0]
	assert_int(int(entry["col"])).is_equal(1)
	assert_int(int(entry["row"])).is_equal(2)
	assert_str(entry["item_id"]).is_equal("ore")


# --- load: OK ---

func test_save_then_load_returns_OK_and_round_trips() -> void:
	GameManager.add_gold(30)
	GameManager.add_shop_xp(70)
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
	assert_int(int(after["shop_xp"])).is_equal(int(before["shop_xp"]))
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
	var dir := DirAccess.open(TEST_SAVE_DIR)
	if dir == null:
		return false
	for file_name in dir.get_files():
		if file_name.begins_with(SaveManager.CORRUPT_PREFIX) and file_name.ends_with(".json"):
			return true
	return false


func test_load_without_run_seed_returns_CORRUPT() -> void:
	var bad := GameManager.serialize()
	bad.erase("run_seed")
	_write_save_file(JSON.stringify(bad))
	assert_int(SaveManager.load_game_ex()["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_bool_sessions_played_returns_CORRUPT() -> void:
	var bad := GameManager.serialize()
	bad["sessions_played"] = true
	_write_save_file(JSON.stringify(bad))
	assert_int(SaveManager.load_game_ex()["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_without_shop_xp_returns_CORRUPT() -> void:
	var bad := GameManager.serialize()
	bad.erase("shop_xp")
	_write_save_file(JSON.stringify(bad))
	assert_int(SaveManager.load_game_ex()["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)
