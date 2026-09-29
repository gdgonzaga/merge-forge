extends TestBase

const PARTY_SCENE := preload("res://dungeon/party_member.tscn")
const ENEMY_SCENE := preload("res://dungeon/enemy_display.tscn")

func test_party_member_exposes_badge_helpers() -> void:
	var member = PARTY_SCENE.instantiate()
	add_child(member)
	var def = PartyMemberDefinition.new()
	def.name = "Hero"
	def.attack_type = "melee"
	def.max_hp = 50
	var crit_tex = PlaceholderTexture2D.new()
	def.crit_sprite = crit_tex
	member.setup(def, 0)

	assert_object(member.get_badge()).is_not_null()
	member.set_windup_progress(0.7, false)
	assert_float(member.get_badge().get_fill_progress()).is_equal_approx(0.7, 0.01)
	assert_object(member.get_badge().get_icon_texture()).is_not_same(crit_tex)

	member.set_windup_progress(0.7, true)
	assert_object(member.get_badge().get_icon_texture()).is_same(crit_tex)

	member.clear_badge_gauge()
	assert_float(member.get_badge().get_fill_progress()).is_equal(0.0)
	assert_object(member.get_badge().get_icon_texture()).is_not_same(crit_tex)
	member.queue_free()

func test_enemy_display_exposes_badge_helpers() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	var crit_tex = PlaceholderTexture2D.new()
	enemy.setup({"sprite": null, "attack_type": "missile", "current_hp": 30, "max_hp": 30, "crit_sprite": crit_tex})

	assert_object(enemy.get_badge()).is_not_null()
	enemy.set_windup_progress(0.4, false)
	assert_float(enemy.get_badge().get_fill_progress()).is_equal_approx(0.4, 0.01)
	assert_object(enemy.get_badge().get_icon_texture()).is_not_same(crit_tex)

	enemy.set_windup_progress(0.4, true)
	assert_object(enemy.get_badge().get_icon_texture()).is_same(crit_tex)

	enemy.clear_badge_gauge()
	assert_float(enemy.get_badge().get_fill_progress()).is_equal(0.0)
	assert_object(enemy.get_badge().get_icon_texture()).is_not_same(crit_tex)
	enemy.queue_free()

