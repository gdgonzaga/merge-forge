extends RefCounted

# Pays a loyalty gift or contract reward and describes each part for the summary.
func grant(gold: int, blueprint: BlueprintDefinition, reagent: ReagentDefinition, reagent_count: int) -> Array[String]:
	var lines: Array[String] = []
	if gold > 0:
		GameManager.add_gold(gold)
		lines.append("%d gold" % gold)
	if blueprint != null:
		if RecipeResolver.has_blueprint(blueprint.id):
			GameManager.add_gold(blueprint.cost)
			lines.append("%d gold (%s already owned)" % [blueprint.cost, blueprint.name])
		else:
			GameManager.add_blueprint(blueprint.id)
			lines.append(blueprint.name)
	if reagent != null and reagent_count > 0:
		GameManager.add_reagent(reagent.id, reagent_count)
		lines.append("%d %s" % [reagent_count, reagent.name])
	return lines
