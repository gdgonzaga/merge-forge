extends Node

signal gold_changed(new_amount: int)
signal reputation_changed(new_points: int)
signal reputation_level_changed(level: String)
signal blueprint_added(bp_id: String)
signal upgrade_added(upgrade_id: String)
signal reagent_count_changed(id: String, count: int)
signal grid_size_changed(cols: int, rows: int)

const DEFAULT_GOLD := 50

var debug_mode: bool = false
var gold: int = DEFAULT_GOLD
var reputation_points: int = 0
var unlocked_blueprints: Array[String] = []
var reagent_inventory: Dictionary = {}
var purchased_upgrades: Array[String] = []
var shop_board_state: Array = []
var grid_cols: int = 5
var grid_rows: int = 5


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


func get_reputation_level() -> String:
	if reputation_points >= 300:
		return "high"
	if reputation_points >= 100:
		return "mid"
	return "low"


func is_dungeon_unlocked() -> bool:
	return reputation_points >= 150


func get_despawn_time() -> float:
	return 18.0 if "slow_timer" in purchased_upgrades else 12.0


func get_crate_discount() -> float:
	return 0.8 if "crate_discount" in purchased_upgrades else 1.0


func serialize() -> Dictionary:
	return {
		"gold": gold,
		"reputation_points": reputation_points,
		"unlocked_blueprints": unlocked_blueprints,
		"reagent_inventory": reagent_inventory,
		"purchased_upgrades": purchased_upgrades,
		"shop_board_state": shop_board_state,
		"grid_cols": grid_cols,
		"grid_rows": grid_rows,
	}


func deserialize(data: Dictionary) -> void:
	gold = data.get("gold", DEFAULT_GOLD)
	reputation_points = data.get("reputation_points", 0)
	unlocked_blueprints.assign(data.get("unlocked_blueprints", []))
	reagent_inventory = data.get("reagent_inventory", {})
	purchased_upgrades.assign(data.get("purchased_upgrades", []))
	shop_board_state = data.get("shop_board_state", [])
	grid_cols = data.get("grid_cols", 5)
	grid_rows = data.get("grid_rows", 5)
	gold_changed.emit(gold)
	reputation_changed.emit(reputation_points)
	grid_size_changed.emit(grid_cols, grid_rows)
