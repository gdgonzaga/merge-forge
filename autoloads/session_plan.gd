extends RefCounted
class_name SessionPlan

# One shop session, dealt ahead of time. The prep forecast and the shop
# session both get it from SessionPlanner.plan_next_session().
var customers: Array[ShopCustomer] = []


func setup(dealt: Array[ShopCustomer]) -> SessionPlan:
	customers = dealt
	return self
