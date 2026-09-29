extends TestBase

func test_badge_assets_exist_and_have_correct_dimensions() -> void:
	var bg = load("res://resources/sprites/ui/badge_bg.png")
	var melee = load("res://resources/sprites/ui/badge_icon_melee.png")
	var missile = load("res://resources/sprites/ui/badge_icon_missile.png")

	assert_object(bg).is_not_null()
	assert_object(melee).is_not_null()
	assert_object(missile).is_not_null()

	assert_vector(bg.get_size()).is_equal(Vector2(48, 48))
	assert_vector(melee.get_size()).is_equal(Vector2(48, 48))
	assert_vector(missile.get_size()).is_equal(Vector2(48, 48))
