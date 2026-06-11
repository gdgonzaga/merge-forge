extends Control

var _tab_container: TabContainer
var _bp_scroll: VBoxContainer
var _upgrade_scroll: VBoxContainer
var _reagent_scroll: VBoxContainer


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.2)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var title := Label.new()
	title.text = "Prep Phase"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	root.add_child(title)

	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_theme_constant_override("h_separation", 8)
	root.add_child(_tab_container)

	_bp_scroll = _build_tab("Blueprints")
	_upgrade_scroll = _build_tab("Upgrades")
	_reagent_scroll = _build_tab("Reagents")
	_refresh_all()

	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 16)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(btn_box)

	_make_btn(btn_box, "Quit to Menu", EventBus.prep_quit_to_menu.emit)
	_make_btn(btn_box, "Start Session", EventBus.prep_start_session.emit)

	var dungeon_btn := Button.new()
	dungeon_btn.text = "Enter Dungeon"
	dungeon_btn.add_theme_font_size_override("font_size", 22)
	dungeon_btn.custom_minimum_size = Vector2(280, 70)
	dungeon_btn.disabled = not GameManager.is_dungeon_unlocked()
	dungeon_btn.tooltip_text = "Requires 150 reputation"
	dungeon_btn.pressed.connect(EventBus.prep_enter_dungeon.emit)
	btn_box.add_child(dungeon_btn)

	var debug_btn := Button.new()
	debug_btn.text = "DBG: Unlock All + 2000g + 1000rep"
	debug_btn.add_theme_font_size_override("font_size", 16)
	debug_btn.custom_minimum_size = Vector2(280, 50)
	debug_btn.pressed.connect(_debug_unlock_all)
	btn_box.add_child(debug_btn)

	GameManager.gold_changed.connect(func(_v): if is_instance_valid(self): _refresh_all())
	GameManager.blueprint_added.connect(func(_v): if is_instance_valid(self): _refresh_blueprints())
	GameManager.upgrade_added.connect(func(_v): if is_instance_valid(self): _refresh_upgrades())
	GameManager.reagent_count_changed.connect(func(_v, _c): if is_instance_valid(self): _refresh_reagents())
	GameManager.reputation_changed.connect(func(v):
		if is_instance_valid(dungeon_btn):
			dungeon_btn.disabled = v < 150
	)


func try_purchase(type: String, id: String) -> bool:
	match type:
		"blueprint":
			return _buy_blueprint(id)
		"upgrade":
			return _buy_upgrade(id)
		"reagent":
			return _buy_reagent(id)
	return false


func _buy_blueprint(bp_id: String) -> bool:
	if bp_id in GameManager.unlocked_blueprints:
		return false
	var cost: int = RecipeResolver.get_blueprint_cost(bp_id)
	if cost <= 0:
		return false
	var deps: Array[String] = RecipeResolver.get_blueprint_dependencies(bp_id)
	for dep in deps:
		if not dep in GameManager.unlocked_blueprints:
			return false
	if not GameManager.deduct_gold(cost):
		return false
	GameManager.add_blueprint(bp_id)
	EventBus.save_requested.emit()
	return true


func _buy_upgrade(upgrade_id: String) -> bool:
	if upgrade_id in GameManager.purchased_upgrades:
		return false
	var data: Dictionary = RecipeResolver.get_upgrade_data(upgrade_id)
	if data.is_empty():
		return false
	var cost: int = data.get("cost", 0)
	if not GameManager.deduct_gold(cost):
		return false
	var effect_type: String = data.get("effect_type", "")
	var effect_value = data.get("effect_value")
	if effect_type == "grid_size" and effect_value is Dictionary:
		GameManager.grid_cols += effect_value.get("cols", 0)
		GameManager.grid_rows += effect_value.get("rows", 0)
		GameManager.grid_size_changed.emit(GameManager.grid_cols, GameManager.grid_rows)
	GameManager.add_upgrade(upgrade_id)
	EventBus.save_requested.emit()
	return true


func _buy_reagent(reagent_id: String) -> bool:
	var data: Dictionary = RecipeResolver.get_reagent_data(reagent_id)
	if data.is_empty():
		return false
	var cost: int = data.get("cost", 0)
	if not GameManager.deduct_gold(cost):
		return false
	GameManager.add_reagent(reagent_id, 1)
	EventBus.save_requested.emit()
	return true


func _build_tab(tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)
	return content


func _refresh_all() -> void:
	_refresh_blueprints()
	_refresh_upgrades()
	_refresh_reagents()


func _refresh_blueprints() -> void:
	for child in _bp_scroll.get_children():
		child.queue_free()
	var bp_keys: Array = RecipeResolver.blueprints.keys()
	var card_scene: PackedScene = load("res://shop/purchase_card.tscn")
	for bp_id in bp_keys:
		var data: Dictionary = RecipeResolver.blueprints[bp_id]
		var owned: bool = bp_id in GameManager.unlocked_blueprints
		var deps: Array[String] = RecipeResolver.get_blueprint_dependencies(bp_id)
		var deps_met := true
		for dep in deps:
			if not dep in GameManager.unlocked_blueprints:
				deps_met = false
				break
		var cost: int = data.get("cost", 0)
		var desc := ""
		var desc_color := Color(0.7, 0.7, 0.7)
		if not deps_met:
			desc = "Requires: %s" % ", ".join(deps)
			desc_color = Color(0.7, 0.5, 0.5)
		var btn_text := "%dg" % cost
		var disabled := not deps_met or GameManager.gold < cost
		var name_mod := Color.WHITE
		if owned:
			name_mod = Color(0.5, 1, 0.5)
		elif not deps_met:
			name_mod = Color(0.5, 0.5, 0.5)
		var card: PanelContainer = card_scene.instantiate()
		_bp_scroll.add_child(card)
		card.setup(data.get("name", bp_id), desc, desc_color, "Owned" if owned else btn_text, owned or disabled, Callable() if owned else try_purchase.bind("blueprint", bp_id))
		card.name_label.modulate = name_mod


func _refresh_upgrades() -> void:
	for child in _upgrade_scroll.get_children():
		child.queue_free()
	var upgrade_keys: Array = RecipeResolver.upgrades.keys()
	var card_scene: PackedScene = load("res://shop/purchase_card.tscn")
	for uid in upgrade_keys:
		var data: Dictionary = RecipeResolver.upgrades[uid]
		var owned: bool = uid in GameManager.purchased_upgrades
		var cost: int = data.get("cost", 0)
		var desc := _describe_upgrade(data.get("effect_type", ""), data.get("effect_value"))
		var name_mod := Color(0.5, 1, 0.5) if owned else Color.WHITE
		var card: PanelContainer = card_scene.instantiate()
		_upgrade_scroll.add_child(card)
		card.setup(data.get("name", uid), desc, Color(0.7, 0.7, 0.7), "Owned" if owned else "%dg" % cost, owned or GameManager.gold < cost, Callable() if owned else try_purchase.bind("upgrade", uid))
		card.name_label.modulate = name_mod


func _refresh_reagents() -> void:
	for child in _reagent_scroll.get_children():
		child.queue_free()
	var reagent_keys: Array = RecipeResolver.reagents.keys()
	var card_scene: PackedScene = load("res://shop/purchase_card.tscn")
	for rid in reagent_keys:
		var data: Dictionary = RecipeResolver.reagents[rid]
		var cost: int = data.get("cost", 0)
		var owned_count: int = GameManager.reagent_inventory.get(rid, 0)
		var desc: String = data.get("description", "")
		var card: PanelContainer = card_scene.instantiate()
		_reagent_scroll.add_child(card)
		card.setup("%s (x%d)" % [data.get("name", rid), owned_count], desc, Color(0.7, 0.7, 0.7), "%dg" % cost, GameManager.gold < cost, try_purchase.bind("reagent", rid), 72)


func _describe_upgrade(effect_type: String, value) -> String:
	match effect_type:
		"grid_size":
			if value is Dictionary:
				return "+%d cols, +%d rows" % [value.get("cols", 0), value.get("rows", 0)]
		"despawn_time":
			return "Despawn time: %.0fs" % float(value)
		"crate_discount":
			return "Crate prices x%.0f%%" % (float(value) * 100)
	return effect_type


func _make_btn(parent: BoxContainer, text: String, on_press: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 22)
	btn.custom_minimum_size = Vector2(280, 70)
	btn.pressed.connect(on_press)
	parent.add_child(btn)


func _debug_unlock_all() -> void:
	GameManager.debug_mode = true
	GameManager.gold = 2000
	GameManager.gold_changed.emit(2000)
	GameManager.add_reputation(1000)
	var bp_ids: Array = RecipeResolver.blueprints.keys()
	for bp_id in bp_ids:
		if not bp_id in GameManager.unlocked_blueprints:
			GameManager.add_blueprint(bp_id)
	GameManager.add_reagent("fire_essence", 5)
