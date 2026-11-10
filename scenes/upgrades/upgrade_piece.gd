## Root script of every upgrade visual (scenes/upgrades/<id>.tscn, built by build_visuals.gd).
## Uses only the kicker contract: the root's `attach_point` metadata picks the slot, and the
## kicker's `kick_contact` / `state_changed` signals trigger the gag. Pieces on the same slot stack:
## each one moves the next by its `stack_step`, so by round 10 the kicker is a walking pile of gear.
extends Node3D

const WINDUP := 2   # Kicker.State.WINDUP (kicker.gd: IDLE, APPROACH, WINDUP, ...)
const SFX_DIR := "res://assets/audio/sfx/"

## How far this piece pushes the next piece on the same attach point. Zero means worn in place
## (mustache, butterfly, banana peel): it neither moves nor is moved by the stack.
@export var stack_step := Vector3(0.0, 0.1, 0.0)
## Sound for the gag. Played if the file exists, else `fallback_cue` (an existing cue) at `fallback_pitch`.
@export var gag_cue: StringName
@export var fallback_cue: StringName
@export var fallback_pitch := 1.0
## Gag at the start of the wind-up instead of at foot contact.
@export var gag_on_windup := false
## Child `Spin` turns this fast (rad/s) around its own Y; child `Bob` bobs this far (m).
@export var spin_speed := 0.0
@export var bob := 0.0

var _t := 0.0
var _base := Vector3.ZERO
@onready var _spin: Node3D = get_node_or_null(^"Spin")
@onready var _bob: Node3D = get_node_or_null(^"Bob")
@onready var _burst: CPUParticles3D = get_node_or_null(^"Burst")


func _ready() -> void:
	position += _stack_offset()
	_t = randf() * TAU
	if _bob:
		_base = _bob.position
	var kicker := _find_kicker()
	if kicker:
		kicker.kick_contact.connect(_on_kick_contact)
		kicker.state_changed.connect(_on_state_changed)
	set_process(_spin != null or _bob != null)


func _process(delta: float) -> void:
	_t += delta
	if _spin:
		_spin.rotate_object_local(Vector3.UP, spin_speed * delta)
	if _bob:
		_bob.position = _base + Vector3(0.0, sin(_t * 3.0) * bob, 0.0)


## Plays the gag now: burst, a squash-pop and the sound. Also handy from tests and previews.
func gag() -> void:
	if _burst:
		_burst.restart()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.3, 0.75, 1.3), 0.08)
	tw.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var audio := get_node_or_null(^"/root/Audio")
	if audio == null:
		return
	if gag_cue != &"" and ResourceLoader.exists(SFX_DIR + String(gag_cue) + ".ogg"):
		audio.play(String(gag_cue))
	elif fallback_cue != &"":
		audio.play(String(fallback_cue), null, fallback_pitch)


func has_gag() -> bool:
	return _burst != null or gag_cue != &"" or fallback_cue != &""


func _on_kick_contact(_quality: float) -> void:
	if not gag_on_windup and has_gag():
		gag()


func _on_state_changed(state: int) -> void:
	if gag_on_windup and state == WINDUP and has_gag():
		gag()


func _stack_offset() -> Vector3:
	var off := Vector3.ZERO
	var parent := get_parent()
	if parent == null or stack_step == Vector3.ZERO:
		return off
	for c in parent.get_children():
		if c == self:
			break
		if c.is_queued_for_deletion():
			continue
		var step = c.get(&"stack_step")
		off += step if step is Vector3 else Vector3(0.0, 0.12, 0.0)
	return off


func _find_kicker() -> Node:
	var n := get_parent()
	while n:
		if n.has_signal(&"kick_contact") and n.has_signal(&"state_changed"):
			return n
		n = n.get_parent()
	return null
