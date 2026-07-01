class_name TestBase
extends GdUnitTestSuite

# Base class for project test suites. Provides autoload reset in before_test()
# so every test starts from a clean, deterministic GameManager state.
# Tests extend TestBase (instead of GdUnitTestSuite) to inherit the reset.
#
# Why a base class and not a static helper: GDScript static methods cannot
# reach autoload singletons by name, so the reset must live in an instance
# method. Instantiating a helper and calling an instance method on it hits a
# GDScript parse quirk, so the reset lives here on the suite itself.

func before_test() -> void:
	reset_game_state()


# Reset project autoloads to defaults. Runs automatically before each test (via
# before_test). Call mid-test when you need to wipe state, e.g. between
# serialize and deserialize in a round-trip test.
func reset_game_state() -> void:
	GameManager.gold = GameManager.DEFAULT_GOLD
	GameManager.reputation_points = 0
	GameManager.unlocked_blueprints.clear()
	GameManager.reagent_inventory.clear()
	GameManager.purchased_upgrades.clear()
	GameManager.shop_board_state.clear()
	GameManager.dungeon_board_state.clear()
	GameManager.grid_cols = 5
	GameManager.grid_rows = 5
