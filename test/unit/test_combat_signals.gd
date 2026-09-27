extends TestBase

# Verifies the payloads of the signals views animate from: party_attacked,
# enemy_attacked, windup_changed and effect_applied.

const ENGINE := preload("res://dungeon/combat_engine.gd")

const BRUISER_ID := "__test_signal_bruiser"
const CRUSHER_ID := "__test_signal_crusher"
const FRAGILE_ID := "__test_signal_fragile"

var _engine: Node


func before_test() -> void:
	super.before_test()
	set_catalog_entry(RecipeResolver.enemies, BRUISER_ID, _enemy("Bruiser", 10000, 0.0))
	set_catalog_entry(RecipeResolver.enemies, CRUSHER_ID, _enemy("Crusher", 10000, 1.0))
	set_catalog_entry(RecipeResolver.enemies, FRAGILE_ID, _enemy("Fragile", 50, 0.0))
	_engine = auto_free(load("res://dungeon/combat_engine.gd").new())
	add_child(_engine)
	var party: Array[Dictionary] = [
		_member("Fighter", 10, "melee"),
		_member("Healer", 8, "missile"),
	]
	_engine.init_party(party)


func test_party_attacked_carries_target_damage_and_crit() -> void:
	var events: Array[Array] = []
	_engine.party_attacked.connect(func(idx: int, target: int, dmg: int, is_crit: bool) -> void:
		events.append([idx, target, dmg, is_crit])
	)
	_engine.start_combat([{"enemy_id": BRUISER_ID, "count": 1}, {"enemy_id": FRAGILE_ID, "count": 1}])
	_engine.tick()
	# Fighter (melee) hits the front enemy; Healer (missile) the weakest one.
	assert_array(events).is_equal([[0, 0, 10, false], [1, 1, 8, false]])


func test_enemy_attacked_carries_target_damage_and_crit() -> void:
	var events: Array[Array] = []
	_engine.enemy_attacked.connect(func(idx: int, target: int, dmg: int, is_crit: bool) -> void:
		events.append([idx, target, dmg, is_crit])
	)
	_engine.start_combat([{"enemy_id": BRUISER_ID, "count": 1}, {"enemy_id": CRUSHER_ID, "count": 1}])
	_engine.tick()
	assert_array(events).is_equal([[0, 0, 6, false]])
	_engine.tick()
	# The Crusher's 2-tick crit lands for 6 x 4.
	assert_array(events).is_equal([[0, 0, 6, false], [0, 0, 6, false], [1, 0, 24, true]])


func test_windup_changed_on_start_landing_and_restart() -> void:
	var events: Array[Array] = []
	_engine.windup_changed.connect(func(side: int, idx: int, target: int, is_crit: bool) -> void:
		if side == ENGINE.SIDE_ENEMY:
			events.append([idx, target, is_crit])
	)
	_engine.start_combat([{"enemy_id": CRUSHER_ID, "count": 1}])
	assert_array(events).is_equal([[0, 0, true]])
	_engine.tick()
	assert_int(events.size()).is_equal(1)
	_engine.tick()
	assert_array(events).is_equal([[0, 0, true], [0, -1, false], [0, 0, true]])


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


func _member(member_name: String, attack: int, attack_type: String) -> Dictionary:
	return {
		"name": member_name,
		"max_hp": 100,
		"attack": attack,
		"attack_type": attack_type,
		"windup": 1,
		"crit_chance": 0.0,
		"crit_name": "Crit",
	}


func _enemy(enemy_name: String, max_hp: int, crit_chance: float) -> Dictionary:
	return {
		"name": enemy_name,
		"max_hp": max_hp,
		"attack_type": "melee",
		"attack": 6,
		"windup": 1,
		"crit_chance": crit_chance,
		"crit_name": "Crit",
		"drop_count": {"min": 0, "max": 0},
		"drop_pool": [],
		"sprite": "",
	}
