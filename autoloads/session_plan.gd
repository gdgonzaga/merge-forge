extends RefCounted
class_name SessionPlan

# One shop session, dealt ahead of time. The prep forecast and the shop
# session both get it from SessionPlanner.plan_next_session().
var customers: Array[ShopCustomer] = []
# Null when no market modifier rolled.
var modifier: SessionModifierDefinition
# The contracts prep offers before this session.
var contract_offers: Array[ContractDefinition] = []


func setup(dealt: Array[ShopCustomer], rolled: SessionModifierDefinition) -> SessionPlan:
	customers = dealt
	modifier = rolled
	return self


# Share of every order in the plan (0 to 1) per item family, largest first,
# ties by family. The forecast's "what will they ask for".
func family_demand() -> Array[Dictionary]:
	var counts := {}
	var total := 0
	for customer in customers:
		for order in customer.orders:
			counts[order.item.family] = counts.get(order.item.family, 0) + 1
			total += 1
	var result: Array[Dictionary] = []
	for family: String in counts:
		result.append({"family": family, "share": counts[family] / float(total)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["share"] != b["share"]:
			return a["share"] > b["share"]
		return a["family"] < b["family"]
	)
	return result
