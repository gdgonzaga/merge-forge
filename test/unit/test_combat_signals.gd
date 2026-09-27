extends TestBase

# Verifies the payloads of the signals views animate from: party_attacked,
# enemy_attacked, windup_changed and effect_applied.

const ENGINE := preload("res://dungeon/combat_engine.gd")

var _bruiser: EnemyDefinition
var _crusher: EnemyDefinition
var _fragile: EnemyDefinition
var _engine: Node


func before_test() -> void:
	super.before_test()
	_bruiser = _enemy("Bruiser", 10000, 0.0)
	_crusher = _enemy("Crusher", 10000, 1.0)
	_fragile = _enemy("Fragile", 50, 0.0)
	_engine = auto_free(load("res://dungeon/combat_engine.gd").new())
	add_child(_engine)
	var party: Array[PartyMemberDefinition] = [
		_member("Fighter", 10, "melee"),
		_member("Healer", 8, "missile"),
	]
	_engine.init_party(party)


func test_party_attacked_carries_target_damage_and_crit() -> void:
	var events: Array[Array] = []
	_engine.party_attacked.connect(func(idx: int, target: int, dmg: int, is_crit: bool) -> void:
		events.append([idx, target, dmg, is_crit])
	)
	_engine.start_combat(_spawns([_bruiser, _fragile]))
	_engine.tick()
	# Fighter (melee) hits the front enemy; Healer (missile) the weakest one.
	assert_array(events).is_equal([[0, 0, 10, false], [1, 1, 8, false]])


func test_enemy_attacked_carries_target_damage_and_crit() -> void:
	var events: Array[Array] = []
	_engine.enemy_attacked.connect(func(idx: int, target: int, dmg: int, is_crit: bool) -> void:
		events.append([idx, target, dmg, is_crit])
	)
	_engine.start_combat(_spawns([_bruiser, _crusher]))
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
	_engine.start_combat(_spawns([_crusher]))
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
	_engine.apply_effect(0, _effect("heal", 15, 0))
	_engine.apply_effect(1, _effect("buff_attack", 5, 3))

	assert_int(events.size()).is_equal(2)
	assert_int(events[0]["m_idx"]).is_equal(0)
	assert_str(events[0]["etype"]).is_equal("heal")
	assert_int(events[0]["amount"]).is_equal(15)

	assert_int(events[1]["m_idx"]).is_equal(1)
	assert_str(events[1]["etype"]).is_equal("buff_attack")
	assert_int(events[1]["amount"]).is_equal(5)


func _member(member_name: String, attack: int, attack_type: String) -> PartyMemberDefinition:
	var def := PartyMemberDefinition.new()
	def.id = member_name.to_snake_case()
	def.name = member_name
	def.max_hp = 100
	def.attack = attack
	def.attack_type = attack_type
	def.windup = 1
	def.crit_name = "Crit"
	return def


func _enemy(enemy_name: String, max_hp: int, crit_chance: float) -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.id = enemy_name.to_snake_case()
	def.name = enemy_name
	def.max_hp = max_hp
	def.attack_type = "melee"
	def.attack = 6
	def.windup = 1
	def.crit_chance = crit_chance
	def.crit_name = "Crit"
	return def


func _spawns(enemies: Array[EnemyDefinition]) -> Array[EnemySpawn]:
	var spawns: Array[EnemySpawn] = []
	for enemy in enemies:
		var spawn := EnemySpawn.new()
		spawn.enemy = enemy
		spawns.append(spawn)
	return spawns


func _effect(type: String, value: int, duration: int) -> EffectDefinition:
	var effect := EffectDefinition.new()
	effect.type = type
	effect.value = value
	effect.duration = duration
	return effect
