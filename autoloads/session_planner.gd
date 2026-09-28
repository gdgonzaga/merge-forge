extends Node

# The one place the next shop session is planned. Prep (core/) and the shop
# (shop/) can't share code any other way (no cross-subsystem preloads), and
# the plan is a pure function of GameManager's state, so both see the same
# session.

const CUSTOMER_GENERATOR := preload("res://autoloads/customer_generator.gd")


func plan_next_session() -> SessionPlan:
	return CUSTOMER_GENERATOR.new().plan(
		DefinitionLibrary.get_all_customers(),
		DefinitionLibrary.get_all_modifiers(),
		DefinitionLibrary.get_shop_rules(),
		GameManager.get_shop_level(),
		GameManager.get_session_seed(),
		RecipeResolver.is_craftable,
		GameManager.get_order_price_multiplier(),
	)
