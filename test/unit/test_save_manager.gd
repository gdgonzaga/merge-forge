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


func test_load_previous_save_version_returns_CORRUPT() -> void:
	var old_save := GameManager.serialize()
	old_save["version"] = 9
	_write_save_file(JSON.stringify(old_save))
	assert_int(SaveManager.load_game_ex()["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


func test_loyalty_and_contracts_survive_save_and_load() -> void:
	GameManager.add_loyalty("__regular", 7)
	GameManager.active_contracts = [{"id": "__contract", "delivered": {"__ore": 2}, "sessions_left": 3}]
	SaveManager.save_game()
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.OK)
	reset_game_state()
	GameManager.deserialize(r["data"])
	assert_int(GameManager.get_loyalty("__regular")).is_equal(7)
	assert_array(GameManager.active_contracts).is_equal([{"id": "__contract", "delivered": {"__ore": 2}, "sessions_left": 3}])


func test_load_without_loyalty_or_contracts_returns_CORRUPT() -> void:
	for field: String in ["regular_loyalty", "active_contracts"]:
		var bad := GameManager.serialize()
		bad.erase(field)
		_write_save_file(JSON.stringify(bad))
		assert_int(SaveManager.load_game_ex()["status"]).override_failure_message("no %s" % field) \
			.is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_bad_loyalty_returns_CORRUPT() -> void:
	for bad_value: Variant in [-1, 1.5, true, "3"]:
		var bad := GameManager.serialize()
		bad["regular_loyalty"] = {"__regular": bad_value}
		_write_save_file(JSON.stringify(bad))
		assert_int(SaveManager.load_game_ex()["status"]).override_failure_message("loyalty %s" % str(bad_value)) \
			.is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_bad_contract_entry_returns_CORRUPT() -> void:
	var bad_values: Array = [
		{"__contract": 1},
		["__contract"],
		[{"delivered": {}, "sessions_left": 2}],
		[{"id": 5, "delivered": {}, "sessions_left": 2}],
		[{"id": "__contract", "delivered": [], "sessions_left": 2}],
		[{"id": "__contract", "delivered": {"__ore": 1.5}, "sessions_left": 2}],
		[{"id": "__contract", "delivered": {"__ore": -1}, "sessions_left": 2}],
		[{"id": "__contract", "delivered": {}}],
		[{"id": "__contract", "delivered": {}, "sessions_left": 0}],
		[{"id": "__contract", "delivered": {}, "sessions_left": true}],
	]
	for bad_value: Variant in bad_values:
		var bad := GameManager.serialize()
		bad["active_contracts"] = bad_value
		_write_save_file(JSON.stringify(bad))
		assert_int(SaveManager.load_game_ex()["status"]).override_failure_message("contracts %s" % str(bad_value)) \
			.is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_duplicate_active_contract_ids_returns_CORRUPT() -> void:
	var bad := GameManager.serialize()
	bad["active_contracts"] = [
		{"id": "__contract", "delivered": {}, "sessions_left": 2},
		{"id": "__contract", "delivered": {"__ore": 1}, "sessions_left": 1},
	]
	_write_save_file(JSON.stringify(bad))
	assert_int(SaveManager.load_game_ex()["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


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
	bad["dungeon_board_state"] = [{"col": "a", "row": 0, "item_id": "ore", "quality": 0}]
	_write_save_file(JSON.stringify(bad))
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_upgrade_level_that_is_not_a_number_returns_CORRUPT() -> void:
	var bad := GameManager.serialize()
	bad["upgrade_levels"] = {"__test_track": "two"}
	_write_save_file(JSON.stringify(bad))
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_upgrade_levels_that_are_not_a_dictionary_returns_CORRUPT() -> void:
	var bad := GameManager.serialize()
	bad["upgrade_levels"] = ["__test_track"]
	_write_save_file(JSON.stringify(bad))
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_negative_upgrade_level_returns_CORRUPT() -> void:
	var bad := GameManager.serialize()
	bad["upgrade_levels"] = {"__test_track": -1}
	_write_save_file(JSON.stringify(bad))
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_shelf_entry_without_item_id_returns_CORRUPT() -> void:
	var bad := GameManager.serialize()
	bad["shop_shelf_state"] = [{"col": 0, "row": 0}]
	_write_save_file(JSON.stringify(bad))
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_board_entry_without_quality_returns_CORRUPT() -> void:
	var bad := GameManager.serialize()
	bad["shop_board_state"] = [{"col": 0, "row": 0, "item_id": "ore"}]
	_write_save_file(JSON.stringify(bad))
	assert_int(SaveManager.load_game_ex()["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_board_entry_with_a_bad_quality_returns_CORRUPT() -> void:
	for quality: Variant in [3, -1, 1.5, "1", true]:
		var bad := GameManager.serialize()
		bad["dungeon_board_state"] = [{"col": 0, "row": 0, "item_id": "ore", "quality": quality}]
		_write_save_file(JSON.stringify(bad))
		assert_int(SaveManager.load_game_ex()["status"]).override_failure_message("quality %s" % str(quality)).is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_shelf_entry_with_a_bad_quality_returns_CORRUPT() -> void:
	var bad := GameManager.serialize()
	bad["shop_shelf_state"] = [{"col": 0, "row": 0, "item_id": "ore", "quality": 9}]
	_write_save_file(JSON.stringify(bad))
	assert_int(SaveManager.load_game_ex()["status"]).is_equal(SaveManager.LoadStatus.CORRUPT)


# JSON turns the level into a float; it must come back as the same level.
func test_upgrade_levels_and_shelf_survive_save_and_load() -> void:
	GameManager.upgrade_levels = {"__test_track": 2}
	GameManager.shop_shelf_state = [{"col": 1, "row": 0, "item_id": "ore", "quality": 0}]
	SaveManager.save_game()
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.OK)
	GameManager.deserialize(r["data"])
	assert_int(GameManager.get_upgrade_level("__test_track")).is_equal(2)
	assert_str(GameManager.shop_shelf_state[0]["item_id"]).is_equal("ore")


func test_board_state_entries_survive_save_and_load() -> void:
	GameManager.shop_board_state = [{"col": 1, "row": 2, "item_id": "ore", "quality": 1}]
	SaveManager.save_game()
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.OK)
	var entry: Dictionary = r["data"]["shop_board_state"][0]
	assert_int(int(entry["col"])).is_equal(1)
	assert_int(int(entry["row"])).is_equal(2)
	assert_str(entry["item_id"]).is_equal("ore")
	assert_int(int(entry["quality"])).is_equal(1)


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


# --- v10: town and Guild Charter progress ---

func test_charter_progress_survives_save_and_load() -> void:
	var far := TownDefinition.new()
	far.id = "__test_far"
	set_definition(DefinitionLibrary.towns, far)
	GameManager.current_town = "__test_far"
	GameManager.charters = 2
	GameManager.charter_points = 7
	GameManager.perk_levels = {"__perk": 1}
	GameManager.codex = {"__item": 2}
	GameManager.codex_stars_credited = 4
	GameManager.codex_families_credited.assign(["__family"])
	SaveManager.save_game()
	var r: Dictionary = SaveManager.load_game_ex()
	assert_int(r["status"]).is_equal(SaveManager.LoadStatus.OK)
	reset_game_state()
	GameManager.deserialize(r["data"])
	assert_str(GameManager.current_town).is_equal("__test_far")
	assert_int(GameManager.charters).is_equal(2)
	assert_int(GameManager.charter_points).is_equal(7)
	assert_dict(GameManager.perk_levels).is_equal({"__perk": 1})
	assert_dict(GameManager.codex).is_equal({"__item": 2})
	assert_int(GameManager.codex_stars_credited).is_equal(4)
	assert_array(GameManager.codex_families_credited).is_equal(["__family"])


func test_load_without_charter_fields_returns_CORRUPT() -> void:
	for field: String in ["current_town", "charters", "charter_points", "perk_levels", "codex", "codex_stars_credited", "codex_families_credited"]:
		var bad := GameManager.serialize()
		bad.erase(field)
		_write_save_file(JSON.stringify(bad))
		assert_int(SaveManager.load_game_ex()["status"]).override_failure_message("no %s" % field) \
			.is_equal(SaveManager.LoadStatus.CORRUPT)


func test_load_bad_charter_fields_returns_CORRUPT() -> void:
	var bad_values: Array = [
		["current_town", 5],
		["current_town", "__no_such_town"],
		["charters", -1],
		["charters", 1.5],
		["charter_points", true],
		["perk_levels", []],
		["perk_levels", {"__perk": -1}],
		["codex", []],
		["codex", {"__item": 3}],
		["codex", {"__item": 0.5}],
		["codex_stars_credited", -2],
		["codex_families_credited", "metal"],
		["codex_families_credited", [4]],
	]
	for pair: Array in bad_values:
		var bad := GameManager.serialize()
		bad[pair[0]] = pair[1]
		_write_save_file(JSON.stringify(bad))
		assert_int(SaveManager.load_game_ex()["status"]).override_failure_message("%s = %s" % [pair[0], str(pair[1])]) \
			.is_equal(SaveManager.LoadStatus.CORRUPT)
