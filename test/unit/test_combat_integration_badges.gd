extends TestBase

const ENGINE_SCRIPT := preload("res://dungeon/combat_engine.gd")
const PRESENTER_SCRIPT := preload("res://dungeon/combat_presenter.gd")
const LINES_SCRIPT := preload("res://dungeon/combat_lines.gd")
const PARTY_SCENE := preload("res://dungeon/party_member.tscn")
const ENEMY_SCENE := preload("res://dungeon/enemy_display.tscn")

func test_combat_badge_gauge_advances_and_launches_on_attack() -> void:
	var engine = ENGINE_SCRIPT.new()
	add_child(engine)

	var presenter = PRESENTER_SCRIPT.new()
	add_child(presenter)

	var lines = LINES_SCRIPT.new()
	add_child(lines)

	var vfx = Control.new()
	add_child(vfx)

	var party_member = PARTY_SCENE.instantiate()
	add_child(party_member)
	var member_def = PartyMemberDefinition.new()
	member_def.name = "Knight"
	member_def.attack = 10
	member_def.max_hp = 50
	member_def.windup = 1
	member_def.attack_type = "melee"
	member_def.crit_chance = 0.0
	party_member.setup(member_def, 0)

	var enemy_display = ENEMY_SCENE.instantiate()
	add_child(enemy_display)
	enemy_display.setup({
		"name": "Slime",
		"sprite": null,
		"attack": 5,
		"max_hp": 30,
		"current_hp": 30,
		"windup": 2,
		"attack_type": "melee",
		"crit_chance": 0.0
	})

	presenter.setup(engine, [party_member], vfx, lines)
	presenter.set_enemy_units([enemy_display])

	engine.init_party([member_def])
	var enemy_def = EnemyDefinition.new()
	enemy_def.name = "Slime"
	enemy_def.max_hp = 30
	enemy_def.attack = 5
	enemy_def.windup = 2
	enemy_def.attack_type = "melee"
	enemy_def.crit_chance = 0.0
	var spawn = EnemySpawn.new()
	spawn.enemy = enemy_def
	spawn.count = 1

	engine.start_combat([spawn])

	# Initially gauge is at 0 or small start progress
	assert_float(party_member.get_badge().get_fill_progress()).is_between(0.0, 1.0)

	# Simulate windup tick
	presenter._process(0.1)
	assert_bool(lines.has_active_flights()).is_false()

	# Tick engine to trigger party attack
	engine.tick()

	# Attack launched: lines has active flight, party member gauge cleared
	assert_bool(lines.has_active_flights()).is_true()
	assert_float(party_member.get_badge().get_fill_progress()).is_equal(0.0)

	# Advance flight time past duration
	lines.advance_flights(0.3)
	assert_bool(lines.has_active_flights()).is_false()

	# Stop combat and cleanup
	engine.stop_combat()
	engine.queue_free()
	presenter.queue_free()
	lines.queue_free()
	vfx.queue_free()
	party_member.queue_free()
	enemy_display.queue_free()
