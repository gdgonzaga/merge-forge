extends Node

# The one place the next shop session is planned. Prep (core/) and the shop
# (shop/) can't share code any other way (no cross-subsystem preloads), and
# the plan is a pure function of GameManager's state, so both see the same
# session.

const CUSTOMER_GENERATOR := preload("res://autoloads/customer_generator.gd")


func plan_next_session() -> SessionPlan:
	var rules := DefinitionLibrary.get_shop_rules()
	var customers: Array[ShopCustomer] = CUSTOMER_GENERATOR.new().generate(
		DefinitionLibrary.get_all_customers(),
		rules.session_size,
		GameManager.get_shop_level(),
		GameManager.get_session_seed(),
		RecipeResolver.is_craftable,
	)
	return SessionPlan.new().setup(customers)
