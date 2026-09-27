extends Resource
class_name EffectDefinition

# What `value` means per type. CombatEngine applies only "heal" and
# "buff_attack" so far; the other types are defined content waiting on engine
# support, and using such an item does nothing yet.
#   heal          HP restored
#   buff_attack   ATK added for `duration` ticks
#   absorb        shield HP that soaks damage before HP
#   crit_charges  number of next attacks that crit
#   revive        percent of max HP a knocked-out member comes back with
#   damage        damage dealt to each target
@export_enum("heal", "buff_attack", "absorb", "crit_charges", "revive", "damage") var type: String = ""
@export var value: int = 0
@export var duration: int = 0 # in ticks, 0 = instant
