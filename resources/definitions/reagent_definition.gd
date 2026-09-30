extends Resource
class_name ReagentDefinition

# Positive-cost reagents are bought in prep; zero-cost reagents come from
# dungeon clears. All are spent on merge variants and never placed on a board.
@export var id: String = ""
@export var name: String = ""
@export var cost: int = 0
@export var min_shop_level: int = 1
@export_multiline var description: String = ""
@export var sprite: Texture2D
