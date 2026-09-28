extends Resource
class_name ShopRulesDefinition

# Shop-wide rule values. There is one definition, id "default".
@export var id: String = ""
@export var session_size: int = 10
@export var fulfill_reputation: int = 10
@export var reject_reputation_penalty: int = 2
