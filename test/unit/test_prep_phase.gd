extends TestBase

# PrepPhase: its GameManager connections (GameManager is an autoload that
# outlives every screen, so leaving must take them along) and its dungeon button.

const PREP_PHASE := preload("res://core/prep_phase.tscn")
const MAX_FRAMES := 10


func test_leaving_prep_phase_drops_its_game_manager_connections() -> void:
	var signals: Array[Signal] = [
		GameManager.gold_changed,
		GameManager.blueprint_added,
		GameManager.upgrade_added,
		GameManager.reagent_count_changed,
		GameManager.shop_level_changed,
	]
	var before: Array[int] = _connection_counts(signals)
	var prep := PREP_PHASE.instantiate()
	add_child(prep)
	# Guards against a vacuous pass: the screen does listen while it is up.
	assert_array(_connection_counts(signals)).is_equal(_plus_one(before))
	prep.queue_free()
	var frames := 0
	while is_instance_valid(prep) and frames < MAX_FRAMES:
		await get_tree().process_frame
		frames += 1
	assert_bool(is_instance_valid(prep)).is_false()
	assert_array(_connection_counts(signals)).is_equal(before)


func test_dungeon_button_enters_the_first_dungeon_to_unlock() -> void:
	var dungeon := DungeonDefinition.new()
	dungeon.id = "__test_dungeon"
	dungeon.min_shop_level = -9001
	set_definition(DefinitionLibrary.dungeons, dungeon)
	var entered: Array[String] = []
	var on_enter := func(dungeon_id: String) -> void: entered.append(dungeon_id)
	EventBus.prep_enter_dungeon.connect(on_enter)
	var prep: Control = auto_free(PREP_PHASE.instantiate())
	add_child(prep)
	var button: Button = prep.get_node("%DungeonBtn")
	var enabled := not button.disabled
	button.pressed.emit()
	EventBus.prep_enter_dungeon.disconnect(on_enter)
	assert_bool(enabled).is_true()
	assert_array(entered).is_equal(["__test_dungeon"])


func test_blueprint_below_its_level_shows_its_unlock_level_and_cannot_be_bought() -> void:
	var blueprint := BlueprintDefinition.new()
	blueprint.id = "__test_bp"
	blueprint.name = "Test Blueprint"
	blueprint.cost = 1
	blueprint.min_shop_level = 9000
	set_definition(DefinitionLibrary.blueprints, blueprint)
	var prep: Control = auto_free(PREP_PHASE.instantiate())
	add_child(prep)
	var card: PanelContainer = _card_named(prep, "Test Blueprint")
	assert_object(card).is_not_null()
	assert_str(card.desc_label.text).is_equal("Unlocks at level 9000")
	assert_bool(card.buy_btn.disabled).is_true()


func _connection_counts(signals: Array[Signal]) -> Array[int]:
	var counts: Array[int] = []
	for sig in signals:
		counts.append(sig.get_connections().size())
	return counts


func _plus_one(counts: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for count in counts:
		result.append(count + 1)
	return result


func _card_named(prep: Control, card_name: String) -> PanelContainer:
	var content: VBoxContainer = prep.get_node("VBox/TabContainer/Blueprints/BpContent")
	for child in content.get_children():
		if child.is_queued_for_deletion():
			continue
		if child.name_label.text == card_name:
			return child
	return null
