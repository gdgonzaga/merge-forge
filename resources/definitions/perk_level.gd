extends Resource
class_name PerkLevel

# One level of a Guild perk. `value` is the absolute value at this level
# (400 starting gold, then 1000), not a step.
@export var cost_points: int = 0
@export var value: float = 0.0
