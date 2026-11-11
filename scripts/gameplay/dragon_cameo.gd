## Playtest 2026-11-10 #3: on a tuned chance per run (data/dragon_cameo.tres), the first flight that
## climbs into the Clouds tier meets The Hill's Dragon gliding through (scenes/sky/sky_dragon.gd).
## She joins SkyField's flight like any sky thing (same hit test, same clean-up when the ball comes
## home), so she can never hold up a run. main.gd owns one.
class_name DragonCameo
extends Node

const DATA_PATH := "res://data/dragon_cameo.tres"

var data: CameoData
var rng := RandomNumberGenerator.new()
## This run gets her (rolled at run start).
var active := false
var shown := 0
## The last one spawned (tests, frames).
var dragon: SkyDragon


func _ready() -> void:
	data = load(DATA_PATH) as CameoData if ResourceLoader.exists(DATA_PATH) else CameoData.new()
	rng.randomize()
	Run.run_started.connect(roll)
	_hook_balls.call_deferred()


func _hook_balls() -> void:
	for b in get_tree().get_nodes_in_group(&"balls"):
		watch(b)


func watch(ball: Node3D) -> void:
	if ball.has_signal(&"launched") and not ball.launched.is_connected(_on_launched):
		ball.launched.connect(_on_launched.bind(ball))


## A new run: does she come this time?
func roll() -> void:
	shown = 0
	active = rng.randf() < data.chance_per_run
	for arg in OS.get_cmdline_user_args():
		if arg == "--dragon":
			active = true   # playtests and frames: always


func _on_launched(peak: float, ball: Node3D) -> void:
	_try.call_deferred(peak, ball)   # after SkyField has opened this flight


func _try(peak: float, ball: Node3D) -> void:
	if not active or shown >= data.per_run or not is_instance_valid(ball):
		return
	var field := _sky_field()
	if field == null or field.tiers == null:
		return
	var tier := _tier_index(field.tiers)
	if tier < 1 or field.tiers.tier_for(peak) < tier:
		return   # the ball won't reach the Clouds: she waits for a bigger kick
	shown += 1
	dragon = spawn(field, ball, peak, tier, rng.randf() < data.on_path_chance)


## Puts her in `ball`'s flight, in the lower part of the tier's band (always below the peak).
func spawn(field: SkyField, ball: Node3D, peak: float, tier: int, on_path: bool) -> SkyDragon:
	var st := field.sky.get_tier(data.tier_id) if field.sky else null
	var tier_scale := st.scale if st else 5.5
	var b := field.band(tier)
	var top := TierSet.visual_y(peak)
	var y := clampf(lerpf(b.x, b.y, 0.3), b.x, maxf(b.x, top - tier_scale * 1.2))
	var d := SkyDragon.make()
	d.field = field
	d.size = SkyField.size_at(tier_scale, top - y) * data.size_mult
	d.push = data.boost
	d.homing = on_path
	field.add_child(d, true)
	d.scale = Vector3.ONE * d.size
	var base := ball.global_position
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	# She glides across the view (the follow camera sits on +X), facing where she's going and
	# turned a little toward the lens so her sleepy face reads.
	d.drift = Vector3(0.0, 0.0, 0.35)
	d.rotation.y = 0.6 if side < 0.0 else PI - 0.6
	var off := Vector3(-0.6, 0.0, 0.0) if on_path else Vector3(-1.5, 0.0, side * 2.6)
	d.global_position = base + Vector3(0.0, y, 0.0) + off * d.size
	if on_path:
		d.home_jitter = Vector2(0.0, 0.0)
		var c := d.hit_center()
		d.global_position += Vector3(base.x - c.x, 0.0, base.z - c.z)
	field.adopt(ball, d)
	var full := d.scale
	d.scale = full * 0.05
	d.create_tween().tween_property(d, "scale", full, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return d


func _tier_index(tiers: TierSet) -> int:
	for i in tiers.tiers.size():
		if tiers.tiers[i].id == data.tier_id:
			return i + 1
	return -1


func _sky_field() -> SkyField:
	return get_tree().get_first_node_in_group(&"sky_field") as SkyField
