extends Control

const CONFIRM_DIALOG := preload("res://ui/confirm_dialog.tscn")
const PURCHASES := preload("res://core/purchases.gd")

@onready var _bp_scroll: VBoxContainer = $VBox/TabContainer/Blueprints/BpContent
@onready var _upgrade_scroll: VBoxContainer = $VBox/TabContainer/Upgrades/UpgradeContent
@onready var _reagent_scroll: VBoxContainer = $VBox/TabContainer/Reagents/ReagentContent
@onready var _dungeon_btn: Button = %DungeonBtn

var _purchases: RefCounted = PURCHASES.new()
# Today's single Enter Dungeon button targets the first dungeon to unlock.
var _dungeon: DungeonDefinition


func _ready() -> void:
	for child in _bp_scroll.get_children():
		child.queue_free()
	for child in _upgrade_scroll.get_children():
		child.queue_free()
	for child in _reagent_scroll.get_children():
		child.queue_free()

	_dungeon = DefinitionLibrary.get_all_dungeons()[0]
	_dungeon_btn.disabled = not GameManager.meets_level(_dungeon.min_shop_level)
	$VBox/BtnBox/QuitBtn.pressed.connect(_on_quit_pressed)
	$VBox/BtnBox/SessionBtn.pressed.connect(EventBus.prep_start_session.emit)
	_dungeon_btn.pressed.connect(EventBus.prep_enter_dungeon.emit.bind(_dungeon.id))
	$VBox/DebugBtn.pressed.connect(_debug_unlock_all)
	# Bound methods, not lambdas: Godot drops a connection when the callable's
	# object is freed, and a lambda that never touches self has no object, so
	# its connection would outlive the screen.
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.blueprint_added.connect(_on_blueprint_added)
	GameManager.upgrade_added.connect(_on_upgrade_added)
	GameManager.reagent_count_changed.connect(_on_reagent_count_changed)
	GameManager.shop_level_changed.connect(_on_shop_level_changed)
	_refresh_all()


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


func _on_upgrade_added(_id: String) -> void:
	_refresh_upgrades()


func _on_reagent_count_changed(_id: String, _count: int) -> void:
	_refresh_reagents()


func _on_shop_level_changed(_level: int) -> void:
	_dungeon_btn.disabled = not GameManager.meets_level(_dungeon.min_shop_level)
	_refresh_all()


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


func _refresh_blueprints() -> void:
	for child in _bp_scroll.get_children():
		child.queue_free()
	var card_scene: PackedScene = load("res://shop/purchase_card.tscn")
	for blueprint in DefinitionLibrary.get_all_blueprints():
		var bp_id := blueprint.id
		var owned := RecipeResolver.has_blueprint(bp_id)
		var deps_met := RecipeResolver.are_dependencies_met(blueprint)
		var cost := blueprint.cost
		var desc: String = ""
		var desc_color := Color(0.7, 0.7, 0.7)
		if not deps_met:
			var dep_names: Array[String] = []
			for dep in blueprint.dependencies:
				dep_names.append(dep.name)
			desc = "Requires: %s" % ", ".join(dep_names)
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
		card.setup(blueprint.name, desc, desc_color, "Owned" if owned else btn_text, owned or disabled, Callable() if owned else try_purchase.bind("blueprint", bp_id))
		card.name_label.modulate = name_mod


func _refresh_upgrades() -> void:
	for child in _upgrade_scroll.get_children():
		child.queue_free()
	var card_scene: PackedScene = load("res://shop/purchase_card.tscn")
	for upgrade in DefinitionLibrary.get_all_upgrades():
		var owned: bool = upgrade.id in GameManager.purchased_upgrades
		var cost := upgrade.cost
		var name_mod := Color(0.5, 1, 0.5) if owned else Color.WHITE
		var card: PanelContainer = card_scene.instantiate()
		_upgrade_scroll.add_child(card)
		card.setup(upgrade.name, _describe_upgrade(upgrade), Color(0.7, 0.7, 0.7), "Owned" if owned else "%dg" % cost, owned or GameManager.gold < cost, Callable() if owned else try_purchase.bind("upgrade", upgrade.id))
		card.name_label.modulate = name_mod


func _refresh_reagents() -> void:
	for child in _reagent_scroll.get_children():
		child.queue_free()
	var card_scene: PackedScene = load("res://shop/purchase_card.tscn")
	for reagent in DefinitionLibrary.get_all_reagents():
		var owned_count: int = GameManager.reagent_inventory.get(reagent.id, 0)
		var card: PanelContainer = card_scene.instantiate()
		_reagent_scroll.add_child(card)
		card.setup("%s (x%d)" % [reagent.name, owned_count], reagent.description, Color(0.7, 0.7, 0.7), "%dg" % reagent.cost, GameManager.gold < reagent.cost, try_purchase.bind("reagent", reagent.id), 72)


func _describe_upgrade(upgrade: UpgradeDefinition) -> String:
	match upgrade.effect:
		"grid_size":
			return "+%d cols, +%d rows" % [upgrade.grid_cols, upgrade.grid_rows]
		"despawn_time":
			return "Despawn time: %.0fs" % upgrade.value
		"crate_discount":
			return "Crate prices x%.0f%%" % (upgrade.value * 100)
	return upgrade.effect


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
