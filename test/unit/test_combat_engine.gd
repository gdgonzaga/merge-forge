extends TestBase

# Telegraphed heavy attacks: windup targeting, the locked-in target, and the
# per-slot stagger. Uses a fixture enemy with huge HP so no encounter ends
# mid-test; ticks are driven by hand, never by the engine's timer.

const BRUTE_ID := "__test_brute"

var _engine: Node


func before_test() -> void:
	super.before_test()
	set_catalog_entry(RecipeResolver.enemies, BRUTE_ID, {
		"name": "Brute",
		"max_hp": 10000,
		"attack": 3,
		"heavy_attack": {"name": "Crush", "interval": 4, "windup": 2, "damage": 20},
		"drop_count": {"min": 0, "max": 0},
		"drop_pool": [],
		"sprite": "",
	})
	_engine = auto_free(load("res://dungeon/combat_engine.gd").new())
	add_child(_engine)
	var party: Array[Dictionary] = [
		{"name": "A", "max_hp": 100, "attack": 1},
		{"name": "B", "max_hp": 99, "attack": 1},
	]
	_engine.init_party(party)


func test_no_target_before_windup_then_weakest_member_is_marked() -> void:
	_engine.start_combat([{"enemy_id": BRUTE_ID, "count": 1}])
	_engine.tick()
	assert_int(_engine.get_enemy_data(0)["heavy_target"]).is_equal(-1)
	# Two basic hits of 3 split over 2 members: A 98, B 97 -> B is weakest.
	_engine.tick()
	assert_int(_engine.get_enemy_data(0)["heavy_in"]).is_equal(2)
	assert_int(_engine.get_enemy_data(0)["heavy_target"]).is_equal(1)


func test_heavy_lands_only_on_target_and_resets() -> void:
	_engine.start_combat([{"enemy_id": BRUTE_ID, "count": 1}])
	for _i in range(4):
		_engine.tick()
	# Ticks 1-3 are basic hits of 1 each; tick 4 is the heavy on B alone.
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(97)
	assert_int(_engine.get_member_data(1)["current_hp"]).is_equal(76)
	assert_int(_engine.get_enemy_data(0)["heavy_in"]).is_equal(4)
	assert_int(_engine.get_enemy_data(0)["heavy_target"]).is_equal(-1)


func test_target_stays_locked_after_healing() -> void:
	_engine.start_combat([{"enemy_id": BRUTE_ID, "count": 1}])
	_engine.tick()
	_engine.tick()
	# B (97) is locked in; healing it to 99 makes A (98) the weakest.
	_engine.apply_effect(1, {"type": "heal", "power": 40})
	_engine.tick()
	_engine.tick()
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(97)
	assert_int(_engine.get_member_data(1)["current_hp"]).is_equal(78)


func test_group_heavy_attacks_are_staggered() -> void:
	_engine.start_combat([{"enemy_id": BRUTE_ID, "count": 2}])
	for _i in range(4):
		_engine.tick()
	assert_int(_engine.get_enemy_data(0)["heavy_in"]).is_equal(4)
	# Second slot starts 2 ticks later: 4 + 2 - 4 = 2.
	assert_int(_engine.get_enemy_data(1)["heavy_in"]).is_equal(2)
