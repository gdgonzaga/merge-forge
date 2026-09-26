extends Resource
class_name AttackDefinition

@export var name: String = ""
@export var interval: int = 0
@export var windup: int = 0
@export var damage: int = 0
@export var type: String = "damage" # "damage", "heal", "buff", "debuff"
@export var effect: EffectDefinition
