extends TestBase

# Tests for DefinitionLibrary and the shipped .tres definitions. Content checks
# loop over whatever ships, so they hold for any content set.


const USE_TARGETS: Array[String] = ["party-individual", "enemy-individual", "enemy-all"]
const UPGRADE_EFFECTS: Array[String] = ["grid_size", "despawn_time", "crate_discount"]


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
	for customer in DefinitionLibrary.get_all_customers():
		for order in customer.orders:
			assert_object(order.item).override_failure_message("%s has an order with no item" % customer.id).is_not_null()
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
