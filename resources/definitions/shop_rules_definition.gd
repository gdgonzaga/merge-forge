extends Resource
class_name ShopRulesDefinition

# Shop-wide rule values. There is one definition, id "default".
@export var id: String = ""
# Where a new game opens.
@export var starting_town: TownDefinition
@export var session_size: int = 10
# Chance that a session rolls a market modifier (at most one per session).
@export var modifier_chance: float = 0.0
# How many of the next session's customers the prep forecast reveals.
@export var forecast_customers: int = 3
# How many contracts prep offers per session.
@export var contract_offers: int = 2
# The most display-shelf slots the shop layout holds, whatever upgrades and
# perks add.
@export var max_shelf_slots: int = 6

# Order price multiplier per required quality, indexed by min_quality
# (Normal, Fine, Masterwork).
@export var quality_price_multipliers: Array[float] = [1.0, 1.0, 1.0]

# Order XP = gold reward x xp_per_gold, raised by the fulfil streak: each
# customer fulfilled in a row adds streak_step, up to streak_cap.
@export var xp_per_gold: float = 0.5
@export var streak_step: float = 0.1
@export var streak_cap: float = 0.5
# A quality order earns the higher loyalty amount for a regular.
@export var loyalty_per_order: int = 1
@export var loyalty_per_quality_order: int = 2
# XP from level k to k+1 is level_xp_base x k^level_xp_exponent. A power law,
# not geometric: income stops growing once content runs out, and a geometric
# curve then makes every later level cost a fixed factor more sessions.
@export var level_xp_base: int = 50
@export var level_xp_exponent: float = 1.5
@export var max_level: int = 60
# Guild Charter: founding one needs charter_level. It earns
# charter_base_points + floor((level - charter_level) x
# charter_points_per_level) + new codex stars + codex_family_points per
# newly completed family (charter_points()).
@export var charter_level: int = 40
@export var charter_base_points: int = 10
@export var charter_points_per_level: float = 1.0
# Charter points a codex family pays, once, at the first charter after every
# one of its codex items has been made.
@export var codex_family_points: int = 5


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


# Points a charter founded at `level` earns; 0 below charter_level.
func charter_points(level: int, new_stars: int, new_families: int) -> int:
	if level < charter_level:
		return 0
	return charter_base_points + charter_level_points(level) + new_stars + new_families * codex_family_points


# The part of charter_points() for levels past charter_level.
func charter_level_points(level: int) -> int:
	return maxi(floori((level - charter_level) * charter_points_per_level), 0)
