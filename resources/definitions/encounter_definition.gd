extends Resource
class_name EncounterDefinition

# Wraps one encounter's spawns: Godot can't export a nested Array[Array].
@export var spawns: Array[EnemySpawn] = []
