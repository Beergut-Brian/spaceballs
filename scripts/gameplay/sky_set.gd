## Every tier's sky objects, keyed by TierData.id (data/sky.tres). Sky lane.
class_name SkySet
extends Resource

@export var tiers: Array[SkyTier] = []


func get_tier(id: StringName) -> SkyTier:
	for t in tiers:
		if t.id == id:
			return t
	return null
