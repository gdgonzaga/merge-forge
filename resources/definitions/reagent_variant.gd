extends Resource
class_name ReagentVariant

# A merge result that costs one reagent from the inventory.
@export var result: ItemDefinition
@export var reagent: ReagentDefinition
# Null when the variant needs no blueprint.
@export var blueprint: BlueprintDefinition
