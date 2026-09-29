extends Resource
class_name PartyMemberDefinition

@export var id: String = ""
@export var name: String = ""
@export var sprite: Texture2D
@export var max_hp: int = 50
@export var attack: int = 10
# "melee" hits the front enemy; "missile" hits the weakest alive enemy.
# Required: the empty default fails CombatEngine's check.
@export var attack_type: String = ""
# Ticks one attack winds up for; a crit winds up longer (CombatEngine).
# Required: 0 fails CombatEngine's check.
@export var windup: int = 0
# Ticks a critical attack winds up for. Defaults to windup * 2 if 0.
@export var crit_windup: int = 0
@export var crit_chance: float = 0.0
# Pops up when a crit lands.
@export var crit_name: String = ""
# Icon overlay for critical hit badge and line flight.
@export var crit_sprite: Texture2D
@export var slot_order: int = 0
