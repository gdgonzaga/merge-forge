extends TestBase

# Tests for DefinitionLibrary and .tres definition resources.
# Verifies that items, party members, enemies, and effects load
# as valid Resource instances with Texture2D sprites.


func test_definition_library_loads_items() -> void:
	var item_def: ItemDefinition = DefinitionLibrary.get_item("healing_potion")
	assert_object(item_def).is_not_null()
	assert_str(item_def.id).is_equal("healing_potion")
	assert_str(item_def.name).is_equal("Healing Potion")
	assert_bool(item_def.dungeon_usable).is_true()
	assert_object(item_def.effect).is_not_null()
	assert_str(item_def.effect.type).is_equal("heal")
	assert_int(item_def.effect.value).is_equal(40)
	assert_object(item_def.sprite).is_not_null()
	assert_bool(item_def.sprite is Texture2D).is_true()


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
