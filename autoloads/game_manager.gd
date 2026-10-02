extends Node

signal gold_changed(new_amount: int)
signal shop_xp_changed(xp: int)
signal shop_level_changed(level: int)
signal blueprint_added(bp_id: String)
signal upgrade_level_changed(upgrade_id: String, level: int)
signal reagent_count_changed(id: String, count: int)
signal grid_size_changed(cols: int, rows: int)

const DEFAULT_GOLD := 50
const SAVE_VERSION := 10
const DEFAULT_DESPAWN_TIME := 12.0
const DEFAULT_CRATE_COST_MULTIPLIER := 1.0
const DEFAULT_SHELF_SLOTS := 0
const DEFAULT_ORDER_PRICE_MULTIPLIER := 1.0
const DEFAULT_CONTRACT_SLOTS := 0
const DEFAULT_XP_MULTIPLIER := 1.0
const DEFAULT_LOYALTY_MULTIPLIER := 1.0

# Kept across a Guild Charter. Every other save field goes back to its
# fresh-game default, so a field added later resets unless it's listed here.
const CHARTER_KEPT_FIELDS: Array[String] = [
	"sessions_played", "seen_intro", "charters", "charter_points",
	"perk_levels", "codex", "codex_stars_credited", "codex_families_credited",
]

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
# Regular's customer id -> loyalty points. Never decreases; only customers
# with a loyalty track earn points (ShopSession decides).
var regular_loyalty: Dictionary = {}
# Accepted contracts, oldest first: {id, delivered: {item_id: count},
# sessions_left}. An entry is removed when its contract completes or expires.
var active_contracts: Array = []
# UI-state flag, not core progression. Optional in the save: is_valid_save()
# does NOT check it, so older saves lacking the field load with false.
var seen_intro: bool = false
# The id of the town this run's shop is in (TownDefinition).
var current_town: String = ""
# Guild Charter progress. These survive a charter (CHARTER_KEPT_FIELDS).
var charters: int = 0
# Unspent points; a charter adds what it earns and takes what its picks cost.
var charter_points: int = 0
# Perk id -> level bought; an id that's absent is level 0.
var perk_levels: Dictionary = {}
# Item id -> the best quality a merge ever made it at. Only ever rises.
var codex: Dictionary = {}
# Codex stars and completed families a charter has already paid for.
var codex_stars_credited: int = 0
var codex_families_credited: Array[String] = []


func _ready() -> void:
	EventBus.merge_completed.connect(record_crafted)


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func deduct_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


# XP never goes down: a rejection only breaks the streak. The XP perk scales
# every gain, and the gain is returned so summaries report what was added.
# One shop_level_changed per level crossed, so a gain that skips levels still
# announces each one.
func add_shop_xp(amount: int) -> int:
	var gained := roundi(amount * get_xp_multiplier())
	if gained <= 0:
		return 0
	var old_level := get_shop_level()
	shop_xp += gained
	shop_xp_changed.emit(shop_xp)
	for level in range(old_level + 1, get_shop_level() + 1):
		shop_level_changed.emit(level)
	return gained


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


func get_current_town() -> TownDefinition:
	return DefinitionLibrary.get_town(current_town)


func get_loyalty(customer_id: String) -> int:
	return int(regular_loyalty.get(customer_id, 0))


# Loyalty never goes down, which is what makes each gift one-time. The
# loyalty perk scales every gain.
func add_loyalty(customer_id: String, points: int) -> void:
	var gained := roundi(points * get_loyalty_multiplier())
	if gained <= 0:
		return
	regular_loyalty[customer_id] = get_loyalty(customer_id) + gained


# The codex keeps the best quality each codex item was ever merged at. An id
# RecipeResolver.get_codex_items() doesn't list (a dungeon-drop-only item, e.g.
# the powder family) is ignored: the Codex tab never lists it, so it must
# never earn charter stars either.
func record_crafted(item_id: String, quality: int) -> void:
	if not _is_codex_item(item_id):
		return
	if quality > int(codex.get(item_id, -1)):
		codex[item_id] = quality


func _is_codex_item(item_id: String) -> bool:
	for item in RecipeResolver.get_codex_items():
		if item.id == item_id:
			return true
	return false


# One star per quality reached: Normal 1, Fine 2, Masterwork 3.
func get_codex_stars() -> int:
	var stars := 0
	for quality: int in codex.values():
		stars += quality + 1
	return stars


# Families whose every codex item has been made, sorted.
func get_completed_codex_families() -> Array[String]:
	var families := {}
	var missing := {}
	for item in RecipeResolver.get_codex_items():
		families[item.family] = true
		if not codex.has(item.id):
			missing[item.family] = true
	var complete: Array[String] = []
	for family: String in families:
		if not missing.has(family):
			complete.append(family)
	complete.sort()
	return complete


func can_found_charter() -> bool:
	return get_shop_level() >= DefinitionLibrary.get_shop_rules().charter_level


# `charters_required` counts the charter being founded.
func is_town_open(town: TownDefinition) -> bool:
	return town.charters_required <= charters + 1


func get_new_codex_stars() -> int:
	return maxi(get_codex_stars() - codex_stars_credited, 0)


func get_new_codex_families() -> Array[String]:
	var fresh: Array[String] = []
	for family in get_completed_codex_families():
		if not family in codex_families_credited:
			fresh.append(family)
	return fresh


# What founding a charter now would add to charter_points; 0 below the
# charter level.
func get_charter_points_earned() -> int:
	return DefinitionLibrary.get_shop_rules().charter_points(get_shop_level(), get_new_codex_stars(), get_new_codex_families().size())


func get_perk_level(perk_id: String) -> int:
	return int(perk_levels.get(perk_id, 0))


# Charter points for buying `picks` in order, one perk level per entry, on
# top of the levels owned. -1 when a pick names an unknown perk or goes past
# its max level.
func perk_purchase_cost(picks: Array[String]) -> int:
	var levels := {}
	var cost := 0
	for perk_id in picks:
		var perk := DefinitionLibrary.get_perk(perk_id)
		if perk == null:
			return -1
		var level: int = levels.get(perk_id, get_perk_level(perk_id))
		var next := perk.next_level(level)
		if next == null:
			return -1
		cost += next.cost_points
		levels[perk_id] = level + 1
	return cost


# Founds a charter in `town_id`: banks the points it earns, buys `picks` (one
# perk level per entry) with them, then starts a fresh run in that town.
# Refused with nothing changed below the charter level, for a town that isn't
# open, or when the picks are invalid or cost more than the points available.
# The caller saves.
func found_charter(town_id: String, picks: Array[String] = []) -> bool:
	var town := DefinitionLibrary.get_town(town_id)
	if town == null or not can_found_charter() or not is_town_open(town):
		return false
	var cost := perk_purchase_cost(picks)
	var balance := charter_points + get_charter_points_earned()
	if cost < 0 or cost > balance:
		return false
	var stars := get_codex_stars()
	var new_families := get_new_codex_families()
	var old_seed := run_seed
	_reset_for_charter()
	current_town = town_id
	charters += 1
	charter_points = balance - cost
	codex_stars_credited = stars
	codex_families_credited.append_array(new_families)
	for perk_id in picks:
		perk_levels[perk_id] = get_perk_level(perk_id) + 1
	# Never the old seed, so re-founding in the same town can't replay it.
	while run_seed == old_seed:
		run_seed = randi()
	_apply_starting_perks(town)
	return true


# deserialize() is the one source of fresh-game defaults, so feed it only the
# kept fields. A deep copy: the kept arrays and dictionaries must not be the
# ones deserialize() rebuilds in place.
func _reset_for_charter() -> void:
	var saved := serialize().duplicate(true)
	var kept := {}
	for field in CHARTER_KEPT_FIELDS:
		kept[field] = saved[field]
	deserialize(kept)


# The run a charter founds opens with the stipend's gold and the town's
# cheapest blueprints.
func _apply_starting_perks(town: TownDefinition) -> void:
	var stipend := _perk_value("starting_gold", 0.0)
	if stipend > 0.0:
		gold = int(stipend)
		gold_changed.emit(gold)
	for _i in range(int(_perk_value("starting_blueprint", 0.0))):
		var blueprint := _cheapest_open_blueprint(town)
		if blueprint == null:
			return
		add_blueprint(blueprint.id)


# The cheapest blueprint the town sells that isn't owned and whose
# dependencies are, ignoring its shop level; null when none is left.
func _cheapest_open_blueprint(town: TownDefinition) -> BlueprintDefinition:
	for blueprint in DefinitionLibrary.get_town_blueprints(town):
		if blueprint.cost > 0 and not blueprint.id in unlocked_blueprints and RecipeResolver.are_dependencies_met(blueprint):
			return blueprint
	return null


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


# The Bulk Deal upgrade and the Trade Ties perk multiply.
func get_crate_discount() -> float:
	return _purchased_upgrade_value("crate_discount", DEFAULT_CRATE_COST_MULTIPLIER) * _perk_value("crate_discount", 1.0)


func get_shelf_slots() -> int:
	var slots := int(_purchased_upgrade_value("shelf_slots", DEFAULT_SHELF_SLOTS)) + int(_perk_value("shelf_bonus", 0.0))
	return mini(slots, DefinitionLibrary.get_shop_rules().max_shelf_slots)


func get_xp_multiplier() -> float:
	return _perk_value("xp_multiplier", DEFAULT_XP_MULTIPLIER)


func get_loyalty_multiplier() -> float:
	return _perk_value("loyalty_multiplier", DEFAULT_LOYALTY_MULTIPLIER)


func get_order_price_multiplier() -> float:
	return _purchased_upgrade_value("order_price", DEFAULT_ORDER_PRICE_MULTIPLIER)


func get_contract_slots() -> int:
	return int(_purchased_upgrade_value("contract_slots", DEFAULT_CONTRACT_SLOTS))


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


# The value at the owned level of the perk with this effect, else the default.
# The level is capped at the perk's length in case content shrank.
func _perk_value(effect: String, default: float) -> float:
	for perk in DefinitionLibrary.get_all_perks():
		if perk.effect != effect:
			continue
		var level := mini(get_perk_level(perk.id), perk.max_level())
		if level > 0:
			return perk.levels[level - 1].value
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
		"regular_loyalty": regular_loyalty,
		"active_contracts": active_contracts,
		"current_town": current_town,
		"charters": charters,
		"charter_points": charter_points,
		"perk_levels": perk_levels,
		"codex": codex,
		"codex_stars_credited": codex_stars_credited,
		"codex_families_credited": codex_families_credited,
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
	if not _is_valid_counts(data.get("upgrade_levels")): return false
	if not _is_valid_board_state(data.get("shop_board_state")): return false
	if not _is_valid_board_state(data.get("shop_shelf_state")): return false
	if not _is_valid_board_state(data.get("dungeon_board_state")): return false
	if not _is_number(data.get("grid_cols")): return false
	if not _is_number(data.get("grid_rows")): return false
	if not _is_number(data.get("run_seed")): return false
	if not _is_number(data.get("sessions_played")): return false
	if not _is_valid_counts(data.get("regular_loyalty")): return false
	if not _is_valid_contracts(data.get("active_contracts")): return false
	if not data.get("current_town") is String or DefinitionLibrary.get_town(data["current_town"]) == null:
		return false
	if not _is_whole_at_least(data.get("charters"), 0): return false
	if not _is_whole_at_least(data.get("charter_points"), 0): return false
	if not _is_valid_counts(data.get("perk_levels")): return false
	if not _is_valid_codex(data.get("codex")): return false
	if not _is_whole_at_least(data.get("codex_stars_credited"), 0): return false
	if not _is_string_array(data.get("codex_families_credited")): return false
	return true


# Id -> a whole number >= 0 (upgrade levels, loyalty points, delivered counts).
static func _is_valid_counts(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for count: Variant in value.values():
		if not _is_whole_at_least(count, 0):
			return false
	return true


# Entries are {id, delivered: {item_id: count}, sessions_left}. An expired
# contract is removed, so a saved one has at least 1 session left.
static func _is_valid_contracts(value: Variant) -> bool:
	if not value is Array:
		return false
	var seen_ids: Dictionary = {}
	for entry: Variant in value:
		if not entry is Dictionary or not entry.get("id") is String:
			return false
		var contract_id: String = entry["id"]
		if seen_ids.has(contract_id):
			return false
		seen_ids[contract_id] = true
		if not _is_valid_counts(entry.get("delivered")):
			return false
		if not _is_whole_at_least(entry.get("sessions_left"), 1):
			return false
	return true


# Item id -> a quality in 0..MAX_QUALITY.
static func _is_valid_codex(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for quality: Variant in value.values():
		if not _is_valid_quality(quality):
			return false
	return true


static func _is_string_array(value: Variant) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if not entry is String:
			return false
	return true


# A whole number no lower than `minimum` (JSON makes it a float), never a bool.
static func _is_whole_at_least(value: Variant, minimum: int) -> bool:
	if not _is_number(value):
		return false
	var number: float = value
	return number >= minimum and number == floor(number)


# Board entries are {col, row, item_id, quality}; item data is rebuilt from the catalog.
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
		if not _is_valid_quality(entry.get("quality")):
			return false
	return true


# A whole number in 0..MAX_QUALITY (JSON makes it a float).
static func _is_valid_quality(value: Variant) -> bool:
	if not _is_number(value):
		return false
	var quality: float = value
	return quality >= 0.0 and quality <= ItemDefinition.MAX_QUALITY and quality == floor(quality)


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
	upgrade_levels = _whole_counts(data.get("upgrade_levels", {}))
	shop_board_state = data.get("shop_board_state", [])
	shop_shelf_state = data.get("shop_shelf_state", [])
	dungeon_board_state = data.get("dungeon_board_state", [])
	grid_cols = data.get("grid_cols", 5)
	grid_rows = data.get("grid_rows", 5)
	run_seed = int(data["run_seed"]) if data.has("run_seed") else randi()
	sessions_played = int(data.get("sessions_played", 0))
	regular_loyalty = _whole_counts(data.get("regular_loyalty", {}))
	active_contracts = []
	for entry: Dictionary in data.get("active_contracts", []):
		active_contracts.append(_contract_entry(entry))
	seen_intro = data.get("seen_intro", false)
	current_town = data.get("current_town", _starting_town_id())
	charters = int(data.get("charters", 0))
	charter_points = int(data.get("charter_points", 0))
	perk_levels = _whole_counts(data.get("perk_levels", {}))
	codex = _whole_counts(data.get("codex", {}))
	codex_stars_credited = int(data.get("codex_stars_credited", 0))
	codex_families_credited.assign(data.get("codex_families_credited", []))
	gold_changed.emit(gold)
	shop_xp_changed.emit(shop_xp)
	grid_size_changed.emit(grid_cols, grid_rows)


# New games open in the shop rules' starting town.
func _starting_town_id() -> String:
	var town := DefinitionLibrary.get_shop_rules().starting_town
	return "" if town == null else town.id


# JSON turns whole numbers into floats; the game expects ints. Always a new
# dictionary, so a caller's data is never shared.
static func _whole_counts(saved: Dictionary) -> Dictionary:
	var counts := {}
	for key: String in saved:
		counts[key] = int(saved[key])
	return counts


static func _contract_entry(entry: Dictionary) -> Dictionary:
	return {"id": entry["id"], "delivered": _whole_counts(entry["delivered"]), "sessions_left": int(entry["sessions_left"])}
