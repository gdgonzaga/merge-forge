extends TestBase

# An order card badges the quality an order needs; Normal orders show none.

const ORDER_CARD := preload("res://shop/order_card.tscn")


func test_a_masterwork_order_shows_two_stars() -> void:
	assert_int(_card_stars(2).quality).is_equal(2)
	assert_bool(_card_stars(2).visible).is_true()


func test_a_normal_order_shows_no_stars() -> void:
	assert_bool(_card_stars(0).visible).is_false()


func test_disabled_order_card_uses_disabled_stylebox() -> void:
	var item := ItemDefinition.new()
	item.id = "__test_item"
	item.sprite = PlaceholderTexture2D.new()
	var order := OrderDefinition.new()
	order.item = item
	order.quantity = 1
	order.gold_reward = 10
	order.min_quality = 0
	var card: Button = auto_free(ORDER_CARD.instantiate())
	add_child(card)
	card.setup(order, 0)
	card.disabled = true
	var style: StyleBox = card.get_theme_stylebox("disabled")
	assert_object(style).is_not_null()
	assert_str(style.resource_path).is_equal("res://resources/themes/button_secondary_disabled.tres")


func test_enabled_order_card_uses_normal_stylebox() -> void:
	var item := ItemDefinition.new()
	item.id = "__test_item"
	item.sprite = PlaceholderTexture2D.new()
	var order := OrderDefinition.new()
	order.item = item
	order.quantity = 1
	order.gold_reward = 10
	order.min_quality = 0
	var card: Button = auto_free(ORDER_CARD.instantiate())
	add_child(card)
	card.setup(order, 0)
	card.disabled = false
	var style: StyleBox = card.get_theme_stylebox("normal")
	assert_object(style).is_not_null()
	assert_str(style.resource_path).is_equal("res://resources/themes/button_secondary.tres")


func test_play_glow_modulates_button() -> void:
	var item := ItemDefinition.new()
	item.id = "__test_item"
	item.sprite = PlaceholderTexture2D.new()
	var order := OrderDefinition.new()
	order.item = item
	order.quantity = 1
	order.gold_reward = 10
	order.min_quality = 0
	var card: Button = auto_free(ORDER_CARD.instantiate())
	add_child(card)
	card.setup(order, 0)
	card.play_glow()
	assert_bool(card.self_modulate != Color.WHITE).is_true()


func _card_stars(min_quality: int) -> Control:
	var item := ItemDefinition.new()
	item.id = "__test_item"
	item.sprite = PlaceholderTexture2D.new()
	var order := OrderDefinition.new()
	order.item = item
	order.quantity = 1
	order.gold_reward = 10
	order.min_quality = min_quality
	var card: Control = auto_free(ORDER_CARD.instantiate())
	add_child(card)
	card.setup(order, 0)
	return card.get_node("%QualityStars")
