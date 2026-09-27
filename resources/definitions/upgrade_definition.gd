extends Resource
class_name UpgradeDefinition

@export var id: String = ""
@export var name: String = ""
@export var cost: int = 0
# grid_size adds grid_cols and grid_rows to the board. despawn_time sets the
# staging despawn time to `value` seconds. crate_discount multiplies crate
# prices by `value`.
@export_enum("grid_size", "despawn_time", "crate_discount") var effect: String = ""
@export var value: float = 0.0
@export var grid_cols: int = 0
@export var grid_rows: int = 0
