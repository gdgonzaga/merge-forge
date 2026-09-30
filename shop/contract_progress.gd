extends RefCounted

var definition: ContractDefinition
var sessions_left: int = 0
var _delivered: Dictionary = {}


func setup(contract: ContractDefinition, entry: Dictionary) -> RefCounted:
	definition = contract
	sessions_left = int(entry["sessions_left"])
	_delivered = {}
	var saved: Dictionary = entry["delivered"]
	for item_id: String in saved:
		_delivered[item_id] = int(saved[item_id])
	return self


func delivered(item_id: String) -> int:
	return int(_delivered.get(item_id, 0))


func remaining(item_id: String) -> int:
	var requirement := definition.requirement_for(item_id)
	if requirement == null:
		return 0
	return maxi(requirement.min_quantity - delivered(item_id), 0)


func deliver(item_id: String, count: int, quality: int) -> int:
	var requirement := definition.requirement_for(item_id)
	if requirement == null or quality < requirement.min_quality:
		return 0
	var accepted := mini(maxi(count, 0), remaining(item_id))
	if accepted > 0:
		_delivered[item_id] = delivered(item_id) + accepted
	return accepted


func is_complete() -> bool:
	for requirement in definition.requirements:
		if remaining(requirement.item.id) > 0:
			return false
	return true


func tick_session() -> bool:
	sessions_left -= 1
	return sessions_left <= 0


func to_entry() -> Dictionary:
	return {"id": definition.id, "delivered": _delivered.duplicate(), "sessions_left": sessions_left}
