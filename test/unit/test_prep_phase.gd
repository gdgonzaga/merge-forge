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
