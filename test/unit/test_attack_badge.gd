extends TestBase

const BADGE_SCENE := preload("res://dungeon/attack_badge.tscn")

func test_attack_badge_initializes_empty_and_sets_type() -> void:
	var badge = BADGE_SCENE.instantiate()
	add_child(badge)
	badge.set_attack_type("melee")
	assert_float(badge.get_fill_progress()).is_equal(0.0)

	badge.set_fill_progress(0.5, false, 0)
	assert_float(badge.get_fill_progress()).is_equal_approx(0.5, 0.01)

	badge.set_empty()
	assert_float(badge.get_fill_progress()).is_equal(0.0)
	badge.queue_free()

func test_attack_badge_crit_tinting() -> void:
	var badge = BADGE_SCENE.instantiate()
	add_child(badge)
	badge.set_fill_progress(0.75, true, 0)
	assert_bool(badge.is_crit_active()).is_true()
	badge.queue_free()

func test_attack_badge_play_glow_pulse() -> void:
	var badge = BADGE_SCENE.instantiate()
	add_child(badge)
	badge.play_glow_pulse()
	# Ensure method runs cleanly without error
	assert_object(badge).is_not_null()
	badge.queue_free()
