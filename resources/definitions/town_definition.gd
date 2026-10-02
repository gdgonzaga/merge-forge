extends Resource
class_name TownDefinition

# A town the player can run a shop branch in. The top tier: a town points
# down at everything its shop and prep offer, and nothing points back at a
# town (ShopRulesDefinition.starting_town aside). Items, reagents, upgrades,
# perks, party members and enemies are shared by every town.

# The catalogs a town scopes. Shop and prep read these from the current town;
# the whole catalogs stay for integrity tests and the codex.
const SCOPED_CATALOGS: Array[String] = ["customers", "crates", "modifiers", "contracts", "dungeons", "blueprints"]

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
# The shop session's backdrop in this town.
@export var background: Texture2D
# Charters founded, counting the one being founded, before this town can be
# chosen: 0 for the starting town, 1 opens at the first charter.
@export var charters_required: int = 0
# Scales every order's price in this town.
@export var price_multiplier: float = 1.0
@export var customers: Array[CustomerDefinition] = []
@export var crates: Array[CrateDefinition] = []
@export var modifiers: Array[SessionModifierDefinition] = []
@export var contracts: Array[ContractDefinition] = []
@export var dungeons: Array[DungeonDefinition] = []
@export var blueprints: Array[BlueprintDefinition] = []


# The town's own array for a scoped catalog folder, by reference; empty for
# any other folder.
func content(catalog: String) -> Array:
	match catalog:
		"customers":
			return customers
		"crates":
			return crates
		"modifiers":
			return modifiers
		"contracts":
			return contracts
		"dungeons":
			return dungeons
		"blueprints":
			return blueprints
	return []
