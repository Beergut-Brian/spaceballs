## The sideline crowd reacts to the kick, bigger kick, bigger reaction (playtest 2026-11-09 #2):
## a decent kick gets claps, a great one jumping, arms up, hats in the air and a wave, a ball
## reaching a tier nobody has reached this run gets a roar, a curse a sympathetic "awww".
## Drives the Jarlings under the Art lane's crowd node (art/scripts/crowd.gd plays the arm
## animations through cheer(); this adds the hops, the wave, the hats and the sounds). Gameplay lane.
class_name CrowdReactions
extends Node

enum Level { AWW = -1, NONE, CLAP, GREAT, ROAR }

## A good run-up (Kicker.run_up_quality) lifts a kick one level.
const GREAT_QUALITY := 1.12
const HAT_COLORS: Array[Color] = [Color("ff4f5e"), Color("38c6ff"), Color("ffd84d"), Color("1cc9a6"), Color("ff8ee6")]

var crowd: Node3D
var last_level: Level = Level.NONE
var _members: Array[Node3D] = []
var _rest := {}
var _hop := {}   # member -> [time left, height, speed]
var _slump := 0.0
var _rng := RandomNumberGenerator.new()


func setup(crowd_node: Node3D) -> void:
	crowd = crowd_node
	_members.clear()
	if crowd == null:
		return
	for c in crowd.get_children():
		if c is Node3D:
			_members.append(c)
			_rest[c] = c.position
	# Left to right along the sideline, so the wave rolls one way.
	_members.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.z < b.position.z)


## How big a kick is: gaining on your own best is great, a cracking run-up is great, else claps.
static func kick_level(tier: int, best_tier_before: int, quality: float, cursed: bool) -> Level:
	if cursed:
		return Level.NONE   # the "awww" comes when the ball stops
	var lvl := Level.CLAP
	if tier > best_tier_before or quality >= GREAT_QUALITY:
		lvl = Level.GREAT
	return lvl


func react(level: Level) -> void:
	last_level = level
	if crowd == null:
		return
	match level:
		Level.AWW:
			Audio.play("crowd_aww")
			_slump = 1.6
		Level.CLAP:
			Audio.play("crowd_clap")
			_cheer_anim(1.6)
			for m in _members:
				_start_hop(m, _rng.randf() * 0.3, 0.12, 9.0, 1.2)
		Level.GREAT:
			Audio.play("cheer")
			_cheer_anim(3.2)
			_wave(0.35, 2.4)
			_hats(0.5)
		Level.ROAR:
			Audio.play("crowd_wild")
			get_tree().create_timer(0.3).timeout.connect(Audio.play.bind("cheer", null, 1.2))
			_cheer_anim(4.5)
			_wave(0.55, 3.6)
			_hats(0.9)
			for m in _members:
				Fx.puff(m.global_position + Vector3.UP * 2.2, HAT_COLORS[_rng.randi() % HAT_COLORS.size()], 0.6)


func _cheer_anim(seconds: float) -> void:
	if crowd.has_method("cheer"):
		crowd.cheer(seconds)


## Everybody jumps, one after the other down the line.
func _wave(height: float, seconds: float) -> void:
	for i in _members.size():
		_start_hop(_members[i], i * 0.14, height, 7.0, seconds)


func _start_hop(m: Node3D, delay: float, height: float, speed: float, seconds: float) -> void:
	_hop[m] = [seconds, height, speed, -delay]


## Hats in the air: spin up off their heads and come back down.
func _hats(odds: float) -> void:
	for i in _members.size():
		var m := _members[i]
		if i > 0 and _rng.randf() > odds:
			continue   # most throw, never nobody
		var hat := _hat(HAT_COLORS[_rng.randi() % HAT_COLORS.size()])
		crowd.add_child(hat)
		var start := m.global_position + Vector3.UP * 1.75
		hat.global_position = start
		var up := _rng.randf_range(2.2, 3.4)
		var drift := Vector3(_rng.randf_range(-0.4, 0.4), 0.0, _rng.randf_range(-0.6, 0.6))
		var spin := _rng.randf_range(2.0, 4.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var delay := _rng.randf() * 0.12
		var tw := hat.create_tween()
		tw.tween_interval(delay)
		tw.tween_method(func(u: float) -> void:
			hat.global_position = start + drift * u + Vector3.UP * up * sin(u * PI)
			hat.rotation = Vector3(sin(u * 9.0) * 0.4, u * TAU * spin * 0.5, 0.0), 0.0, 1.0, 1.3)
		tw.tween_callback(hat.queue_free)


func _hat(c: Color) -> Node3D:
	var hat := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.rim_enabled = true
	var crown := CylinderMesh.new()
	crown.top_radius = 0.2
	crown.bottom_radius = 0.24
	crown.height = 0.28
	crown.material = mat
	var brim := CylinderMesh.new()
	brim.top_radius = 0.4
	brim.bottom_radius = 0.4
	brim.height = 0.04
	brim.material = mat
	for part in [[crown, 0.14], [brim, 0.0]]:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.position.y = part[1]
		hat.add_child(mi)
	return hat


func _process(delta: float) -> void:
	_slump = maxf(_slump - delta, 0.0)
	for m in _members:
		if not is_instance_valid(m):
			continue
		var y := 0.0
		if _hop.has(m):
			var h: Array = _hop[m]
			h[3] += delta
			if h[3] >= 0.0:
				h[0] -= delta
				y = absf(sin(h[3] * h[2])) * h[1] * clampf(h[0] / 0.4, 0.0, 1.0)
				if h[0] <= 0.0:
					_hop.erase(m)
		# The "awww": everybody sags a little.
		var sag := sin(clampf(_slump / 1.6, 0.0, 1.0) * PI) * 0.12
		m.position = _rest[m] + Vector3.UP * (y - sag)
