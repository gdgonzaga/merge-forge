extends Resource
class_name ItemDefinition

@export var id: String = ""
@export var name: String = ""
@export var family: String = "" # "metal", "herb", "powder", etc.
@export var gold_value: int = 0
@export var dungeon_usable: bool = false
# "party-individual", "enemy-individual" or "enemy-all". Only party members
# accept drops so far, so enemy-targeted items can't be used yet.
@export var dungeon_use_target: String = ""
@export var effect: EffectDefinition
@export var sprite: Texture2D
# What three of this item merge into. More than one available result makes the
# player choose.
@export var merge_results: Array[MergeResult] = []
@export var reagent_variants: Array[ReagentVariant] = []
