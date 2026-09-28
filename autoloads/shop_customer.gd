extends RefCounted
class_name ShopCustomer

# One customer dealt into a session: the archetype plus the orders rolled for it.
var definition: CustomerDefinition
var orders: Array[OrderDefinition] = []


func setup(customer_def: CustomerDefinition, customer_orders: Array[OrderDefinition]) -> ShopCustomer:
	definition = customer_def
	orders = customer_orders
	return self
