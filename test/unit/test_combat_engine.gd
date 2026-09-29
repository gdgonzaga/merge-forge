extends TestBase

# Combat rules: every attack winds up before it lands, crits wind up longer and
# hit harder, melee hits the front unit and missile the weakest, targets lock
# when a windup starts, and the incoming-damage read-out views use. Fixture
# enemies have huge HP so no encounter ends mid-test; ticks are driven by hand,
# never by the engine's timer. Crit chances are 0 or 1, so nothing is random.
# Party index is slot order: A (0) is the front member.

const ENGINE := preload("res://dungeon/combat_engine.gd")

var _bruiser: EnemyDefinition
var _slow: EnemyDefinition
var _crusher: EnemyDefinition
var _archer: EnemyDefinition
var _fragile: EnemyDefinition
var _engine: Node


func before_test() -> void:
	super.before_test()
	_bruiser = _enemy("Bruiser", 10000, "melee", 3, 1, 0.0)
	_slow = _enemy("Slow", 10000, "melee", 3, 2, 0.0)
	_crusher = _enemy("Crusher", 10000, "melee", 3, 1, 1.0)
	_archer = _enemy("Archer", 10000, "missile", 3, 1, 0.0)
	_fragile = _enemy("Fragile", 50, "melee", 3, 2, 0.0)
	_engine = auto_free(load("res://dungeon/combat_engine.gd").new())
	add_child(_engine)
	_init_party(100, 99)


func test_attack_lands_when_its_windup_ends() -> void:
	_engine.start_combat(_spawns([_slow]))
	_engine.tick()
	# Windup 2: nothing lands on the first tick.
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(100)
	_engine.tick()
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(97)
	# The next windup started right after the hit.
	assert_bool(_engine.is_winding_up(ENGINE.SIDE_ENEMY, 0)).is_true()


func test_crit_winds_up_twice_as_long_and_hits_four_times_harder() -> void:
	_engine.start_combat(_spawns([_crusher]))
	_engine.tick()
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(100)
	_engine.tick()
	# 3 x 4 = 12, after 1 x 2 = 2 ticks.
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(88)


func test_crit_windup_uses_custom_ticks_when_set() -> void:
	var custom_enemy := _enemy("Custom", 10000, "melee", 5, 1, 1.0)
	custom_enemy.crit_windup = 3
	_engine.start_combat(_spawns([custom_enemy]))
	_engine.tick()
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(100)
	_engine.tick()
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(100)
	_engine.tick()
	# 5 x 4 = 20 damage lands on tick 3
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(80)


func test_crit_windup_falls_back_to_double_when_zero() -> void:
	var fallback_enemy := _enemy("Fallback", 10000, "melee", 5, 2, 1.0)
	fallback_enemy.crit_windup = 0
	_engine.start_combat(_spawns([fallback_enemy]))
	for _i in range(3):
		_engine.tick()
		assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(100)
	_engine.tick()
	# 2 * 2 = 4 ticks, 5 x 4 = 20 damage
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(80)


func test_crit_sprite_exposed_in_unit_data() -> void:
	var custom_enemy := _enemy("Custom", 10000, "melee", 5, 1, 1.0)
	var tex := PlaceholderTexture2D.new()
	custom_enemy.crit_sprite = tex
	_engine.start_combat(_spawns([custom_enemy]))
	assert_object(_engine.get_enemy_data(0)["crit_sprite"]).is_same(tex)



func test_melee_hits_only_the_front_member() -> void:
	_engine.start_combat(_spawns([_bruiser]))
	for _i in range(3):
		_engine.tick()
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(91)
	assert_int(_engine.get_member_data(1)["current_hp"]).is_equal(99)


func test_missile_hits_only_the_weakest_member() -> void:
	_engine.start_combat(_spawns([_archer]))
	for _i in range(2):
		_engine.tick()
	# B (99) is weaker than A (100) and stays so.
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(100)
	assert_int(_engine.get_member_data(1)["current_hp"]).is_equal(93)


func test_target_stays_locked_after_healing() -> void:
	_archer = _enemy("Archer", 10000, "missile", 3, 2, 0.0)
	_engine.party_members[1]["current_hp"] = 50
	_engine.start_combat(_spawns([_archer]))
	# B (50) is locked in; A drops to 80 and B heals to 90, making A the weakest.
	_engine.party_members[0]["current_hp"] = 80
	_engine.apply_effect(1, _effect("heal", 40, 0))
	_engine.tick()
	_engine.tick()
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(80)
	assert_int(_engine.get_member_data(1)["current_hp"]).is_equal(87)


func test_heal_restores_hp_up_to_max() -> void:
	_engine.party_members[0]["current_hp"] = 50
	_engine.apply_effect(0, _effect("heal", 30, 0))
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(80)
	_engine.apply_effect(0, _effect("heal", 30, 0))
	assert_int(_engine.get_member_data(0)["current_hp"]).is_equal(100)


func test_windup_retargets_when_its_target_falls() -> void:
	_bruiser = _enemy("Bruiser", 10000, "melee", 5, 1, 0.0)
	_init_party(5, 99)
	_engine.start_combat(_spawns([_slow, _bruiser]))
	_engine.tick()
	# The Bruiser KOs A; the Slow one, halfway through a windup on A, moves to B.
	assert_bool(_engine.get_member_data(0)["is_ko"]).is_true()
	assert_int(_engine.get_enemy_data(0)["target"]).is_equal(1)
	_engine.tick()
	# Slow's 3 and the Bruiser's 5 both land on B.
	assert_int(_engine.get_member_data(1)["current_hp"]).is_equal(91)


func test_party_melee_hits_the_front_enemy() -> void:
	_init_single_attacker(10, "melee", 0.0)
	_engine.start_combat(_spawns([_bruiser, _fragile]))
	_engine.tick()
	assert_int(_engine.get_enemy_data(0)["current_hp"]).is_equal(9990)
	assert_int(_engine.get_enemy_data(1)["current_hp"]).is_equal(50)


func test_party_missile_hits_the_weakest_enemy() -> void:
	_init_single_attacker(10, "missile", 0.0)
	_engine.start_combat(_spawns([_bruiser, _fragile]))
	_engine.tick()
	assert_int(_engine.get_enemy_data(0)["current_hp"]).is_equal(10000)
	assert_int(_engine.get_enemy_data(1)["current_hp"]).is_equal(40)


func test_party_crit_multiplies_the_buffed_attack() -> void:
	_init_single_attacker(10, "melee", 1.0)
	_engine.start_combat(_spawns([_bruiser]))
	_engine.apply_effect(0, _effect("buff_attack", 5, 5))
	_engine.tick()
	_engine.tick()
	# (10 + 5) x 4 = 60.
	assert_int(_engine.get_enemy_data(0)["current_hp"]).is_equal(9940)


func test_incoming_damage_sums_enemies_on_one_member() -> void:
	_engine.start_combat(_spawns([_bruiser, _crusher]))
	# Both melee, so both aim at A: 3 plus a 3 x 4 crit.
	assert_int(_engine.get_incoming_damage(0)).is_equal(15)
	assert_int(_engine.get_incoming_damage(1)).is_equal(0)


func test_incoming_damage_ignores_dead_enemy() -> void:
	_fragile = _enemy("Fragile", 1, "melee", 3, 2, 0.0)
	_engine.start_combat(_spawns([_fragile, _bruiser]))
	assert_int(_engine.get_incoming_damage(0)).is_equal(6)
	# The party's melee hits kill Fragile before its windup ends.
	_engine.tick()
	assert_bool(_engine.get_enemy_data(0)["alive"]).is_false()
	assert_int(_engine.get_incoming_damage(0)).is_equal(3)


func test_windup_progress_only_while_winding_up_in_combat() -> void:
	_engine.start_combat(_spawns([_slow]))
	assert_float(_engine.get_windup_progress(ENGINE.SIDE_ENEMY, 0, 0.0)).is_between(0.0, 1.0)
	_engine.stop_combat()
	assert_float(_engine.get_windup_progress(ENGINE.SIDE_ENEMY, 0, 0.0)).is_equal(-1.0)


func test_winning_an_encounter_clears_party_windups() -> void:
	_fragile = _enemy("Fragile", 1, "melee", 3, 2, 0.0)
	_engine.start_combat(_spawns([_fragile]))
	_engine.tick()
	assert_bool(_engine.is_winding_up(ENGINE.SIDE_PARTY, 0)).is_false()
	assert_bool(_engine.is_winding_up(ENGINE.SIDE_PARTY, 1)).is_false()



func _init_single_attacker(attack: int, attack_type: String, crit_chance: float) -> void:
	var party: Array[PartyMemberDefinition] = [_member("A", 100, attack, attack_type, crit_chance)]
	_engine.init_party(party)


func _init_party(a_hp: int, b_hp: int) -> void:
	var party: Array[PartyMemberDefinition] = [
		_member("A", a_hp, 1, "melee", 0.0),
		_member("B", b_hp, 1, "melee", 0.0),
	]
	_engine.init_party(party)


func _member(member_name: String, max_hp: int, attack: int, attack_type: String, crit_chance: float) -> PartyMemberDefinition:
	var def := PartyMemberDefinition.new()
	def.id = member_name.to_snake_case()
	def.name = member_name
	def.max_hp = max_hp
	def.attack = attack
	def.attack_type = attack_type
	def.windup = 1
	def.crit_chance = crit_chance
	def.crit_name = "Crit"
	return def


func _enemy(enemy_name: String, max_hp: int, attack_type: String, attack: int, windup: int, crit_chance: float) -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.id = enemy_name.to_snake_case()
	def.name = enemy_name
	def.max_hp = max_hp
	def.attack_type = attack_type
	def.attack = attack
	def.windup = windup
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
