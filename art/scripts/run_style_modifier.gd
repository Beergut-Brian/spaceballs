## The character's own run on top of the shared run clip (P-03 / P-04, RunStyle): Jeff's arms
## windmill and his chicken comb flaps; Chuck's arms stay stiff with a short pump. Runs after the
## AnimationPlayer (SkeletonModifier3D), fades in with the kicker's run, off when he stops.
## Art lane. jarling_rig.gd adds one under the Jarling's Skeleton3D.
class_name RunStyleModifier
extends SkeletonModifier3D

const ARMS := ["arm.L", "arm.R"]
## Bones that flap with RunStyle.flap: Jeff's comb (the chicken hood's top).
const FLAPS := ["comb"]

var kicker: Kicker
## The arm pose the run clip carries on average (per arm), for stiff arms (RunStyle.arm_keep).
var _carry := {}


func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null or kicker == null:
		return
	var st := kicker.run_style
	var run := kicker.run_amount
	influence = smoothstep(0.15, 0.45, run)
	if influence <= 0.001 or st == null:
		return
	var side := Vector3.RIGHT   # the body's left-right axis in skeleton space
	for i in ARMS.size():
		var b := skel.find_bone(ARMS[i])
		if b < 0:
			continue
		var anim := skel.get_bone_pose_rotation(b)
		# Stiff arms: the clip's swing pulled toward its average carry.
		var carry: Quaternion = _carry.get(b, anim)
		carry = carry.slerp(anim, 0.02)
		_carry[b] = carry
		skel.set_bone_pose_rotation(b, carry.slerp(anim, st.arm_keep))
		var a: float
		if st.windmill:
			a = kicker.stride * st.arm_swing + PI * i   # right round, half a turn apart
		else:
			a = sin(kicker.stride * PI + PI * i) * st.arm_swing
		_turn(skel, b, side, a)
	for name in FLAPS:
		var b := skel.find_bone(name)
		if b >= 0 and st.flap > 0.0:
			_turn(skel, b, side, sin(kicker.stride * PI * 3.0) * st.flap * run)


## Turns bone `b` by `angle` about `axis` (skeleton space) at its own joint.
func _turn(skel: Skeleton3D, b: int, axis: Vector3, angle: float) -> void:
	var parent := skel.get_bone_parent(b)
	var local := Basis(skel.get_bone_pose_rotation(b))
	var pg := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	var g := pg * local
	var turned := Basis(axis, angle) * g
	skel.set_bone_pose_rotation(b, Quaternion((pg.inverse() * turned).orthonormalized()))
