extends TestBase

# An order card badges the quality an order needs; Normal orders show none.

const ORDER_CARD := preload("res://shop/order_card.tscn")


func test_a_masterwork_order_shows_two_stars() -> void:
	assert_int(_card_stars(2).quality).is_equal(2)
	assert_bool(_card_stars(2).visible).is_true()


func test_a_normal_order_shows_no_stars() -> void:
	assert_bool(_card_stars(0).visible).is_false()


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
