extends TestBase

# Tests for DefinitionLibrary and the shipped .tres definitions. Content checks
# loop over whatever ships, so they hold for any content set.


const USE_TARGETS: Array[String] = ["party-individual", "enemy-individual", "enemy-all"]
const UPGRADE_EFFECTS: Array[String] = ["grid_size", "despawn_time", "crate_discount", "shelf_slots", "forecast_detail", "order_price", "contract_slots"]
const ATTACK_TYPES: Array[String] = ["melee", "missile"]
const PERK_EFFECTS: Array[String] = ["starting_gold", "xp_multiplier", "crate_discount", "starting_blueprint", "shelf_bonus", "loyalty_multiplier"]


# A copy-pasted file that kept its source's id would shadow it in the catalog.
func test_every_definition_id_matches_its_file_name() -> void:
	var catalogs := DefinitionLibrary.get_catalogs()
	for folder: String in catalogs:
		var catalog: Dictionary = catalogs[folder]
		assert_bool(catalog.is_empty()).override_failure_message("no %s loaded" % folder).is_false()
		for id: String in catalog:
			if folder == "towns" and id == TEST_TOWN_ID:
				continue
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


func test_upgrade_tracks_have_levels_with_rising_costs() -> void:
	for upgrade in DefinitionLibrary.get_all_upgrades():
		assert_bool(upgrade.levels.is_empty()).override_failure_message("%s has no levels" % upgrade.id).is_false()
		var previous := 0
		for level in upgrade.levels:
			assert_object(level).override_failure_message("%s has an empty level" % upgrade.id).is_not_null()
			assert_int(level.cost).override_failure_message("%s level costs do not rise" % upgrade.id).is_greater(previous)
			previous = level.cost


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


func test_contracts_are_found_by_id_and_listed_in_id_order() -> void:
	var second := ContractDefinition.new()
	second.id = "__test_b"
	var first := ContractDefinition.new()
	first.id = "__test_a"
	set_definition(DefinitionLibrary.contracts, second)
	set_definition(DefinitionLibrary.contracts, first)
	assert_bool(DefinitionLibrary.get_contract("__test_b") == second).is_true()
	assert_object(DefinitionLibrary.get_contract("__missing_contract")).is_null()
	var contracts := DefinitionLibrary.get_all_contracts()
	assert_str(contracts[0].id).is_equal("__test_a")
	assert_str(contracts[1].id).is_equal("__test_b")


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
		assert_int(customer.weight).override_failure_message("%s weight" % customer.id).is_greater(0)
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


# A new player (no blueprints, level 1) must be dealt a full session in every town.
func test_a_fresh_game_deals_a_full_session_in_every_town() -> void:
	var size := DefinitionLibrary.get_shop_rules().session_size
	for town in _shipped_towns():
		reset_game_state()
		GameManager.current_town = town.id
		var dealt: Array = preload("res://autoloads/customer_generator.gd").new().generate(
			town.customers, size, 1, 1, RecipeResolver.is_craftable)
		assert_int(dealt.size()).override_failure_message("%s deals %d" % [town.id, dealt.size()]).is_equal(size)


# Every catalog whose definitions carry min_shop_level.
func _gated() -> Array[Resource]:
	var gated: Array[Resource] = []
	for catalog: Dictionary in DefinitionLibrary.get_catalogs().values():
		for definition: Resource in catalog.values():
			if "min_shop_level" in definition:
				gated.append(definition)
	return gated


func test_level_gates_are_within_the_curve() -> void:
	var max_level := DefinitionLibrary.get_shop_rules().max_level
	for definition in _gated():
		assert_bool(definition.min_shop_level >= 1 and definition.min_shop_level <= max_level) \
			.override_failure_message("%s unlocks at level %d" % [definition.id, definition.min_shop_level]).is_true()


func test_a_blueprint_never_unlocks_before_its_dependencies() -> void:
	for blueprint in DefinitionLibrary.get_all_blueprints():
		for dep in blueprint.dependencies:
			assert_bool(dep.min_shop_level <= blueprint.min_shop_level) \
				.override_failure_message("%s (Lv %d) needs %s (Lv %d)" % [blueprint.id, blueprint.min_shop_level, dep.id, dep.min_shop_level]).is_true()


# A dungeon must never open before the player can make something that heals there.
func test_a_healing_item_is_craftable_when_each_dungeon_opens() -> void:
	var rules := DefinitionLibrary.get_shop_rules()
	for town in _shipped_towns():
		for dungeon in DefinitionLibrary.get_town_dungeons(town):
			reset_game_state()
			GameManager.current_town = town.id
			GameManager.shop_xp = rules.xp_for_level(dungeon.min_shop_level)
			for blueprint in town.blueprints:
				if blueprint.min_shop_level <= dungeon.min_shop_level:
					GameManager.add_blueprint(blueprint.id)
			var heals := false
			for item: ItemDefinition in DefinitionLibrary.get_all_items().values():
				if item.dungeon_usable and item.effect != null and item.effect.type == "heal" and RecipeResolver.is_craftable(item):
					heals = true
			assert_bool(heals).override_failure_message("%s opens in %s with nothing craftable that heals" % [dungeon.id, town.id]).is_true()


func test_unlocks_between_is_exclusive_below_and_inclusive_above() -> void:
	set_definition(DefinitionLibrary.crates, _gated_crate("__test_l2", 2))
	set_definition(DefinitionLibrary.blueprints, _gated_blueprint("__test_l3", 3))
	set_definition(DefinitionLibrary.blueprints, _gated_blueprint("__test_l4", 4))
	assert_array(_ids_of(DefinitionLibrary.get_unlocks_between(2, 3, GameManager.get_current_town()))).is_equal(["__test_l3"])


func test_unlocks_between_spans_every_skipped_level() -> void:
	set_definition(DefinitionLibrary.blueprints, _gated_blueprint("__test_l4", 4))
	set_definition(DefinitionLibrary.crates, _gated_crate("__test_l2", 2))
	set_definition(DefinitionLibrary.blueprints, _gated_blueprint("__test_l3", 3))
	assert_array(_ids_of(DefinitionLibrary.get_unlocks_between(1, 4, GameManager.get_current_town()))).is_equal(["__test_l2", "__test_l3", "__test_l4"])


func test_no_level_gained_unlocks_nothing() -> void:
	assert_array(DefinitionLibrary.get_unlocks_between(3, 3, GameManager.get_current_town())).is_empty()


func test_contracts_are_well_formed() -> void:
	for contract in DefinitionLibrary.get_all_contracts():
		var id := contract.id
		assert_object(contract.giver).override_failure_message("%s has no giver" % id).is_not_null()
		assert_bool(contract.requirements.is_empty()).override_failure_message("%s asks for nothing" % id).is_false()
		assert_int(contract.sessions_allowed).override_failure_message("%s sessions" % id).is_greater(0)
		assert_int(contract.weight).override_failure_message("%s weight" % id).is_greater(0)
		assert_int(contract.reward_gold).override_failure_message("%s pays no gold" % id).is_greater(0)
		var seen := {}
		for requirement in contract.requirements:
			assert_object(requirement.item).override_failure_message("%s has an empty requirement" % id).is_not_null()
			assert_bool(seen.has(requirement.item.id)).override_failure_message("%s asks for %s twice" % [id, requirement.item.id]).is_false()
			seen[requirement.item.id] = true
			assert_bool(requirement.min_quantity >= 1 and requirement.min_quantity == requirement.max_quantity) \
				.override_failure_message("%s needs %s x%d-%d" % [id, requirement.item.id, requirement.min_quantity, requirement.max_quantity]).is_true()
			assert_bool(requirement.min_quality >= 0 and requirement.min_quality <= ItemDefinition.MAX_QUALITY) \
				.override_failure_message("%s quality %d" % [id, requirement.min_quality]).is_true()
		assert_bool((contract.reward_reagent == null) == (contract.reward_reagent_count <= 0)) \
			.override_failure_message("%s reagent reward without a count, or a count without a reagent" % id).is_true()
		if contract.reward_reagent != null:
			assert_int(contract.reward_reagent.cost).override_failure_message("%s gives a dungeon-only reagent" % id).is_greater(0)
		assert_object(contract.reward_blueprint).override_failure_message("%s gives a blueprint (repeatable)" % id).is_null()


func test_loyalty_tracks_rise_and_give_something() -> void:
	for customer in DefinitionLibrary.get_all_customers():
		var previous := 0
		for reward in customer.loyalty_rewards:
			assert_object(reward).override_failure_message("%s has an empty gift" % customer.id).is_not_null()
			assert_int(reward.points).override_failure_message("%s thresholds don't rise" % customer.id).is_greater(previous)
			previous = reward.points
			assert_str(reward.title).override_failure_message("%s gift %d has no title" % [customer.id, reward.points]).is_not_empty()
			assert_bool(reward.gold > 0 or reward.blueprint != null or reward.reagent != null) \
				.override_failure_message("%s gift %d gives nothing" % [customer.id, reward.points]).is_true()
			assert_bool((reward.reagent == null) == (reward.reagent_count <= 0)) \
				.override_failure_message("%s gift %d reagent/count mismatch" % [customer.id, reward.points]).is_true()


func test_dungeon_reagent_rewards_are_well_formed() -> void:
	for dungeon in DefinitionLibrary.get_all_dungeons():
		for reward in dungeon.reagent_rewards:
			assert_object(reward.reagent).override_failure_message("%s rewards no reagent" % dungeon.id).is_not_null()
			assert_bool(reward.min_count >= 1 and reward.min_count <= reward.max_count) \
				.override_failure_message("%s gives %d-%d" % [dungeon.id, reward.min_count, reward.max_count]).is_true()
			assert_bool(reward.chance > 0.0 and reward.chance <= 1.0) \
				.override_failure_message("%s chance %s" % [dungeon.id, reward.chance]).is_true()


func test_every_dungeon_only_reagent_drops_in_a_dungeon() -> void:
	var dropped := {}
	for dungeon in DefinitionLibrary.get_all_dungeons():
		for reward in dungeon.reagent_rewards:
			dropped[reward.reagent.id] = true
	for reagent in DefinitionLibrary.get_all_reagents():
		if reagent.cost <= 0:
			assert_bool(dropped.has(reagent.id)).override_failure_message("no dungeon drops %s" % reagent.id).is_true()


# A lone option auto-picks, so a dungeon-only variant needs a base result
# unlocked alongside it or the player would spend the reagent without a choice.
func test_a_dungeon_only_variant_always_has_a_base_option_beside_it() -> void:
	for source: ItemDefinition in DefinitionLibrary.get_all_items().values():
		for variant in source.reagent_variants:
			if variant.reagent.cost > 0:
				continue
			var covered := false
			for option in source.merge_results:
				if option.blueprint == null or (variant.blueprint != null and option.blueprint in variant.blueprint.dependencies):
					covered = true
			assert_bool(covered).override_failure_message("%s -> %s can be the only option" % [source.id, variant.result.id]).is_true()


func test_merge_sources_fit_the_choice_popup() -> void:
	for source: ItemDefinition in DefinitionLibrary.get_all_items().values():
		var option_count := source.merge_results.size() + source.reagent_variants.size()
		assert_int(option_count).override_failure_message("%s has %d merge options" % [source.id, option_count]).is_less_equal(4)


func test_every_gated_definition_has_a_name() -> void:
	for definition in _gated():
		assert_str(definition.name).override_failure_message("%s has no name" % definition.id).is_not_empty()


func _gated_crate(id: String, level: int) -> CrateDefinition:
	var crate := CrateDefinition.new()
	crate.id = id
	crate.name = id
	crate.min_shop_level = level
	return crate


func _gated_blueprint(id: String, level: int) -> BlueprintDefinition:
	var blueprint := BlueprintDefinition.new()
	blueprint.id = id
	blueprint.name = id
	blueprint.min_shop_level = level
	return blueprint


func _ids_of(defs: Array) -> Array[String]:
	var ids: Array[String] = []
	for definition: Resource in defs:
		ids.append(definition.id)
	return ids


func test_some_archetype_is_open_at_level_1_in_every_town() -> void:
	for town in _shipped_towns():
		var open := town.customers.filter(
			func(customer: CustomerDefinition) -> bool: return customer.min_shop_level == 1)
		assert_bool(open.is_empty()).override_failure_message("%s opens with no customer" % town.id).is_false()


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


func test_towns_come_back_by_charters_required_then_id() -> void:
	set_definition(DefinitionLibrary.towns, _town_def("__test_late", 9001))
	set_definition(DefinitionLibrary.towns, _town_def("__test_tie_b", -1))
	set_definition(DefinitionLibrary.towns, _town_def("__test_tie_a", -1))
	var towns := DefinitionLibrary.get_all_towns()
	assert_str(towns[0].id).is_equal("__test_tie_a")
	assert_str(towns[1].id).is_equal("__test_tie_b")
	assert_str(towns.back().id).is_equal("__test_late")
	assert_object(DefinitionLibrary.get_town("__test_late")).is_same(towns.back())
	assert_object(DefinitionLibrary.get_town("__missing_town")).is_null()


func test_a_towns_shop_lists_come_back_in_display_order() -> void:
	var town := _town_def("__test_sorted", 0)
	town.crates.assign([_priced_crate("__test_c30", 30), _priced_crate("__test_c10", 10), _priced_crate("__test_b10", 10)])
	town.blueprints.assign([_priced_blueprint("__test_p9", 9), _priced_blueprint("__test_p1", 1)])
	town.dungeons.assign([_dungeon("__test_d9", 9), _dungeon("__test_d2", 2)])
	assert_array(_ids_of(DefinitionLibrary.get_town_crates(town))).is_equal(["__test_b10", "__test_c10", "__test_c30"])
	assert_array(_ids_of(DefinitionLibrary.get_town_blueprints(town))).is_equal(["__test_p1", "__test_p9"])
	assert_array(_ids_of(DefinitionLibrary.get_town_dungeons(town))).is_equal(["__test_d2", "__test_d9"])


func test_a_town_hands_out_its_list_for_a_scoped_catalog() -> void:
	var town := _town_def("__test_lists", 0)
	assert_bool(is_same(town.content("customers"), town.customers)).is_true()
	assert_bool(is_same(town.content("dungeons"), town.dungeons)).is_true()
	assert_array(town.content("items")).is_empty()


func _town_def(id: String, charters_required: int) -> TownDefinition:
	var town := TownDefinition.new()
	town.id = id
	town.name = id
	town.charters_required = charters_required
	return town


func _priced_crate(id: String, cost: int) -> CrateDefinition:
	var crate := CrateDefinition.new()
	crate.id = id
	crate.cost = cost
	return crate


func _priced_blueprint(id: String, cost: int) -> BlueprintDefinition:
	var blueprint := BlueprintDefinition.new()
	blueprint.id = id
	blueprint.cost = cost
	return blueprint


# --- towns ---

# A shop definition no town lists can never be met.
func test_every_shop_definition_belongs_to_a_town() -> void:
	var catalogs := DefinitionLibrary.get_catalogs()
	for folder: String in TownDefinition.SCOPED_CATALOGS:
		for definition: Resource in catalogs[folder].values():
			var listed := false
			for town in DefinitionLibrary.get_all_towns():
				if definition in town.content(folder):
					listed = true
			assert_bool(listed).override_failure_message("%s/%s is in no town" % [folder, definition.id]).is_true()


func test_the_starting_town_needs_no_charter() -> void:
	var start := DefinitionLibrary.get_shop_rules().starting_town
	assert_object(start).is_not_null()
	assert_int(start.charters_required).is_equal(0)


func test_towns_are_well_formed() -> void:
	for town in _shipped_towns():
		assert_str(town.name).override_failure_message("%s has no name" % town.id).is_not_empty()
		assert_bool(town.background is Texture2D).override_failure_message("%s has no background" % town.id).is_true()
		assert_float(town.price_multiplier).override_failure_message("%s price" % town.id).is_greater(0.0)
		assert_int(town.charters_required).override_failure_message("%s charters" % town.id).is_greater_equal(0)
		for folder: String in TownDefinition.SCOPED_CATALOGS:
			for definition: Resource in town.content(folder):
				assert_object(definition).override_failure_message("%s has an empty %s entry" % [town.id, folder]).is_not_null()


# Links out of a town's content must land inside the same town.
func test_town_references_stay_inside_the_town() -> void:
	for town in _shipped_towns():
		for modifier in town.modifiers:
			for customer in modifier.boosted_customers:
				assert_bool(customer in town.customers).override_failure_message("%s boosts %s outside %s" % [modifier.id, customer.id, town.id]).is_true()
			for crate in modifier.affected_crates:
				assert_bool(crate in town.crates).override_failure_message("%s prices %s outside %s" % [modifier.id, crate.id, town.id]).is_true()
		for contract in town.contracts:
			assert_bool(contract.giver in town.customers).override_failure_message("%s's giver is outside %s" % [contract.id, town.id]).is_true()
			if contract.reward_blueprint != null:
				assert_bool(contract.reward_blueprint in town.blueprints).override_failure_message("%s rewards %s outside %s" % [contract.id, contract.reward_blueprint.id, town.id]).is_true()
		for customer in town.customers:
			for reward in customer.loyalty_rewards:
				if reward.blueprint != null:
					assert_bool(reward.blueprint in town.blueprints).override_failure_message("%s gifts %s outside %s" % [customer.id, reward.blueprint.id, town.id]).is_true()
		for dungeon in town.dungeons:
			if dungeon.blueprint_reward != null:
				assert_bool(dungeon.blueprint_reward in town.blueprints).override_failure_message("%s rewards a blueprint outside %s" % [dungeon.id, town.id]).is_true()
		for blueprint in town.blueprints:
			for dep in blueprint.dependencies:
				assert_bool(dep in town.blueprints).override_failure_message("%s needs %s outside %s" % [blueprint.id, dep.id, town.id]).is_true()


# Whatever a town's customers or contracts ask for, its crates, blueprints and
# dungeons (for dungeon-only reagents) can make.
func test_everything_a_town_asks_for_can_be_made_there() -> void:
	for town in _shipped_towns():
		var makeable := _makeable_in(town)
		for customer in town.customers:
			for want in customer.wants:
				assert_bool(makeable.has(want.item.id)).override_failure_message("%s wants %s, unmakeable in %s" % [customer.id, want.item.id, town.id]).is_true()
		for contract in town.contracts:
			for requirement in contract.requirements:
				assert_bool(makeable.has(requirement.item.id)).override_failure_message("%s needs %s, unmakeable in %s" % [contract.id, requirement.item.id, town.id]).is_true()


func _shipped_towns() -> Array[TownDefinition]:
	var shipped: Array[TownDefinition] = []
	for town in DefinitionLibrary.get_all_towns():
		if town.id != TEST_TOWN_ID:
			shipped.append(town)
	return shipped


# Item ids a town can make at some level: what its crates sell, then merges
# gated by its own blueprints (or none), with a reagent bought in prep or
# dropped by one of its dungeons.
func _makeable_in(town: TownDefinition) -> Dictionary:
	var made := {}
	for crate in town.crates:
		for entry in crate.pool:
			made[entry.item.id] = true
	var dropped := {}
	for dungeon in town.dungeons:
		for reward in dungeon.reagent_rewards:
			dropped[reward.reagent.id] = true
	var changed := true
	while changed:
		changed = false
		for source: ItemDefinition in DefinitionLibrary.get_all_items().values():
			if not made.has(source.id):
				continue
			for option in source.merge_results:
				if _open_in(option.blueprint, town) and not made.has(option.result.id):
					made[option.result.id] = true
					changed = true
			for variant in source.reagent_variants:
				var reagent_ok := variant.reagent.cost > 0 or dropped.has(variant.reagent.id)
				if reagent_ok and _open_in(variant.blueprint, town) and not made.has(variant.result.id):
					made[variant.result.id] = true
					changed = true
	return made


func _open_in(blueprint: BlueprintDefinition, town: TownDefinition) -> bool:
	return blueprint == null or blueprint in town.blueprints


func test_perks_are_well_formed() -> void:
	for perk in DefinitionLibrary.get_all_perks():
		assert_str(perk.name).override_failure_message("%s has no name" % perk.id).is_not_empty()
		assert_bool(perk.effect in PERK_EFFECTS).override_failure_message("%s has effect '%s'" % [perk.id, perk.effect]).is_true()
		assert_bool(perk.levels.is_empty()).override_failure_message("%s has no levels" % perk.id).is_false()
		var previous := 0
		for level in perk.levels:
			assert_object(level).override_failure_message("%s has an empty level" % perk.id).is_not_null()
			assert_int(level.cost_points).override_failure_message("%s costs do not rise" % perk.id).is_greater(previous)
			previous = level.cost_points
			assert_float(level.value).override_failure_message("%s value" % perk.id).is_greater(0.0)
			if perk.effect in ["starting_gold", "starting_blueprint", "shelf_bonus"]:
				assert_float(level.value).override_failure_message("%s value is not whole" % perk.id).is_equal(floorf(level.value))


func test_perks_are_found_by_id_and_listed_in_id_order() -> void:
	var second := PerkDefinition.new()
	second.id = "__test_b"
	var first := PerkDefinition.new()
	first.id = "__test_a"
	set_definition(DefinitionLibrary.perks, second)
	set_definition(DefinitionLibrary.perks, first)
	assert_object(DefinitionLibrary.get_perk("__test_b")).is_same(second)
	assert_object(DefinitionLibrary.get_perk("__missing_perk")).is_null()
	var perks := DefinitionLibrary.get_all_perks()
	assert_str(perks[0].id).is_equal("__test_a")
	assert_str(perks[1].id).is_equal("__test_b")
