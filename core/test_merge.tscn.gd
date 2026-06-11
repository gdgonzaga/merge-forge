extends Control

var _merge_board: Control
var _gold_label: Label
var _popup: PopupPanel
var _choice_callback: Callable
var _log_label: RichTextLabel


func _ready() -> void:
	var merge_board_scene: PackedScene = load("res://board/merge_board.tscn")
	_merge_board = merge_board_scene.instantiate()
	_merge_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_merge_board)

	_gold_label = Label.new()
	_gold_label.text = "Gold: %d" % GameManager.gold
	_gold_label.position = Vector2(10, 10)
	_gold_label.add_theme_font_size_override("font_size", 24)
	_gold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gold_label)
	GameManager.gold_changed.connect(_on_gold_changed)

	var crate_btn := Button.new()
	crate_btn.text = "Buy Basic Crate (10g)"
	crate_btn.position = Vector2(10, 40)
	crate_btn.size = Vector2(300, 50)
	crate_btn.add_theme_font_size_override("font_size", 20)
	crate_btn.pressed.connect(_on_buy_crate)
	add_child(crate_btn)

	var cell_scene: PackedScene = load("res://board/board_cell.tscn")
	_merge_board.setup({
		"cols": 5,
		"rows": 5,
		"cell_scene": cell_scene,
		"popup_callback": _on_merge_choice_requested,
		"despawn_time": 12.0,
	})

	var popup_scene: PackedScene = load("res://board/merge_choice_popup.tscn")
	_popup = popup_scene.instantiate()
	add_child(_popup)
	_popup.choice_made.connect(_on_choice_from_popup)

	GameManager.add_reagent("fire_essence", 3)

	_setup_test_panel()


func _setup_test_panel() -> void:
	var bx := 540
	var by := 100

	_make_button("Test: Save/Load", Vector2(bx, by), _test_save_load, 250)
	_make_button("Test: JSON Loads", Vector2(bx, by + 55), _test_json_loads, 250)
	_make_button("Test: Resolver", Vector2(bx, by + 110), _test_recipe_resolver, 250)
	_make_button("Clear Log", Vector2(bx, by + 165), func(): _log_label.clear(), 250)
	_make_button("Reset GM", Vector2(bx, by + 220), _test_reset_game_manager, 250)

	_log_label = RichTextLabel.new()
	_log_label.position = Vector2(540, by + 280)
	_log_label.size = Vector2(530, 600)
	_log_label.bbcode_enabled = true
	_log_label.add_theme_font_size_override("normal_font_size", 16)
	_log_label.scroll_following = true
	add_child(_log_label)


func _make_button(text: String, pos: Vector2, on_press: Callable, width: int = 400) -> void:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = Vector2(width, 48)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(on_press)
	add_child(btn)


func _log(msg: String, color: String = "white") -> void:
	_log_label.append_text("[color=%s]%s[/color]\n" % [color, msg])
	print("[TestMerge] %s" % msg)


func _test_save_load() -> void:
	_log_label.clear()
	_log("=== SAVE/LOAD ROUND-TRIP TEST ===", "cyan")

	GameManager.gold = 500
	GameManager.reputation_points = 75
	GameManager.unlocked_blueprints = ["bp_iron_plate", "bp_sword"]
	GameManager.reagent_inventory = {"fire_essence": 5}
	GameManager.purchased_upgrades = ["grid_expand"]
	GameManager.grid_cols = 6
	GameManager.grid_rows = 7
	GameManager.shop_board_state = [{"item_id": "iron_ore", "col": 2, "row": 3}]

	_log("Set test state: gold=500 rep=75 bps=[bp_iron_plate,bp_sword] reagents={fire_essence:5} upgrades=[grid_expand] grid=6x7")

	var before: Dictionary = GameManager.serialize()
	_log("Serialized: %s" % [JSON.stringify(before, "  ").left(200)])

	SaveManager.save_game()
	_log("Saved to disk. has_save=%s" % SaveManager.has_save(), "yellow")

	GameManager.deserialize({})
	_log("Reset GameManager to defaults: gold=%d rep=%d" % [GameManager.gold, GameManager.reputation_points])

	var loaded: Dictionary = SaveManager.load_game()
	_log("Loaded from disk: %s" % [JSON.stringify(loaded, "  ").left(200)])

	GameManager.deserialize(loaded)

	var passed := true
	if GameManager.gold != 500:
		_log("FAIL gold: expected 500 got %d" % GameManager.gold, "red")
		passed = false
	if GameManager.reputation_points != 75:
		_log("FAIL rep: expected 75 got %d" % GameManager.reputation_points, "red")
		passed = false
	if GameManager.unlocked_blueprints.size() != 2 or GameManager.unlocked_blueprints[0] != "bp_iron_plate":
		_log("FAIL blueprints: %s" % str(GameManager.unlocked_blueprints), "red")
		passed = false
	if GameManager.reagent_inventory.get("fire_essence", 0) != 5:
		_log("FAIL reagent: expected 5 got %d" % GameManager.reagent_inventory.get("fire_essence", 0), "red")
		passed = false
	if GameManager.purchased_upgrades.size() != 1 or GameManager.purchased_upgrades[0] != "grid_expand":
		_log("FAIL upgrades: %s" % str(GameManager.purchased_upgrades), "red")
		passed = false
	if GameManager.grid_cols != 6 or GameManager.grid_rows != 7:
		_log("FAIL grid: expected 6x7 got %dx%d" % [GameManager.grid_cols, GameManager.grid_rows], "red")
		passed = false
	if GameManager.shop_board_state.size() != 1:
		_log("FAIL board_state: expected 1 entry got %d" % GameManager.shop_board_state.size(), "red")
		passed = false

	if passed:
		_log("ALL SAVE/LOAD CHECKS PASSED", "lime")
	else:
		_log("SOME CHECKS FAILED — see above", "red")

	_gold_label.text = "Gold: %d" % GameManager.gold
	SaveManager.delete_save()
	_log("Cleaned up test save.", "gray")


func _test_json_loads() -> void:
	_log_label.clear()
	_log("=== JSON DATA LOAD TEST ===", "cyan")

	var files := {
		"items": "items.json",
		"recipes": "recipes.json",
		"crates": "crates.json",
		"blueprints": "blueprints.json",
		"reagent_combos": "reagent_combos.json",
		"upgrades": "upgrades.json",
		"reagents": "reagents.json",
		"customers": "customers.json",
		"dungeons": "dungeons.json",
		"enemies": "enemies.json",
		"party": "party.json",
	}

	var all_ok := true
	for label in files:
		var fname: String = files[label]
		var path := "res://data/" + fname
		if not FileAccess.file_exists(path):
			_log("MISSING: %s (%s)" % [label, fname], "red")
			all_ok = false
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		var text := file.get_as_text()
		file.close()
		var json := JSON.new()
		if json.parse(text) != OK:
			_log("PARSE ERROR: %s at line %d" % [fname, json.get_error_line()], "red")
			all_ok = false
			continue
		var data = json.data
		var count: int = 0
		if data is Dictionary:
			count = data.size()
		elif data is Array:
			count = data.size()
		_log("OK: %-18s -> %d top-level keys/entries" % [label + " (" + fname + ")", count], "lime")

	if all_ok:
		_log("ALL 11 JSON FILES LOADED OK", "lime")
	else:
		_log("SOME FILES MISSING OR BROKEN", "red")

	_log("", "white")
	_log("--- RecipeResolver cache check ---", "yellow")
	var rr_items: int = RecipeResolver.items.size()
	var rr_recipes: int = RecipeResolver.recipes.size()
	var rr_bps: int = RecipeResolver.blueprints.size()
	var rr_combos: int = RecipeResolver.reagent_combos.size()
	var rr_crates: int = RecipeResolver.crates.size()
	var rr_upgrades: int = RecipeResolver.upgrades.size()
	var rr_reagents: int = RecipeResolver.reagents.size()
	_log("items=%d recipes=%d blueprints=%d combos=%d crates=%d upgrades=%d reagents=%d" % [rr_items, rr_recipes, rr_bps, rr_combos, rr_crates, rr_upgrades, rr_reagents])

	if rr_items == 0 or rr_recipes == 0:
		_log("WARN: RecipeResolver loaded empty dicts — data files may not exist at res:// path at runtime", "orange")


func _test_recipe_resolver() -> void:
	_log_label.clear()
	_log("=== RECIPERESOLVER QUERY TEST ===", "cyan")

	var all_ok := true

	_log("--- get_options (no blueprint required) ---", "yellow")
	var ore_opts: Array[Dictionary] = RecipeResolver.get_options("iron_ore")
	_log("iron_ore options: %s" % str(ore_opts))
	if ore_opts.size() != 1 or ore_opts[0].get("result_id", "") != "iron_ingot":
		_log("FAIL: expected 1 option (iron_ingot)", "red")
		all_ok = false
	else:
		_log("PASS", "lime")

	_log("--- get_options (blueprint required, NOT unlocked) ---", "yellow")
	var ingot_opts: Array[Dictionary] = RecipeResolver.get_options("iron_ingot")
	_log("iron_ingot options (bp_iron_plate NOT unlocked): %s" % str(ingot_opts))
	if ingot_opts.size() != 0:
		_log("FAIL: expected 0 options when blueprint not unlocked", "red")
		all_ok = false
	else:
		_log("PASS — correctly gated", "lime")

	_log("--- get_options (blueprint required, IS unlocked) ---", "yellow")
	GameManager.add_blueprint("bp_iron_plate")
	var ingot_opts2: Array[Dictionary] = RecipeResolver.get_options("iron_ingot")
	_log("iron_ingot options (bp_iron_plate unlocked): %s" % str(ingot_opts2))
	if ingot_opts2.size() != 1 or ingot_opts2[0].get("result_id", "") != "iron_plate":
		_log("FAIL: expected 1 option (iron_plate)", "red")
		all_ok = false
	else:
		_log("PASS", "lime")

	_log("--- get_options (multi-choice: refined_potion) ---", "yellow")
	GameManager.add_blueprint("bp_healing_potion")
	GameManager.add_blueprint("bp_battle_elixir")
	var pot_opts: Array[Dictionary] = RecipeResolver.get_options("refined_potion")
	_log("refined_potion options: %s" % str(pot_opts))
	if pot_opts.size() != 2:
		_log("FAIL: expected 2 options (healing_potion + battle_elixir)", "red")
		all_ok = false
	else:
		_log("PASS", "lime")

	_log("--- get_variant_options (sword + fire_essence → flame_sword) ---", "yellow")
	GameManager.add_blueprint("bp_flame_sword")
	GameManager.reagent_inventory["fire_essence"] = 1
	var var_opts: Array[Dictionary] = RecipeResolver.get_variant_options("sword")
	_log("sword variants: %s" % str(var_opts))
	if var_opts.size() != 1 or var_opts[0].get("variant_item_id", "") != "flame_sword":
		_log("FAIL: expected 1 variant (flame_sword)", "red")
		all_ok = false
	else:
		_log("PASS", "lime")

	_log("--- get_item_data ---", "yellow")
	var ore_data: Dictionary = RecipeResolver.get_item_data("iron_ore")
	_log("iron_ore data: %s" % str(ore_data))
	if ore_data.get("item_id", "") != "iron_ore" or ore_data.get("family", "") != "metal":
		_log("FAIL: expected item_id=iron_ore family=metal", "red")
		all_ok = false
	else:
		_log("PASS", "lime")

	_log("--- get_crate_data ---", "yellow")
	var basic_crate: Dictionary = RecipeResolver.get_crate_data("basic")
	_log("basic crate: %s" % str(basic_crate))
	if basic_crate.get("cost", 0) != 10:
		_log("FAIL: expected cost=10", "red")
		all_ok = false
	else:
		_log("PASS", "lime")

	_log("--- get_blueprint_cost / get_blueprint_dependencies ---", "yellow")
	var bp_cost: int = RecipeResolver.get_blueprint_cost("bp_sword")
	var bp_deps: Array[String] = RecipeResolver.get_blueprint_dependencies("bp_sword")
	_log("bp_sword cost=%d deps=%s" % [bp_cost, str(bp_deps)])
	if bp_cost != 120 or bp_deps.size() != 1 or bp_deps[0] != "bp_iron_plate":
		_log("FAIL: expected cost=120 deps=[bp_iron_plate]", "red")
		all_ok = false
	else:
		_log("PASS", "lime")

	_log("--- get_upgrade_data ---", "yellow")
	var upgrade: Dictionary = RecipeResolver.get_upgrade_data("crate_discount")
	_log("crate_discount: %s" % str(upgrade))
	if upgrade.get("effect_type", "") != "crate_discount" or upgrade.get("effect_value", 0) != 0.8:
		_log("FAIL: expected effect_type=crate_discount effect_value=0.8", "red")
		all_ok = false
	else:
		_log("PASS", "lime")

	_log("--- get_reagent_data ---", "yellow")
	var reag: Dictionary = RecipeResolver.get_reagent_data("fire_essence")
	_log("fire_essence: %s" % str(reag))
	if reag.get("cost", 0) != 75:
		_log("FAIL: expected cost=75", "red")
		all_ok = false
	else:
		_log("PASS", "lime")

	_log("--- get_all_crate_ids ---", "yellow")
	var crate_ids: Array[String] = RecipeResolver.get_all_crate_ids()
	_log("crate ids: %s" % str(crate_ids))
	if crate_ids.size() < 2:
		_log("FAIL: expected at least 2 crates", "red")
		all_ok = false
	else:
		_log("PASS", "lime")

	if all_ok:
		_log("ALL RECIPERESOLVER CHECKS PASSED", "lime")
	else:
		_log("SOME CHECKS FAILED — see above", "red")


func _test_reset_game_manager() -> void:
	GameManager.deserialize({})
	GameManager.unlocked_blueprints.clear()
	GameManager.reagent_inventory.clear()
	GameManager.purchased_upgrades.clear()
	GameManager.shop_board_state.clear()
	GameManager.grid_cols = 5
	GameManager.grid_rows = 5
	GameManager.gold = 1000
	GameManager.reputation_points = 0
	GameManager.add_reagent("fire_essence", 3)
	_gold_label.text = "Gold: %d" % GameManager.gold
	_log_label.clear()
	_log("GameManager reset to test defaults", "yellow")


func _on_buy_crate() -> void:
	_merge_board.buy_crate("basic")


func _on_gold_changed(new_amount: int) -> void:
	_gold_label.text = "Gold: %d" % new_amount


func _on_merge_choice_requested(options: Array[Dictionary], callback: Callable) -> void:
	_choice_callback = callback
	_popup.call("show_options", options)
	_popup.popup_centered()


func _on_choice_from_popup(item_id: String, is_variant: bool, reagent_id: String) -> void:
	if _choice_callback.is_valid():
		_choice_callback.call(item_id, is_variant, reagent_id)
