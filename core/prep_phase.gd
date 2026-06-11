extends Control

@onready var _bp_scroll: VBoxContainer = $VBox/TabContainer/Blueprints/BpContent
@onready var _upgrade_scroll: VBoxContainer = $VBox/TabContainer/Upgrades/UpgradeContent
@onready var _reagent_scroll: VBoxContainer = $VBox/TabContainer/Reagents/ReagentContent


func _ready() -> void:
	for child in _bp_scroll.get_children():
		child.queue_free()
	for child in _upgrade_scroll.get_children():
		child.queue_free()
	for child in _reagent_scroll.get_children():
		child.queue_free()

	var dungeon_btn: Button = $VBox/BtnBox/DungeonBtn
	dungeon_btn.disabled = not GameManager.is_dungeon_unlocked()
	dungeon_btn.tooltip_text = "Requires 150 reputation"
	$VBox/BtnBox/QuitBtn.pressed.connect(EventBus.prep_quit_to_menu.emit)
	$VBox/BtnBox/SessionBtn.pressed.connect(EventBus.prep_start_session.emit)
	dungeon_btn.pressed.connect(EventBus.prep_enter_dungeon.emit)
	$VBox/BtnBox/DebugBtn.pressed.connect(_debug_unlock_all)
	GameManager.gold_changed.connect(func(_v): if is_instance_valid(self): _refresh_all())
	GameManager.blueprint_added.connect(func(_v): if is_instance_valid(self): _refresh_blueprints())
	GameManager.upgrade_added.connect(func(_v): if is_instance_valid(self): _refresh_upgrades())
	GameManager.reagent_count_changed.connect(func(_v, _c): if is_instance_valid(self): _refresh_reagents())
	GameManager.reputation_changed.connect(func(v):
		if is_instance_valid(dungeon_btn):
			dungeon_btn.disabled = v < 150
	)
	_refresh_all()


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
		var desc: String = ""
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
