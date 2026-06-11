extends PanelContainer

@onready var name_label: Label = $HBox/Info/NameLabel
@onready var desc_label: Label = $HBox/Info/DescLabel
@onready var buy_btn: Button = $HBox/BuyBtn


func setup(card_name: String, description: String, desc_color: Color, btn_text: String, disabled: bool, on_press: Callable, min_height: int = 64) -> void:
	custom_minimum_size.y = min_height
	name_label.text = card_name
	name_label.modulate = Color.WHITE
	desc_label.text = description
	desc_label.visible = description != ""
	desc_label.modulate = desc_color
	buy_btn.text = btn_text
	buy_btn.disabled = disabled
	if on_press.is_valid():
		buy_btn.pressed.connect(on_press)
