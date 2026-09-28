extends TestBase

# The shop's fulfil streak: each customer fulfilled in a row earns more XP, and
# a rejection starts it over.

const ORDER_STREAK := preload("res://shop/order_streak.gd")

var _rules: ShopRulesDefinition


func before_test() -> void:
	super.before_test()
	_rules = ShopRulesDefinition.new()
	_rules.id = "__test_rules"
	_rules.xp_per_gold = 0.5
	_rules.streak_step = 0.1
	_rules.streak_cap = 0.2


func test_each_fulfil_in_a_row_earns_more_up_to_the_cap() -> void:
	var streak: RefCounted = ORDER_STREAK.new()
	var earned: Array[int] = []
	for _i in range(4):
		earned.append(streak.fulfill(60, _rules))
	assert_array(earned).is_equal([30, 33, 36, 36])


func test_a_rejection_starts_the_streak_over() -> void:
	var streak: RefCounted = ORDER_STREAK.new()
	streak.fulfill(60, _rules)
	streak.fulfill(60, _rules)
	streak.reject()
	assert_int(streak.fulfill(60, _rules)).is_equal(30)
