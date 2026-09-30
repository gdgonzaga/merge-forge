extends Resource
class_name ItemDefinition

# Item quality: 0 Normal, 1 Fine, 2 Masterwork. A board item dict carries it
# (RecipeResolver.make_item); oversized merge groups raise it.
const MAX_QUALITY := 2
const QUALITY_NAMES: Array[String] = ["Normal", "Fine", "Masterwork"]

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


# Shared wording for quality requirements shown in prep and the shop.
func name_at_quality(quality: int) -> String:
	return name if quality <= 0 else "%s %s" % [QUALITY_NAMES[quality], name]
