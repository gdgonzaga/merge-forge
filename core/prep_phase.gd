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

	_build_blueprints_tab()
	_build_upgrades_tab()
	_build_reagents_tab()

	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 16)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(btn_box)

	_make_btn(btn_box, "Quit to Menu", _on_quit)
	_make_btn(btn_box, "Start Session", _on_start_session)

	var dungeon_btn := Button.new()
	dungeon_btn.text = "Enter Dungeon"
	dungeon_btn.add_theme_font_size_override("font_size", 22)
	dungeon_btn.custom_minimum_size = Vector2(280, 70)
	dungeon_btn.disabled = not GameManager.is_dungeon_unlocked()
	dungeon_btn.tooltip_text = "Requires 150 reputation"
	dungeon_btn.pressed.connect(_on_enter_dungeon)
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


func _build_blueprints_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Blueprints"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

	_bp_scroll = VBoxContainer.new()
	_bp_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bp_scroll.add_theme_constant_override("separation", 6)
	scroll.add_child(_bp_scroll)
	_refresh_blueprints()


func _build_upgrades_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Upgrades"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

	_upgrade_scroll = VBoxContainer.new()
	_upgrade_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_scroll.add_theme_constant_override("separation", 6)
	scroll.add_child(_upgrade_scroll)
	_refresh_upgrades()


func _build_reagents_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Reagents"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

	_reagent_scroll = VBoxContainer.new()
	_reagent_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reagent_scroll.add_theme_constant_override("separation", 6)
	scroll.add_child(_reagent_scroll)
	_refresh_reagents()


func _refresh_all() -> void:
	_refresh_blueprints()
	_refresh_upgrades()
	_refresh_reagents()


func _refresh_blueprints() -> void:
	for child in _bp_scroll.get_children():
		child.queue_free()
	var bp_keys: Array = RecipeResolver.blueprints.keys()
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
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 64)
		_bp_scroll.add_child(card)

		var hbox := HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.add_theme_constant_override("separation", 8)
		card.add_child(hbox)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		hbox.add_child(info)

		var name_label := Label.new()
		name_label.text = data.get("name", bp_id)
		name_label.add_theme_font_size_override("font_size", 18)
		if owned:
			name_label.modulate = Color(0.5, 1, 0.5)
		elif not deps_met:
			name_label.modulate = Color(0.5, 0.5, 0.5)
		info.add_child(name_label)

		if not deps_met:
			var dep_label := Label.new()
			dep_label.text = "Requires: %s" % ", ".join(deps)
			dep_label.add_theme_font_size_override("font_size", 14)
			dep_label.modulate = Color(0.7, 0.5, 0.5)
			info.add_child(dep_label)

		var btn := Button.new()
		if owned:
			btn.text = "Owned"
			btn.disabled = true
		else:
			btn.text = "%dg" % cost
			btn.disabled = not deps_met or GameManager.gold < cost
			if not owned:
				btn.pressed.connect(try_purchase.bind("blueprint", bp_id))
		btn.custom_minimum_size = Vector2(100, 40)
		btn.add_theme_font_size_override("font_size", 16)
		hbox.add_child(btn)


func _refresh_upgrades() -> void:
	for child in _upgrade_scroll.get_children():
		child.queue_free()
	var upgrade_keys: Array = RecipeResolver.upgrades.keys()
	for uid in upgrade_keys:
		var data: Dictionary = RecipeResolver.upgrades[uid]
		var owned: bool = uid in GameManager.purchased_upgrades
		var cost: int = data.get("cost", 0)
		var effect_type: String = data.get("effect_type", "")
		var desc := _describe_upgrade(effect_type, data.get("effect_value"))

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 64)
		_upgrade_scroll.add_child(card)

		var hbox := HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.add_theme_constant_override("separation", 8)
		card.add_child(hbox)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		hbox.add_child(info)

		var name_label := Label.new()
		name_label.text = data.get("name", uid)
		name_label.add_theme_font_size_override("font_size", 18)
		if owned:
			name_label.modulate = Color(0.5, 1, 0.5)
		info.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = desc
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.modulate = Color(0.7, 0.7, 0.7)
		info.add_child(desc_label)

		var btn := Button.new()
		if owned:
			btn.text = "Owned"
			btn.disabled = true
		else:
			btn.text = "%dg" % cost
			btn.disabled = GameManager.gold < cost
			btn.pressed.connect(try_purchase.bind("upgrade", uid))
		btn.custom_minimum_size = Vector2(100, 40)
		btn.add_theme_font_size_override("font_size", 16)
		hbox.add_child(btn)


func _refresh_reagents() -> void:
	for child in _reagent_scroll.get_children():
		child.queue_free()
	var reagent_keys: Array = RecipeResolver.reagents.keys()
	for rid in reagent_keys:
		var data: Dictionary = RecipeResolver.reagents[rid]
		var cost: int = data.get("cost", 0)
		var owned_count: int = GameManager.reagent_inventory.get(rid, 0)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 72)
		_reagent_scroll.add_child(card)

		var hbox := HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.add_theme_constant_override("separation", 8)
		card.add_child(hbox)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		hbox.add_child(info)

		var name_label := Label.new()
		name_label.text = "%s (x%d)" % [data.get("name", rid), owned_count]
		name_label.add_theme_font_size_override("font_size", 18)
		info.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = data.get("description", "")
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.modulate = Color(0.7, 0.7, 0.7)
		info.add_child(desc_label)

		var btn := Button.new()
		btn.text = "%dg" % cost
		btn.disabled = GameManager.gold < cost
		btn.pressed.connect(try_purchase.bind("reagent", rid))
		btn.custom_minimum_size = Vector2(100, 40)
		btn.add_theme_font_size_override("font_size", 16)
		hbox.add_child(btn)


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


func _on_quit() -> void:
	EventBus.prep_quit_to_menu.emit()


func _on_start_session() -> void:
	EventBus.prep_start_session.emit()


func _on_enter_dungeon() -> void:
	EventBus.prep_enter_dungeon.emit()


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
