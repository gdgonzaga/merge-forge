extends RefCounted
class_name SessionPlan

# One shop session, dealt ahead of time. The prep forecast and the shop
# session both get it from SessionPlanner.plan_next_session().
var customers: Array[ShopCustomer] = []
# Null when no market modifier rolled.
var modifier: SessionModifierDefinition


func setup(dealt: Array[ShopCustomer], rolled: SessionModifierDefinition) -> SessionPlan:
	customers = dealt
	modifier = rolled
	return self
