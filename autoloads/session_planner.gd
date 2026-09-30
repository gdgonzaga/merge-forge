extends Node

# The one place the next shop session is planned. Prep (core/) and the shop
# (shop/) can't share code any other way (no cross-subsystem preloads), and
# the plan is a pure function of GameManager's state, so both see the same
# session. It also rolls the contracts prep offers.

const CUSTOMER_GENERATOR := preload("res://autoloads/customer_generator.gd")
const CONTRACT_OFFERS := preload("res://autoloads/contract_offers.gd")


func plan_next_session() -> SessionPlan:
	var plan: SessionPlan = CUSTOMER_GENERATOR.new().plan(
		DefinitionLibrary.get_all_customers(),
		DefinitionLibrary.get_all_modifiers(),
		DefinitionLibrary.get_shop_rules(),
		GameManager.get_shop_level(),
		GameManager.get_session_seed(),
		RecipeResolver.is_craftable,
		GameManager.get_order_price_multiplier(),
	)
	plan.contract_offers = CONTRACT_OFFERS.new().offer(
		DefinitionLibrary.get_all_contracts(),
		GameManager.get_shop_level(),
		GameManager.get_session_seed(),
		_settled_contract_ids(),
		RecipeResolver.is_within_one_blueprint,
		DefinitionLibrary.get_shop_rules().contract_offers,
	)
	return plan


# Accepting in prep keeps an offer visible. After a session ticks its time
# limit, the active contract no longer competes for an offer.
func _settled_contract_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in GameManager.active_contracts:
		var contract := DefinitionLibrary.get_contract(entry["id"])
		if contract == null or int(entry["sessions_left"]) < contract.sessions_allowed:
			ids.append(entry["id"])
	return ids
