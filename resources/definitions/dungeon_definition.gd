extends Resource
class_name DungeonDefinition

@export var id: String = ""
@export var name: String = ""
@export var min_shop_level: int = 1
# Share of the route covered per second of walking.
@export var walk_speed: float = 0.02
# Route progress (0..1) at which each encounter starts, one per encounter.
@export var encounter_points: Array[float] = []
@export var encounters: Array[EncounterDefinition] = []
@export var gold_reward: int = 0
@export var blueprint_reward: BlueprintDefinition
@export var reagent_rewards: Array[ReagentReward] = []
# Shop XP for a clear; a wipe gives none.
@export var xp_reward: int = 0
