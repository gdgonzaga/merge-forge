extends TestBase

# The merge-choice popup names the quality the merge will make, so a mixed
# group's outcome is never a surprise.

const POPUP := preload("res://board/merge_choice_popup.tscn")


func test_buttons_name_the_result_quality() -> void:
	var popup: PopupPanel = auto_free(POPUP.instantiate())
	add_child(popup)
	popup.show_options([
		{"item_id": "__a", "display_name": "Sword", "is_variant": false, "reagent_id": "", "reagent_cost": 0, "result_quality": 1},
		{"item_id": "__b", "display_name": "Flame Sword", "is_variant": true, "reagent_id": "__r", "reagent_cost": 40, "result_quality": 1},
	] as Array[Dictionary])
	assert_array(_button_texts(popup)).is_equal(["Sword (Fine)", "Flame Sword (Fine, 40g)"])


func test_normal_results_keep_their_plain_names() -> void:
	var popup: PopupPanel = auto_free(POPUP.instantiate())
	add_child(popup)
	popup.show_options([
		{"item_id": "__a", "display_name": "Sword", "is_variant": false, "reagent_id": "", "reagent_cost": 0, "result_quality": 0},
		{"item_id": "__b", "display_name": "Flame Sword", "is_variant": true, "reagent_id": "__r", "reagent_cost": 40, "result_quality": 0},
	] as Array[Dictionary])
	assert_array(_button_texts(popup)).is_equal(["Sword", "Flame Sword (40g)"])


func _button_texts(popup: PopupPanel) -> Array:
	var texts: Array = []
	for child in popup.find_children("*", "Button", true, false):
		if not child.is_queued_for_deletion():
			texts.append(child.text)
	return texts
