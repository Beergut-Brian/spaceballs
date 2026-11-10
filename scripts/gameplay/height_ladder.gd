# PLACEHOLDER (systems grey-box): Gameplay owns height_ladder.tscn and replaces this.
## Builds a placeholder landmark ring at each tier's height from data/tiers.tres (or the tier's
## landmark scene if Content set one) and steps the sky colour with the camera's height.
extends Node3D

@export var environment: WorldEnvironment

var _tiers: TierSet


func _ready() -> void:
	_tiers = load(Run.TIERS_PATH)
	# The busy sky: objects along each flight that the ball bumps into (Sky lane).
	var sky := SkyField.new()
	sky.name = "SkyField"
	add_child(sky)
	for i in range(1, _tiers.tiers.size()):
		var t: TierData = _tiers.tiers[i]
		var y := TierSet.visual_y(t.threshold)
		if t.landmark:
			var lm := t.landmark.instantiate() as Node3D
			add_child(lm)
			lm.position = Vector3(0, y, 0)
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = t.color
		for k in 6:
			var m := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1.2, 0.6, 1.2) * (1.0 + i * 0.3)
			box.material = mat
			m.mesh = box
			var a := TAU * k / 6.0 + i
			m.position = Vector3(cos(a) * (6.0 + i * 1.5), y, sin(a) * (6.0 + i * 1.5) - 2.0)
			m.name = "%s_%d" % [t.id, k]
			add_child(m)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or environment == null or environment.environment == null:
		return
	var h := TierSet.real_height(maxf(cam.global_position.y - 3.0, 0.0))
	var tier := _tiers.tier_for(h)
	var data := _tiers.get_tier(tier)
	var want: Color = data.sky.get_color(0) if data.sky else data.color
	var env := environment.environment
	env.background_color = env.background_color.lerp(want, 0.05)
