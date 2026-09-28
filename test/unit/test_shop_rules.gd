extends TestBase

# ShopRulesDefinition's pure formulas: the level curve and order XP. Fixture
# rules only; hand-computed values.


# Base 100, exponent 1: 100, 200, 300, 400 XP per level, so levels 2-5 start at
# 100, 300, 600 and 1000.
func test_level_for_xp_at_each_boundary() -> void:
	var rules := _rules(100, 1.0, 5)
	var cases := [[0, 1], [99, 1], [100, 2], [299, 2], [300, 3], [599, 3], [600, 4], [999, 4], [1000, 5]]
	for c: Array in cases:
		assert_int(rules.level_for_xp(c[0])).override_failure_message("xp %d" % c[0]).is_equal(c[1])


func test_level_caps_at_max_level() -> void:
	assert_int(_rules(100, 1.0, 5).level_for_xp(1_000_000)).is_equal(5)


func test_exponent_steepens_the_curve() -> void:
	# Base 100, exponent 2: 100 then 400, so level 3 starts at 500.
	var rules := _rules(100, 2.0, 5)
	assert_int(rules.level_for_xp(499)).is_equal(2)
	assert_int(rules.level_for_xp(500)).is_equal(3)


func test_xp_for_level_is_where_a_level_starts() -> void:
	var rules := _rules(100, 1.0, 5)
	assert_int(rules.xp_for_level(1)).is_equal(0)
	assert_int(rules.xp_for_level(3)).is_equal(300)
	assert_int(rules.xp_for_level(5)).is_equal(1000)
	assert_int(rules.xp_for_level(9)).is_equal(1000)


func test_order_xp_scales_with_the_streak() -> void:
	var rules := _rules(100, 1.0, 5)
	rules.xp_per_gold = 0.5
	rules.streak_step = 0.1
	rules.streak_cap = 0.5
	assert_int(rules.order_xp(60, 0)).is_equal(30)
	assert_int(rules.order_xp(60, 2)).is_equal(36)


func test_order_xp_streak_bonus_stops_at_the_cap() -> void:
	var rules := _rules(100, 1.0, 5)
	rules.xp_per_gold = 0.5
	rules.streak_step = 0.1
	rules.streak_cap = 0.5
	assert_int(rules.order_xp(60, 9)).is_equal(45)


func _rules(base: int, exponent: float, max_level: int) -> ShopRulesDefinition:
	var rules := ShopRulesDefinition.new()
	rules.id = "__test_rules"
	rules.level_xp_base = base
	rules.level_xp_exponent = exponent
	rules.max_level = max_level
	return rules
