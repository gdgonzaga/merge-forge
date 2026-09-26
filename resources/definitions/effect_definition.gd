extends Resource
class_name EffectDefinition

@export var type: String = "" # e.g. "heal", "buff_attack"
@export var value: int = 0
@export var duration: int = 0 # in ticks, 0 = instant
