## The whole height ladder. Tier 8's threshold is the space line.
class_name TierSet
extends Resource

## Below this the world is 1:1; above it heights are log-compressed so a 100 km kick
## stays a few hundred metres of scene and float precision never matters.
const LINEAR_UNTIL := 20.0
const LOG_SCALE := 60.0

@export var tiers: Array[TierData] = []


func tier_for(height: float) -> int:
	var out := 1
	for i in tiers.size():
		if height >= tiers[i].threshold:
			out = i + 1
	return out


func space_height() -> float:
	return tiers[-1].threshold if not tiers.is_empty() else 100000.0


func get_tier(tier: int) -> TierData:
	return tiers[clampi(tier, 1, tiers.size()) - 1]


static func visual_y(height: float) -> float:
	if height <= LINEAR_UNTIL:
		return height
	return LINEAR_UNTIL + LOG_SCALE * log(height / LINEAR_UNTIL)


static func real_height(visual: float) -> float:
	if visual <= LINEAR_UNTIL:
		return visual
	return LINEAR_UNTIL * exp((visual - LINEAR_UNTIL) / LOG_SCALE)


## 0..1 up the HUD strip: one equal block per tier, log-interpolated inside a block.
func ladder_fraction(height: float) -> float:
	var n := tiers.size()
	if n == 0:
		return 0.0
	var t := tier_for(height)
	if t >= n:
		return (float(n) - 0.5) / float(n)
	var lo := maxf(tiers[t - 1].threshold, 0.5)
	var hi := tiers[t].threshold
	var f := clampf(log(maxf(height, 0.5) / lo) / log(hi / lo), 0.0, 1.0)
	return (float(t - 1) + f) / float(n)
