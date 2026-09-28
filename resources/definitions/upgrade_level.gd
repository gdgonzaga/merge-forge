extends Resource
class_name UpgradeLevel

# One level of an upgrade track. `value` is the absolute value at this level
# (despawn 15, then 18, then 22), not a step. grid_cols and grid_rows are what
# this level adds to the board, so grid growth adds up over bought levels.
@export var cost: int = 0
@export var value: float = 0.0
@export var grid_cols: int = 0
@export var grid_rows: int = 0
@export var min_shop_level: int = 1
