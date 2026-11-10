## One upgrade card. Content fills data/upgrades/<id>.tres. Gameplay owns the schema (docs/contracts.md
## "UpgradeData"): the GAME.md fields, plus the gameplay effects that make each pick felt and seen.
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

@export_group("Effects")
## Body slot it is worn in. One item per slot; `none` never conflicts.
@export_enum("head", "face", "back", "hands", "waist", "knees", "feet", "ball", "none") var slot: String = "none"
@export var run_speed_mult: float = 1.0
@export var accel_mult: float = 1.0
@export var jump_mult: float = 1.0
## The kicker's own gravity while hopping: < 1 floats.
@export var gravity_mult: float = 1.0
## Added to run-up quality (the 1.2 cap stays): an easy perfect run-up.
@export var runup_bonus: float = 0.0
## normal|stomp|cannon|spin|pogo|jet|zap
@export var kick_style: StringName = &"normal"
## none|bouncy|floaty|rocket|curve|split|sparkle|confetti
@export var ball_effect: StringName = &"none"
## none|flame|bounce|honk|wind|sparkle|squeak
@export var run_fx: StringName = &"none"
## Body scale while worn.
@export var bulk: float = 1.0
## Camera shake on the kick, 0..1.
@export var shake: float = 0.0

const SLOTS: Array[String] = ["head", "face", "back", "hands", "waist", "knees", "feet", "ball", "none"]
const KICK_STYLES: Array[StringName] = [&"normal", &"stomp", &"cannon", &"spin", &"pogo", &"jet", &"zap"]
const BALL_EFFECTS: Array[StringName] = [&"none", &"bouncy", &"floaty", &"rocket", &"curve", &"split", &"sparkle", &"confetti"]
const RUN_FX: Array[StringName] = [&"none", &"flame", &"bounce", &"honk", &"wind", &"sparkle", &"squeak"]


func is_curse() -> bool:
	return kind == "curse"


## True if a pick of this card does something you can feel or see beyond the height.
func has_effect() -> bool:
	return run_speed_mult != 1.0 or accel_mult != 1.0 or jump_mult != 1.0 or gravity_mult != 1.0 \
			or runup_bonus != 0.0 or kick_style != &"normal" or ball_effect != &"none" \
			or run_fx != &"none" or bulk != 1.0 or shake > 0.0 or windup_anim != &""
