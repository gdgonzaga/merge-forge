extends TestBase

const REWARD_GRANT := preload("res://shop/reward_grant.gd")

var _blueprint: BlueprintDefinition
var _reagent: ReagentDefinition


func before_test() -> void:
	super.before_test()
	_blueprint = BlueprintDefinition.new()
	_blueprint.id = "__test_bp"
	_blueprint.name = "Test Blueprint"
	_blueprint.cost = 300
	_reagent = ReagentDefinition.new()
	_reagent.id = "__test_ice"
	_reagent.name = "Test Ice"


func test_gold_is_added_and_described() -> void:
	var lines: Array[String] = REWARD_GRANT.new().grant(40, null, null, 0)
	assert_int(GameManager.gold).is_equal(90)
	assert_array(lines).is_equal(["40 gold"])


func test_a_new_blueprint_is_unlocked() -> void:
	var lines: Array[String] = REWARD_GRANT.new().grant(0, _blueprint, null, 0)
	assert_bool(RecipeResolver.has_blueprint("__test_bp")).is_true()
	assert_int(GameManager.gold).is_equal(50)
	assert_array(lines).is_equal(["Test Blueprint"])


func test_an_owned_blueprint_pays_its_cost_instead() -> void:
	GameManager.add_blueprint("__test_bp")
	var lines: Array[String] = REWARD_GRANT.new().grant(0, _blueprint, null, 0)
	assert_int(GameManager.gold).is_equal(350)
	assert_array(lines).is_equal(["300 gold (Test Blueprint already owned)"])


func test_reagents_are_added_to_the_inventory() -> void:
	GameManager.add_reagent("__test_ice", 1)
	var lines: Array[String] = REWARD_GRANT.new().grant(0, null, _reagent, 2)
	assert_int(GameManager.reagent_inventory["__test_ice"]).is_equal(3)
	assert_array(lines).is_equal(["2 Test Ice"])


func test_everything_at_once_lists_gold_blueprint_then_reagent() -> void:
	var lines: Array[String] = REWARD_GRANT.new().grant(40, _blueprint, _reagent, 1)
	assert_int(GameManager.gold).is_equal(90)
	assert_array(lines).is_equal(["40 gold", "Test Blueprint", "1 Test Ice"])
