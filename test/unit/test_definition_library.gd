extends TestBase

# Tests for DefinitionLibrary and the shipped .tres definitions. Content checks
# loop over whatever ships, so they hold for any content set.


const USE_TARGETS: Array[String] = ["party-individual", "enemy-individual", "enemy-all"]
const UPGRADE_EFFECTS: Array[String] = ["grid_size", "despawn_time", "crate_discount"]
const ATTACK_TYPES: Array[String] = ["melee", "missile"]


# A copy-pasted file that kept its source's id would shadow it in the catalog.
func test_every_definition_id_matches_its_file_name() -> void:
	var catalogs := DefinitionLibrary.get_catalogs()
	for folder: String in catalogs:
		var catalog: Dictionary = catalogs[folder]
		assert_bool(catalog.is_empty()).override_failure_message("no %s loaded" % folder).is_false()
		for id: String in catalog:
			var file_id: String = (catalog[id] as Resource).resource_path.get_file().get_basename()
			assert_str(id).override_failure_message("%s/%s.tres has id '%s'" % [folder, file_id, id]).is_equal(file_id)


func test_definition_library_loads_items() -> void:
	for item_id: String in DefinitionLibrary.get_all_items():
		var item_def := DefinitionLibrary.get_item(item_id)
		assert_str(item_def.name).is_not_empty()
		assert_bool(item_def.sprite is Texture2D).override_failure_message("%s has no sprite" % item_id).is_true()


func test_usable_items_have_an_effect_and_a_known_target() -> void:
	for item_def: ItemDefinition in DefinitionLibrary.get_all_items().values():
		if not item_def.dungeon_usable:
			continue
		assert_object(item_def.effect).override_failure_message("%s has no effect" % item_def.id).is_not_null()
		assert_str(item_def.effect.type).override_failure_message("%s effect has no type" % item_def.id).is_not_empty()
		assert_bool(item_def.dungeon_use_target in USE_TARGETS) \
			.override_failure_message("%s has target '%s'" % [item_def.id, item_def.dungeon_use_target]).is_true()


# Dungeon drops are ready to use: raw materials never drop.
func test_enemy_drops_are_dungeon_usable_items() -> void:
	for enemy_def: EnemyDefinition in DefinitionLibrary.get_all_enemies().values():
		for entry in enemy_def.drop_pool:
			assert_object(entry.item).override_failure_message("%s has an empty drop" % enemy_def.id).is_not_null()
			assert_bool(entry.item.dungeon_usable) \
				.override_failure_message("%s drops non-usable '%s'" % [enemy_def.id, entry.item.id]).is_true()


# Broken references load as null instead of failing, so check every link.
func test_item_merge_links_are_complete() -> void:
	for item_def: ItemDefinition in DefinitionLibrary.get_all_items().values():
		for option in item_def.merge_results:
			assert_object(option.result).override_failure_message("%s has an empty merge result" % item_def.id).is_not_null()
		for variant in item_def.reagent_variants:
			assert_object(variant.result).override_failure_message("%s has an empty variant" % item_def.id).is_not_null()
			assert_object(variant.reagent).override_failure_message("%s variant has no reagent" % item_def.id).is_not_null()


func test_shop_links_are_complete() -> void:
	for crate in DefinitionLibrary.get_all_crates():
		for entry in crate.pool:
			assert_object(entry.item).override_failure_message("crate %s has an empty entry" % crate.id).is_not_null()
	for blueprint in DefinitionLibrary.get_all_blueprints():
		for dep in blueprint.dependencies:
			assert_object(dep).override_failure_message("%s has an empty dependency" % blueprint.id).is_not_null()


func test_dungeon_links_are_complete() -> void:
	for dungeon: DungeonDefinition in DefinitionLibrary.dungeons.values():
		assert_int(dungeon.encounters.size()).is_equal(dungeon.encounter_points.size())
		for encounter in dungeon.encounters:
			for spawn in encounter.spawns:
				assert_object(spawn.enemy).override_failure_message("%s spawns no enemy" % dungeon.id).is_not_null()


func test_upgrades_have_a_known_effect() -> void:
	for upgrade in DefinitionLibrary.get_all_upgrades():
		assert_bool(upgrade.effect in UPGRADE_EFFECTS) \
			.override_failure_message("%s has effect '%s'" % [upgrade.id, upgrade.effect]).is_true()


func test_party_members_have_valid_stats() -> void:
	var slots: Array[int] = []
	for member in DefinitionLibrary.get_all_party_members():
		_assert_unit_stats(member)
		assert_bool(member.slot_order in slots) \
			.override_failure_message("%s reuses slot_order %d" % [member.id, member.slot_order]).is_false()
		slots.append(member.slot_order)


func test_enemies_have_valid_stats() -> void:
	for enemy: EnemyDefinition in DefinitionLibrary.get_all_enemies().values():
		_assert_unit_stats(enemy)
		assert_bool(enemy.min_drops <= enemy.max_drops) \
			.override_failure_message("%s has min_drops > max_drops" % enemy.id).is_true()


func test_party_members_come_back_in_slot_order() -> void:
	var back := PartyMemberDefinition.new()
	back.id = "__test_back"
	back.slot_order = 9001
	var front := PartyMemberDefinition.new()
	front.id = "__test_front"
	front.slot_order = -9001
	set_definition(DefinitionLibrary.party, back)
	set_definition(DefinitionLibrary.party, front)
	var members := DefinitionLibrary.get_all_party_members()
	assert_str(members.front().id).is_equal("__test_front")
	assert_str(members.back().id).is_equal("__test_back")


func test_dungeons_come_back_in_unlock_order() -> void:
	set_definition(DefinitionLibrary.dungeons, _dungeon("__test_late", 9001))
	set_definition(DefinitionLibrary.dungeons, _dungeon("__test_tie_b", -9001))
	set_definition(DefinitionLibrary.dungeons, _dungeon("__test_tie_a", -9001))
	var dungeons := DefinitionLibrary.get_all_dungeons()
	assert_str(dungeons[0].id).is_equal("__test_tie_a")
	assert_str(dungeons[1].id).is_equal("__test_tie_b")
	assert_str(dungeons.back().id).is_equal("__test_late")


func test_definition_library_missing_returns_null() -> void:
	assert_object(DefinitionLibrary.get_item("__nonexistent__")).is_null()
	assert_object(DefinitionLibrary.get_party_member("__nonexistent__")).is_null()
	assert_object(DefinitionLibrary.get_enemy("__nonexistent__")).is_null()


func _dungeon(id: String, min_shop_level: int) -> DungeonDefinition:
	var dungeon := DungeonDefinition.new()
	dungeon.id = id
	dungeon.min_shop_level = min_shop_level
	return dungeon


func test_customer_archetypes_are_well_formed() -> void:
	for customer in DefinitionLibrary.get_all_customers():
		assert_bool(customer.wants.is_empty()).override_failure_message("%s wants nothing" % customer.id).is_false()
		assert_bool(customer.min_orders >= 1 and customer.min_orders <= customer.max_orders) \
			.override_failure_message("%s has orders %d-%d" % [customer.id, customer.min_orders, customer.max_orders]).is_true()
		assert_float(customer.price_multiplier).override_failure_message("%s price" % customer.id).is_greater(0.0)
		var seen := {}
		for want in customer.wants:
			assert_object(want.item).override_failure_message("%s has an empty want" % customer.id).is_not_null()
			assert_bool(seen.has(want.item.id)).override_failure_message("%s wants %s twice" % [customer.id, want.item.id]).is_false()
			seen[want.item.id] = true
			assert_bool(want.min_quantity >= 1 and want.min_quantity <= want.max_quantity) \
				.override_failure_message("%s wants %s x%d-%d" % [customer.id, want.item.id, want.min_quantity, want.max_quantity]).is_true()


func test_shop_rules_are_defined() -> void:
	var rules := DefinitionLibrary.get_shop_rules()
	assert_object(rules).is_not_null()
	assert_int(rules.session_size).is_greater(0)
	assert_int(rules.level_xp_base).is_greater(0)
	assert_float(rules.level_xp_exponent).is_greater_equal(0.0)
	assert_int(rules.max_level).is_greater(1)
	assert_float(rules.xp_per_gold).is_greater(0.0)
	assert_float(rules.streak_step).is_greater_equal(0.0)
	assert_float(rules.streak_cap).is_greater_equal(0.0)


# A new player (no blueprints, level 1) must be dealt a full session.
func test_a_fresh_game_deals_a_full_session() -> void:
	var size := DefinitionLibrary.get_shop_rules().session_size
	var dealt: Array = preload("res://shop/customer_generator.gd").new().generate(
		DefinitionLibrary.get_all_customers(), size, 1, 1, RecipeResolver.is_craftable)
	assert_int(dealt.size()).is_equal(size)


# Party members and enemies share the combat stat fields CombatEngine reads.
func _assert_unit_stats(unit: Resource) -> void:
	var id: String = unit.id
	assert_str(unit.name).override_failure_message("%s has no name" % id).is_not_empty()
	assert_bool(unit.sprite is Texture2D).override_failure_message("%s has no sprite" % id).is_true()
	assert_bool(unit.max_hp > 0).override_failure_message("%s has max_hp %d" % [id, unit.max_hp]).is_true()
	assert_bool(unit.attack >= 0).override_failure_message("%s has attack %d" % [id, unit.attack]).is_true()
	assert_bool(unit.windup >= 1).override_failure_message("%s has windup %d" % [id, unit.windup]).is_true()
	assert_bool(unit.crit_chance >= 0.0 and unit.crit_chance <= 1.0) \
		.override_failure_message("%s has crit_chance %s" % [id, unit.crit_chance]).is_true()
	assert_bool(unit.attack_type in ATTACK_TYPES) \
		.override_failure_message("%s has attack_type '%s'" % [id, unit.attack_type]).is_true()
