extends RefCounted

# Prep-phase purchase rules: each buy checks, charges and grants in one step,
# and refuses without charging when any check fails. Instance methods, not
# static: GDScript static methods can't reach autoloads by name.


func buy_blueprint(bp_id: String) -> bool:
	if RecipeResolver.has_blueprint(bp_id):
		return false
	var blueprint := DefinitionLibrary.get_blueprint(bp_id)
	if blueprint == null or blueprint.cost <= 0:
		return false
	if not GameManager.meets_level(blueprint.min_shop_level):
		return false
	if not RecipeResolver.are_dependencies_met(blueprint):
		return false
	if not GameManager.deduct_gold(blueprint.cost):
		return false
	GameManager.add_blueprint(bp_id)
	EventBus.save_requested.emit()
	return true


func buy_upgrade(upgrade_id: String) -> bool:
	if upgrade_id in GameManager.purchased_upgrades:
		return false
	var upgrade := DefinitionLibrary.get_upgrade(upgrade_id)
	if upgrade == null:
		return false
	if not GameManager.deduct_gold(upgrade.cost):
		return false
	if upgrade.effect == "grid_size":
		GameManager.grid_cols += upgrade.grid_cols
		GameManager.grid_rows += upgrade.grid_rows
		GameManager.grid_size_changed.emit(GameManager.grid_cols, GameManager.grid_rows)
	GameManager.add_upgrade(upgrade_id)
	EventBus.save_requested.emit()
	return true


func buy_reagent(reagent_id: String) -> bool:
	var reagent := DefinitionLibrary.get_reagent(reagent_id)
	if reagent == null:
		return false
	if not GameManager.meets_level(reagent.min_shop_level):
		return false
	if not GameManager.deduct_gold(reagent.cost):
		return false
	GameManager.add_reagent(reagent_id, 1)
	EventBus.save_requested.emit()
	return true
