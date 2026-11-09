# PLACEHOLDER (systems grey-box): schema only. Gameplay owns future changes (contract PR first).
## One upgrade card. Content fills data/upgrades/<id>.tres. Fields exactly as GAME.md lists them.
class_name UpgradeData
extends Resource

@export var id: StringName
@export var name: String
@export var icon: Texture2D
@export_range(1, 3) var tier: int = 1
@export_enum("normal", "strong", "joke", "curse") var kind: String = "normal"
@export var power_mult: float = 1.0
@export var visual: PackedScene
@export var windup_anim: StringName
@export var kick_sfx: StringName
@export var scene_override: PackedScene
@export var description: String


func is_curse() -> bool:
	return kind == "curse"
