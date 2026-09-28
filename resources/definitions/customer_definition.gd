extends Resource
class_name CustomerDefinition

# A customer archetype. Shop sessions deal customers from the unlocked
# archetypes and roll each one's orders from `wants`.
@export var id: String = ""
@export var name: String = ""
@export var role: String = ""
# The customer's portrait.
@export var sprite: Texture2D
@export var reputation_required: int = 0
# Chance of being dealt, relative to the other unlocked archetypes.
@export var weight: int = 1
@export var min_orders: int = 1
@export var max_orders: int = 1
# Scales every order's price (item gold_value x quantity).
@export var price_multiplier: float = 1.0
@export var wants: Array[OrderTemplate] = []
