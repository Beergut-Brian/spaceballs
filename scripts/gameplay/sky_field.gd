## The busy sky (docs/contracts.md, Sky objects). Sky lane. A child of HeightLadder.
## On every ball's `launched` it rolls a seeded plan from data/sky.tres: 3 to 6 objects per tier the
## flight crosses, `hits_for()` of them in the ball's path, the rest beside it. Objects spawn a little
## before the ball gets to them, home onto its path while it comes up, and are freed once far below
## it, on its `returned`, or at its next launch. Touches go to SkyObject.hit (cosmetic only).
class_name SkyField
extends Node3D

const SKY_PATH := "res://data/sky.tres"
## Spawn objects this far (visual metres) above the ball; free them this far below it.
const LOOKAHEAD := 120.0
const CULL_BELOW := 80.0
## The ball's radius, added to every hit reach.
const BALL_RADIUS := 0.3
## Path objects sit this deep inside their tier (share of the band), and at least this many of their
## own scale units under the peak, so the ball really gets to them.
const BAND_MARGIN := 0.12
const PEAK_CLEARANCE := 0.8
## Homing: how fast a path object slides onto the ball's column (1/s).
const HOME_RATE := 6.0
## Space has no top: its band is this tall above the space line.
const SPACE_BAND := 30.0
const BACKYARD_FLOOR := 1.3
## size_at(): the follow camera's closest distance (camera_rig.gd follow_min) and the smallest share.
const CAMERA_NEAR := 9.0
const MIN_SIZE := 0.35
## Ball.Flight.PHYSICS, Ball.Flight.SCRIPTED: the climb.
const RISING := [1, 2]

var sky: SkySet
var tiers: TierSet
var rng := RandomNumberGenerator.new()
## ball -> {plan, next, live, base, last}
var _flights := {}
var _juice: Node


func _ready() -> void:
	add_to_group(&"sky_field")   # DragonCameo finds it here
	sky = load(SKY_PATH)
	tiers = load(Run.TIERS_PATH)
	rng.randomize()
	_hook_balls.call_deferred()


func _hook_balls() -> void:
	for b in get_tree().get_nodes_in_group(&"balls"):
		watch(b)


## Follow this ball's flights (SkyField finds the group's balls itself; tests call it directly).
func watch(ball: Node3D) -> void:
	if not ball.has_signal(&"launched") or ball.launched.is_connected(_on_launched):
		return
	ball.launched.connect(_on_launched.bind(ball))
	if ball.has_signal(&"returned"):
		ball.returned.connect(clear.bind(ball))
	ball.tree_exiting.connect(clear.bind(ball))


## Objects in the path per flight, by the flight's top tier: 1 for a backyard kick, 5 for space.
static func hits_for(top_tier: int) -> int:
	return [1, 1, 2, 2, 3, 3, 4, 5][clampi(top_tier, 1, 8) - 1]


## Visual band [lo, hi] (metres above the tee) of ladder tier `i` (1-based).
func band(i: int) -> Vector2:
	var lo := TierSet.visual_y(tiers.tiers[i - 1].threshold) if i > 1 else BACKYARD_FLOOR
	if i >= tiers.tiers.size():
		# A space kick peaks just over the line: space things wait a little under it too.
		return Vector2(lo - SPACE_BAND * 0.6, lo + SPACE_BAND)
	var hi := TierSet.visual_y(tiers.tiers[i].threshold)
	return Vector2(lo, hi)


## A flight's objects, lowest first: [{tier, entry, scale, y, offset (x, z), on_path, yaw}].
## Pure and seeded, so tests can check counts and the aim.
func plan(peak: float, seed_value: int) -> Array[Dictionary]:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var top := TierSet.visual_y(peak)
	var top_tier := tiers.tier_for(peak)
	var crossed: Array[int] = []
	var pathable: Array[int] = []
	for i in range(1, top_tier + 1):
		var st := sky.get_tier(tiers.tiers[i - 1].id)
		if st == null or st.entries.is_empty():
			continue
		crossed.append(i)
		if _path_band(i, st, top).y > 0.0 and _pick(st, r, true) != null:
			pathable.append(i)
	var on_path := {}
	var want := hits_for(top_tier)
	var pool := pathable.duplicate()
	for k in want:
		if pathable.is_empty():
			break
		if pool.is_empty():
			pool = pathable.duplicate()
		var t: int = pool.pop_at(r.randi_range(0, pool.size() - 1))
		on_path[t] = on_path.get(t, 0) + 1
	var out: Array[Dictionary] = []
	for i in crossed:
		var st := sky.get_tier(tiers.tiers[i - 1].id)
		var b := band(i)
		var n_path: int = on_path.get(i, 0)
		var n := maxi(r.randi_range(st.count_min, st.count_max), n_path)
		var span := b.y - b.x
		var lo := b.x + span * BAND_MARGIN * 0.5
		var hi := minf(b.y - span * BAND_MARGIN * 0.5, top + st.scale)
		for k in n:
			var path := k < n_path
			var e := _pick(st, r, path)
			if e == null:
				continue
			var y: float
			var off: Vector2
			if path:
				var pb := _path_band(i, st, top)
				y = r.randf_range(pb.x, pb.y)
				off = Vector2(r.randf_range(-0.3, 0.3), r.randf_range(-0.3, 0.3))
			else:
				y = r.randf_range(lo, maxf(hi, lo))
				var side := -1.0 if r.randf() < 0.5 else 1.0
				# Behind the ball's column (the follow camera sits on +X), never between it and the lens.
				off = Vector2(r.randf_range(-3.0, -0.4), side * r.randf_range(st.spread.x, st.spread.y)) * st.scale
			var size := size_at(st.scale, top - y)
			out.append({tier = i, entry = e, scale = size, y = y, offset = off * size / st.scale, on_path = path,
					yaw = r.randf_range(-0.6, 0.6) + (PI if r.randf() < 0.5 else 0.0)})
	out.sort_custom(func(a: Dictionary, b2: Dictionary) -> bool: return a.y < b2.y)
	return out


## The follow camera zooms back in as the ball slows near its peak, so things up there shrink with
## it: about tier scale on the way up, down to MIN_SIZE of it right at the peak (big tiers only).
static func size_at(tier_scale: float, below_peak: float) -> float:
	return tier_scale * clampf((CAMERA_NEAR + maxf(below_peak, 0.0) * 0.6) / (tier_scale * 4.0), MIN_SIZE, 1.0)


func _path_band(i: int, st: SkyTier, top: float) -> Vector2:
	var b := band(i)
	var span := b.y - b.x
	var lo := b.x + span * BAND_MARGIN
	var hi := minf(b.y - span * BAND_MARGIN, top - PEAK_CLEARANCE * st.scale)
	return Vector2(lo, hi) if hi > lo else Vector2()


func _pick(st: SkyTier, r: RandomNumberGenerator, path: bool) -> SkyEntry:
	var total := 0.0
	for e in st.entries:
		if e.scene and (e.on_path or not path):
			total += e.weight
	if total <= 0.0:
		return null
	var x := r.randf() * total
	for e in st.entries:
		if e.scene and (e.on_path or not path):
			x -= e.weight
			if x <= 0.0:
				return e
	return null


func _on_launched(peak: float, ball: Node3D) -> void:
	clear(ball)
	_flights[ball] = {plan = plan(peak, rng.randi()), next = 0, live = [], base = ball.global_position,
			last = ball.global_position}


## A sky thing spawned outside the plan (the Dragon cameo) joins this ball's flight: the same hit
## test, culling and clean-up as the planned ones. No flight, no adoption: it is freed.
func adopt(ball: Node3D, o: SkyObject) -> void:
	if not _flights.has(ball):
		o.queue_free()
		return
	(_flights[ball].live as Array).append(o)


## Free this ball's sky objects.
func clear(ball: Node3D) -> void:
	var f: Dictionary = _flights.get(ball, {})
	for o in f.get("live", []):
		if is_instance_valid(o):
			o.queue_free()
	_flights.erase(ball)


func live_objects(ball: Node3D) -> Array:
	var f: Dictionary = _flights.get(ball, {})
	return (f.get("live", []) as Array).filter(func(o: Variant) -> bool: return is_instance_valid(o))


func _physics_process(delta: float) -> void:
	for ball in _flights.keys():
		if not is_instance_valid(ball):
			_flights.erase(ball)
			continue
		_step(ball, _flights[ball], delta)


func _step(ball: Node3D, f: Dictionary, delta: float) -> void:
	var base: Vector3 = f.base
	var now: Vector3 = ball.global_position
	var vis := now.y - base.y
	var items: Array = f.plan
	while f.next < items.size() and items[f.next].y <= vis + LOOKAHEAD:
		f.live.append(_spawn(items[f.next], ball, base))
		f.next += 1
	var last: Vector3 = f.last
	# Only the climb bumps things: not the peak hold, the drop's teleport or the orbit.
	var climbing: bool = ball.get(&"flight") in RISING
	var keep: Array = []
	for x in f.live:
		if not is_instance_valid(x) or x.is_queued_for_deletion():
			continue   # popped, scattered or snagged: it freed itself
		var o := x as SkyObject
		if o.global_position.y - base.y < vis - CULL_BELOW - o.size * 2.0:
			o.queue_free()
			continue
		keep.append(o)
		if climbing and o.homing and not o.was_hit and o.hit_center().y > now.y:
			var target := Vector3(now.x, 0, now.z) + Vector3(o.home_jitter.x, 0, o.home_jitter.y) * o.hit_reach()
			var c := o.hit_center()
			var move := (target - Vector3(c.x, 0, c.z)) * (1.0 - exp(-HOME_RATE * delta))
			o.global_position += move
		if not climbing:
			continue
		var d := _segment_distance(last, now, o.hit_center())
		if not o.was_hit and d <= o.hit_reach() + BALL_RADIUS:
			o.hit(ball)
		elif o.near_reach() > 0.0 and d <= o.near_reach():
			o.near(ball)
	f.live = keep
	f.last = now


func _spawn(item: Dictionary, ball: Node3D, base: Vector3) -> SkyObject:
	var e: SkyEntry = item.entry
	var o := e.scene.instantiate() as SkyObject
	o.field = self
	add_child(o, true)
	o.size = float(item.scale)
	o.scale = Vector3.ONE * o.size
	o.rotation.y = item.yaw
	var off: Vector2 = item.offset
	o.global_position = base + Vector3(off.x, item.y, off.y)
	if item.on_path:
		o.homing = true
		o.home_jitter = off
		# Straight onto the column now; homing keeps it there if the ball drifts (curve, wind-up push).
		var c := o.hit_center()
		var now := ball.global_position
		o.global_position += Vector3(now.x - c.x, 0, now.z - c.z) + Vector3(off.x, 0, off.y) * o.hit_reach()
	# Pop in (some appear in view on a small kick).
	var full := o.scale
	o.scale = full * 0.05
	o.create_tween().tween_property(o, "scale", full, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return o


static func _segment_distance(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.000001:
		return a.distance_to(p)
	return (a + ab * clampf((p - a).dot(ab) / l2, 0.0, 1.0)).distance_to(p)


## A little camera shake through the field's Juice (art/scripts/juice.gd), if it is there.
func shake(amount: float) -> void:
	if _juice == null or not is_instance_valid(_juice):
		var root := get_tree().current_scene
		_juice = root.find_child("Juice", true, false) if root else null
	if _juice and _juice.has_method("shake"):
		_juice.shake(amount)
