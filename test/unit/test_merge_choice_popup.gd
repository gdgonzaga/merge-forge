extends TestBase

# The merge-choice popup names the quality the merge will make, so a mixed
# group's outcome and a variant's remaining reagent are clear.

const POPUP := preload("res://board/merge_choice_popup.tscn")


func test_buttons_name_the_result_quality_and_the_reagent_left() -> void:
	var popup: PopupPanel = auto_free(POPUP.instantiate())
	add_child(popup)
	popup.show_options([
		{"item_id": "__a", "display_name": "Sword", "is_variant": false, "reagent_id": "", "reagent_cost": 0, "result_quality": 1},
		{"item_id": "__b", "display_name": "Flame Sword", "is_variant": true, "reagent_id": "__r", "reagent_cost": 40, "result_quality": 1, "reagent_name": "Fire", "reagent_left": 3},
	] as Array[Dictionary])
	assert_array(_button_texts(popup)).is_equal(["Sword (Fine)", "Flame Sword (Fine, 3 Fire left, 40g)"])


func test_normal_results_keep_their_plain_names() -> void:
	var popup: PopupPanel = auto_free(POPUP.instantiate())
	add_child(popup)
	popup.show_options([
		{"item_id": "__a", "display_name": "Sword", "is_variant": false, "reagent_id": "", "reagent_cost": 0, "result_quality": 0},
		{"item_id": "__b", "display_name": "Flame Sword", "is_variant": true, "reagent_id": "__r", "reagent_cost": 40, "result_quality": 0, "reagent_name": "Fire", "reagent_left": 3},
	] as Array[Dictionary])
	assert_array(_button_texts(popup)).is_equal(["Sword", "Flame Sword (3 Fire left, 40g)"])


func test_a_reagent_with_no_price_shows_only_how_many_are_left() -> void:
	var popup: PopupPanel = auto_free(POPUP.instantiate())
	add_child(popup)
	popup.show_options([
		{"item_id": "__a", "display_name": "Sword", "is_variant": false, "reagent_id": "", "reagent_cost": 0, "result_quality": 0},
		{"item_id": "__b", "display_name": "Frost Blade", "is_variant": true, "reagent_id": "__r", "reagent_cost": 0, "result_quality": 0, "reagent_name": "Ice", "reagent_left": 1},
	] as Array[Dictionary])
	assert_array(_button_texts(popup)).is_equal(["Sword", "Frost Blade (1 Ice left)"])


func test_choice_buttons_are_touch_sized_and_readable() -> void:
	var popup: PopupPanel = auto_free(POPUP.instantiate())
	add_child(popup)
	popup.show_options([{"item_id": "__a", "display_name": "Sword", "is_variant": false, "reagent_id": "", "reagent_cost": 0, "result_quality": 0}] as Array[Dictionary])
	var buttons := popup.find_children("*", "Button", true, false)
	var button: Button = buttons[0]
	assert_bool(button.custom_minimum_size.x >= 120.0 and button.custom_minimum_size.y >= 120.0).is_true()
	assert_bool(button.get_theme_font_size("font_size") >= 32).is_true()


func _button_texts(popup: PopupPanel) -> Array:
	var texts: Array = []
	for child in popup.find_children("*", "Button", true, false):
		if not child.is_queued_for_deletion():
			texts.append(child.text)
	return texts
