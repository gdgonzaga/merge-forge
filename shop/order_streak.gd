extends RefCounted

# Customers fulfilled in a row this session. A rejection breaks the streak; it
# lasts one session and isn't saved.

var count: int = 0


# XP for a fulfilled order at the current streak; the streak then grows.
func fulfill(gold_reward: int, rules: ShopRulesDefinition) -> int:
	var xp := rules.order_xp(gold_reward, count)
	count += 1
	return xp


func reject() -> void:
	count = 0
