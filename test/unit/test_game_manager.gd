extends TestBase

# Characterization tests for the GameManager autoload.
# Applies writing-godot-tests: public contract (methods/properties/signals),
# invariants, boundary inputs, and a save/load round-trip.
# before_test() (autoload reset) is inherited from TestBase.


# --- Defaults (public properties) ---

func test_default_state() -> void:
	assert_int(GameManager.gold).is_equal(50)
	assert_int(GameManager.shop_xp).is_equal(0)
	assert_array(GameManager.unlocked_blueprints).is_empty()
	assert_dict(GameManager.reagent_inventory).is_empty()
	assert_dict(GameManager.upgrade_levels).is_empty()
	assert_dict(GameManager.regular_loyalty).is_empty()
	assert_array(GameManager.active_contracts).is_empty()
	assert_array(GameManager.shop_shelf_state).is_empty()
	assert_int(GameManager.grid_cols).is_equal(5)
	assert_int(GameManager.grid_rows).is_equal(5)
	assert_bool(GameManager.seen_intro).is_false()
	assert_bool(GameManager.debug_mode).is_false()
	assert_int(GameManager.charters).is_equal(0)
	assert_int(GameManager.charter_points).is_equal(0)
	assert_dict(GameManager.perk_levels).is_empty()
	assert_dict(GameManager.codex).is_empty()
	assert_int(GameManager.codex_stars_credited).is_equal(0)
	assert_array(GameManager.codex_families_credited).is_empty()


# --- add_gold ---

func test_add_gold_increases_and_emits_gold_changed() -> void:
	var seen: Array = []
	GameManager.gold_changed.connect(func(v: int) -> void: seen.append(v))
	GameManager.add_gold(10)
	assert_int(GameManager.gold).is_equal(60)
	assert_array(seen).has_size(1)
	assert_int(int(seen[0])).is_equal(60)


# --- deduct_gold ---

func test_deduct_gold_success_returns_true_and_decreases() -> void:
	var ok := GameManager.deduct_gold(20)
	assert_bool(ok).is_true()
	assert_int(GameManager.gold).is_equal(30)


func test_deduct_gold_exact_amount_to_zero() -> void:
	var ok := GameManager.deduct_gold(50)
	assert_bool(ok).is_true()
	assert_int(GameManager.gold).is_equal(0)


func test_deduct_gold_insufficient_returns_false_no_change_no_emit() -> void:
	var emitted := false
	GameManager.gold_changed.connect(func(_v: int) -> void: emitted = true)
	var ok := GameManager.deduct_gold(999)
	assert_bool(ok).is_false()
	assert_int(GameManager.gold).is_equal(50)
	assert_bool(emitted).is_false()


# Invariant: gold can never go negative through deduct_gold.
func test_deduct_gold_cannot_make_gold_negative() -> void:
	var _ok := GameManager.deduct_gold(10_000)
	assert_int(GameManager.gold).is_greater_equal(0)


# --- shop XP and level ---

func test_add_shop_xp_increases_and_emits() -> void:
	var seen: Array[int] = []
	var on_xp := func(xp: int) -> void: seen.append(xp)
	GameManager.shop_xp_changed.connect(on_xp)
	GameManager.add_shop_xp(40)
	GameManager.shop_xp_changed.disconnect(on_xp)
	assert_int(GameManager.shop_xp).is_equal(40)
	assert_array(seen).is_equal([40])


# Invariant: XP never goes down.
func test_add_shop_xp_ignores_zero_and_negative_amounts() -> void:
	GameManager.add_shop_xp(30)
	var seen: Array[int] = []
	var on_xp := func(xp: int) -> void: seen.append(xp)
	GameManager.shop_xp_changed.connect(on_xp)
	assert_int(GameManager.add_shop_xp(0)).is_equal(0)
	assert_int(GameManager.add_shop_xp(-100)).is_equal(0)
	GameManager.shop_xp_changed.disconnect(on_xp)
	assert_int(GameManager.shop_xp).is_equal(30)
	assert_array(seen).is_empty()


func test_level_signal_fires_once_per_level_crossed() -> void:
	set_definition(DefinitionLibrary.shop_rules, _curve_rules())
	var levels: Array[int] = []
	var on_level := func(level: int) -> void: levels.append(level)
	GameManager.shop_level_changed.connect(on_level)
	GameManager.add_shop_xp(99)  # 99: still level 1
	GameManager.add_shop_xp(501)  # 600: level 4, skipping 2 and 3
	GameManager.add_shop_xp(10_000)  # past the cap: level 5
	GameManager.shop_level_changed.disconnect(on_level)
	assert_array(levels).is_equal([2, 3, 4, 5])
	assert_int(GameManager.get_shop_level()).is_equal(5)


func test_meets_level_at_its_boundary() -> void:
	set_definition(DefinitionLibrary.shop_rules, _curve_rules())
	GameManager.shop_xp = 299  # level 2
	assert_bool(GameManager.meets_level(3)).is_false()
	GameManager.shop_xp = 300  # level 3
	assert_bool(GameManager.meets_level(3)).is_true()


# Base 100, exponent 1, max 5: levels 2-5 start at 100, 300, 600, 1000.
func _curve_rules() -> ShopRulesDefinition:
	var rules := ShopRulesDefinition.new()
	rules.id = "default"
	rules.level_xp_base = 100
	rules.level_xp_exponent = 1.0
	rules.max_level = 5
	return rules


# --- blueprints (idempotent add) ---

func test_add_blueprint_appends_and_emits() -> void:
	var seen: Array = []
	GameManager.blueprint_added.connect(func(id: String) -> void: seen.append(id))
	GameManager.add_blueprint("bp_1")
	assert_array(GameManager.unlocked_blueprints).contains("bp_1")
	assert_array(seen).contains("bp_1")


func test_add_blueprint_duplicate_is_noop() -> void:
	GameManager.add_blueprint("bp_1")
	var emitted := false
	GameManager.blueprint_added.connect(func(_id: String) -> void: emitted = true)
	GameManager.add_blueprint("bp_1")
	assert_bool(emitted).is_false()
	assert_array(GameManager.unlocked_blueprints).has_size(1)


# --- reagents ---

func test_add_reagent_new_then_increment() -> void:
	GameManager.add_reagent("fire", 2)
	assert_int(int(GameManager.reagent_inventory["fire"])).is_equal(2)
	GameManager.add_reagent("fire", 3)
	assert_int(int(GameManager.reagent_inventory["fire"])).is_equal(5)


func test_consume_reagent_success_decrements() -> void:
	GameManager.add_reagent("fire", 2)
	var ok := GameManager.consume_reagent("fire")
	assert_bool(ok).is_true()
	assert_int(int(GameManager.reagent_inventory["fire"])).is_equal(1)


func test_consume_reagent_absent_returns_false() -> void:
	var ok := GameManager.consume_reagent("missing")
	assert_bool(ok).is_false()


func test_consume_reagent_at_zero_returns_false() -> void:
	GameManager.add_reagent("fire", 1)
	GameManager.consume_reagent("fire")  # now zero
	var ok := GameManager.consume_reagent("fire")
	assert_bool(ok).is_false()


# --- upgrade tracks ---

func test_an_unbought_track_gives_the_default() -> void:
	set_definition(DefinitionLibrary.upgrades, _track("__test_patience", "despawn_time", [15.0, 18.0, 22.0]))
	assert_int(GameManager.get_upgrade_level("__test_patience")).is_equal(0)
	assert_float(GameManager.get_despawn_time()).is_equal(GameManager.DEFAULT_DESPAWN_TIME)


func test_a_bought_level_gives_that_levels_value() -> void:
	set_definition(DefinitionLibrary.upgrades, _track("__test_patience", "despawn_time", [15.0, 18.0, 22.0]))
	GameManager.raise_upgrade_level("__test_patience")
	GameManager.raise_upgrade_level("__test_patience")
	assert_int(GameManager.get_upgrade_level("__test_patience")).is_equal(2)
	assert_float(GameManager.get_despawn_time()).is_equal(18.0)


func test_raising_a_level_announces_the_new_level() -> void:
	set_definition(DefinitionLibrary.upgrades, _track("__test_bulk", "crate_discount", [0.9, 0.8]))
	var seen: Array = []
	var on_level := func(id: String, level: int) -> void: seen.append([id, level])
	GameManager.upgrade_level_changed.connect(on_level)
	GameManager.raise_upgrade_level("__test_bulk")
	GameManager.raise_upgrade_level("__test_bulk")
	GameManager.upgrade_level_changed.disconnect(on_level)
	assert_array(seen).is_equal([["__test_bulk", 1], ["__test_bulk", 2]])
	assert_float(GameManager.get_crate_discount()).is_equal(0.8)


# A track with another effect leaves the value alone.
func test_upgrade_value_only_comes_from_its_effect() -> void:
	set_definition(DefinitionLibrary.upgrades, _track("__test_bulk", "crate_discount", [0.5]))
	GameManager.raise_upgrade_level("__test_bulk")
	assert_float(GameManager.get_despawn_time()).is_equal(GameManager.DEFAULT_DESPAWN_TIME)


func test_new_effects_default_until_bought() -> void:
	var rules := ShopRulesDefinition.new()
	rules.id = "default"
	rules.forecast_customers = 4
	set_definition(DefinitionLibrary.shop_rules, rules)
	set_definition(DefinitionLibrary.upgrades, _track("__test_shelf", "shelf_slots", [2.0]))
	set_definition(DefinitionLibrary.upgrades, _track("__test_signage", "order_price", [1.05]))
	set_definition(DefinitionLibrary.upgrades, _track("__test_crier", "forecast_detail", [5.0, 0.0]))
	assert_int(GameManager.get_shelf_slots()).is_equal(0)
	assert_float(GameManager.get_order_price_multiplier()).is_equal(1.0)
	assert_int(GameManager.get_forecast_customers()).is_equal(4)
	GameManager.raise_upgrade_level("__test_shelf")
	GameManager.raise_upgrade_level("__test_signage")
	GameManager.raise_upgrade_level("__test_crier")
	assert_int(GameManager.get_shelf_slots()).is_equal(2)
	assert_float(GameManager.get_order_price_multiplier()).is_equal(1.05)
	assert_int(GameManager.get_forecast_customers()).is_equal(5)
	GameManager.raise_upgrade_level("__test_crier")
	assert_int(GameManager.get_forecast_customers()).is_equal(0)


func _track(id: String, effect: String, values: Array[float]) -> UpgradeDefinition:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = id
	upgrade.effect = effect
	for value in values:
		var level := UpgradeLevel.new()
		level.value = value
		upgrade.levels.append(level)
	return upgrade


# --- loyalty and contracts ---

func test_loyalty_adds_up_per_customer() -> void:
	GameManager.add_loyalty("__a", 2)
	GameManager.add_loyalty("__a", 1)
	GameManager.add_loyalty("__b", 4)
	assert_int(GameManager.get_loyalty("__a")).is_equal(3)
	assert_int(GameManager.get_loyalty("__b")).is_equal(4)
	assert_int(GameManager.get_loyalty("__c")).is_equal(0)


func test_loyalty_ignores_zero_and_negative_gains() -> void:
	GameManager.add_loyalty("__a", 0)
	GameManager.add_loyalty("__a", -2)
	assert_dict(GameManager.regular_loyalty).is_empty()


func test_contract_slots_default_to_none_until_bought() -> void:
	set_definition(DefinitionLibrary.upgrades, _track("__test_board", "contract_slots", [1.0, 2.0]))
	assert_int(GameManager.get_contract_slots()).is_equal(0)
	GameManager.raise_upgrade_level("__test_board")
	assert_int(GameManager.get_contract_slots()).is_equal(1)


# --- save/load round-trip ---

func test_serialize_deserialize_round_trip() -> void:
	GameManager.add_gold(30)
	GameManager.add_shop_xp(120)
	GameManager.add_blueprint("bp_x")
	GameManager.add_reagent("fire", 4)
	set_definition(DefinitionLibrary.upgrades, _track("__test_patience", "despawn_time", [15.0, 18.0]))
	GameManager.raise_upgrade_level("__test_patience")
	GameManager.shop_shelf_state = [{"col": 1, "row": 0, "item_id": "ore"}]
	GameManager.record_session_played()
	GameManager.add_loyalty("cust_x", 3)
	GameManager.active_contracts = [{"id": "con_x", "delivered": {"ore": 2}, "sessions_left": 2}]
	GameManager.charters = 1
	GameManager.charter_points = 3
	GameManager.perk_levels = {"perk_x": 2}
	GameManager.codex = {"ore": 1}
	GameManager.codex_stars_credited = 2
	GameManager.codex_families_credited.assign(["metal"])

	var saved := GameManager.serialize()
	reset_game_state()
	GameManager.deserialize(saved)
	var resaved := GameManager.serialize()

	# Round-trip invariant: the deserialized state must re-serialize identically.
	assert_dict(resaved).is_equal(saved)


# --- sessions ---

func test_new_game_has_played_no_sessions() -> void:
	assert_int(GameManager.sessions_played).is_equal(0)


func test_record_session_played_counts_up() -> void:
	GameManager.record_session_played()
	GameManager.record_session_played()
	assert_int(GameManager.sessions_played).is_equal(2)


func test_session_seed_is_fixed_by_run_seed_and_session_count() -> void:
	GameManager.run_seed = 7
	var first: int = GameManager.get_session_seed()
	assert_int(GameManager.get_session_seed()).is_equal(first)
	GameManager.record_session_played()
	assert_int(GameManager.get_session_seed()).is_not_equal(first)
	GameManager.sessions_played = 0
	assert_int(GameManager.get_session_seed()).is_equal(first)


# Two fresh games share a run seed with odds of 1 in 2^32.
func test_new_games_roll_their_own_run_seed() -> void:
	var first: int = GameManager.run_seed
	reset_game_state()
	assert_int(GameManager.run_seed).is_not_equal(first)


# --- towns ---

# deserialize({}) directly: TestBase's reset may point the game elsewhere.
func test_a_new_game_opens_in_the_starting_town() -> void:
	var start := TownDefinition.new()
	start.id = "__test_start"
	set_definition(DefinitionLibrary.towns, start)
	var rules := ShopRulesDefinition.new()
	rules.id = "default"
	rules.starting_town = start
	set_definition(DefinitionLibrary.shop_rules, rules)
	GameManager.deserialize({})
	assert_str(GameManager.current_town).is_equal("__test_start")
	assert_object(GameManager.get_current_town()).is_same(start)
