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

func test_attack_badge_crit_icon_swapping() -> void:
	var badge = BADGE_SCENE.instantiate()
	add_child(badge)
	badge.set_attack_type("melee")
	var normal_tex = badge.get_icon_texture()
	assert_object(normal_tex).is_not_null()

	var custom_crit = PlaceholderTexture2D.new()
	badge.set_crit_icon(custom_crit)

	# Normal windup keeps normal texture
	badge.set_fill_progress(0.3, false, 0)
	assert_object(badge.get_icon_texture()).is_same(normal_tex)

	# Crit windup swaps to custom_crit
	badge.set_fill_progress(0.6, true, 0)
	assert_object(badge.get_icon_texture()).is_same(custom_crit)

	# Emptying reverts to normal texture
	badge.set_empty()
	assert_object(badge.get_icon_texture()).is_same(normal_tex)
	badge.queue_free()

func test_attack_badge_crit_icon_fallback_when_null() -> void:
	var badge = BADGE_SCENE.instantiate()
	add_child(badge)
	badge.set_attack_type("missile")
	var normal_tex = badge.get_icon_texture()

	badge.set_crit_icon(null)
	badge.set_fill_progress(0.5, true, 0)
	assert_object(badge.get_icon_texture()).is_same(normal_tex)
	badge.queue_free()

