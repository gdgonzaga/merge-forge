extends Resource
class_name BlueprintDefinition

# Unlocks the merge results and reagent variants that name it. References only
# point down (items -> blueprints -> dependencies): a blueprint never points
# back at an item, since Godot can't load cyclic resource files.
@export var id: String = ""
@export var name: String = ""
@export var cost: int = 0
@export var dependencies: Array[BlueprintDefinition] = []
