extends TestBase

# PrepPhase: its GameManager connections (GameManager is an autoload that
# outlives every screen, so leaving must take them along) and its dungeon button.

const PREP_PHASE := preload("res://core/prep_phase.tscn")
const MAX_FRAMES := 10


func test_leaving_prep_phase_drops_its_game_manager_connections() -> void:
	var signals: Array[Signal] = [
		GameManager.gold_changed,
		GameManager.blueprint_added,
		GameManager.upgrade_level_changed,
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
	var card: PanelContainer = _card_named(prep, "VBox/TabContainer/Blueprints/BpContent", "Test Blueprint")
	assert_object(card).is_not_null()
	assert_str(card.desc_label.text).is_equal("Unlocks at level 9000")
	assert_bool(card.buy_btn.disabled).is_true()


const UPGRADE_CONTENT := "VBox/TabContainer/Upgrades/UpgradeContent"
const REAGENT_CONTENT := "VBox/TabContainer/Reagents/ReagentContent"


func test_upgrade_card_shows_its_level_next_value_and_next_cost() -> void:
	set_definition(DefinitionLibrary.upgrades, _patience_track())
	GameManager.gold = 100
	GameManager.raise_upgrade_level("__test_patience")
	var prep: Control = auto_free(PREP_PHASE.instantiate())
	add_child(prep)
	var card: PanelContainer = _card_named(prep, UPGRADE_CONTENT, "Test Patience (1/2)")
	assert_object(card).is_not_null()
	assert_str(card.desc_label.text).is_equal("Items wait longer.\nNext: 18s")
	assert_str(card.buy_btn.text).is_equal("20g")
	assert_bool(card.buy_btn.disabled).is_false()


func test_a_maxed_upgrade_card_cannot_be_bought() -> void:
	set_definition(DefinitionLibrary.upgrades, _patience_track())
	GameManager.gold = 100
	GameManager.raise_upgrade_level("__test_patience")
	GameManager.raise_upgrade_level("__test_patience")
	var prep: Control = auto_free(PREP_PHASE.instantiate())
	add_child(prep)
	var card: PanelContainer = _card_named(prep, UPGRADE_CONTENT, "Test Patience (2/2)")
	assert_object(card).is_not_null()
	assert_str(card.desc_label.text).is_equal("Items wait longer.\nMax level")
	assert_str(card.buy_btn.text).is_equal("Max")
	assert_bool(card.buy_btn.disabled).is_true()


func test_an_upgrade_level_below_its_shop_level_shows_its_unlock_level() -> void:
	var track := _patience_track()
	track.levels[0].min_shop_level = 9000
	set_definition(DefinitionLibrary.upgrades, track)
	GameManager.gold = 100
	var prep: Control = auto_free(PREP_PHASE.instantiate())
	add_child(prep)
	var card: PanelContainer = _card_named(prep, UPGRADE_CONTENT, "Test Patience (0/2)")
	assert_str(card.desc_label.text).is_equal("Items wait longer.\nUnlocks at level 9000")
	assert_bool(card.buy_btn.disabled).is_true()


func test_a_dungeon_only_reagent_says_where_it_is_found_and_cannot_be_bought() -> void:
	var ice := ReagentDefinition.new()
	ice.id = "__test_ice"
	ice.name = "Test Ice"
	ice.description = "Cold."
	set_definition(DefinitionLibrary.reagents, ice)
	var reward := ReagentReward.new()
	reward.reagent = ice
	var cave := DungeonDefinition.new()
	cave.id = "__test_cave"
	cave.name = "Test Cave"
	cave.reagent_rewards = [reward]
	set_definition(DefinitionLibrary.dungeons, cave)
	var prep: Control = auto_free(PREP_PHASE.instantiate())
	add_child(prep)
	var card: PanelContainer = _card_named(prep, REAGENT_CONTENT, "Test Ice (x0)")
	assert_str(card.desc_label.text).is_equal("Cold.\nFound in: Test Cave")
	assert_str(card.buy_btn.text).is_equal("Dungeon only")
	assert_bool(card.buy_btn.disabled).is_true()


func test_the_contracts_tab_shows_the_planned_offers() -> void:
	for contract: ContractDefinition in DefinitionLibrary.contracts.values().duplicate():
		var moved: ContractDefinition = contract.duplicate()
		moved.min_shop_level = 9999
		set_definition(DefinitionLibrary.contracts, moved)
	var item := ItemDefinition.new()
	item.id = "__test_contract_item"
	item.name = "Test Item"
	set_definition(DefinitionLibrary.items, item)
	var entry := WeightedItem.new()
	entry.item = item
	var crate := CrateDefinition.new()
	crate.id = "__test_contract_crate"
	crate.pool = [entry]
	set_definition(DefinitionLibrary.crates, crate)
	var requirement := OrderTemplate.new()
	requirement.item = item
	var contract := ContractDefinition.new()
	contract.id = "__test_contract"
	contract.name = "Test Contract"
	contract.giver = CustomerDefinition.new()
	contract.requirements = [requirement]
	set_definition(DefinitionLibrary.contracts, contract)
	var prep: Control = auto_free(PREP_PHASE.instantiate())
	add_child(prep)
	var titles: Array[String] = []
	for label: Node in prep.get_node("%ContractsPanel").find_children("TitleLabel", "Label", true, false):
		titles.append(label.text)
	assert_array(titles).is_equal(["Test Contract"])


func test_prep_tabs_are_touch_sized_and_all_visible_at_portrait_width() -> void:
	var prep: Control = auto_free(PREP_PHASE.instantiate())
	add_child(prep)
	await get_tree().process_frame
	var tabs: TabContainer = prep.get_node("%TabContainer")
	var layout: VBoxContainer = prep.get_node("%VBox")
	var bar := tabs.get_tab_bar()
	# Xvfb can report the whole display instead of this app's window.
	prep.call("apply_safe_area", Rect2i(0, 0, 1280, 1024), Transform2D.IDENTITY, "Linux")
	await get_tree().process_frame
	assert_vector(layout.position).is_equal(Vector2(48, 48))
	assert_vector(layout.size).is_equal(prep.get_viewport_rect().size - Vector2(96, 96))
	assert_int(bar.get_theme_font_size("font_size")).is_greater_equal(32)
	assert_int(tabs.get_tab_count()).is_equal(5)
	for index in tabs.get_tab_count():
		var rect := bar.get_tab_rect(index)
		assert_bool(rect.size.x >= 120.0).is_true()
		assert_bool(rect.size.y >= 120.0).is_true()
		assert_bool(rect.position.x >= 0.0 and rect.end.x <= bar.size.x).is_true()


func test_prep_applies_a_simulated_display_safe_area_with_48px_padding() -> void:
	var prep: Control = auto_free(PREP_PHASE.instantiate())
	add_child(prep)
	await get_tree().process_frame
	var viewport_size := prep.get_viewport_rect().size
	var inset_area := Rect2i(80, 120, int(viewport_size.x) - 160, int(viewport_size.y) - 220)
	prep.call("apply_safe_area", inset_area, Transform2D.IDENTITY, "Android")
	await get_tree().process_frame
	var layout: VBoxContainer = prep.get_node("%VBox")
	var tabs: TabContainer = prep.get_node("%TabContainer")
	tabs.current_tab = 1
	var item := ItemDefinition.new()
	item.name = "Test Item"
	var requirement := OrderTemplate.new()
	requirement.item = item
	var offer := ContractDefinition.new()
	offer.name = "Test Contract"
	offer.giver = CustomerDefinition.new()
	offer.requirements = [requirement]
	var offer_plan := SessionPlan.new()
	offer_plan.contract_offers = [offer]
	var panel: Control = prep.get_node("%ContractsPanel")
	panel.setup(offer_plan)
	await get_tree().process_frame
	assert_vector(layout.position).is_equal(Vector2(128, 168))
	assert_vector(layout.size).is_equal(viewport_size - Vector2(256, 316))
	var bar := tabs.get_tab_bar()
	assert_bool(bar.global_position.y >= layout.global_position.y).is_true()
	for index in tabs.get_tab_count():
		var rect := bar.get_tab_rect(index)
		assert_bool(rect.end.x <= bar.size.x).is_true()
	assert_bool(panel.global_position.x >= layout.global_position.x).is_true()
	assert_bool(panel.global_position.x + panel.size.x <= layout.global_position.x + layout.size.x).is_true()
	var card: PanelContainer = panel.get_node("%Offers").get_child(0)
	assert_bool(card.global_position.x >= layout.global_position.x).is_true()
	assert_bool(card.global_position.x + card.size.x <= layout.global_position.x + layout.size.x).is_true()
	assert_bool(card.global_position.y >= bar.global_position.y + bar.size.y).is_true()


func _patience_track() -> UpgradeDefinition:
	var track := UpgradeDefinition.new()
	track.id = "__test_patience"
	track.name = "Test Patience"
	track.description = "Items wait longer."
	track.effect = "despawn_time"
	for pair: Array in [[10, 15.0], [20, 18.0]]:
		var level := UpgradeLevel.new()
		level.cost = pair[0]
		level.value = pair[1]
		track.levels.append(level)
	return track


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


func _card_named(prep: Control, content_path: String, card_name: String) -> PanelContainer:
	var content: VBoxContainer = prep.get_node(content_path)
	for child in content.get_children():
		if child.is_queued_for_deletion():
			continue
		if child.name_label.text == card_name:
			return child
	return null
