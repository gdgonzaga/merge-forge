extends TestBase

const DUNGEON_CONTROLLER := preload("res://dungeon/dungeon_controller.gd")
const DUNGEON_SUMMARY := preload("res://dungeon/dungeon_summary.tscn")

var _ice: ReagentDefinition


func before_test() -> void:
	super.before_test()
	_ice = ReagentDefinition.new()
	_ice.id = "__test_ice"
	_ice.name = "Test Ice"
	set_definition(DefinitionLibrary.reagents, _ice)


func test_a_zero_chance_never_gives_anything() -> void:
	var reward := _reward(0.0, 1, 3)
	var rng := _rng()
	for _i in range(200):
		assert_int(reward.roll(rng)).is_equal(0)


func test_a_certain_chance_always_gives_a_count_in_range() -> void:
	var reward := _reward(1.0, 2, 4)
	var rng := _rng()
	var seen := {}
	for _i in range(200):
		var count := reward.roll(rng)
		assert_bool(count >= 2 and count <= 4).override_failure_message("rolled %d" % count).is_true()
		seen[count] = true
	var counts: Array = seen.keys()
	counts.sort()
	assert_array(counts).is_equal([2, 3, 4])


func test_a_clear_adds_the_rolled_reagents_to_the_inventory() -> void:
	var dungeon := DungeonDefinition.new()
	dungeon.id = "__test_cave"
	dungeon.reagent_rewards = [_reward(1.0, 2, 2), _reward(0.0, 1, 1)]
	var controller: Control = auto_free(DUNGEON_CONTROLLER.new())
	var given: Dictionary = controller.grant_reagent_rewards(dungeon, _rng())
	assert_dict(given).is_equal({"__test_ice": 2})
	assert_int(GameManager.reagent_inventory.get("__test_ice", 0)).is_equal(2)


func test_the_summary_lists_the_reagents_found() -> void:
	var summary: Control = auto_free(DUNGEON_SUMMARY.instantiate())
	add_child(summary)
	summary.display_results({"cleared": true, "gold_reward": 0, "xp_gained": 0, "reagent_rewards": {"__test_ice": 2}})
	var label: Label = summary.get_node("%ReagentLabel")
	assert_bool(label.visible).is_true()
	assert_str(label.text).is_equal("Reagents: 2 Test Ice")


func test_a_failed_run_lists_no_reagents() -> void:
	var summary: Control = auto_free(DUNGEON_SUMMARY.instantiate())
	add_child(summary)
	summary.display_results({"cleared": false, "reagent_rewards": {}})
	assert_bool(summary.get_node("%ReagentLabel").visible).is_false()


func test_a_summary_without_results_waits_for_a_payload() -> void:
	var summary: Control = auto_free(DUNGEON_SUMMARY.instantiate())
	add_child(summary)
	var title: Label = summary.get_node("VBox/TitleLabel")
	assert_str(title.text).is_empty()


func _reward(chance: float, min_count: int, max_count: int) -> ReagentReward:
	var reward := ReagentReward.new()
	reward.reagent = _ice
	reward.chance = chance
	reward.min_count = min_count
	reward.max_count = max_count
	return reward


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return rng
