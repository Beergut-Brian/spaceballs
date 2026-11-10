## The sky objects of one ladder tier (data/sky.tres). Sky lane.
class_name SkyTier
extends Resource

## TierData.id this belongs to.
@export var id: StringName
@export var count_min := 3
@export var count_max := 5
## World size of this tier's objects: the follow camera is far back up high, so they grow.
@export var scale := 1.0
## How far beside the ball's path scenery sits (multiples of `scale`, sideways on screen).
@export var spread := Vector2(1.6, 4.5)
@export var entries: Array[SkyEntry] = []
