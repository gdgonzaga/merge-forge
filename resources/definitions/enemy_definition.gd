extends Resource
class_name EnemyDefinition

@export var id: String = ""
@export var name: String = ""
@export var max_hp: int = 0
@export var attack_type: String = "melee" # "melee" or "missile"
@export var attack: int = 0
# Ticks one attack winds up for; a crit winds up longer (CombatEngine).
# Required: 0 fails CombatEngine's check.
@export var windup: int = 0
@export var crit_chance: float = 0.0
# Pops up when a crit lands.
@export var crit_name: String = ""
@export var sprite: Texture2D
@export var drop_count: Dictionary = {"min": 0, "max": 0}
@export var drop_pool: Array[Dictionary] = []
