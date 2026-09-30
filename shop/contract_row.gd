extends HBoxContainer

signal give_requested(item_id: String, count: int)

@onready var _item_label: Label = %ItemLabel
@onready var _have_label: Label = %HaveLabel
@onready var _give_one_btn: Button = %GiveOneBtn
@onready var _give_all_btn: Button = %GiveAllBtn


func setup(requirement: OrderTemplate, delivered: int, have: int) -> void:
	var needed := requirement.min_quantity
	_item_label.text = "%d/%d %s" % [delivered, needed, requirement.item.name_at_quality(requirement.min_quality)]
	_have_label.text = "You have %d" % have
	var can_give := mini(needed - delivered, have)
	_give_one_btn.disabled = can_give < 1
	_give_all_btn.visible = can_give > 1
	_give_all_btn.text = "Give %d" % can_give
	_give_one_btn.pressed.connect(give_requested.emit.bind(requirement.item.id, 1))
	_give_all_btn.pressed.connect(give_requested.emit.bind(requirement.item.id, can_give))
