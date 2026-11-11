## One rung of the height ladder (data/tiers.tres holds eight of these, lowest first).
class_name TierData
extends Resource

@export var id: StringName
@export var threshold: float = 0.0
@export var color: Color = Color.WHITE
@export var sky: Gradient
@export var landmark: PackedScene
@export var icon: Texture2D
@export var tier_up_cue: StringName = &"tier_up"
