extends Resource
class_name ReagentDefinition

# Bought in the prep phase and spent from GameManager.reagent_inventory when a
# merge picks a reagent variant. Never placed on the board.
@export var id: String = ""
@export var name: String = ""
@export var cost: int = 0
@export_multiline var description: String = ""
@export var sprite: Texture2D
