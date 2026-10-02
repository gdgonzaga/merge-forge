class_name TestBase
extends GdUnitTestSuite

# Base class for project test suites. Every test starts from a fresh-game
# GameManager, with SaveManager pointed at a scratch dir, and any catalog
# fixtures a test injected are removed afterwards.
# Tests extend TestBase (instead of GdUnitTestSuite) to inherit this.
#
# Why a base class and not a static helper: GDScript static methods cannot
# reach autoload singletons by name, so the reset must live in an instance
# method. Instantiating a helper and calling an instance method on it hits a
# GDScript parse quirk, so the reset lives here on the suite itself.

const TEST_SAVE_DIR := "user://test_saves"

# The current town in every test. It starts empty; set_definition() adds each
# fixture from a catalog a town scopes, so shipped shop content never joins a
# test. Tests that need a definition outside the town erase it from here.
const TEST_TOWN_ID := "__test_town"

var test_town: TownDefinition

# [catalog, id, had_entry, previous_entry] per injected fixture, in insertion order.
var _catalog_snapshots: Array[Array] = []


func before_test() -> void:
	_install_test_town()
	reset_game_state()
	# Redirect saves so no test (including ones that trigger EventBus.save_requested)
	# can overwrite or delete the developer's real user://save_data.json.
	_redirect_saves()


func after_test() -> void:
	# Undo injected fixtures first: restores exactly the ids tests touched.
	_restore_catalog_entries()
	# Put SaveManager back on the real path and drop everything tests wrote.
	_restore_saves()
	test_town = null


# Reset GameManager to a fresh game in the test town. Uses deserialize({}) —
# the same path New Game takes — so the defaults live in one place and a new
# persistent field is reset automatically. Call mid-test to wipe state, e.g.
# between serialize and deserialize in a round-trip test.
func reset_game_state() -> void:
	GameManager.deserialize({})
	GameManager.current_town = TEST_TOWN_ID
	GameManager.debug_mode = false


# Put a fixture definition into a DefinitionLibrary catalog (e.g.
# DefinitionLibrary.items) under its id, for the current test only. after_test
# restores the previous entry, or erases the id if it did not exist, so shipped
# content is never relied on or leaked. A fixture from a catalog a town scopes
# also joins the test town.
func set_definition(catalog: Dictionary, def: Resource) -> void:
	var id: String = def.id
	_catalog_snapshots.append([catalog, id, catalog.has(id), catalog.get(id)])
	catalog[id] = def
	_add_to_test_town(catalog, def)


func _redirect_saves() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	SaveManager.save_path = TEST_SAVE_DIR.path_join("save_data.json")


func _restore_saves() -> void:
	SaveManager.save_path = SaveManager.DEFAULT_SAVE_PATH
	_remove_dir_files(TEST_SAVE_DIR)
	DirAccess.remove_absolute(TEST_SAVE_DIR)


func _restore_catalog_entries() -> void:
	# Reverse order so an id injected twice ends at its original value.
	for i in range(_catalog_snapshots.size() - 1, -1, -1):
		var snap: Array = _catalog_snapshots[i]
		var catalog: Dictionary = snap[0]
		if snap[2]:
			catalog[snap[1]] = snap[3]
		else:
			catalog.erase(snap[1])
	# Drop the catalog references so no cycle outlives the test.
	_catalog_snapshots.clear()


func _remove_dir_files(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(dir_path.path_join(file_name))


func _install_test_town() -> void:
	test_town = TownDefinition.new()
	test_town.id = TEST_TOWN_ID
	test_town.name = "Test Town"
	set_definition(DefinitionLibrary.towns, test_town)


# Catalogs are matched by identity: == compares dictionaries by content. A
# fixture replaces any town entry with its id, like it does in the catalog.
func _add_to_test_town(catalog: Dictionary, def: Resource) -> void:
	if test_town == null:
		return
	var catalogs := DefinitionLibrary.get_catalogs()
	for folder: String in TownDefinition.SCOPED_CATALOGS:
		if not is_same(catalogs[folder], catalog):
			continue
		var list: Array = test_town.content(folder)
		for i in range(list.size() - 1, -1, -1):
			if list[i].id == def.id:
				list.remove_at(i)
		list.append(def)
		return
