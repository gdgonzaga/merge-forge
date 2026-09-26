extends TestBase

# Enemy attacks: telegraphed heavy attacks (windup targeting, the locked-in
# target, the per-slot stagger, the incoming-damage read-outs views use) and
# melee vs. missile reach. Fixture enemies
# have huge HP so no encounter ends mid-test; ticks are driven by hand, never
# by the engine's timer. Party index is slot order: A (0) is the front member.

const BRUTE_ID := "__test_brute"
const BRUISER_ID := "__test_bruiser"
const LUNGER_ID := "__test_lunger"
const FRAGILE_ID := "__test_fragile"

var _engine: Node


func before_test() -> void:
	super.before_test()
	set_catalog_entry(RecipeResolver.enemies, BRUTE_ID, {
		"name": "Brute",
		"max_hp": 10000,
		"attack_type": "missile",
		"attack": 3,
		"heavy_attack": {"name": "Crush", "interval": 4, "windup": 2, "damage": 20},
		"drop_count": {"min": 0, "max": 0},
		"drop_pool": [],
		"sprite": "",
	})
	set_catalog_entry(RecipeResolver.enemies, BRUISER_ID, {
		"name": "Bruiser",
		"max_hp": 10000,
		"attack_type": "melee",
		"attack": 3,
		"heavy_attack": {"name": "Pound", "interval": 4, "windup": 2, "damage": 20},
		"drop_count": {"min": 0, "max": 0},
		"drop_pool": [],
		"sprite": "",
	})
	_engine = auto_free(load("res://dungeon/combat_engine.gd").new())
	add_child(_engine)
	_init_party(100, 99)


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


func test_melee_basic_hits_only_front_member() -> void:
	_engine.start_combat([{"enemy_id": BRUISER_ID, "count": 1}])
	for _i in range(3):
		_engine.tick()
	# The whole 3 lands on A each tick, unsplit; B is out of reach.
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(91)
	assert_int(_engine.get_member_data(1)["current_hp"]).is_equal(99)


func test_melee_heavy_targets_front_even_when_back_is_weaker() -> void:
	_init_party(100, 50)
	_engine.start_combat([{"enemy_id": BRUISER_ID, "count": 1}])
	_engine.tick()
	_engine.tick()
	# B (50) is weaker than A (94), but only A is in melee reach.
	assert_int(_engine.get_enemy_data(0)["heavy_target"]).is_equal(0)
	_engine.tick()
	_engine.tick()
	# 3 basics of 3 plus the 20 Pound, all on A.
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(71)
	assert_int(_engine.get_member_data(1)["current_hp"]).is_equal(50)


func test_melee_moves_to_next_slot_when_front_falls() -> void:
	_init_party(5, 99)
	_engine.start_combat([{"enemy_id": BRUISER_ID, "count": 1}])
	_engine.tick()
	_engine.tick()
	# A: 5 -> 2 -> KO. The windup that starts this tick locks B, now in front.
	assert_bool(_engine.get_member_data(0)["is_ko"]).is_true()
	assert_int(_engine.get_member_data(1)["current_hp"]).is_equal(99)
	assert_int(_engine.get_enemy_data(0)["heavy_target"]).is_equal(1)
	_engine.tick()
	_engine.tick()
	# One basic of 3, then the 20 Pound.
	assert_int(_engine.get_member_data(1)["current_hp"]).is_equal(76)


func test_incoming_heavy_damage_is_zero_before_windup() -> void:
	_engine.start_combat([{"enemy_id": BRUISER_ID, "count": 1}])
	_engine.tick()
	# heavy_in 3 is still above windup 2.
	assert_int(_engine.get_incoming_heavy_damage(0)).is_equal(0)
	assert_float(_engine.get_windup_progress(0)).is_equal(-1.0)


func test_incoming_heavy_damage_counts_locked_target_during_windup() -> void:
	_engine.start_combat([{"enemy_id": BRUISER_ID, "count": 1}])
	_engine.tick()
	_engine.tick()
	assert_int(_engine.get_incoming_heavy_damage(0)).is_equal(20)
	assert_int(_engine.get_incoming_heavy_damage(1)).is_equal(0)
	assert_float(_engine.get_windup_progress(0)).is_between(0.0, 1.0)
	_engine.tick()
	assert_int(_engine.get_incoming_heavy_damage(0)).is_equal(20)


func test_incoming_heavy_damage_clears_after_hit_lands() -> void:
	_engine.start_combat([{"enemy_id": BRUISER_ID, "count": 1}])
	for _i in range(4):
		_engine.tick()
	assert_int(_engine.get_incoming_heavy_damage(0)).is_equal(0)
	assert_float(_engine.get_windup_progress(0)).is_equal(-1.0)


func test_incoming_heavy_damage_sums_two_enemies_on_one_target() -> void:
	set_catalog_entry(RecipeResolver.enemies, LUNGER_ID, _melee_fixture("Lunger", 10000, 3))
	_engine.start_combat([{"enemy_id": LUNGER_ID, "count": 2}])
	# Slot 0 locks at tick 1 (heavy_in 3), slot 1 at tick 3 (6 -> 3); slot 0
	# lands at tick 4, so after tick 3 both are winding up on A.
	for _i in range(3):
		_engine.tick()
	assert_int(_engine.get_incoming_heavy_damage(0)).is_equal(40)
	assert_int(_engine.get_incoming_heavy_damage(1)).is_equal(0)


func test_incoming_heavy_damage_ignores_dead_enemy() -> void:
	set_catalog_entry(RecipeResolver.enemies, FRAGILE_ID, _melee_fixture("Fragile", 5, 2))
	_engine.start_combat([{"enemy_id": FRAGILE_ID, "count": 1}, {"enemy_id": BRUISER_ID, "count": 1}])
	_engine.tick()
	_engine.tick()
	# Fragile (slot 0) locked A at tick 2. Each member deals max(1 / 2, 1) = 1 to
	# each enemy, so Fragile goes 5 -> 3 -> 1 -> dead at tick 3.
	assert_int(_engine.get_incoming_heavy_damage(0)).is_equal(20)
	_engine.tick()
	assert_bool(_engine.get_enemy_data(0)["alive"]).is_false()
	assert_int(_engine.get_incoming_heavy_damage(0)).is_equal(0)


func _melee_fixture(enemy_name: String, max_hp: int, windup: int) -> Dictionary:
	return {
		"name": enemy_name,
		"max_hp": max_hp,
		"attack_type": "melee",
		"attack": 3,
		"heavy_attack": {"name": "Lunge", "interval": 4, "windup": windup, "damage": 20},
		"drop_count": {"min": 0, "max": 0},
		"drop_pool": [],
		"sprite": "",
	}


func _init_party(a_hp: int, b_hp: int) -> void:
	var party: Array[Dictionary] = [
		{"name": "A", "max_hp": a_hp, "attack": 1},
		{"name": "B", "max_hp": b_hp, "attack": 1},
	]
	_engine.init_party(party)
