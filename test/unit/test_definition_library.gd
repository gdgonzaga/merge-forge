extends TestBase

# Tests for DefinitionLibrary and .tres definition resources.
# Verifies that items, party members, enemies, and effects load
# as valid Resource instances with Texture2D sprites.


const USE_TARGETS: Array[String] = ["party-individual", "enemy-individual", "enemy-all"]


func test_definition_library_loads_items() -> void:
	var items: Dictionary = DefinitionLibrary.get_all_items()
	assert_bool(items.is_empty()).is_false()
	for item_id: String in items:
		var item_def: ItemDefinition = items[item_id]
		assert_str(item_def.id).is_equal(item_id)
		assert_str(item_def.name).is_not_empty()
		assert_bool(item_def.sprite is Texture2D).override_failure_message("%s has no sprite" % item_id).is_true()


func test_usable_items_have_an_effect_and_a_known_target() -> void:
	for item_def: ItemDefinition in DefinitionLibrary.get_all_items().values():
		if not item_def.dungeon_usable:
			continue
		assert_object(item_def.effect).override_failure_message("%s has no effect" % item_def.id).is_not_null()
		assert_str(item_def.effect.type).is_not_empty()
		assert_bool(item_def.dungeon_use_target in USE_TARGETS) \
			.override_failure_message("%s has target '%s'" % [item_def.id, item_def.dungeon_use_target]).is_true()


# Dungeon drops are ready to use: raw materials never drop.
func test_enemy_drops_are_defined_dungeon_usable_items() -> void:
	for enemy_def: EnemyDefinition in DefinitionLibrary.get_all_enemies().values():
		for entry: Dictionary in enemy_def.drop_pool:
			var drop_id: String = entry.get("item_id", "")
			var item_def: ItemDefinition = DefinitionLibrary.get_item(drop_id)
			assert_object(item_def).override_failure_message("%s drops unknown '%s'" % [enemy_def.id, drop_id]).is_not_null()
			assert_bool(item_def.dungeon_usable) \
				.override_failure_message("%s drops non-usable '%s'" % [enemy_def.id, drop_id]).is_true()


func test_definition_library_loads_party_members() -> void:
	var members: Array[PartyMemberDefinition] = DefinitionLibrary.get_all_party_members()
	assert_int(members.size()).is_equal(3)
	var fighter: PartyMemberDefinition = DefinitionLibrary.get_party_member("fighter")
	assert_object(fighter).is_not_null()
	assert_str(fighter.id).is_equal("fighter")
	assert_int(fighter.max_hp).is_equal(120)
	assert_object(fighter.sprite).is_not_null()
	assert_bool(fighter.sprite is Texture2D).is_true()


func test_definition_library_loads_enemies() -> void:
	var slime: EnemyDefinition = DefinitionLibrary.get_enemy("slime")
	assert_object(slime).is_not_null()
	assert_str(slime.id).is_equal("slime")
	assert_int(slime.max_hp).is_equal(90)
	assert_str(slime.attack_type).is_equal("melee")
	assert_object(slime.sprite).is_not_null()
	assert_bool(slime.sprite is Texture2D).is_true()


func test_definition_library_missing_returns_null() -> void:
	assert_object(DefinitionLibrary.get_item("__nonexistent__")).is_null()
	assert_object(DefinitionLibrary.get_party_member("__nonexistent__")).is_null()
	assert_object(DefinitionLibrary.get_enemy("__nonexistent__")).is_null()


func test_combat_engine_applies_effect_definition() -> void:
	var engine: Node = auto_free(load("res://dungeon/combat_engine.gd").new())
	add_child(engine)
	var test_party: Array[Dictionary] = [{"name": "Hero", "max_hp": 100, "attack": 10, "attack_type": "melee", "windup": 1, "crit_chance": 0.0, "crit_name": "Crit"}]
	engine.init_party(test_party)
	# Reduce HP to 50
	engine.party_members[0]["current_hp"] = 50

	var heal_effect := EffectDefinition.new()
	heal_effect.type = "heal"
	heal_effect.value = 30

	var sig_data := {"received": false, "idx": -1, "type": "", "amt": 0}
	engine.effect_applied.connect(func(idx: int, etype: String, amt: int) -> void:
		sig_data["received"] = true
		sig_data["idx"] = idx
		sig_data["type"] = etype
		sig_data["amt"] = amt
	)

	engine.apply_effect(0, heal_effect)
	assert_int(engine.get_member_data(0)["current_hp"]).is_equal(80)
	assert_bool(sig_data["received"]).is_true()
	assert_int(sig_data["idx"]).is_equal(0)
	assert_str(sig_data["type"]).is_equal("heal")
	assert_int(sig_data["amt"]).is_equal(30)
