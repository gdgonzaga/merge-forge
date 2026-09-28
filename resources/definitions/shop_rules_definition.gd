extends Resource
class_name ShopRulesDefinition

# Shop-wide rule values. There is one definition, id "default".
@export var id: String = ""
@export var session_size: int = 10
@export var fulfill_reputation: int = 10
@export var reject_reputation_penalty: int = 2

# Order XP = gold reward x xp_per_gold, raised by the fulfil streak: each
# customer fulfilled in a row adds streak_step, up to streak_cap.
@export var xp_per_gold: float = 0.5
@export var streak_step: float = 0.1
@export var streak_cap: float = 0.5
# XP from level k to k+1 is level_xp_base x k^level_xp_exponent. A power law,
# not geometric: income stops growing once content runs out, and a geometric
# curve then makes every later level cost a fixed factor more sessions.
@export var level_xp_base: int = 50
@export var level_xp_exponent: float = 1.5
@export var max_level: int = 60


func xp_to_next(level: int) -> int:
	return roundi(level_xp_base * pow(level, level_xp_exponent))


# Total XP at which `level` starts; level 1 starts at 0.
func xp_for_level(level: int) -> int:
	var total := 0
	for k in range(1, clampi(level, 1, max_level)):
		total += xp_to_next(k)
	return total


func level_for_xp(xp: int) -> int:
	var level := 1
	var needed := 0
	while level < max_level:
		needed += xp_to_next(level)
		if xp < needed:
			break
		level += 1
	return level


# `streak` counts the customers fulfilled in a row before this one.
func order_xp(gold_reward: int, streak: int) -> int:
	var bonus := minf(streak * streak_step, streak_cap)
	return roundi(gold_reward * xp_per_gold * (1.0 + bonus))
