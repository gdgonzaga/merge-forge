extends Resource
class_name CustomerDefinition

# A customer archetype. Shop sessions deal customers from the unlocked
# archetypes and roll each one's orders from `wants`.
@export var id: String = ""
@export var name: String = ""
@export var role: String = ""
# The customer's portrait.
@export var sprite: Texture2D
@export var min_shop_level: int = 1
# How often this archetype is dealt, relative to the other eligible
# archetypes. Must be at least 1.
@export var weight: int = 1
@export var min_orders: int = 1
@export var max_orders: int = 1
# Scales every order's price (item gold_value x quantity).
@export var price_multiplier: float = 1.0
@export var wants: Array[OrderTemplate] = []
# Gifts for a loyal regular, lowest points first. Empty for a generic
# archetype, which then earns no loyalty.
@export var loyalty_rewards: Array[LoyaltyReward] = []


# The rewards a gain from old_points to new_points reaches: above old_points,
# up to and including new_points. Loyalty never goes down, so each reward is
# given once.
func rewards_crossed(old_points: int, new_points: int) -> Array[LoyaltyReward]:
	var crossed: Array[LoyaltyReward] = []
	for reward in loyalty_rewards:
		if reward.points > old_points and reward.points <= new_points:
			crossed.append(reward)
	return crossed


# The title of the highest threshold reached, or "" before the first.
func title_at(points: int) -> String:
	var title := ""
	var best := 0
	for reward in loyalty_rewards:
		if reward.points <= points and reward.points > best:
			best = reward.points
			title = reward.title
	return title


# The lowest threshold above `points`, or -1 once every gift is given.
func next_threshold(points: int) -> int:
	var next := -1
	for reward in loyalty_rewards:
		if reward.points > points and (next < 0 or reward.points < next):
			next = reward.points
	return next
