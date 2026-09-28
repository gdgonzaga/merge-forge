extends Control

const CONFIRM_DIALOG := preload("res://ui/confirm_dialog.tscn")
const PURCHASES := preload("res://core/purchases.gd")

@onready var _bp_scroll: VBoxContainer = $VBox/TabContainer/Blueprints/BpContent
@onready var _upgrade_scroll: VBoxContainer = $VBox/TabContainer/Upgrades/UpgradeContent
@onready var _reagent_scroll: VBoxContainer = $VBox/TabContainer/Reagents/ReagentContent
@onready var _dungeon_btn: Button = %DungeonBtn
@onready var _forecast_panel: VBoxContainer = %ForecastPanel

var _purchases: RefCounted = PURCHASES.new()
# Today's single Enter Dungeon button targets the first dungeon to unlock.
var _dungeon: DungeonDefinition
# The next session exactly as the shop will deal it.
var _plan: SessionPlan


func _ready() -> void:
	for child in _bp_scroll.get_children():
		child.queue_free()
	for child in _upgrade_scroll.get_children():
		child.queue_free()
	for child in _reagent_scroll.get_children():
		child.queue_free()

	_dungeon = DefinitionLibrary.get_all_dungeons()[0]
	_refresh_dungeon_button()
	$VBox/BtnBox/QuitBtn.pressed.connect(_on_quit_pressed)
	$VBox/BtnBox/SessionBtn.pressed.connect(EventBus.prep_start_session.emit)
	_dungeon_btn.pressed.connect(EventBus.prep_enter_dungeon.emit.bind(_dungeon.id))
	$VBox/DebugBtn.pressed.connect(_debug_unlock_all)
	# Bound methods, not lambdas: Godot drops a connection when the callable's
	# object is freed, and a lambda that never touches self has no object, so
	# its connection would outlive the screen.
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.blueprint_added.connect(_on_blueprint_added)
	GameManager.upgrade_level_changed.connect(_on_upgrade_level_changed)
	GameManager.reagent_count_changed.connect(_on_reagent_count_changed)
	GameManager.shop_level_changed.connect(_on_shop_level_changed)
	_refresh_all()
	_refresh_forecast()


# Quit to menu drops any in-flight prep/board state. Confirm before leaving.
func _on_quit_pressed() -> void:
	var dialog := CONFIRM_DIALOG.instantiate()
	add_child(dialog)
	dialog.setup(
		"Quit to the main menu?",
		EventBus.prep_quit_to_menu.emit,
		Callable(),
		"Quit",
	)


func _on_gold_changed(_value: int) -> void:
	_refresh_all()


func _on_blueprint_added(_id: String) -> void:
	_refresh_blueprints()
	_refresh_forecast()


func _on_upgrade_level_changed(_id: String, _level: int) -> void:
	_refresh_upgrades()
	_refresh_forecast()


func _on_reagent_count_changed(_id: String, _count: int) -> void:
	_refresh_reagents()
	_refresh_forecast()


func _on_shop_level_changed(_level: int) -> void:
	_refresh_dungeon_button()
	_refresh_all()
	_refresh_forecast()


func _refresh_dungeon_button() -> void:
	var open := GameManager.meets_level(_dungeon.min_shop_level)
	_dungeon_btn.disabled = not open
	_dungeon_btn.text = "Enter Dungeon" if open else "Dungeon (Lv %d)" % _dungeon.min_shop_level


func get_forecast_plan() -> SessionPlan:
	return _plan


func try_purchase(type: String, id: String) -> bool:
	match type:
		"blueprint":
			return _purchases.buy_blueprint(id)
		"upgrade":
			return _purchases.buy_upgrade(id)
		"reagent":
			return _purchases.buy_reagent(id)
	return false


func _refresh_all() -> void:
	_refresh_blueprints()
	_refresh_upgrades()
	_refresh_reagents()


func _refresh_forecast() -> void:
	_plan = SessionPlanner.plan_next_session()
	_forecast_panel.setup(_plan, GameManager.get_forecast_customers())


func _refresh_blueprints() -> void:
	for child in _bp_scroll.get_children():
		child.queue_free()
	var card_scene: PackedScene = load("res://shop/purchase_card.tscn")
	for blueprint in DefinitionLibrary.get_all_blueprints():
		var bp_id := blueprint.id
		var owned := RecipeResolver.has_blueprint(bp_id)
		var level_ok := GameManager.meets_level(blueprint.min_shop_level)
		var deps_met := RecipeResolver.are_dependencies_met(blueprint)
		var cost := blueprint.cost
		var desc: String = ""
		var desc_color := Color(0.7, 0.7, 0.7)
		if not owned and not level_ok:
			desc = "Unlocks at level %d" % blueprint.min_shop_level
			desc_color = Color(0.5, 0.5, 0.5)
		elif not deps_met:
			var dep_names: Array[String] = []
			for dep in blueprint.dependencies:
				dep_names.append(dep.name)
			desc = "Requires: %s" % ", ".join(dep_names)
			desc_color = Color(0.7, 0.5, 0.5)
		var btn_text := "%dg" % cost
		var disabled := not owned and (not level_ok or not deps_met or GameManager.gold < cost)
		var name_mod := Color.WHITE
		if owned:
			name_mod = Color(0.5, 1, 0.5)
		elif not level_ok:
			name_mod = Color(0.5, 0.5, 0.5)
		elif not deps_met:
			name_mod = Color(0.5, 0.5, 0.5)
		var card: PanelContainer = card_scene.instantiate()
		_bp_scroll.add_child(card)
		card.setup(blueprint.name, desc, desc_color, "Owned" if owned else btn_text, owned or disabled, Callable() if owned else try_purchase.bind("blueprint", bp_id))
		card.name_label.modulate = name_mod


func _refresh_upgrades() -> void:
	for child in _upgrade_scroll.get_children():
		child.queue_free()
	var card_scene: PackedScene = load("res://shop/purchase_card.tscn")
	for upgrade in DefinitionLibrary.get_all_upgrades():
		var level := GameManager.get_upgrade_level(upgrade.id)
		var next := upgrade.next_level(level)
		var level_ok := next != null and GameManager.meets_level(next.min_shop_level)
		var card: PanelContainer = card_scene.instantiate()
		_upgrade_scroll.add_child(card)
		card.setup(
			"%s (%d/%d)" % [upgrade.name, level, upgrade.max_level()],
			"%s\n%s" % [upgrade.description, _describe_next_level(upgrade, next)],
			Color(0.7, 0.7, 0.7),
			"Max" if next == null else "%dg" % next.cost,
			not level_ok or GameManager.gold < next.cost,
			Callable() if next == null else try_purchase.bind("upgrade", upgrade.id),
		)
		card.name_label.modulate = Color(0.5, 1, 0.5) if next == null else Color.WHITE


func _describe_next_level(upgrade: UpgradeDefinition, next: UpgradeLevel) -> String:
	if next == null:
		return "Max level"
	if not GameManager.meets_level(next.min_shop_level):
		return "Unlocks at level %d" % next.min_shop_level
	return "Next: %s" % _describe_value(upgrade.effect, next)


func _describe_value(effect: String, level: UpgradeLevel) -> String:
	match effect:
		"grid_size":
			return "%dx%d board" % [GameManager.grid_cols + level.grid_cols, GameManager.grid_rows + level.grid_rows]
		"despawn_time":
			return "%.0fs" % level.value
		"crate_discount":
			return "crates x%d%%" % roundi(level.value * 100.0)
		"shelf_slots":
			return "%d shelf slots" % int(level.value)
		"forecast_detail":
			return "every customer and order" if int(level.value) <= 0 else "%d customers" % int(level.value)
		"order_price":
			return "orders x%d%%" % roundi(level.value * 100.0)
	return effect


func _refresh_reagents() -> void:
	for child in _reagent_scroll.get_children():
		child.queue_free()
	var card_scene: PackedScene = load("res://shop/purchase_card.tscn")
	for reagent in DefinitionLibrary.get_all_reagents():
		var owned_count: int = GameManager.reagent_inventory.get(reagent.id, 0)
		var level_ok := GameManager.meets_level(reagent.min_shop_level)
		var desc := reagent.description if level_ok else "Unlocks at level %d" % reagent.min_shop_level
		var disabled := not level_ok or GameManager.gold < reagent.cost
		var card: PanelContainer = card_scene.instantiate()
		_reagent_scroll.add_child(card)
		card.setup("%s (x%d)" % [reagent.name, owned_count], desc, Color(0.7, 0.7, 0.7), "%dg" % reagent.cost, disabled, try_purchase.bind("reagent", reagent.id), 72)


func _debug_unlock_all() -> void:
	GameManager.debug_mode = true
	GameManager.gold = 20000
	GameManager.gold_changed.emit(20000)
	var rules := DefinitionLibrary.get_shop_rules()
	GameManager.add_shop_xp(rules.xp_for_level(rules.max_level) - GameManager.shop_xp)
	for blueprint in DefinitionLibrary.get_all_blueprints():
		GameManager.add_blueprint(blueprint.id)
	for reagent in DefinitionLibrary.get_all_reagents():
		GameManager.add_reagent(reagent.id, 5)
