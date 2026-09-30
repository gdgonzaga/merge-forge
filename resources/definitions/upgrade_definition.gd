extends Resource
class_name UpgradeDefinition

# A leveled upgrade track. Buying it raises its level by one, up to
# max_level(); level k uses levels[k - 1].
@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
# grid_size: each level adds its grid_cols and grid_rows to the board.
# despawn_time: staging items last `value` seconds.
# crate_discount: crate prices x `value`.
# shelf_slots: the shop's display shelf holds `value` items.
# forecast_detail: the prep forecast reveals `value` customers; 0 reveals
# every customer and their orders.
# order_price: every order pays x `value`.
# contract_slots: the player can hold `value` accepted contracts at once.
@export_enum("grid_size", "despawn_time", "crate_discount", "shelf_slots", "forecast_detail", "order_price", "contract_slots") var effect: String = ""
@export var levels: Array[UpgradeLevel] = []


func max_level() -> int:
	return levels.size()


# The level bought after `level`, or null at the max.
func next_level(level: int) -> UpgradeLevel:
	if level < 0 or level >= levels.size():
		return null
	return levels[level]
