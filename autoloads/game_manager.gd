extends Node

signal gold_changed(new_amount: int)
signal shop_xp_changed(xp: int)
signal shop_level_changed(level: int)
signal blueprint_added(bp_id: String)
signal upgrade_level_changed(upgrade_id: String, level: int)
signal reagent_count_changed(id: String, count: int)
signal grid_size_changed(cols: int, rows: int)

const DEFAULT_GOLD := 50
const SAVE_VERSION := 7
const DEFAULT_DESPAWN_TIME := 12.0
const DEFAULT_CRATE_COST_MULTIPLIER := 1.0
const DEFAULT_SHELF_SLOTS := 0
const DEFAULT_ORDER_PRICE_MULTIPLIER := 1.0

var debug_mode: bool = false
var gold: int = DEFAULT_GOLD
# Never decreases; the shop level is derived from it (ShopRulesDefinition).
var shop_xp: int = 0
var unlocked_blueprints: Array[String] = []
var reagent_inventory: Dictionary = {}
# Upgrade id -> level bought; an id that's absent is level 0.
var upgrade_levels: Dictionary = {}
var shop_board_state: Array = []
var shop_shelf_state: Array = []
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


# XP never goes down: a rejection only breaks the streak. One
# shop_level_changed per level crossed, so a gain that skips levels still
# announces each one.
func add_shop_xp(amount: int) -> void:
	if amount <= 0:
		return
	var old_level := get_shop_level()
	shop_xp += amount
	shop_xp_changed.emit(shop_xp)
	for level in range(old_level + 1, get_shop_level() + 1):
		shop_level_changed.emit(level)


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


func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrade_levels.get(upgrade_id, 0))


func raise_upgrade_level(upgrade_id: String) -> void:
	var level := get_upgrade_level(upgrade_id) + 1
	upgrade_levels[upgrade_id] = level
	upgrade_level_changed.emit(upgrade_id, level)


func record_session_played() -> void:
	sessions_played += 1


# Fixed for a given run and session number, so the next session can be
# previewed in prep. A crash mid-session deals the same customers on replay,
# unless shop XP (saved mid-session) crossed a level that unlocks an
# archetype.
func get_session_seed() -> int:
	return hash([run_seed, sessions_played])


func get_shop_level() -> int:
	return DefinitionLibrary.get_shop_rules().level_for_xp(shop_xp)


func meets_level(min_shop_level: int) -> bool:
	return get_shop_level() >= min_shop_level


func get_despawn_time() -> float:
	return _purchased_upgrade_value("despawn_time", DEFAULT_DESPAWN_TIME)


func get_crate_discount() -> float:
	return _purchased_upgrade_value("crate_discount", DEFAULT_CRATE_COST_MULTIPLIER)


func get_shelf_slots() -> int:
	return int(_purchased_upgrade_value("shelf_slots", DEFAULT_SHELF_SLOTS))


func get_order_price_multiplier() -> float:
	return _purchased_upgrade_value("order_price", DEFAULT_ORDER_PRICE_MULTIPLIER)


# How many customers the prep forecast reveals; 0 means every one.
func get_forecast_customers() -> int:
	return int(_purchased_upgrade_value("forecast_detail", DefinitionLibrary.get_shop_rules().forecast_customers))


# The value at the bought level of the track with this effect, else the
# default. The level is capped at the track's length in case content shrank.
func _purchased_upgrade_value(effect: String, default: float) -> float:
	for upgrade in DefinitionLibrary.get_all_upgrades():
		if upgrade.effect != effect:
			continue
		var level := mini(get_upgrade_level(upgrade.id), upgrade.max_level())
		if level > 0:
			return upgrade.levels[level - 1].value
	return default


func serialize() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"gold": gold,
		"shop_xp": shop_xp,
		"unlocked_blueprints": unlocked_blueprints,
		"reagent_inventory": reagent_inventory,
		"upgrade_levels": upgrade_levels,
		"shop_board_state": shop_board_state,
		"shop_shelf_state": shop_shelf_state,
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
	if not _is_number(data.get("shop_xp")): return false
	if not (data.get("unlocked_blueprints") is Array): return false
	if not (data.get("reagent_inventory") is Dictionary): return false
	if not _is_valid_upgrade_levels(data.get("upgrade_levels")): return false
	if not _is_valid_board_state(data.get("shop_board_state")): return false
	if not _is_valid_board_state(data.get("shop_shelf_state")): return false
	if not _is_valid_board_state(data.get("dungeon_board_state")): return false
	if not _is_number(data.get("grid_cols")): return false
	if not _is_number(data.get("grid_rows")): return false
	if not _is_number(data.get("run_seed")): return false
	if not _is_number(data.get("sessions_played")): return false
	return true


# Upgrade id -> level; the level is a number (JSON makes it a float).
static func _is_valid_upgrade_levels(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for level: Variant in value.values():
		if not _is_number(level):
			return false
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
	shop_xp = int(data.get("shop_xp", 0))
	unlocked_blueprints.assign(data.get("unlocked_blueprints", []))
	reagent_inventory = data.get("reagent_inventory", {})
	upgrade_levels = {}
	var saved_levels: Dictionary = data.get("upgrade_levels", {})
	for upgrade_id: String in saved_levels:
		upgrade_levels[upgrade_id] = int(saved_levels[upgrade_id])
	shop_board_state = data.get("shop_board_state", [])
	shop_shelf_state = data.get("shop_shelf_state", [])
	dungeon_board_state = data.get("dungeon_board_state", [])
	grid_cols = data.get("grid_cols", 5)
	grid_rows = data.get("grid_rows", 5)
	run_seed = int(data["run_seed"]) if data.has("run_seed") else randi()
	sessions_played = int(data.get("sessions_played", 0))
	seen_intro = data.get("seen_intro", false)
	gold_changed.emit(gold)
	shop_xp_changed.emit(shop_xp)
	grid_size_changed.emit(grid_cols, grid_rows)
