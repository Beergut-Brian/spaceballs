## Sky ramp: blends the sky shader, fog and stars between the eight tiers of data/tiers.tres as
## the camera climbs (TierData.sky is top -> horizon). Art lane. During the split-screen pick the
## halves are on the lawn, so the ramp goes back to the backyard sky.
extends Node

const TIERS := "res://data/tiers.tres"
## Must match sky.gdshader planet_color (sRGB).
const PLANET := Color(0.13, 0.36, 0.78)

@export var environment: WorldEnvironment
## Camera height above the lawn that still counts as ground level.
@export var eye_height := 3.0

var _tiers: TierSet
var _sky: ShaderMaterial
var _last := -1.0


func _ready() -> void:
	_tiers = load(TIERS)
	if environment and environment.environment and environment.environment.sky:
		_sky = environment.environment.sky.sky_material as ShaderMaterial
	_apply(0.0)


func _process(_delta: float) -> void:
	var vp := get_viewport()
	var cam := vp.get_camera_3d()
	var h := 0.0
	if cam and not vp.disable_3d:
		h = TierSet.real_height(maxf(cam.global_position.y - eye_height, 0.0))
	var f := _fraction(h)
	if absf(f - _last) > 0.002:
		_apply(h)


## Continuous tier position: 0 at the lawn, 7 at the space line.
func _fraction(h: float) -> float:
	var n := _tiers.tiers.size()
	var t := _tiers.tier_for(h)
	if t >= n:
		return float(n - 1)
	var lo := maxf(_tiers.tiers[t - 1].threshold, 0.5)
	var hi := _tiers.tiers[t].threshold
	return float(t - 1) + clampf(log(maxf(h, 0.5) / lo) / log(hi / lo), 0.0, 1.0)


func _apply(h: float) -> void:
	if _sky == null or _tiers == null:
		return
	var f := _fraction(h)
	_last = f
	var i := clampi(int(floor(f)), 0, _tiers.tiers.size() - 1)
	var j := mini(i + 1, _tiers.tiers.size() - 1)
	# Ease inside a tier so the colour steps clearly at each boundary and holds in between.
	var k := smoothstep(0.55, 1.0, f - float(i))
	var a: Gradient = _tiers.tiers[i].sky
	var b: Gradient = _tiers.tiers[j].sky
	if a == null or b == null:
		return
	var top := a.get_color(0).lerp(b.get_color(0), k)
	var horizon := a.get_color(a.get_point_count() - 1).lerp(b.get_color(b.get_point_count() - 1), k)
	_sky.set_shader_parameter(&"top_color", top)
	_sky.set_shader_parameter(&"horizon_color", horizon)
	_sky.set_shader_parameter(&"stars", smoothstep(5.2, 6.8, f))
	_sky.set_shader_parameter(&"sun_glow", lerpf(0.35, 0.05, smoothstep(5.0, 7.0, f)))
	var env := environment.environment
	# From high up the lawn melts into haze, then into a planet below (sky shader `planet`).
	var planet := smoothstep(4.2, 6.5, f)
	_sky.set_shader_parameter(&"planet", planet)
	_sky.set_shader_parameter(&"ground_color", horizon)
	var below: Color = horizon.lerp(PLANET, planet)
	env.fog_light_color = below if f > 3.0 else horizon
	env.fog_density = lerpf(0.0015, 0.0008, smoothstep(3.0, 6.0, f))
	env.fog_height_density = lerpf(0.0, 2.0, smoothstep(2.6, 4.0, f))
