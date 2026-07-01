extends TestBase

# Characterization tests for the GameManager autoload.
# Applies writing-godot-tests: public contract (methods/properties/signals),
# invariants, boundary inputs, and a save/load round-trip.
# before_test() (autoload reset) is inherited from TestBase.


# --- Defaults (public properties) ---

func test_default_state() -> void:
	assert_int(GameManager.gold).is_equal(50)
	assert_int(GameManager.reputation_points).is_equal(0)
	assert_array(GameManager.unlocked_blueprints).is_empty()
	assert_dict(GameManager.reagent_inventory).is_empty()
	assert_array(GameManager.purchased_upgrades).is_empty()
	assert_int(GameManager.grid_cols).is_equal(5)
	assert_int(GameManager.grid_rows).is_equal(5)


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


# --- reputation ---

func test_add_reputation_increases_and_emits() -> void:
	var seen: Array = []
	GameManager.reputation_changed.connect(func(v: int) -> void: seen.append(v))
	GameManager.add_reputation(50)
	assert_int(GameManager.reputation_points).is_equal(50)
	assert_array(seen).has_size(1)
	assert_int(int(seen[0])).is_equal(50)


# Invariant: reputation_points never goes negative (clamped at 0).
func test_add_reputation_negative_clamps_to_zero() -> void:
	GameManager.add_reputation(20)
	GameManager.add_reputation(-100)
	assert_int(GameManager.reputation_points).is_greater_equal(0)
	assert_int(GameManager.reputation_points).is_equal(0)


func test_reputation_level_change_emits_when_crossing_threshold() -> void:
	var seen_levels: Array = []
	GameManager.reputation_level_changed.connect(func(lvl: String) -> void: seen_levels.append(lvl))
	GameManager.add_reputation(100)  # low -> mid
	assert_array(seen_levels).contains("mid")


# --- get_reputation_level (boundary inputs at exact thresholds) ---

func test_reputation_level_thresholds() -> void:
	var cases: Array = [
		[0, "low"], [99, "low"],
		[100, "mid"], [101, "mid"], [299, "mid"],
		[300, "high"], [301, "high"],
	]
	for c in cases:
		var pts: int = int(c[0])
		var expected: String = String(c[1])
		GameManager.reputation_points = pts
		assert_str(GameManager.get_reputation_level()).is_equal(expected)


# --- is_dungeon_unlocked (boundary) ---

func test_dungeon_unlock_boundary_at_150() -> void:
	GameManager.reputation_points = 149
	assert_bool(GameManager.is_dungeon_unlocked()).is_false()
	GameManager.reputation_points = 150
	assert_bool(GameManager.is_dungeon_unlocked()).is_true()


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


# --- upgrade-driven getters ---

func test_despawn_time_default_then_upgrade() -> void:
	assert_float(GameManager.get_despawn_time()).is_equal(12.0)
	GameManager.add_upgrade("slow_timer")
	assert_float(GameManager.get_despawn_time()).is_equal(18.0)


func test_crate_discount_default_then_upgrade() -> void:
	assert_float(GameManager.get_crate_discount()).is_equal(1.0)
	GameManager.add_upgrade("crate_discount")
	assert_float(GameManager.get_crate_discount()).is_equal(0.8)


# --- save/load round-trip ---

func test_serialize_deserialize_round_trip() -> void:
	GameManager.add_gold(30)
	GameManager.add_reputation(120)
	GameManager.add_blueprint("bp_x")
	GameManager.add_reagent("fire", 4)
	GameManager.add_upgrade("slow_timer")

	var saved := GameManager.serialize()
	reset_game_state()
	GameManager.deserialize(saved)
	var resaved := GameManager.serialize()

	# Round-trip invariant: the deserialized state must re-serialize identically.
	assert_dict(resaved).is_equal(saved)
