## Tiny procedural motion for props and landmarks: bob, spin, orbit, fly-past, wave, flap, sway.
## Art lane. Runs on its own node; cheap (one transform write per frame).
extends Node3D

enum Mode { BOB, SPIN, ORBIT, FLY, WAVE, FLAP, SWAY, HOP }

@export var mode: Mode = Mode.BOB
@export var amount := 0.3          ## metres (BOB/HOP/FLY half-length) or radians (WAVE/FLAP/SWAY)
@export var speed := 1.0           ## cycles per second (FLY: fraction of the path per second)
@export var axis := Vector3.UP     ## SPIN/ORBIT/WAVE/FLAP/SWAY axis, FLY direction
@export var phase := 0.0

var _t := 0.0
var _rest: Transform3D


func _ready() -> void:
	_rest = transform
	_t = phase


func _process(delta: float) -> void:
	_t += delta
	var w := _t * speed * TAU
	match mode:
		Mode.BOB:
			position = _rest.origin + Vector3.UP * sin(w) * amount
		Mode.HOP:
			position = _rest.origin + Vector3.UP * absf(sin(w)) * amount
		Mode.SPIN:
			transform = Transform3D(_rest.basis.rotated(axis.normalized(), w), _rest.origin)
		Mode.ORBIT:
			transform = Transform3D(Basis(axis.normalized(), w), Vector3.ZERO) * _rest
		Mode.FLY:
			var u := fposmod(_t * speed, 1.0) * 2.0 - 1.0
			position = _rest.origin + axis.normalized() * u * amount
		Mode.WAVE, Mode.FLAP, Mode.SWAY:
			basis = _rest.basis * Basis(axis.normalized(), sin(w) * amount)
