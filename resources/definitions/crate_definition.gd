extends Resource
class_name CrateDefinition

@export var id: String = ""
@export var name: String = ""
@export var cost: int = 0
@export var min_shop_level: int = 1
@export var min_items: int = 1
@export var max_items: int = 1
@export var pool: Array[WeightedItem] = []
