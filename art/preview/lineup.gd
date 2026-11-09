## Art preview: stages the real kickers on the real field so the frog forms, the lawn-chair sit and
## the Jarlings can be checked up close. Run: scripts/tools/shots.sh res://art/preview/lineup.tscn 2,4 <dir>
extends Node3D

const JEFF := preload("res://scenes/players/jeff.tscn")
const CHUCK := preload("res://scenes/players/chuck.tscn")


func _ready() -> void:
	var field := $Field
	var chair := field.get_node("LawnChair") as Node3D
	var face := atan2(-5.0, -3.0)   # towards the camera
	var jeff := _spawn(JEFF, Vector3(-1.3, 0, 0.6), face + 0.3)
	var chuck := _spawn(CHUCK, chair.global_position, chair.rotation.y + PI * 0.5)
	chuck.set_waiting(true)
	jeff.set_waiting(false)
	var fj := _spawn(JEFF, Vector3(0.0, 0, 2.2), face)
	var fc := _spawn(CHUCK, Vector3(1.4, 0, 1.6), face)
	fj.set_frog(true)
	fc.set_frog(true)
	var cam := $Camera3D as Camera3D
	if "--view=chair" in OS.get_cmdline_user_args():
		var c := chair.global_position
		cam.look_at_from_position(c + Vector3(2.6, 1.3, 2.4), c + Vector3(0, 0.55, 0))
	else:
		cam.look_at_from_position(Vector3(4.8, 1.6, 5.4), Vector3(0.2, 0.55, 1.4))


func _spawn(scene: PackedScene, at: Vector3, rot_y: float) -> Node3D:
	var k := scene.instantiate() as Node3D
	add_child(k)
	k.global_position = at
	k.rotation.y = rot_y
	return k
