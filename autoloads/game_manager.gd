extends Node

signal gold_changed(new_amount: int)
signal reputation_changed(new_points: int)
signal reputation_level_changed(level: String)
signal blueprint_added(bp_id: String)
signal upgrade_added(upgrade_id: String)
signal reagent_count_changed(id: String, count: int)
signal grid_size_changed(cols: int, rows: int)

const DEFAULT_GOLD := 50
const SAVE_VERSION := 5
const DEFAULT_DESPAWN_TIME := 12.0
const DEFAULT_CRATE_COST_MULTIPLIER := 1.0

var debug_mode: bool = false
var gold: int = DEFAULT_GOLD
var reputation_points: int = 0
var unlocked_blueprints: Array[String] = []
var reagent_inventory: Dictionary = {}
var purchased_upgrades: Array[String] = []
var shop_board_state: Array = []
var dungeon_board_state: Array = []
var grid_cols: int = 5
var grid_rows: int = 5
# Rolled once per new game; with sessions_played it seeds each shop session.
# sessions_played also gates the ad grace period, so it counts completed sessions only.
var run_seed: int = 0
var sessions_played: int = 0
# UI-state flag, not core progression. Optional in the save: is_valid_save()
# does NOT check it, so older saves lacking the field load with false.
var seen_intro: bool = false


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func deduct_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func add_reputation(points: int) -> void:
	var old_level := get_reputation_level()
	reputation_points = maxi(reputation_points + points, 0)
	reputation_changed.emit(reputation_points)
	var new_level := get_reputation_level()
	if new_level != old_level:
		reputation_level_changed.emit(new_level)


func add_blueprint(bp_id: String) -> void:
	if bp_id in unlocked_blueprints:
		return
	unlocked_blueprints.append(bp_id)
	blueprint_added.emit(bp_id)


func add_reagent(reagent_id: String, count: int) -> void:
	if reagent_inventory.has(reagent_id):
		reagent_inventory[reagent_id] += count
	else:
		reagent_inventory[reagent_id] = count
	reagent_count_changed.emit(reagent_id, reagent_inventory[reagent_id])


func consume_reagent(reagent_id: String) -> bool:
	if not reagent_inventory.has(reagent_id) or reagent_inventory[reagent_id] <= 0:
		return false
	reagent_inventory[reagent_id] -= 1
	reagent_count_changed.emit(reagent_id, reagent_inventory[reagent_id])
	return true


func add_upgrade(upgrade_id: String) -> void:
	purchased_upgrades.append(upgrade_id)
	upgrade_added.emit(upgrade_id)


func record_session_played() -> void:
	sessions_played += 1


# Fixed for a given run and session number, so the next session can be
# previewed in prep. A crash mid-session deals the same customers on replay,
# unless reputation_points (saved mid-session) crossed an archetype's
# reputation_required and changed the eligible pool.
func get_session_seed() -> int:
	return hash([run_seed, sessions_played])


func get_reputation_level() -> String:
	if reputation_points >= 300:
		return "high"
	if reputation_points >= 100:
		return "mid"
	return "low"


func is_dungeon_unlocked(dungeon: DungeonDefinition) -> bool:
	return reputation_points >= dungeon.reputation_required


func get_despawn_time() -> float:
	return _purchased_upgrade_value("despawn_time", DEFAULT_DESPAWN_TIME)


func get_crate_discount() -> float:
	return _purchased_upgrade_value("crate_discount", DEFAULT_CRATE_COST_MULTIPLIER)


# The value of the first purchased upgrade with this effect, else the default.
func _purchased_upgrade_value(effect: String, default: float) -> float:
	for upgrade_id in purchased_upgrades:
		var upgrade := DefinitionLibrary.get_upgrade(upgrade_id)
		if upgrade != null and upgrade.effect == effect:
			return upgrade.value
	return default


func serialize() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"gold": gold,
		"reputation_points": reputation_points,
		"unlocked_blueprints": unlocked_blueprints,
		"reagent_inventory": reagent_inventory,
		"purchased_upgrades": purchased_upgrades,
		"shop_board_state": shop_board_state,
		"dungeon_board_state": dungeon_board_state,
		"grid_cols": grid_cols,
		"grid_rows": grid_rows,
		"run_seed": run_seed,
		"sessions_played": sessions_played,
		"seen_intro": seen_intro,
	}


# Atomic save-schema check, called by SaveManager before deserializing.
# Any single bad field makes the whole save untrustworthy -> CORRUPT.
# Note: JSON round-trips whole numbers as floats, so numeric fields accept
# int or float (but not bool, which is technically an int subtype in GDScript).
func is_valid_save(data: Dictionary) -> bool:
	if not _is_number(data.get("version")) or int(data.get("version")) != SAVE_VERSION:
		return false
	if not _is_number(data.get("gold")): return false
	if not _is_number(data.get("reputation_points")): return false
	if not (data.get("unlocked_blueprints") is Array): return false
	if not (data.get("reagent_inventory") is Dictionary): return false
	if not (data.get("purchased_upgrades") is Array): return false
	if not _is_valid_board_state(data.get("shop_board_state")): return false
	if not _is_valid_board_state(data.get("dungeon_board_state")): return false
	if not _is_number(data.get("grid_cols")): return false
	if not _is_number(data.get("grid_rows")): return false
	if not _is_number(data.get("run_seed")): return false
	if not _is_number(data.get("sessions_played")): return false
	return true


# Board entries are {col, row, item_id}; item data is rebuilt from the catalog.
static func _is_valid_board_state(value: Variant) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if not entry is Dictionary:
			return false
		if not _is_number(entry.get("col")) or not _is_number(entry.get("row")):
			return false
		if not entry.get("item_id") is String:
			return false
	return true


# True for int or float, but not bool (GDScript bools are int subtypes, so the
# explicit exclusion matters — a saved `"gold": true` must not pass validation).
static func _is_number(value: Variant) -> bool:
	if value is bool:
		return false
	return value is int or value is float


func deserialize(data: Dictionary) -> void:
	gold = data.get("gold", DEFAULT_GOLD)
	reputation_points = data.get("reputation_points", 0)
	unlocked_blueprints.assign(data.get("unlocked_blueprints", []))
	reagent_inventory = data.get("reagent_inventory", {})
	purchased_upgrades.assign(data.get("purchased_upgrades", []))
	shop_board_state = data.get("shop_board_state", [])
	dungeon_board_state = data.get("dungeon_board_state", [])
	grid_cols = data.get("grid_cols", 5)
	grid_rows = data.get("grid_rows", 5)
	run_seed = int(data["run_seed"]) if data.has("run_seed") else randi()
	sessions_played = int(data.get("sessions_played", 0))
	seen_intro = data.get("seen_intro", false)
	gold_changed.emit(gold)
	reputation_changed.emit(reputation_points)
	grid_size_changed.emit(grid_cols, grid_rows)
