## Drives a Jarling .glb (openjar-characters avatar kit) from the Kicker it sits under.
## Art lane. Lives under Kicker/Body, listens to the kicker's signals, never calls back into it:
## state -> animation + face, kick_contact -> squash-and-stretch (+ hat pop), CHAIR -> sit pose.
extends Node3D

## Face atlas cells (avatar/README.md): neutral, happy, surprised, determined.
const EXPR := {
	&"neutral": Vector3(0, 0, 0), &"happy": Vector3(0.5, 0, 0),
	&"surprised": Vector3(0, 0.5, 0), &"determined": Vector3(0.5, 0.5, 0),
}
const LOOPS := [&"idle", &"run", &"cheer"]
const BLEND := 0.15
## The kicker lowers Body by this in CHAIR (tuned for the grey-box capsule); undone here.
const CHAIR_DROP := 0.45

## Name of a node inside the model that pops off on the kick and lands back (Chuck's hat).
@export var detachable := ""
@export var hat_pop_height := 1.1
@export var rim := 0.45
@export var rim_tint := 0.3

var _kicker: Kicker
var _anim: AnimationPlayer
var _skel: Skeleton3D
var _face_body: MeshInstance3D
var _face_surface := -1
var _face_mat: StandardMaterial3D
var _hat: Node3D
var _hat_rest := Transform3D.IDENTITY
var _hat_tween: Tween
var _pop_node: Node3D
var _pop_rest := Transform3D.IDENTITY
var _squash: Tween
var _sitting := false
var _base_y := 0.0

@onready var model: Node3D = $Model


func _ready() -> void:
	_base_y = position.y
	_kicker = _find_kicker()
	_anim = model.find_child("AnimationPlayer", true, false)
	_skel = model.find_child("Skeleton3D", true, false)
	for a in LOOPS:
		if _anim.has_animation(a):
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_dress_materials()
	if detachable != "":
		_hat = model.find_child(detachable, true, false)
		if _hat:
			_hat_rest = _hat.transform
	_attach_helmet()
	if _kicker:
		_kicker.state_changed.connect(_on_state)
		_kicker.kick_contact.connect(_on_contact)
		_kicker.shouted.connect(func(_p: int) -> void: _flash_face(&"happy"))
		_kicker.hopped.connect(func(_p: int) -> void: _flash_face(&"surprised"))
		_on_state(_kicker.state)
	else:
		_play(&"idle")


func _process(_delta: float) -> void:
	if _kicker == null:
		return
	if _kicker.state == Kicker.State.APPROACH and _anim.current_animation == "run":
		var hv := Vector2(_kicker.velocity.x, _kicker.velocity.z).length()
		_anim.speed_scale = clampf(0.6 + hv / _kicker.max_speed * 0.9, 0.6, 1.6)
	else:
		_anim.speed_scale = 1.0
	if _sitting:
		_sit_pose()


func _on_state(s: Kicker.State) -> void:
	_sitting = s == Kicker.State.CHAIR
	position.y = _base_y + (CHAIR_DROP if _sitting else 0.0)
	match s:
		Kicker.State.IDLE:
			_play(&"idle")
			_set_face(&"neutral")
		Kicker.State.APPROACH:
			_play(&"run")
			_set_face(&"determined")
		Kicker.State.WINDUP:
			# Contact in `kick` is about f14 (0.58 s), close to the kicker's 0.6 s wind-up.
			_anim.play(&"kick", 0.05)
			_anim.seek(0.0, true)
			_set_face(&"determined")
		Kicker.State.FOLLOW_THROUGH:
			_set_face(&"happy")
		Kicker.State.CHEER, Kicker.State.CLOUD:
			_play(&"cheer")
			_set_face(&"happy")
		Kicker.State.CHAIR:
			_play(&"idle")
			_set_face(&"neutral")


func _on_contact(_quality: float) -> void:
	_set_face(&"surprised")
	if _squash and _squash.is_valid():
		_squash.kill()
	model.scale = Vector3.ONE
	_squash = create_tween()
	_squash.tween_property(model, "scale", Vector3(1.3, 0.72, 1.3), 0.05)
	_squash.tween_property(model, "scale", Vector3(0.82, 1.28, 0.82), 0.09)
	_squash.tween_property(model, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_squash.tween_callback(_set_face.bind(&"happy"))
	_pop_hat()


func _pop_hat() -> void:
	if _hat == null:
		return
	if _hat_tween and _hat_tween.is_valid():
		_hat_tween.kill()
	if is_instance_valid(_pop_node):
		_pop_node.transform = _pop_rest
	_pop_node = _hat
	_pop_rest = _hat_rest
	if not _hat.is_visible_in_tree() and _kicker and _kicker.equipment:
		# A head item took the hat's place: that pops instead, propeller and all.
		var worn := _kicker.equipment.equipped(&"head")
		var holder := _kicker.equipment.slot_node(&"head").get_node_or_null("gear_%s" % worn.id) if worn else null
		_pop_node = holder.get_node_or_null("pop") if holder else null
		_pop_rest = Transform3D.IDENTITY
	if _pop_node == null:
		return
	var hat := _pop_node
	var rest := _pop_rest
	var up := rest.origin + Vector3(0.0, hat_pop_height, 0.15)
	_hat_tween = hat.create_tween()
	_hat_tween.tween_property(hat, "position", up, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hat_tween.parallel().tween_property(hat, "rotation:y", TAU, 0.6).as_relative()
	_hat_tween.parallel().tween_property(hat, "rotation:x", -0.5, 0.3)
	_hat_tween.tween_property(hat, "position", rest.origin, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hat_tween.parallel().tween_property(hat, "rotation:x", 0.0, 0.28)
	# Plonk: a little squash when it lands back on his head.
	_hat_tween.tween_property(hat, "scale", Vector3(1.2, 0.75, 1.2), 0.05)
	_hat_tween.tween_property(hat, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hat_tween.tween_callback(func() -> void: hat.transform = rest)


func _play(anim: StringName) -> void:
	if _anim.current_animation != String(anim):
		_anim.play(anim, BLEND)


func _sit_pose() -> void:
	# Thighs forward, shins down: the idle keeps the arms and head alive.
	for side in ["L", "R"]:
		var leg := _skel.find_bone("leg." + side)
		var foot := _skel.find_bone("foot." + side)
		if leg >= 0:
			_skel.set_bone_pose_rotation(leg, Quaternion(Vector3.RIGHT, -1.45))
		if foot >= 0:
			_skel.set_bone_pose_rotation(foot, Quaternion(Vector3.RIGHT, 1.45))


func _set_face(e: StringName) -> void:
	if _face_mat:
		_face_mat.uv1_offset = EXPR[e]


func _flash_face(e: StringName) -> void:
	_set_face(e)
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if _kicker:
			_on_state_face(_kicker.state))


func _on_state_face(s: Kicker.State) -> void:
	match s:
		Kicker.State.APPROACH, Kicker.State.WINDUP:
			_set_face(&"determined")
		Kicker.State.IDLE, Kicker.State.CHAIR:
			_set_face(&"neutral")
		_:
			_set_face(&"happy")


func _dress_materials() -> void:
	# The .glb holds flat colours only; the look needs a soft rim (avatar/README.md step 5).
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(s) as StandardMaterial3D
			if mat == null:
				continue
			if mat.resource_name.ends_with("_face"):
				# Per instance, so each kicker has his own expression.
				_face_mat = mat.duplicate()
				_face_mat.rim_enabled = true
				_face_mat.rim = rim
				_face_mat.rim_tint = rim_tint
				m.set_surface_override_material(s, _face_mat)
				continue
			mat.rim_enabled = true
			mat.rim = rim
			mat.rim_tint = rim_tint
			mat.roughness = 0.75


func _attach_helmet() -> void:
	# Space-suit helmet follows the head bone instead of floating where the capsule's head was.
	if _kicker == null or _skel == null:
		return
	var helmet := _kicker.get_node_or_null("Body/Helmet") as Node3D
	var bone := _skel.find_bone("head")
	if helmet == null or bone < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_idx = bone
	_skel.add_child(ba)
	helmet.reparent.call_deferred(ba, false)
	helmet.set_deferred("transform", Transform3D(Basis.from_scale(Vector3.ONE * 0.62), Vector3(0, 0.27, 0.02)))


func _find_kicker() -> Kicker:
	var n := get_parent()
	while n and not n is Kicker:
		n = n.get_parent()
	return n as Kicker
