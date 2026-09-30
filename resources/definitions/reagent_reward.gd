extends Resource
class_name ReagentReward

@export var reagent: ReagentDefinition
@export var min_count: int = 1
@export var max_count: int = 1
@export_range(0.0, 1.0) var chance: float = 1.0


func roll(rng: RandomNumberGenerator) -> int:
	if reagent == null or chance <= 0.0:
		return 0
	if chance < 1.0 and rng.randf() >= chance:
		return 0
	return rng.randi_range(min_count, max_count)
