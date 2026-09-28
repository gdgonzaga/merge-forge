extends Resource
class_name OrderTemplate

# Something a customer archetype may ask for. The shop rolls a quantity in
# [min_quantity, max_quantity] and prices it from the item's gold_value.
@export var item: ItemDefinition
@export var weight: int = 1
@export var min_quantity: int = 1
@export var max_quantity: int = 1
# 0 any quality, 1 Fine or better, 2 Masterwork. Only on items at least this
# many merges deep (a crate item can never be Fine). Priced by
# ShopRulesDefinition.quality_price_multipliers.
@export var min_quality: int = 0
