extends Resource
class_name SessionModifierDefinition

# A market event a shop session may roll (ShopRulesDefinition.modifier_chance).
# At most one applies per session. A multiplier of 1.0 or a delta of 0 leaves
# that part of the session alone.
@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var sprite: Texture2D
@export var min_shop_level: int = 1
# How often this modifier is picked, relative to the other unlocked ones.
@export var weight: int = 1
@export var boosted_customers: Array[CustomerDefinition] = []
@export var customer_weight_multiplier: float = 1.0
# An item `family` key such as "herb". Empty means every item.
@export var family: String = ""
@export var family_price_multiplier: float = 1.0
@export var affected_crates: Array[CrateDefinition] = []
@export var crate_cost_multiplier: float = 1.0
@export var session_size_delta: int = 0


# Never below 1, so a boosted archetype keeps a real weight.
func customer_weight(archetype: CustomerDefinition) -> int:
	if archetype in boosted_customers:
		return maxi(roundi(archetype.weight * customer_weight_multiplier), 1)
	return archetype.weight


func price_multiplier(item: ItemDefinition) -> float:
	if family.is_empty() or item.family == family:
		return family_price_multiplier
	return 1.0


# Crate id -> cost multiplier, the shape MergeBoard.setup takes.
func get_crate_cost_multipliers() -> Dictionary:
	var result := {}
	for crate in affected_crates:
		result[crate.id] = crate_cost_multiplier
	return result


# Never below 1: a session always deals someone.
func session_size(base: int) -> int:
	return maxi(base + session_size_delta, 1)
