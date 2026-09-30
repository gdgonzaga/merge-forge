extends Resource
class_name LoyaltyReward

# One gift on a regular's loyalty track, given once when the regular's
# loyalty reaches `points`. A blueprint the player already owns pays its gold
# cost instead (shop/reward_grant.gd).
@export var points: int = 1
# Shown with the customer's name once reached ("Regular").
@export var title: String = ""
@export var gold: int = 0
@export var blueprint: BlueprintDefinition
@export var reagent: ReagentDefinition
@export var reagent_count: int = 0
