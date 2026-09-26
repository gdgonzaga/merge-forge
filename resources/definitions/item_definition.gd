extends Resource
class_name ItemDefinition

@export var id: String = ""
@export var name: String = ""
@export var family: String = "" # "metal", "herb", "reagent", etc.
@export var gold_value: int = 0
@export var dungeon_usable: bool = false
@export var dungeon_use_target: String = "" # e.g. "party-individual"
@export var effect: EffectDefinition
@export var sprite: Texture2D
