extends TestBase

const SUMMARY := preload("res://shop/session_summary.tscn")


func test_notes_list_every_line() -> void:
	var summary: Control = auto_free(SUMMARY.instantiate())
	add_child(summary)
	summary.display_summary({"notes": ["Brom gives you: 40 gold", "Iron Run expired"]})
	var label: Label = summary.get_node("%NotesLabel")
	assert_bool(label.visible).is_true()
	assert_str(label.text).is_equal("Brom gives you: 40 gold\nIron Run expired")


func test_no_notes_hide_the_label() -> void:
	var summary: Control = auto_free(SUMMARY.instantiate())
	add_child(summary)
	summary.display_summary({})
	assert_bool(summary.get_node("%NotesLabel").visible).is_false()
