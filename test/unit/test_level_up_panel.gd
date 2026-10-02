extends TestBase

const PANEL := preload("res://ui/level_up_panel.tscn")


func test_panel_hides_when_no_level_was_gained() -> void:
	var panel: VBoxContainer = auto_free(PANEL.instantiate())
	add_child(panel)
	panel.setup(3, 3)
	assert_bool(panel.visible).is_false()


func test_panel_names_the_new_level_and_its_unlocks() -> void:
	var blueprint := BlueprintDefinition.new()
	blueprint.id = "__test_bp"
	blueprint.name = "Test Blueprint"
	blueprint.min_shop_level = 9000
	set_definition(DefinitionLibrary.blueprints, blueprint)
	var panel: VBoxContainer = auto_free(PANEL.instantiate())
	add_child(panel)
	panel.setup(8999, 9000)
	assert_bool(panel.visible).is_true()
	assert_str(panel.get_node("%LevelBanner").text).is_equal("Level 9000!")
	assert_str(panel.get_node("%UnlockList").text).contains("Test Blueprint")


func test_an_unlock_outside_the_town_is_not_named() -> void:
	var away := BlueprintDefinition.new()
	away.id = "__test_away_bp"
	away.name = "Away Blueprint"
	away.min_shop_level = 9000
	set_definition(DefinitionLibrary.blueprints, away)
	test_town.blueprints.erase(away)
	var panel: VBoxContainer = auto_free(PANEL.instantiate())
	add_child(panel)
	panel.setup(8999, 9000)
	assert_str(panel.get_node("%UnlockList").text).not_contains("Away Blueprint")
