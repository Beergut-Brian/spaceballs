## One kind of sky object a tier can show (data/sky.tres). Sky lane.
class_name SkyEntry
extends Resource

@export var scene: PackedScene
## Relative odds against the tier's other entries.
@export var weight := 1.0
## May be placed in the ball's path (planes, balloons, birds). Off: scenery only (the chimney cat).
@export var on_path := true
