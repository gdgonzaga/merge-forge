extends TestBase

# Verifies that CombatEngine emits animation signals:
# party_attacked, enemy_attacked, telegraph_changed, and effect_applied.

const BRUTE_ID := "__test_signal_brute"
const BRUISER_ID := "__test_signal_bruiser"

var _engine: Node


func before_test() -> void:
	super.before_test()
	set_catalog_entry(RecipeResolver.enemies, BRUTE_ID, {
		"name": "Brute",
		"max_hp": 10000,
		"attack_type": "missile",
		"attack": 6,
		"heavy_attack": {"name": "Crush", "interval": 4, "windup": 2, "damage": 20},
		"drop_count": {"min": 0, "max": 0},
		"drop_pool": [],
		"sprite": "",
	})
	set_catalog_entry(RecipeResolver.enemies, BRUISER_ID, {
		"name": "Bruiser",
		"max_hp": 10000,
		"attack_type": "melee",
		"attack": 6,
		"heavy_attack": {"name": "Pound", "interval": 4, "windup": 2, "damage": 20},
		"drop_count": {"min": 0, "max": 0},
		"drop_pool": [],
		"sprite": "",
	})
	_engine = auto_free(load("res://dungeon/combat_engine.gd").new())
	add_child(_engine)
	_init_party(100, 90)


func _init_party(hp_a: int, hp_b: int) -> void:
	var party: Array[Dictionary] = [
		{"role": "fighter", "name": "Fighter", "max_hp": hp_a, "attack": 10},
		{"role": "healer", "name": "Healer", "max_hp": hp_b, "attack": 8},
	]
	_engine.init_party(party)


func test_party_attacked_signal_emits_with_targets_and_damage() -> void:
	var events: Array[Dictionary] = []
	_engine.party_attacked.connect(func(idx: int, targets: Array[int], dmg: int):
		events.append({"idx": idx, "targets": targets, "dmg": dmg})
	)
	_engine.start_combat([{"enemy_id": BRUTE_ID, "count": 1}])
	_engine.tick()

	assert_int(events.size()).is_equal(2)
	assert_int(events[0]["idx"]).is_equal(0)
	assert_array(events[0]["targets"]).is_equal([0])
	assert_int(events[0]["dmg"]).is_equal(10)

	assert_int(events[1]["idx"]).is_equal(1)
	assert_array(events[1]["targets"]).is_equal([0])
	assert_int(events[1]["dmg"]).is_equal(8)


func test_enemy_attacked_melee_emits_front_target() -> void:
	var events: Array[Dictionary] = []
	_engine.enemy_attacked.connect(func(e_idx: int, atk_type: String, is_heavy: bool, targets: Array[int], dmg: int):
		events.append({"e_idx": e_idx, "atk_type": atk_type, "is_heavy": is_heavy, "targets": targets, "dmg": dmg})
	)
	_engine.start_combat([{"enemy_id": BRUISER_ID, "count": 1}])
	_engine.tick()

	assert_int(events.size()).is_equal(1)
	assert_int(events[0]["e_idx"]).is_equal(0)
	assert_str(events[0]["atk_type"]).is_equal("melee")
	assert_bool(events[0]["is_heavy"]).is_false()
	assert_array(events[0]["targets"]).is_equal([0])
	assert_int(events[0]["dmg"]).is_equal(6)


func test_enemy_attacked_missile_emits_all_standing_targets() -> void:
	var events: Array[Dictionary] = []
	_engine.enemy_attacked.connect(func(e_idx: int, atk_type: String, is_heavy: bool, targets: Array[int], dmg: int):
		events.append({"e_idx": e_idx, "atk_type": atk_type, "is_heavy": is_heavy, "targets": targets, "dmg": dmg})
	)
	_engine.start_combat([{"enemy_id": BRUTE_ID, "count": 1}])
	_engine.tick()

	assert_int(events.size()).is_equal(1)
	assert_int(events[0]["e_idx"]).is_equal(0)
	assert_str(events[0]["atk_type"]).is_equal("missile")
	assert_bool(events[0]["is_heavy"]).is_false()
	assert_array(events[0]["targets"]).is_equal([0, 1])
	# 6 atk split over 2 members = 3 dmg each
	assert_int(events[0]["dmg"]).is_equal(3)


func test_telegraph_and_heavy_attack_cycle() -> void:
	var telegraph_events: Array[Dictionary] = []
	var attack_events: Array[Dictionary] = []
	_engine.telegraph_changed.connect(func(e_idx: int, t_idx: int, turns: int):
		telegraph_events.append({"e_idx": e_idx, "t_idx": t_idx, "turns": turns})
	)
	_engine.enemy_attacked.connect(func(e_idx: int, atk_type: String, is_heavy: bool, targets: Array[int], dmg: int):
		attack_events.append({"e_idx": e_idx, "is_heavy": is_heavy, "targets": targets, "dmg": dmg})
	)
	_engine.start_combat([{"enemy_id": BRUTE_ID, "count": 1}])

	# Tick 1: heavy_in decrements 4 -> 3 (not <= windup 2). No telegraph yet.
	_engine.tick()
	assert_int(telegraph_events.size()).is_equal(0)

	# Tick 2: heavy_in decrements 3 -> 2 (<= windup 2). Target picked (member 1 is weakest at 90-3=87).
	_engine.tick()
	assert_int(telegraph_events.size()).is_equal(1)
	assert_int(telegraph_events[0]["t_idx"]).is_equal(1)
	assert_int(telegraph_events[0]["turns"]).is_equal(2)

	# Tick 3: heavy_in decrements 2 -> 1. Telegraph updated with 1 turn remaining.
	_engine.tick()
	assert_int(telegraph_events.size()).is_equal(2)
	assert_int(telegraph_events[1]["t_idx"]).is_equal(1)
	assert_int(telegraph_events[1]["turns"]).is_equal(1)

	# Tick 4: heavy lands! heavy_in was 1 -> lands.
	_engine.tick()
	var last_attack: Dictionary = attack_events.back()
	assert_bool(last_attack["is_heavy"]).is_true()
	assert_array(last_attack["targets"]).is_equal([1])
	assert_int(last_attack["dmg"]).is_equal(20)

	# Telegraph reset to -1 target after landing
	var last_telegraph: Dictionary = telegraph_events.back()
	assert_int(last_telegraph["t_idx"]).is_equal(-1)


func test_effect_applied_signal() -> void:
	var events: Array[Dictionary] = []
	_engine.effect_applied.connect(func(m_idx: int, etype: String, amount: int):
		events.append({"m_idx": m_idx, "etype": etype, "amount": amount})
	)
	_engine.apply_effect(0, {"type": "heal", "power": 15})
	_engine.apply_effect(1, {"type": "buff_attack", "power": 5, "duration": 3})

	assert_int(events.size()).is_equal(2)
	assert_int(events[0]["m_idx"]).is_equal(0)
	assert_str(events[0]["etype"]).is_equal("heal")
	assert_int(events[0]["amount"]).is_equal(15)

	assert_int(events[1]["m_idx"]).is_equal(1)
	assert_str(events[1]["etype"]).is_equal("buff_attack")
	assert_int(events[1]["amount"]).is_equal(5)
