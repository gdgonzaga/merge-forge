extends Node

# All game content: one catalog per folder under DEFINITIONS_DIR, keyed by id.
# Definitions reference each other directly, so a catalog entry is the loaded
# Resource itself. Treat them as read-only; they are shared.

const DEFINITIONS_DIR := "res://resources/definitions"

var items: Dictionary = {}
var party: Dictionary = {}
var enemies: Dictionary = {}
var reagents: Dictionary = {}
var blueprints: Dictionary = {}
var crates: Dictionary = {}
var upgrades: Dictionary = {}
var customers: Dictionary = {}
var dungeons: Dictionary = {}
var shop_rules: Dictionary = {}
var modifiers: Dictionary = {}
var contracts: Dictionary = {}


func _ready() -> void:
	load_all_definitions()


func load_all_definitions() -> void:
	var catalogs := get_catalogs()
	for folder: String in catalogs:
		var catalog: Dictionary = catalogs[folder]
		catalog.clear()
		_load_directory(DEFINITIONS_DIR.path_join(folder), catalog)
		# An empty catalog means the definitions weren't packaged (export
		# filter) or couldn't be listed. There's no fallback content.
		if catalog.is_empty():
			push_error("DefinitionLibrary: no %s definitions loaded" % folder)
			assert(false, "DefinitionLibrary: no %s definitions loaded" % folder)


# Folder name -> catalog.
func get_catalogs() -> Dictionary:
	return {
		"items": items,
		"party": party,
		"enemies": enemies,
		"reagents": reagents,
		"blueprints": blueprints,
		"crates": crates,
		"upgrades": upgrades,
		"customers": customers,
		"dungeons": dungeons,
		"shop_rules": shop_rules,
		"modifiers": modifiers,
		"contracts": contracts,
	}


func _load_directory(path: String, target: Dictionary) -> void:
	# Not DirAccess: in exports, text resources are remapped to binary and a raw
	# listing shows "x.tres.remap". ResourceLoader lists the original names.
	for file_name in ResourceLoader.list_directory(path):
		if not file_name.ends_with(".tres"):
			continue
		var full_path := path.path_join(file_name)
		var res: Resource = load(full_path)
		if res == null or not "id" in res or res.id == "":
			push_error("DefinitionLibrary: %s has no id" % full_path)
			assert(false, "DefinitionLibrary: %s has no id" % full_path)
			continue
		if target.has(res.id):
			push_error("DefinitionLibrary: %s reuses id '%s'" % [full_path, res.id])
			assert(false, "DefinitionLibrary: %s reuses id '%s'" % [full_path, res.id])
			continue
		target[res.id] = res


func get_item(id: String) -> ItemDefinition:
	return items.get(id, null)


func get_all_items() -> Dictionary:
	return items


func get_party_member(id: String) -> PartyMemberDefinition:
	return party.get(id, null)


func get_all_party_members() -> Array[PartyMemberDefinition]:
	var result: Array[PartyMemberDefinition] = []
	result.assign(party.values())
	result.sort_custom(func(a: PartyMemberDefinition, b: PartyMemberDefinition) -> bool:
		return a.slot_order < b.slot_order
	)
	return result


func get_enemy(id: String) -> EnemyDefinition:
	return enemies.get(id, null)


func get_all_enemies() -> Dictionary:
	return enemies


func get_reagent(id: String) -> ReagentDefinition:
	return reagents.get(id, null)


func get_all_reagents() -> Array[ReagentDefinition]:
	var result: Array[ReagentDefinition] = []
	result.assign(_by_cost(reagents))
	return result


func get_blueprint(id: String) -> BlueprintDefinition:
	return blueprints.get(id, null)


func get_all_blueprints() -> Array[BlueprintDefinition]:
	var result: Array[BlueprintDefinition] = []
	result.assign(_by_cost(blueprints))
	return result


func get_crate(id: String) -> CrateDefinition:
	return crates.get(id, null)


func get_all_crates() -> Array[CrateDefinition]:
	var result: Array[CrateDefinition] = []
	result.assign(_by_cost(crates))
	return result


func get_upgrade(id: String) -> UpgradeDefinition:
	return upgrades.get(id, null)


# Cheapest first level first; ties by id so the order is stable.
func get_all_upgrades() -> Array[UpgradeDefinition]:
	var result: Array[UpgradeDefinition] = []
	result.assign(upgrades.values())
	result.sort_custom(func(a: UpgradeDefinition, b: UpgradeDefinition) -> bool:
		var cost_a := 0 if a.levels.is_empty() else a.levels[0].cost
		var cost_b := 0 if b.levels.is_empty() else b.levels[0].cost
		if cost_a != cost_b:
			return cost_a < cost_b
		return a.id < b.id
	)
	return result


# Sorted by id; shop sessions deal from these archetypes.
func get_all_customers() -> Array[CustomerDefinition]:
	var result: Array[CustomerDefinition] = []
	result.assign(customers.values())
	result.sort_custom(func(a: CustomerDefinition, b: CustomerDefinition) -> bool:
		return a.id < b.id
	)
	return result


func get_dungeon(id: String) -> DungeonDefinition:
	return dungeons.get(id, null)


# In unlock order: lowest min_shop_level first, ties by id.
func get_all_dungeons() -> Array[DungeonDefinition]:
	var result: Array[DungeonDefinition] = []
	result.assign(dungeons.values())
	result.sort_custom(func(a: DungeonDefinition, b: DungeonDefinition) -> bool:
		if a.min_shop_level != b.min_shop_level:
			return a.min_shop_level < b.min_shop_level
		return a.id < b.id
	)
	return result


# The one shop-rules definition.
func get_shop_rules() -> ShopRulesDefinition:
	return shop_rules.get("default", null)


func get_modifier(id: String) -> SessionModifierDefinition:
	return modifiers.get(id, null)


# Sorted by id, so a seeded roll can't depend on catalog load order.
func get_all_modifiers() -> Array[SessionModifierDefinition]:
	var result: Array[SessionModifierDefinition] = []
	result.assign(modifiers.values())
	result.sort_custom(func(a: SessionModifierDefinition, b: SessionModifierDefinition) -> bool:
		return a.id < b.id
	)
	return result


func get_contract(id: String) -> ContractDefinition:
	return contracts.get(id, null)


# Sorted by id, so a seeded offer can't depend on catalog load order.
func get_all_contracts() -> Array[ContractDefinition]:
	var result: Array[ContractDefinition] = []
	result.assign(contracts.values())
	result.sort_custom(func(a: ContractDefinition, b: ContractDefinition) -> bool:
		return a.id < b.id
	)
	return result


# Everything that opens when the shop goes from old_level to new_level: above
# old_level, up to and including new_level. Ordered by level, then catalog,
# then id, so a multi-level jump reads in unlock order.
func get_unlocks_between(old_level: int, new_level: int) -> Array[Resource]:
	var found: Array[Array] = []
	var catalogs := get_catalogs()
	for folder: String in catalogs:
		for definition: Resource in catalogs[folder].values():
			if "min_shop_level" in definition and definition.min_shop_level > old_level and definition.min_shop_level <= new_level:
				found.append([definition.min_shop_level, folder, definition.id, definition])
	found.sort()
	var result: Array[Resource] = []
	for entry in found:
		result.append(entry[3])
	return result


# Shop listings run cheapest first; ties by id so the order is stable.
static func _by_cost(catalog: Dictionary) -> Array:
	var result := catalog.values()
	result.sort_custom(func(a: Resource, b: Resource) -> bool:
		if a.cost != b.cost:
			return a.cost < b.cost
		return a.id < b.id
	)
	return result
