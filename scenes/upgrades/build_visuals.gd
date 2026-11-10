## Builds scenes/upgrades/<id>.tscn: chunky, smooth-shaded attachments from Godot primitives.
## Run: godot --headless --path . -s scenes/upgrades/build_visuals.gd
## Every scene's root runs upgrade_piece.gd and carries `attach_point` metadata (contracts: Kicker).
## Positions are metres from the attach point; the kicker faces -Z, its right foot is the Feet point
## (the left foot is LEFT_FOOT away), Hands is the left hand, Body is the chest front, Back the spine.
extends SceneTree

const OUT := "res://scenes/upgrades/"
const PIECE := preload("res://scenes/upgrades/upgrade_piece.gd")
const LEFT_FOOT := Vector3(-0.24, 0.0, 0.0)
const HEAD_C := Vector3(0.0, -0.22, 0.0)   # head centre, from the Head point
const WAIST := Vector3(0.0, -0.2, 0.3)     # body centre at the waist, from the Body point

const C := {
	"ink": "0a0a14", "white": "eef8ff", "slate": "8e9cc0", "aqua": "86f6ff", "cyan": "38c6ff",
	"blue": "3d8bff", "violet": "7a6cff", "indigo": "6628ff", "teal": "1cc9a6", "plum": "9c5e9e",
	"peach": "ffbfa0", "orange": "ff9f2e", "pink": "ff4fd8", "gold": "ffd84d", "denim": "3b5ba5",
	"brown": "8a5a2b", "dark": "2b2b33", "tan": "c99a6b", "cream": "fff3c4",
}
const GLOW := ["orange_glow", "gold_glow"]

var _mats := {}
var _root: Node3D


func _init() -> void:
	var made := 0
	for id in SPECS:
		_build(id, SPECS[id])
		made += 1
	print("built %d upgrade visuals" % made)
	quit()


# --- the designs ---------------------------------------------------------------------------
# Each part: [shape, dims, pos, rot_deg, colour, parent]. Shapes: sph (dims = radii), box (size),
# cyl (top r, bottom r, height), cap (radius, height), tor (inner, outer). `colour` ending in
# _glow is emissive. `parent` names an earlier node (or Spin / Bob, made on demand).
var SPECS := {
	"big_boot": {"slot": &"feet", "step": Vector3(0, 0.12, 0), "parts": _big_boot()},
	"spring_shoes": {"slot": &"feet", "step": Vector3(0, 0.14, 0), "parts": _pair(_spring_shoe())},
	"lucky_sock": {"slot": &"feet", "step": Vector3(0, 0.08, 0), "parts": [
		["cyl", Vector3(0.1, 0.1, 0.3), Vector3(0, 0.2, 0.02), Vector3.ZERO, "white"],
		["tor", Vector2(0.09, 0.115), Vector3(0, 0.26, 0.02), Vector3.ZERO, "pink"],
		["tor", Vector2(0.09, 0.115), Vector3(0, 0.33, 0.02), Vector3.ZERO, "gold"],
		["sph", Vector3(0.12, 0.08, 0.17), Vector3(0, 0.06, -0.06), Vector3.ZERO, "pink"],
		["sph", Vector3(0.035, 0.035, 0.02), Vector3(0.0, 0.2, -0.1), Vector3.ZERO, "teal"],
		["sph", Vector3(0.035, 0.035, 0.02), Vector3(0.04, 0.24, -0.1), Vector3.ZERO, "teal"],
		["sph", Vector3(0.035, 0.035, 0.02), Vector3(-0.04, 0.24, -0.1), Vector3.ZERO, "teal"]]},
	"trampoline_tee": {"slot": &"back", "step": Vector3(0, 0, 0.1), "parts": [
		["tor", Vector2(0.2, 0.26), Vector3(0, 0.05, 0.08), Vector3(90, 0, 0), "dark"],
		["cyl", Vector3(0.21, 0.21, 0.02), Vector3(0, 0.05, 0.08), Vector3(90, 0, 0), "blue"],
		["cap", Vector2(0.025, 0.2), Vector3(-0.17, -0.12, 0.14), Vector3(70, 0, 0), "dark"],
		["cap", Vector2(0.025, 0.2), Vector3(0.17, -0.12, 0.14), Vector3(70, 0, 0), "dark"],
		["sph", Vector3(0.09, 0.09, 0.09), Vector3(0, 0.05, 0.19), Vector3.ZERO, "orange"]]},
	"helium_ball": {"slot": &"back", "step": Vector3(0, 0, 0.14), "bob": 0.06, "parts": [
		["cap", Vector2(0.09, 0.4), Vector3(0, 0, 0.08), Vector3.ZERO, "slate"],
		["cyl", Vector3(0.03, 0.03, 0.08), Vector3(0, 0.23, 0.08), Vector3.ZERO, "dark"],
		["cyl", Vector3(0.006, 0.006, 0.6), Vector3(0, 0.55, 0.08), Vector3.ZERO, "white"],
		["sph", Vector3(0.2, 0.22, 0.2), Vector3(0, 0.95, 0.08), Vector3.ZERO, "orange", "Bob"],
		["sph", Vector3(0.04, 0.04, 0.04), Vector3(0, 0.72, 0.08), Vector3.ZERO, "orange", "Bob"]]},
	"sweatband": {"slot": &"head", "step": Vector3(0, 0.04, 0), "parts": [
		["tor", Vector2(0.3, 0.38), HEAD_C + Vector3(0, 0.12, 0), Vector3(-8, 0, 0), "white"],
		["tor", Vector2(0.33, 0.385), HEAD_C + Vector3(0, 0.12, 0), Vector3(-8, 0, 0), "orange"]]},
	"rocket_boots": {"slot": &"feet", "step": Vector3(0, 0.12, 0), "parts": _pair(_rocket_boot())},
	"super_strength": {"slot": &"hands", "step": Vector3(0, 0.1, 0), "parts": [
		["cyl", Vector3(0.025, 0.025, 0.5), Vector3(0, 0.02, 0), Vector3(90, 0, 0), "slate"],
		["cyl", Vector3(0.11, 0.11, 0.08), Vector3(0, 0.02, -0.2), Vector3(90, 0, 0), "dark"],
		["cyl", Vector3(0.11, 0.11, 0.08), Vector3(0, 0.02, 0.2), Vector3(90, 0, 0), "dark"],
		["cyl", Vector3(0.08, 0.08, 0.05), Vector3(0, 0.02, -0.27), Vector3(90, 0, 0), "dark"],
		["cyl", Vector3(0.08, 0.08, 0.05), Vector3(0, 0.02, 0.27), Vector3(90, 0, 0), "dark"]]},
	"running_start": {"slot": &"body", "step": Vector3(0, -0.05, -0.04), "parts": [
		["tor", Vector2(0.01, 0.03), Vector3(0, 0.33, 0.22), Vector3(-60, 0, 0), "pink"],
		["cyl", Vector3(0.13, 0.13, 0.05), Vector3(0, 0.0, -0.03), Vector3(90, 0, 0), "slate"],
		["cyl", Vector3(0.105, 0.105, 0.03), Vector3(0, 0.0, -0.05), Vector3(90, 0, 0), "white"],
		["box", Vector3(0.015, 0.08, 0.01), Vector3(0, 0.035, -0.07), Vector3.ZERO, "ink"],
		["box", Vector3(0.06, 0.015, 0.01), Vector3(0.03, 0.0, -0.07), Vector3.ZERO, "pink"],
		["cyl", Vector3(0.025, 0.025, 0.05), Vector3(0, 0.15, -0.03), Vector3.ZERO, "orange"]]},
	"coachs_whistle": {"slot": &"body", "step": Vector3(0, -0.05, -0.04), "windup": true,
		"cue": ["whistle", "ui_confirm", 2.0], "parts": [
		["tor", Vector2(0.24, 0.26), Vector3(0, 0.28, 0.24), Vector3(-55, 0, 0), "pink"],
		["cyl", Vector3(0.07, 0.07, 0.07), Vector3(0.02, -0.02, -0.04), Vector3(0, 0, 90), "gold"],
		["box", Vector3(0.12, 0.05, 0.06), Vector3(-0.07, 0.03, -0.04), Vector3.ZERO, "gold"],
		["cyl", Vector3(0.03, 0.03, 0.072), Vector3(0.02, -0.02, -0.04), Vector3(0, 0, 90), "dark"]]},
	"super_cape": {"slot": &"back", "step": Vector3(0, 0, 0.04), "parts": [
		["box", Vector3(0.62, 0.95, 0.03), Vector3(0, -0.2, 0.08), Vector3(12, 0, 0), "pink"],
		["cap", Vector2(0.05, 0.6), Vector3(0, 0.27, 0.0), Vector3(0, 0, 90), "gold"],
		["sph", Vector3(0.12, 0.12, 0.02), Vector3(0, -0.1, 0.13), Vector3(12, 0, 0), "gold"]]},
	"propeller_cap": {"slot": &"head", "step": Vector3(0, 0.22, 0), "spin": 14.0, "parts": [
		["sph", Vector3(0.3, 0.17, 0.3), HEAD_C + Vector3(0, 0.2, 0), Vector3.ZERO, "blue"],
		["box", Vector3(0.26, 0.03, 0.22), HEAD_C + Vector3(0, 0.2, -0.3), Vector3.ZERO, "denim"],
		["cyl", Vector3(0.015, 0.015, 0.14), Vector3(0, 0.1, 0), Vector3.ZERO, "slate"],
		["sph", Vector3(0.04, 0.04, 0.04), Vector3(0, 0.0, 0), Vector3.ZERO, "gold", "Spin"],
		["sph", Vector3(0.2, 0.015, 0.05), Vector3(0.18, 0.0, 0), Vector3.ZERO, "orange", "Spin"],
		["sph", Vector3(0.2, 0.015, 0.05), Vector3(-0.18, 0.0, 0), Vector3.ZERO, "pink", "Spin"]],
		"spin_at": Vector3(0, 0.17, 0)},
	"foam_finger": {"slot": &"hands", "step": Vector3(0, 0.12, 0), "parts": [
		["sph", Vector3(0.15, 0.16, 0.09), Vector3(0, 0.1, 0), Vector3.ZERO, "gold"],
		["cap", Vector2(0.06, 0.38), Vector3(0, 0.36, 0), Vector3.ZERO, "gold"],
		["cap", Vector2(0.05, 0.16), Vector3(0.14, 0.14, -0.03), Vector3(0, 0, -50), "gold"],
		["cyl", Vector3(0.13, 0.13, 0.1), Vector3(0, -0.04, 0), Vector3.ZERO, "orange"]]},
	"giant_foot": {"slot": &"feet", "step": Vector3(0, 0.18, 0), "parts": [
		["sph", Vector3(0.3, 0.19, 0.48), Vector3(0.04, 0.12, -0.22), Vector3.ZERO, "peach"],
		["sph", Vector3(0.09, 0.08, 0.1), Vector3(-0.14, 0.15, -0.64), Vector3.ZERO, "peach"],
		["sph", Vector3(0.07, 0.065, 0.08), Vector3(0.0, 0.14, -0.67), Vector3.ZERO, "peach"],
		["sph", Vector3(0.065, 0.06, 0.075), Vector3(0.11, 0.13, -0.64), Vector3.ZERO, "peach"],
		["sph", Vector3(0.055, 0.05, 0.065), Vector3(0.21, 0.12, -0.58), Vector3.ZERO, "peach"],
		["sph", Vector3(0.05, 0.045, 0.06), Vector3(0.28, 0.11, -0.5), Vector3.ZERO, "peach"],
		["cyl", Vector3(0.16, 0.2, 0.2), Vector3(0.04, 0.32, -0.02), Vector3.ZERO, "peach"]]},
	"knee_pads": {"slot": &"feet", "step": Vector3(0, 0.05, 0), "parts": _pair([
		["sph", Vector3(0.1, 0.11, 0.06), Vector3(0, 0.38, -0.08), Vector3(10, 0, 0), "orange"],
		["sph", Vector3(0.06, 0.065, 0.03), Vector3(0, 0.38, -0.13), Vector3(10, 0, 0), "gold"]])},
	"wind_up_key": {"slot": &"back", "step": Vector3(0, 0, 0.22), "spin": 3.0, "spin_at": Vector3(0, 0.05, 0.3),
		"spin_rot": Vector3(90, 0, 0), "parts": [
		["cyl", Vector3(0.035, 0.035, 0.32), Vector3(0, 0.05, 0.14), Vector3(90, 0, 0), "gold"],
		["sph", Vector3(0.06, 0.06, 0.06), Vector3(0, 0.0, 0), Vector3.ZERO, "orange", "Spin"],
		["tor", Vector2(0.06, 0.12), Vector3(0.15, 0.0, 0), Vector3(0, 0, 90), "gold", "Spin"],
		["tor", Vector2(0.06, 0.12), Vector3(-0.15, 0.0, 0), Vector3(0, 0, 90), "gold", "Spin"]]},
	"dad_strength": {"slot": &"body", "step": Vector3(0, 0.06, 0), "parts": [
		["tor", Vector2(0.3, 0.37), WAIST, Vector3.ZERO, "brown"],
		["box", Vector3(0.08, 0.12, 0.06), WAIST + Vector3(-0.2, -0.05, -0.26), Vector3.ZERO, "orange"],
		["box", Vector3(0.1, 0.1, 0.06), WAIST + Vector3(0.2, -0.05, -0.26), Vector3.ZERO, "slate"],
		["cyl", Vector3(0.02, 0.02, 0.3), WAIST + Vector3(0.33, -0.1, -0.1), Vector3(0, 0, 10), "brown"],
		["box", Vector3(0.14, 0.06, 0.06), WAIST + Vector3(0.36, 0.06, -0.1), Vector3(0, 0, 10), "dark"]]},
	"slingshot_buddy": {"slot": &"back", "step": Vector3(0, 0, 0.1), "parts": [
		["cyl", Vector3(0.04, 0.04, 0.4), Vector3(0, -0.15, 0.1), Vector3.ZERO, "brown"],
		["cyl", Vector3(0.035, 0.04, 0.35), Vector3(-0.12, 0.17, 0.1), Vector3(0, 0, 35), "brown"],
		["cyl", Vector3(0.035, 0.04, 0.35), Vector3(0.12, 0.17, 0.1), Vector3(0, 0, -35), "brown"],
		["cyl", Vector3(0.012, 0.012, 0.42), Vector3(0, 0.3, 0.12), Vector3(0, 0, 90), "pink"],
		["sph", Vector3(0.07, 0.07, 0.07), Vector3(0, 0.3, 0.16), Vector3.ZERO, "orange"]]},
	"moon_gravity": {"slot": &"head", "step": Vector3.ZERO, "spin": 1.6, "spin_at": HEAD_C + Vector3(0, 0.15, 0), "parts": [
		["sph", Vector3(0.13, 0.13, 0.13), Vector3(0.5, 0.0, 0), Vector3.ZERO, "white", "Spin"],
		["sph", Vector3(0.04, 0.04, 0.02), Vector3(0.48, 0.04, -0.12), Vector3.ZERO, "slate", "Spin"],
		["sph", Vector3(0.03, 0.03, 0.02), Vector3(0.55, -0.05, -0.11), Vector3.ZERO, "slate", "Spin"]]},
	"cannon_leg": {"slot": &"feet", "step": Vector3(0, 0.12, 0), "cue": ["cannon_boom", "kick_3", 0.7], "burst": "smoke",
		"burst_at": Vector3(0, 0.25, -0.6), "parts": [
		["cyl", Vector3(0.11, 0.15, 0.6), Vector3(0, 0.25, -0.2), Vector3(-80, 0, 0), "dark"],
		["tor", Vector2(0.09, 0.15), Vector3(0, 0.3, -0.5), Vector3(-80, 0, 0), "dark"],
		["cyl", Vector3(0.15, 0.15, 0.05), Vector3(0.17, 0.15, 0), Vector3(0, 0, 90), "brown"],
		["cyl", Vector3(0.05, 0.05, 0.06), Vector3(0.18, 0.15, 0), Vector3(0, 0, 90), "gold"]]},
	"pogo_legs": {"slot": &"feet", "step": Vector3(0, 0.0, 0.06), "parts": _pair([
		["cyl", Vector3(0.025, 0.025, 0.95), Vector3(0, 0.45, 0.12), Vector3.ZERO, "slate"],
		["cap", Vector2(0.035, 0.3), Vector3(0, 0.9, 0.12), Vector3(0, 0, 90), "orange"],
		["box", Vector3(0.14, 0.03, 0.1), Vector3(0, 0.2, 0.07), Vector3.ZERO, "blue"],
		["tor", Vector2(0.03, 0.06), Vector3(0, 0.07, 0.12), Vector3.ZERO, "gold"],
		["tor", Vector2(0.03, 0.06), Vector3(0, 0.11, 0.12), Vector3.ZERO, "gold"],
		["tor", Vector2(0.03, 0.06), Vector3(0, 0.15, 0.12), Vector3.ZERO, "gold"]])},
	"tornado_spin": {"slot": &"body", "step": Vector3.ZERO, "spin": 9.0, "spin_at": WAIST + Vector3(0, -0.15, 0), "parts": [
		["cyl", Vector3(0.55, 0.12, 0.7), Vector3(0, 0, 0), Vector3.ZERO, "aqua_clear", "Spin"],
		["tor", Vector2(0.4, 0.46), Vector3(0, 0.2, 0), Vector3(0, 0, 6), "white", "Spin"],
		["tor", Vector2(0.27, 0.32), Vector3(0, -0.05, 0), Vector3(6, 0, 0), "white", "Spin"],
		["tor", Vector2(0.15, 0.19), Vector3(0, -0.25, 0), Vector3(0, 0, -6), "white", "Spin"]]},
	"jetpack": {"slot": &"back", "step": Vector3(0, 0, 0.22), "parts": [
		["box", Vector3(0.3, 0.3, 0.08), Vector3(0, 0.05, 0.06), Vector3.ZERO, "dark"],
		["cap", Vector2(0.11, 0.55), Vector3(-0.15, 0.0, 0.17), Vector3.ZERO, "slate"],
		["cap", Vector2(0.11, 0.55), Vector3(0.15, 0.0, 0.17), Vector3.ZERO, "slate"],
		["cyl", Vector3(0.0, 0.1, 0.16), Vector3(-0.15, 0.32, 0.17), Vector3.ZERO, "orange"],
		["cyl", Vector3(0.0, 0.1, 0.16), Vector3(0.15, 0.32, 0.17), Vector3.ZERO, "orange"],
		["cyl", Vector3(0.09, 0.0, 0.25), Vector3(-0.15, -0.38, 0.17), Vector3.ZERO, "orange_glow"],
		["cyl", Vector3(0.09, 0.0, 0.25), Vector3(0.15, -0.38, 0.17), Vector3.ZERO, "orange_glow"],
		["cyl", Vector3(0.05, 0.0, 0.15), Vector3(-0.15, -0.33, 0.17), Vector3.ZERO, "gold_glow"],
		["cyl", Vector3(0.05, 0.0, 0.15), Vector3(0.15, -0.33, 0.17), Vector3.ZERO, "gold_glow"]]},
	"volcano_boots": {"slot": &"feet", "step": Vector3(0, 0.14, 0), "parts": _pair([
		["cyl", Vector3(0.08, 0.17, 0.26), Vector3(0, 0.13, -0.03), Vector3.ZERO, "brown"],
		["sph", Vector3(0.075, 0.04, 0.075), Vector3(0, 0.26, -0.03), Vector3.ZERO, "orange_glow"],
		["sph", Vector3(0.04, 0.04, 0.04), Vector3(0.02, 0.33, -0.03), Vector3.ZERO, "gold_glow"],
		["sph", Vector3(0.03, 0.08, 0.03), Vector3(0.1, 0.12, -0.14), Vector3(0, 0, -20), "orange_glow"]])},
	"kangaroo_tail": {"slot": &"back", "step": Vector3(0, 0, 0.1), "parts": [
		["sph", Vector3(0.13, 0.13, 0.13), Vector3(0, -0.28, 0.06), Vector3.ZERO, "tan"],
		["sph", Vector3(0.12, 0.12, 0.12), Vector3(0, -0.4, 0.2), Vector3.ZERO, "tan"],
		["sph", Vector3(0.1, 0.1, 0.1), Vector3(0, -0.52, 0.34), Vector3.ZERO, "tan"],
		["sph", Vector3(0.085, 0.085, 0.085), Vector3(0, -0.6, 0.48), Vector3.ZERO, "tan"],
		["sph", Vector3(0.07, 0.07, 0.07), Vector3(0, -0.63, 0.61), Vector3.ZERO, "tan"],
		["sph", Vector3(0.06, 0.06, 0.06), Vector3(0, -0.6, 0.72), Vector3.ZERO, "cream"]]},
	"turbo_fan": {"slot": &"back", "step": Vector3(0, 0, 0.2), "spin": 18.0, "spin_at": Vector3(0, 0.08, 0.2),
		"spin_rot": Vector3(90, 0, 0), "parts": [
		["box", Vector3(0.62, 0.62, 0.14), Vector3(0, 0.08, 0.16), Vector3.ZERO, "slate"],
		["cyl", Vector3(0.27, 0.27, 0.15), Vector3(0, 0.08, 0.17), Vector3(90, 0, 0), "aqua"],
		["sph", Vector3(0.06, 0.06, 0.06), Vector3(0, 0.0, 0), Vector3.ZERO, "orange", "Spin"],
		["sph", Vector3(0.11, 0.015, 0.05), Vector3(0.13, 0.0, 0), Vector3(0, 0, 0), "blue", "Spin"],
		["sph", Vector3(0.11, 0.015, 0.05), Vector3(-0.065, 0.0, 0.11), Vector3(0, 120, 0), "pink", "Spin"],
		["sph", Vector3(0.11, 0.015, 0.05), Vector3(-0.065, 0.0, -0.11), Vector3(0, 240, 0), "gold", "Spin"]]},
	"thunder_hat": {"slot": &"head", "step": Vector3(0, 0.3, 0), "bob": 0.04, "parts": [
		["sph", Vector3(0.2, 0.15, 0.18), Vector3(0, 0.32, 0), Vector3.ZERO, "slate", "Bob"],
		["sph", Vector3(0.15, 0.12, 0.15), Vector3(-0.2, 0.27, 0), Vector3.ZERO, "slate", "Bob"],
		["sph", Vector3(0.15, 0.12, 0.15), Vector3(0.2, 0.27, 0.02), Vector3.ZERO, "slate", "Bob"],
		["sph", Vector3(0.13, 0.1, 0.13), Vector3(0.05, 0.25, -0.13), Vector3.ZERO, "slate", "Bob"],
		["box", Vector3(0.05, 0.14, 0.03), Vector3(0.03, 0.12, -0.12), Vector3(0, 0, 25), "gold_glow", "Bob"],
		["box", Vector3(0.05, 0.14, 0.03), Vector3(0.0, 0.02, -0.12), Vector3(0, 0, -25), "gold_glow", "Bob"]]},
	"tiny_hat": {"slot": &"head", "step": Vector3(0, 0.12, 0), "parts": [
		["cyl", Vector3(0.09, 0.09, 0.015), Vector3(0.03, 0.06, 0), Vector3(0, 0, -8), "dark"],
		["cyl", Vector3(0.055, 0.055, 0.1), Vector3(0.03, 0.11, 0), Vector3(0, 0, -8), "dark"],
		["cyl", Vector3(0.057, 0.057, 0.025), Vector3(0.03, 0.08, 0), Vector3(0, 0, -8), "pink"]]},
	"extra_shoes": {"slot": &"feet", "step": Vector3.ZERO, "parts": [
		["sph", Vector3(0.12, 0.09, 0.19), Vector3(0.02, 0.06, 0.32), Vector3.ZERO, "pink"],
		["sph", Vector3(0.12, 0.09, 0.19), Vector3(-0.26, 0.06, 0.32), Vector3.ZERO, "gold"],
		["cyl", Vector3(0.05, 0.05, 0.3), Vector3(0.02, 0.24, 0.36), Vector3(-15, 0, 0), "peach"],
		["cyl", Vector3(0.05, 0.05, 0.3), Vector3(-0.26, 0.24, 0.36), Vector3(-15, 0, 0), "peach"],
		["box", Vector3(0.24, 0.04, 0.38), Vector3(0.02, 0.0, 0.32), Vector3.ZERO, "white"],
		["box", Vector3(0.24, 0.04, 0.38), Vector3(-0.26, 0.0, 0.32), Vector3.ZERO, "white"]]},
	"mustache": {"slot": &"head", "step": Vector3.ZERO, "parts": [
		["cap", Vector2(0.055, 0.25), HEAD_C + Vector3(-0.085, -0.19, -0.34), Vector3(0, 0, 76), "dark"],
		["cap", Vector2(0.055, 0.25), HEAD_C + Vector3(0.085, -0.19, -0.34), Vector3(0, 0, -76), "dark"],
		["sph", Vector3(0.045, 0.045, 0.045), HEAD_C + Vector3(-0.2, -0.15, -0.3), Vector3.ZERO, "dark"],
		["sph", Vector3(0.045, 0.045, 0.045), HEAD_C + Vector3(0.2, -0.15, -0.3), Vector3.ZERO, "dark"]]},
	"honk_horn_shoes": {"slot": &"feet", "step": Vector3(0, 0.12, 0), "cue": ["honk", "card_move", 0.45],
		"parts": _pair(_honk_shoe())},
	"confetti_kick": {"slot": &"feet", "step": Vector3(0, 0.1, 0), "cue": ["confetti_pop", "tier_up", 1.5],
		"burst": "confetti", "burst_at": Vector3(0, 0.2, -0.45), "parts": [
		["cyl", Vector3(0.0, 0.09, 0.28), Vector3(0, 0.14, -0.28), Vector3(-75, 0, 0), "pink"],
		["tor", Vector2(0.03, 0.08), Vector3(0, 0.12, -0.2), Vector3(-75, 0, 0), "gold"],
		["sph", Vector3(0.09, 0.03, 0.09), Vector3(0, 0.17, -0.42), Vector3(-75, 0, 0), "gold"]]},
	"balloon_animal_ball": {"slot": &"hands", "step": Vector3(0, 0.2, 0), "cue": ["squeak", "hop", 2.0], "parts": [
		["cap", Vector2(0.07, 0.36), Vector3(0, 0.3, 0), Vector3(90, 0, 0), "pink"],
		["cap", Vector2(0.05, 0.2), Vector3(0, 0.18, -0.12), Vector3.ZERO, "pink"],
		["cap", Vector2(0.05, 0.2), Vector3(0, 0.18, 0.12), Vector3.ZERO, "pink"],
		["cap", Vector2(0.06, 0.2), Vector3(0, 0.42, -0.2), Vector3(-30, 0, 0), "pink"],
		["sph", Vector3(0.08, 0.07, 0.1), Vector3(0, 0.52, -0.26), Vector3.ZERO, "pink"],
		["cap", Vector2(0.035, 0.16), Vector3(0.05, 0.62, -0.22), Vector3.ZERO, "pink"],
		["cap", Vector2(0.035, 0.16), Vector3(-0.05, 0.62, -0.22), Vector3.ZERO, "pink"],
		["cap", Vector2(0.03, 0.16), Vector3(0, 0.36, 0.2), Vector3(40, 0, 0), "pink"]]},
	"opera_kick": {"slot": &"head", "step": Vector3.ZERO, "windup": true, "cue": ["opera_la", "cheer", 0.6],
		"burst": "notes", "burst_at": HEAD_C + Vector3(0, 0.2, -0.3), "parts": _ruff()},
	"rubber_chicken": {"slot": &"hands", "step": Vector3(0, 0.15, 0), "cue": ["squawk", "shout", 1.8], "parts": [
		["cap", Vector2(0.08, 0.3), Vector3(0, 0.05, -0.05), Vector3(70, 0, 0), "gold"],
		["cap", Vector2(0.035, 0.28), Vector3(0, 0.15, -0.25), Vector3(20, 0, 0), "gold"],
		["sph", Vector3(0.06, 0.06, 0.06), Vector3(0, 0.29, -0.3), Vector3.ZERO, "gold"],
		["sph", Vector3(0.04, 0.02, 0.05), Vector3(0, 0.28, -0.37), Vector3.ZERO, "orange"],
		["sph", Vector3(0.02, 0.05, 0.04), Vector3(0, 0.35, -0.29), Vector3.ZERO, "pink"],
		["cyl", Vector3(0.012, 0.012, 0.15), Vector3(0.03, -0.08, 0.05), Vector3(-30, 0, 0), "orange"],
		["cyl", Vector3(0.012, 0.012, 0.15), Vector3(-0.03, -0.08, 0.05), Vector3(-30, 0, 0), "orange"]]},
	"duck_floatie": {"slot": &"body", "step": Vector3(0, 0.1, 0), "parts": [
		["tor", Vector2(0.3, 0.52), WAIST + Vector3(0, -0.05, 0), Vector3.ZERO, "gold"],
		["sph", Vector3(0.14, 0.14, 0.14), WAIST + Vector3(0, 0.15, -0.42), Vector3.ZERO, "gold"],
		["sph", Vector3(0.08, 0.035, 0.08), WAIST + Vector3(0, 0.13, -0.56), Vector3.ZERO, "orange"],
		["sph", Vector3(0.025, 0.025, 0.02), WAIST + Vector3(0.07, 0.2, -0.53), Vector3.ZERO, "ink"],
		["sph", Vector3(0.025, 0.025, 0.02), WAIST + Vector3(-0.07, 0.2, -0.53), Vector3.ZERO, "ink"]]},
	"googly_eyes": {"slot": &"body", "step": Vector3(0, 0, -0.03), "bob": 0.015, "parts": [
		["sph", Vector3(0.11, 0.11, 0.05), Vector3(-0.11, 0.0, -0.02), Vector3.ZERO, "white"],
		["sph", Vector3(0.1, 0.1, 0.05), Vector3(0.11, 0.02, -0.02), Vector3.ZERO, "white"],
		["sph", Vector3(0.05, 0.05, 0.03), Vector3(-0.1, -0.03, -0.06), Vector3.ZERO, "ink", "Bob"],
		["sph", Vector3(0.045, 0.045, 0.03), Vector3(0.14, 0.0, -0.06), Vector3.ZERO, "ink", "Bob"]]},
	# --- curses: Gameplay attaches these for the cursed kick (see the report); the frog uses scene_override.
	"banana_peel": {"slot": &"feet", "step": Vector3.ZERO, "cue": ["slip", "land", 1.6], "parts": [
		["sph", Vector3(0.05, 0.12, 0.05), Vector3(0, 0.1, -0.35), Vector3.ZERO, "gold"],
		["sph", Vector3(0.13, 0.025, 0.05), Vector3(0.1, 0.02, -0.35), Vector3(0, 0, -10), "gold"],
		["sph", Vector3(0.13, 0.025, 0.05), Vector3(-0.1, 0.02, -0.35), Vector3(0, 0, 10), "gold"],
		["sph", Vector3(0.05, 0.025, 0.13), Vector3(0, 0.02, -0.25), Vector3.ZERO, "gold"],
		["cyl", Vector3(0.015, 0.015, 0.04), Vector3(0, 0.23, -0.35), Vector3.ZERO, "brown"]]},
	"sneeze": {"slot": &"hands", "step": Vector3(0, 0.12, 0), "windup": true, "cue": ["achoo", "curse", 1.3],
		"burst": "sneeze", "burst_at": Vector3(0.36, 0.95, -0.4), "parts": [
		["box", Vector3(0.2, 0.12, 0.14), Vector3(0, 0.05, 0), Vector3.ZERO, "aqua"],
		["sph", Vector3(0.07, 0.08, 0.06), Vector3(0, 0.15, 0), Vector3.ZERO, "white"]]},
	"shoelaces_tied": {"slot": &"feet", "step": Vector3.ZERO, "parts": [
		["cyl", Vector3(0.015, 0.015, 0.26), Vector3(-0.12, 0.13, -0.1), Vector3(0, 0, 90), "white"],
		["tor", Vector2(0.025, 0.05), Vector3(-0.17, 0.13, -0.12), Vector3(90, 0, 0), "white"],
		["tor", Vector2(0.025, 0.05), Vector3(-0.07, 0.13, -0.12), Vector3(90, 0, 0), "white"],
		["sph", Vector3(0.025, 0.025, 0.025), Vector3(-0.12, 0.13, -0.12), Vector3.ZERO, "white"]]},
	"too_much_lunch": {"slot": &"body", "step": Vector3.ZERO, "parts": [
		["sph", Vector3(0.36, 0.34, 0.3), WAIST + Vector3(0, 0.05, -0.12), Vector3.ZERO, "cream"],
		["box", Vector3(0.22, 0.05, 0.16), WAIST + Vector3(0, 0.15, -0.46), Vector3.ZERO, "tan"],
		["box", Vector3(0.2, 0.02, 0.15), WAIST + Vector3(0, 0.185, -0.46), Vector3.ZERO, "teal"],
		["box", Vector3(0.2, 0.025, 0.15), WAIST + Vector3(0, 0.21, -0.46), Vector3.ZERO, "pink"],
		["box", Vector3(0.22, 0.05, 0.16), WAIST + Vector3(0, 0.25, -0.46), Vector3.ZERO, "tan"]]},
	"butterfly": {"slot": &"head", "step": Vector3.ZERO, "bob": 0.08, "parts": [
		["cap", Vector2(0.02, 0.12), Vector3(0.0, 0.3, -0.35), Vector3(90, 0, 0), "dark", "Bob"],
		["sph", Vector3(0.1, 0.11, 0.01), Vector3(-0.08, 0.34, -0.35), Vector3(0, 30, 20), "pink", "Bob"],
		["sph", Vector3(0.1, 0.11, 0.01), Vector3(0.08, 0.34, -0.35), Vector3(0, -30, -20), "pink", "Bob"],
		["sph", Vector3(0.06, 0.07, 0.01), Vector3(-0.07, 0.25, -0.33), Vector3(0, 30, -20), "gold", "Bob"],
		["sph", Vector3(0.06, 0.07, 0.01), Vector3(0.07, 0.25, -0.33), Vector3(0, -30, 20), "gold", "Bob"]]},
	"hiccups": {"slot": &"head", "step": Vector3.ZERO, "bob": 0.06, "cue": ["hic", "hop", 1.6], "parts": [
		["sph", Vector3(0.07, 0.07, 0.07), Vector3(0.25, 0.1, -0.3), Vector3.ZERO, "aqua_clear", "Bob"],
		["sph", Vector3(0.05, 0.05, 0.05), Vector3(0.35, 0.25, -0.25), Vector3.ZERO, "aqua_clear", "Bob"],
		["sph", Vector3(0.035, 0.035, 0.035), Vector3(0.3, 0.38, -0.2), Vector3.ZERO, "aqua_clear", "Bob"]]},
}


func _pair(parts: Array) -> Array:
	var out := parts.duplicate(true)
	for p in parts:
		var q: Array = p.duplicate(true)
		q[2] = q[2] + LEFT_FOOT
		out.append(q)
	return out


func _big_boot() -> Array:
	return [
		["sph", Vector3(0.2, 0.15, 0.3), Vector3(0, 0.1, -0.14), Vector3.ZERO, "brown"],
		["cyl", Vector3(0.16, 0.17, 0.36), Vector3(0, 0.27, 0.04), Vector3.ZERO, "brown"],
		["box", Vector3(0.42, 0.07, 0.66), Vector3(0, 0.0, -0.08), Vector3.ZERO, "dark"],
		["tor", Vector2(0.14, 0.2), Vector3(0, 0.45, 0.04), Vector3.ZERO, "tan"],
		["cyl", Vector3(0.012, 0.012, 0.16), Vector3(0, 0.25, -0.12), Vector3(0, 0, 90), "white"],
		["cyl", Vector3(0.012, 0.012, 0.16), Vector3(0, 0.32, -0.11), Vector3(0, 0, 90), "white"]]


func _spring_shoe() -> Array:
	return [
		["sph", Vector3(0.12, 0.09, 0.19), Vector3(0, 0.07, -0.05), Vector3.ZERO, "blue"],
		["box", Vector3(0.22, 0.04, 0.36), Vector3(0, 0.0, -0.05), Vector3.ZERO, "white"],
		["tor", Vector2(0.06, 0.1), Vector3(0, 0.16, 0.0), Vector3.ZERO, "gold"],
		["tor", Vector2(0.06, 0.1), Vector3(0, 0.22, 0.0), Vector3.ZERO, "gold"],
		["tor", Vector2(0.06, 0.1), Vector3(0, 0.28, 0.0), Vector3.ZERO, "gold"]]


func _rocket_boot() -> Array:
	return [
		["sph", Vector3(0.13, 0.1, 0.2), Vector3(0, 0.07, -0.05), Vector3.ZERO, "blue"],
		["cyl", Vector3(0.11, 0.11, 0.22), Vector3(0, 0.2, 0.0), Vector3.ZERO, "blue"],
		["cap", Vector2(0.06, 0.26), Vector3(0, 0.22, 0.15), Vector3.ZERO, "slate"],
		["cyl", Vector3(0.0, 0.06, 0.1), Vector3(0, 0.39, 0.15), Vector3.ZERO, "orange"],
		["cyl", Vector3(0.05, 0.0, 0.16), Vector3(0, 0.02, 0.15), Vector3.ZERO, "orange_glow"]]


func _honk_shoe() -> Array:
	return [
		["sph", Vector3(0.13, 0.1, 0.2), Vector3(0, 0.07, -0.05), Vector3.ZERO, "pink"],
		["sph", Vector3(0.06, 0.06, 0.06), Vector3(0, 0.2, 0.02), Vector3.ZERO, "orange"],
		["cyl", Vector3(0.015, 0.06, 0.16), Vector3(0, 0.2, -0.1), Vector3(-90, 0, 0), "gold"]]


func _ruff() -> Array:
	var out := []
	for i in 14:
		var a := TAU * i / 14.0
		out.append(["sph", Vector3(0.09, 0.07, 0.09), HEAD_C + Vector3(cos(a) * 0.3, -0.36, sin(a) * 0.3),
				Vector3(0, -rad_to_deg(a), 30), "white"])
	return out


# --- building ------------------------------------------------------------------------------

func _build(id: String, spec: Dictionary) -> void:
	_root = Node3D.new()
	_root.name = id.to_pascal_case()
	_root.set_script(PIECE)
	_root.set_meta(&"attach_point", spec["slot"])
	_root.set(&"stack_step", spec.get("step", Vector3(0, 0.1, 0)))
	_root.set(&"spin_speed", spec.get("spin", 0.0))
	_root.set(&"bob", spec.get("bob", 0.0))
	_root.set(&"gag_on_windup", spec.get("windup", false))
	if spec.has("cue"):
		_root.set(&"gag_cue", StringName(spec["cue"][0]))
		_root.set(&"fallback_cue", StringName(spec["cue"][1]))
		_root.set(&"fallback_pitch", spec["cue"][2])
	if spec.has("spin"):
		var s := _holder("Spin")
		s.position = spec.get("spin_at", Vector3.ZERO)
		s.rotation_degrees = spec.get("spin_rot", Vector3.ZERO)
	var i := 0
	for p: Array in spec["parts"]:
		var parent: Node3D = _root if p.size() < 6 else _holder(p[5])
		var m := MeshInstance3D.new()
		m.name = "%s%d" % [p[0].capitalize(), i]
		m.mesh = _mesh(p[0], p[1], p[4])
		if p[0] == "sph":
			m.scale = p[1]
		m.position = p[2]
		m.rotation_degrees = p[3]
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		parent.add_child(m)
		m.owner = _root
		i += 1
	if spec.has("burst"):
		var b := _burst(spec["burst"])
		b.position = spec.get("burst_at", Vector3.ZERO)
		_root.add_child(b)
		b.owner = _root
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	assert(err == OK)
	err = ResourceSaver.save(packed, OUT + id + ".tscn")
	if err != OK:
		push_error("could not save %s: %d" % [id, err])
	_root.free()


func _holder(holder_name: String) -> Node3D:
	var n := _root.get_node_or_null(NodePath(holder_name)) as Node3D
	if n == null:
		n = Node3D.new()
		n.name = holder_name
		_root.add_child(n)
		n.owner = _root
	return n


func _mesh(shape: String, d, colour: String) -> Mesh:
	var mesh: PrimitiveMesh
	match shape:
		"sph":
			var s := SphereMesh.new()
			s.radius = 1.0
			s.height = 2.0
			s.radial_segments = 24
			s.rings = 12
			mesh = s
		"box":
			var b := BoxMesh.new()
			b.size = d
			mesh = b
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = d.x
			c.bottom_radius = d.y
			c.height = d.z
			c.radial_segments = 20
			c.rings = 1
			mesh = c
		"cap":
			var c := CapsuleMesh.new()
			c.radius = d.x
			c.height = maxf(d.y, d.x * 2.0)
			c.radial_segments = 16
			c.rings = 6
			mesh = c
		"tor":
			var t := TorusMesh.new()
			t.inner_radius = d.x
			t.outer_radius = d.y
			t.rings = 24
			t.ring_segments = 10
			mesh = t
	mesh.material = _mat(colour)
	return mesh


## Smooth-shaded with a soft rim, like the Jarlings and the frog.
func _mat(colour: String) -> StandardMaterial3D:
	if _mats.has(colour):
		return _mats[colour]
	var m := StandardMaterial3D.new()
	var key := colour.trim_suffix("_glow").trim_suffix("_clear")
	m.albedo_color = Color(C[key])
	m.roughness = 0.55
	m.rim_enabled = true
	m.rim = 0.4
	m.rim_tint = 0.3
	if colour.ends_with("_glow"):
		m.emission_enabled = true
		m.emission = Color(C[key])
		m.emission_energy_multiplier = 1.6
	if colour.ends_with("_clear"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.45
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[colour] = m
	return m


func _burst(kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Burst"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 40
	p.lifetime = 1.4
	p.direction = Vector3(0, 1, -0.6)
	p.spread = 55.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -5.0, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.local_coords = false
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.6
	var g := Gradient.new()
	match kind:
		"confetti":
			var q := BoxMesh.new()
			q.size = Vector3(0.06, 0.01, 0.04)
			q.material = mat
			p.mesh = q
			g.colors = PackedColorArray([Color(C.pink), Color(C.gold), Color(C.cyan), Color(C.orange), Color(C.white)])
			g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
			g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		"notes":
			var s := SphereMesh.new()
			s.radius = 0.05
			s.height = 0.1
			s.material = mat
			p.mesh = s
			p.amount = 12
			p.explosiveness = 0.3
			p.lifetime = 1.6
			p.gravity = Vector3(0, 1.0, 0)
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 1.4
			g.colors = PackedColorArray([Color(C.indigo), Color(C.pink), Color(C.blue)])
			g.offsets = PackedFloat32Array([0.0, 0.4, 0.7])
			g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		_:   # smoke, sneeze: white puffs
			var s := SphereMesh.new()
			s.radius = 0.08
			s.height = 0.16
			s.material = mat
			p.mesh = s
			p.amount = 18
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 2.5
			p.gravity = Vector3(0, 0.5, 0)
			p.direction = Vector3(0, 0.2, -1)
			p.scale_amount_min = 0.8
			p.scale_amount_max = 2.0
			g.colors = PackedColorArray([Color(C.white), Color(C.aqua) if kind == "sneeze" else Color(C.slate)])
			g.offsets = PackedFloat32Array([0.0, 0.6])
	p.color_initial_ramp = g
	return p
