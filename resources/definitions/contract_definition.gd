extends Resource
class_name ContractDefinition

# A multi-session order from a regular. Prep offers it for the next session;
# once accepted, the shop's Contracts sheet takes deliveries until every
# requirement is met or sessions_allowed sessions have passed.
@export var id: String = ""
@export var name: String = ""
@export var giver: CustomerDefinition
@export var min_shop_level: int = 1
# How often this contract is offered, relative to the other eligible ones.
@export var weight: int = 1
# Each requirement's quantity is fixed: min_quantity, which must equal
# max_quantity. One requirement per item.
@export var requirements: Array[OrderTemplate] = []
@export var sessions_allowed: int = 1
@export var reward_gold: int = 0
@export var reward_blueprint: BlueprintDefinition
@export var reward_reagent: ReagentDefinition
@export var reward_reagent_count: int = 0
# Added to the giver's loyalty on completion.
@export var loyalty_points: int = 0


# The requirement for this item, or null when the contract doesn't ask for it.
func requirement_for(item_id: String) -> OrderTemplate:
	for requirement in requirements:
		if requirement.item != null and requirement.item.id == item_id:
			return requirement
	return null


func requirement_items() -> Array[ItemDefinition]:
	var items: Array[ItemDefinition] = []
	for requirement in requirements:
		items.append(requirement.item)
	return items


# Shared by prep and the shop's Contracts sheet so both read the same.
static func sessions_left_text(sessions_left: int) -> String:
	return "Last session" if sessions_left <= 1 else "%d sessions left" % sessions_left
