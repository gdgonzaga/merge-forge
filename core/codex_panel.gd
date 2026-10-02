extends VBoxContainer

# The Guild's codex: every item a merge can make in any town, grouped by
# family (RecipeResolver.get_codex_items()).

const FAMILY := preload("res://core/codex_family.tscn")


func setup() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var by_family := {}
	for item in RecipeResolver.get_codex_items():
		if not by_family.has(item.family):
			var list: Array[ItemDefinition] = []
			by_family[item.family] = list
		by_family[item.family].append(item)
	var complete := GameManager.get_completed_codex_families()
	var families := by_family.keys()
	families.sort()
	for family: String in families:
		var section: VBoxContainer = FAMILY.instantiate()
		add_child(section)
		section.show_family(family, by_family[family], _status_text(family, complete))


func _status_text(family: String, complete: Array[String]) -> String:
	if not family in complete:
		return ""
	if family in GameManager.codex_families_credited:
		return "Complete"
	return "Complete: +%d charter points at your next charter" % DefinitionLibrary.get_shop_rules().codex_family_points
