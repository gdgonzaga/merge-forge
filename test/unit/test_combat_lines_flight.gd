extends TestBase

const LINES_SCRIPT := preload("res://dungeon/combat_lines.gd")
const PARTY_SCENE := preload("res://dungeon/party_member.tscn")
const ENEMY_SCENE := preload("res://dungeon/enemy_display.tscn")

func test_launch_attack_tracks_flight_until_duration_expires() -> void:
	var lines = LINES_SCRIPT.new()
	add_child(lines)

	var party_member = PARTY_SCENE.instantiate()
	add_child(party_member)
	var def = PartyMemberDefinition.new()
	def.name = "Warrior"
	def.attack_type = "melee"
	def.max_hp = 50
	party_member.setup(def, 0)

	var enemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.setup({"sprite": null, "attack_type": "melee", "current_hp": 30, "max_hp": 30})

	lines.setup(null, [party_member], 0.25)
	lines.set_enemy_units([enemy])

	assert_bool(lines.has_active_flights()).is_false()
	lines.launch_attack(0, 0, 0, 15, false, 0.25)
	assert_bool(lines.has_active_flights()).is_true()

	lines.advance_flights(0.1)
	assert_bool(lines.has_active_flights()).is_true()

	lines.advance_flights(0.2)
	assert_bool(lines.has_active_flights()).is_false()

	lines.queue_free()
	party_member.queue_free()
	enemy.queue_free()
