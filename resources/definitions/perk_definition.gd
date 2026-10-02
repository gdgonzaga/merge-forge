extends Resource
class_name PerkDefinition

# A permanent Guild perk, bought with charter points when founding a charter.
# Level k uses levels[k - 1].
@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
# starting_gold: a charter's run starts with `value` gold.
# xp_multiplier: shop XP gains x `value`.
# crate_discount: crate prices x `value`, on top of the Bulk Deal upgrade.
# starting_blueprint: a charter's run starts with the town's `value` cheapest
#   blueprints for sale, dependencies first.
# shelf_bonus: the display shelf holds `value` more items, up to
#   ShopRulesDefinition.max_shelf_slots.
# loyalty_multiplier: loyalty gains x `value`.
@export_enum("starting_gold", "xp_multiplier", "crate_discount", "starting_blueprint", "shelf_bonus", "loyalty_multiplier") var effect: String = ""
@export var levels: Array[PerkLevel] = []


func max_level() -> int:
	return levels.size()


# The level bought after `level`, or null at the max.
func next_level(level: int) -> PerkLevel:
	if level < 0 or level >= levels.size():
		return null
	return levels[level]
