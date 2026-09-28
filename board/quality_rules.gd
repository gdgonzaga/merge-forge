extends RefCounted

# Item quality from a merge. Detection ignores quality, so a group may mix
# qualities: this decides what the group makes and what comes back.

# A group this size or larger makes its results one quality step up.
const UPGRADE_GROUP_SIZE := 5


# result_quality = min(MAX, floor(mean quality) + 1 for a group of 5+).
# The count % 3 refunds are the group's lowest qualities, so the upgrade is
# paid for with the best inputs.
static func resolve(qualities: Array[int], count: int) -> Dictionary:
	var sorted := qualities.duplicate()
	sorted.sort()
	var total := 0
	for quality in sorted:
		total += quality
	var mean_floor := 0 if sorted.is_empty() else total / sorted.size()
	var step := 1 if count >= UPGRADE_GROUP_SIZE else 0
	var refunds: Array[int] = []
	for i in range(mini(count % 3, sorted.size())):
		refunds.append(sorted[i])
	return {
		"result_quality": mini(ItemDefinition.MAX_QUALITY, mean_floor + step),
		"refund_qualities": refunds,
	}
