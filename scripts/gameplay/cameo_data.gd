## A rare sky cameo (playtest 2026-11-10 #3: the Dragon in the Clouds). Data: data/dragon_cameo.tres.
class_name CameoData
extends Resource

## Chance a run gets her at all (rolled at run start), so seeing her is a treat.
@export_range(0.0, 1.0) var chance_per_run := 0.35
## The ladder tier she glides through (TierSet ids: clouds is tier 5).
@export var tier_id: StringName = &"clouds"
## Flights per run she shows up on (the first flights that reach her tier).
@export var per_run := 1
## Chance she glides right across the ball's path (a bonk); else she glides by beside it.
@export_range(0.0, 1.0) var on_path_chance := 0.7
## Her size against the tier's sky things (SkyTier.scale): she is big.
@export var size_mult := 0.75
## The ball's cosmetic bounce off her tummy (m/s up, SkyObject push). Heights never change.
@export var boost := 8.0
