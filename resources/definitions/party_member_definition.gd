extends Resource
class_name PartyMemberDefinition

@export var id: String = ""
@export var name: String = ""
@export var sprite: Texture2D
@export var max_hp: int = 50
@export var attack: int = 10
# "melee" hits the front enemy; "missile" splits across every alive enemy.
# Required: the empty default fails CombatEngine's check.
@export var attack_type: String = ""
@export var slot_order: int = 0
