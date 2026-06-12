extends PanelContainer

@onready var name_label: Label = $HBox/Info/NameLabel
@onready var desc_label: Label = $HBox/Info/DescLabel
@onready var buy_btn: Button = $HBox/BuyBtn

var _pending_setup: Dictionary = {}


func setup(card_name: String, description: String, desc_color: Color, btn_text: String, disabled: bool, on_press: Callable, min_height: int = 64) -> void:
	custom_minimum_size.y = min_height
	if name_label == null:
		_pending_setup = {"card_name": card_name, "description": description, "desc_color": desc_color, "btn_text": btn_text, "disabled": disabled, "on_press": on_press}
		return
	_apply(card_name, description, desc_color, btn_text, disabled, on_press)


func _ready() -> void:
	if not _pending_setup.is_empty():
		_apply(_pending_setup.card_name, _pending_setup.description, _pending_setup.desc_color, _pending_setup.btn_text, _pending_setup.disabled, _pending_setup.on_press)
		_pending_setup = {}


func _apply(card_name: String, description: String, desc_color: Color, btn_text: String, disabled: bool, on_press: Callable) -> void:
	name_label.text = card_name
	name_label.modulate = Color.WHITE
	desc_label.text = description
	desc_label.visible = description != ""
	desc_label.modulate = desc_color
	buy_btn.text = btn_text
	buy_btn.disabled = disabled
	for conn in buy_btn.pressed.get_connections():
		buy_btn.pressed.disconnect(conn.callable)
	if on_press.is_valid():
		buy_btn.pressed.connect(on_press)
