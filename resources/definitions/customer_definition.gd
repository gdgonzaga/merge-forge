extends Resource
class_name CustomerDefinition

@export var id: String = ""
@export var name: String = ""
@export var role: String = ""
# The customer's portrait.
@export var sprite: Texture2D
# Position in a shop session's queue, lowest first.
@export var queue_order: int = 0
@export var orders: Array[OrderDefinition] = []
