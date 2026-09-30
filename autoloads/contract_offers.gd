extends RefCounted

# Rolls the contracts prep offers for the next session from a fixed seed.


# Each contract draws an independent exponential key, so a changed pool does
# not reshuffle the remaining candidates. Lower keys win.
func offer(contracts: Array[ContractDefinition], level: int, session_seed: int, settled_ids: Array[String], is_reachable: Callable, count: int) -> Array[ContractDefinition]:
	var ranked: Array[Dictionary] = []
	for contract in contracts:
		if _is_eligible(contract, level, settled_ids, is_reachable):
			ranked.append({"key": _race_key(contract, session_seed), "contract": contract})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["key"] != b["key"]:
			return a["key"] < b["key"]
		return a["contract"].id < b["contract"].id
	)
	var offers: Array[ContractDefinition] = []
	for entry in ranked.slice(0, maxi(count, 0)):
		offers.append(entry["contract"])
	return offers


func _is_eligible(contract: ContractDefinition, level: int, settled_ids: Array[String], is_reachable: Callable) -> bool:
	if contract.weight <= 0 or level < contract.min_shop_level:
		return false
	if contract.giver == null or level < contract.giver.min_shop_level:
		return false
	if contract.id in settled_ids:
		return false
	return is_reachable.call(contract.requirement_items())


# -log(u) / weight is an exponential draw. 1 - randf() keeps u in (0, 1].
static func _race_key(contract: ContractDefinition, session_seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([session_seed, "contract", contract.id])
	return -log(maxf(1.0 - rng.randf(), 1e-12)) / float(contract.weight)
