extends Resource
class_name EnemyDefinition

@export var id: String = ""
@export var name: String = ""
@export var max_hp: int = 0
@export var attack_type: String = "melee" # "melee" or "missile"
@export var attack: int = 0
@export var heavy_attack: AttackDefinition
@export var sprite: Texture2D
@export var drop_count: Dictionary = {"min": 0, "max": 0}
@export var drop_pool: Array[Dictionary] = []
