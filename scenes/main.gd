## Boot scene and round director: title card, drop-in, and the scene side of Run's phases
## (who stands where, which ball is armed, which camera, which UI). Game rules live in Run.
## Systems lane owns. CLI (after --): --demo plays itself, --timescale=<x> speeds it up.
extends Node3D

const P1 := Players.P1
const P2 := Players.P2
const KICK_CUES := ["kick_1", "kick_2", "kick_3", "kick_4"]

@onready var field: Node3D = $Field
@onready var rig: Node3D = $CameraRig
@onready var hud: Control = $UI/HUD
@onready var pick_ui: Control = $UI/UpgradePick
@onready var end_card: Control = $UI/EndCard
@onready var title: Control = $UI/Title
@onready var pause_overlay: Control = $UI/Pause
@onready var kickers := {P1: $Kickers/Jeff, P2: $Kickers/Chuck}
@onready var balls := {P1: $Balls/P1, P2: $Balls/P2}

## Space moment: the ball circles the planet this long before the next kick.
const ORBIT_SHOW := 2.0
## After the last card is picked, the split screen stays this long so the item is seen landing.
const PICK_BEAT := 0.9

var _title_t := 0.0
var _turn: TurnMarker
var _confetti: CPUParticles2D


func _ready() -> void:
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	Players.solo_changed.connect(_on_solo_changed)
	Game.state_changed.connect(_on_state_changed)
	Run.phase_changed.connect(_on_phase_changed)
	Run.run_started.connect(_on_run_started)
	Run.reached_space.connect(_on_reached_space)
	Run.ball_tier_reached.connect(func(_p: int, tier: int) -> void: Audio.music_level((tier - 1) / 2))
	Run.ball_stopped.connect(func(_p: int, _h: float, _t: int) -> void: rig.hold_peak())
	for p in [P1, P2]:
		balls[p].kick_zone_entered.connect(_on_kick_zone.bind(p))
		balls[p].returned.connect(_on_ball_returned.bind(p))
		kickers[p].kick_contact.connect(_on_kick_contact.bind(p))
		hud.track(p, balls[p])
	pick_ui.picked.connect(_on_picked)
	end_card.restart_requested.connect(_on_end_accepted)
	Run.ball_stopped.connect(_on_ball_stopped)
	_turn = TurnMarker.new()
	add_child(_turn)
	_confetti = end_card.get_node("Confetti").duplicate()
	_confetti.one_shot = true
	_confetti.explosiveness = 0.6
	_confetti.amount = 120
	_confetti.lifetime = 3.0
	$UI.add_child(_confetti)
	title.visible = true
	hud.visible = false
	Audio.music("field_loop")
	_layout_title()
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo":
			Run.demo = true
		elif arg.begins_with("--timescale="):
			Engine.time_scale = clampf(float(arg.trim_prefix("--timescale=")), 0.1, 8.0)
	if Run.demo:
		(func() -> void:
			Players.join_virtual(P1)
			Players.join_virtual(P2)).call_deferred()


func _process(delta: float) -> void:
	if Game.state == Game.State.TITLE:
		_title_t += delta
		title.scale = Vector2.ONE * (1.0 + 0.04 * sin(_title_t * 3.0))
		title.pivot_offset = title.size * 0.5
		# Back from the end card: a pad that is already joined starts the next run with A.
		if _title_t > 0.5:
			for p in Players.active_players():
				if Input.is_action_just_pressed(Players.action(p, "action")):
					Audio.play("ui_confirm")
					Run.start_run()
					return


# --- players -------------------------------------------------------------------

func _on_player_joined(player: int, _device: int) -> void:
	if Game.state == Game.State.TITLE:
		if not Run.demo or player == P2:
			Run.start_run()
		return
	if player == P2 and not Run.in_run(P2):
		# Stands up from the lawn chair; gets a ball at the start of the next round.
		kickers[P2].global_position = _marker("Sidelines", P2)
		kickers[P2].set_waiting(false)
		kickers[P2].cheer()
		Fx.puff(kickers[P2].global_position + Vector3.UP, Players.COLOR[P2], 1.5)


## Solo (playtest): turned on before P1's first kick, restart so both play from round 1.
func _on_solo_changed(on: bool) -> void:
	if on and Game.state != Game.State.TITLE and Run.round_index <= 1 \
			and Run.phase == Run.Phase.KICK_P1 and not Run.in_run(P2):
		Run.start_run()


func _on_player_left(player: int) -> void:
	if player == P2 and not Run.in_run(P2):
		_bench(P2)


# --- phases ----------------------------------------------------------------------

func _on_run_started() -> void:
	end_card.close()
	pick_ui.close()
	hud.visible = true
	for p in [P1, P2]:
		kickers[p].clear_upgrade_visuals()
		kickers[p].set_frog(false)
		kickers[p].set_space_suit(false)
		kickers[p].dance(false)
		balls[p].place_on_tee(_marker("Tees", p))


func _on_phase_changed(from: int, to: int) -> void:
	if from == Run.Phase.PICK and to != Run.Phase.PICK:
		pick_ui.close()
		rig.split(false)
	if to != Run.Phase.KICK_P1 and to != Run.Phase.KICK_P2:
		_turn.hide_marker()
	match to:
		Run.Phase.KICK_P1:
			_begin_kick(P1)
		Run.Phase.KICK_P2:
			_begin_kick(P2)
		Run.Phase.PICK:
			_begin_pick()
		Run.Phase.END:
			_begin_end()


func _begin_kick(p: int) -> void:
	Players.set_solo_focus(p)
	Audio.music("field_loop")
	Audio.music_level(0)
	var tee := _marker("Tees", p)
	for q in [P1, P2]:
		var k: Kicker = kickers[q]
		var q_curse := Run.curse_of(q)
		if q_curse == null or q_curse.scene_override == null:
			k.set_frog(false)
		balls[q].visible = not Run.in_space(q)
		if q == p:
			continue
		if Run.in_space(q):
			_to_cloud(q)
		elif Run.in_run(q) or Players.is_active(q):
			_place(q, _marker("Sidelines", q), tee)
			k.set_waiting(false)
		else:
			_bench(q)
	var me: Kicker = kickers[p]
	_place(p, _marker("Spawns", p), tee)
	balls[p].place_on_tee(tee)
	var curse := Run.curse_of(p)
	var frog_round := curse != null and curse.scene_override != null
	if frog_round:
		me.set_frog(true, curse.scene_override)
		Audio.play("curse")
	elif curse != null:
		Audio.play("curse")
		Fx.puff(me.global_position + Vector3.UP, Color(0.6, 0.4, 0.9), 1.5)
	me.windup = windup_of(p)
	me.begin_approach(balls[p].global_position)
	balls[p].arm(true)
	rig.frame_close(frog_round)
	rig.frame_field(me, tee)
	_turn.show_for(me, tee, Players.COLOR[p])


## The kick's wind-up gag source: the round's curse if it has a gag, else the newest upgrade with one.
func windup_of(p: int) -> UpgradeData:
	var curse := Run.curse_of(p)
	if curse != null:
		return curse
	var ups := Run.upgrades_of(p)
	for i in range(ups.size() - 1, -1, -1):
		if Kicker.gag_of(ups[i]) != &"":
			return ups[i]
	return null


func _on_kick_zone(body: Node3D, p: int) -> void:
	if body != kickers[p] or Run.phase != Run.KICK_PHASE[p]:
		return
	balls[p].arm(false)
	Run.notify_kick_started(p)
	kickers[p].start_windup()
	_turn.hide_marker()
	if Kicker.gag_of(kickers[p].windup) != &"" and not kickers[p].frog:
		rig.frame_close(true)   # move in so the gag reads


func _on_kick_contact(quality: float, p: int) -> void:
	if Run.phase != Run.KICK_PHASE[p]:
		return
	var power := Run.notify_kicked(p, quality)
	var height := Run.kick_height(p, power)
	var tier := Run.tier_of_height(height)
	Audio.play(_kick_cue(p, tier))
	if not kickers[p].frog:
		Fx.puff(balls[p].global_position, Color(1, 1, 0.8), 0.8 + tier * 0.3)
	balls[p].launch(power, height)
	if not kickers[p].frog:
		rig.follow(balls[p])   # the frog's dribble stays in the close-up
	var other := P2 if p == P1 else P1
	if kickers[other].state == Kicker.State.CHEER or kickers[other].state == Kicker.State.CLOUD:
		kickers[other].cheer()


func _kick_cue(p: int, tier: int) -> String:
	var curse := Run.curse_of(p)
	if curse and curse.kick_sfx != &"":
		return String(curse.kick_sfx)
	var ups := Run.upgrades_of(p)
	for i in range(ups.size() - 1, -1, -1):
		if ups[i].kick_sfx != &"":
			return String(ups[i].kick_sfx)
	return KICK_CUES[clampi((tier - 1) / 2, 0, 3)]


func _on_ball_returned(p: int) -> void:
	if Run.in_space(p) and Run.phase == Run.FLIGHT_PHASE[p]:
		# The space moment: let it circle the planet for a bit before the next kick.
		await get_tree().create_timer(ORBIT_SHOW).timeout
		if Run.phase != Run.FLIGHT_PHASE[p]:
			return
	Run.end_flight(p)


## The frog round's payoff: the ball plops a few feet, "bloop", and the whole crowd goes "awww".
func _on_ball_stopped(p: int, _height: float, _tier: int) -> void:
	if Run.in_space(p) and balls[p].flight == balls[p].Flight.FLOATING:
		rig.orbit(balls[p].orbit_center, 4.4, 1.2, false)
		_celebrate_orbit()
		return
	var curse := Run.curse_of(p)
	if curse == null or curse.scene_override == null:
		return
	_sfx("bloop", "frog", 0.6)
	_sfx("aww", "cheer", 0.7)
	Fx.puff(balls[p].global_position + Vector3.UP * 0.3, Color(0.6, 0.9, 0.4), 0.4)
	var crowd := field.find_child("Crowd", true, false)
	if crowd and crowd.has_method("cheer"):
		crowd.cheer(2.0)
	# Both of them laugh it off: the frog does a happy hop, the other one cheers.
	kickers[p].cheer()
	var other := P2 if p == P1 else P1
	if kickers[other].state == Kicker.State.CHEER or kickers[other].state == Kicker.State.CLOUD:
		kickers[other].cheer()


func _begin_pick() -> void:
	var draws := {}
	for p in Run.pickers():
		draws[p] = Run.draw_cards(p)
	var shown: Array = []
	for p in [P1, P2]:
		if not Run.in_space(p):
			balls[p].place_on_tee(_marker("Tees", p))
		if Run.in_run(p) or Run.in_space(p):
			shown.append(p)
		var k: Kicker = kickers[p]
		k.set_frog(false)
		var spot := _marker("PickSpots", p)
		if Run.in_space(p):
			_to_cloud(p)
			spot = k.global_position
		elif shown.has(p):
			k.global_position = spot
			k.set_waiting(false)
		else:
			_bench(p)
		var view := pick_view(spot, _stack_height(k), pick_ui.camera_of(p).fov)
		k.rotation.y = atan2(-(view[0] - spot).x, -(view[0] - spot).z)
		pick_ui.frame(p, view[1], view[0])
	rig.split(true)
	pick_ui.open(draws, shown)


## Pick camera [from, look_at]: low and a little to the side, pulled back far enough that the
## whole pile (feet to top hat, `height` metres) sits between 4 % and 58 % of the half's height,
## clear of the cards along the bottom.
static func pick_view(spot: Vector3, height: float, fov_deg: float = 50.0) -> Array:
	var h := maxf(height, 1.6)
	var view_h := h / 0.54                      # metres of world the half shows, top to bottom
	var dist := view_h / (2.0 * tan(deg_to_rad(fov_deg) * 0.5))
	var look := spot + Vector3.UP * (h * 0.5 - 0.19 * view_h)
	var from := look + Vector3(0.22, 0.12, -1.0).normalized() * dist
	return [from, look]


## World height of everything the kicker wears, measured from his feet.
func _stack_height(k: Kicker) -> float:
	var top := 1.6
	for vi in k.get_node("Attach").find_children("*", "VisualInstance3D", true, false):
		var v := vi as VisualInstance3D
		if not v.is_visible_in_tree() or v is GPUParticles3D or v is CPUParticles3D:
			continue
		var box := v.global_transform * v.get_aabb()
		top = maxf(top, box.end.y - k.global_position.y)
	return minf(top, 6.0)


func _on_picked(p: int, u: UpgradeData) -> void:
	if u.is_curse():
		Audio.play("curse")
		Fx.puff(kickers[p].global_position + Vector3.UP, Color(0.6, 0.4, 0.9), 2.0)
		Fx.pop(kickers[p].body, 1.4)
	else:
		kickers[p].add_upgrade_visual(u)
	var last := Run.pickers().all(func(q: int) -> bool: return q == p or Run.has_picked(q))
	if last:
		# A beat to watch the new gear pop on before the split screen closes.
		await get_tree().create_timer(PICK_BEAT).timeout
		if Run.phase != Run.Phase.PICK:
			return
	Run.pick(p, u)


func _begin_end() -> void:
	rig.split(false)
	_turn.hide_marker()
	# Up among the stars, so the sky ramp shows space and the planet below.
	var center := _marker_node("EndSpot").global_position + Vector3.UP * end_altitude()
	for p in [P1, P2]:
		var k: Kicker = kickers[p]
		k.set_frog(false)
		k.global_position = center + Vector3(-1.1 if p == P1 else 1.1, 0, 0)
		k.rotation.y = PI   # facing the camera's first pass
		k.velocity = Vector3.ZERO
		k.set_cloud()
		k.set_space_suit(true)
		k.dance(true)
		var b: Node3D = balls[p]
		b.visible = true
		b.orbit_around(center + Vector3.UP * 1.3, 2.6, 0.35 if p == P1 else -0.35, 0.0 if p == P1 else PI)
	rig.orbit(center, 6.5, 1.6)
	Audio.play("space")
	Audio.play("cheer")
	Audio.music("space_pad", 1.5)
	end_card.open()


## The end card floats just above the space line.
static func end_altitude() -> float:
	var tiers := load("res://data/tiers.tres") as TierSet
	return TierSet.visual_y(tiers.space_height() * 1.2) if tiers else 300.0


func _on_end_accepted() -> void:
	if Run.demo:
		Run.start_run()
		return
	Game.to_title()


## The big payoff: the camera rides the ball out of the air; at the peak (ball.gd) it settles into
## an orbit with a happy face while the crowd goes wild and confetti rains.
func _on_reached_space(p: int) -> void:
	Audio.play("space")
	Audio.music("space_pad", 1.5)


## The ball has settled into orbit: the crowd goes wild, confetti rains, everybody cheers.
func _celebrate_orbit() -> void:
	_sfx("crowd_wild", "cheer", 1.0)
	get_tree().create_timer(0.35).timeout.connect(Audio.play.bind("cheer", null, 1.2))
	get_tree().create_timer(0.7).timeout.connect(Audio.play.bind("cheer", null, 0.9))
	Audio.play("confetti")
	_confetti.restart()
	_confetti.emitting = true
	var crowd := field.find_child("Crowd", true, false)
	if crowd and crowd.has_method("cheer"):
		crowd.cheer(6.0)
	for q in [P1, P2]:
		if kickers[q].state == Kicker.State.CHEER or kickers[q].state == Kicker.State.CLOUD:
			kickers[q].cheer()


# --- helpers ---------------------------------------------------------------------

func _on_state_changed(_from: int, to: int) -> void:
	title.visible = to == Game.State.TITLE
	pause_overlay.visible = to == Game.State.PAUSED
	if to == Game.State.TITLE:
		# Back from the end card.
		_title_t = 0.0
		end_card.close()
		hud.visible = false
		for p in [P1, P2]:
			kickers[p].dance(false)
			kickers[p].set_space_suit(false)
			kickers[p].clear_upgrade_visuals()
		Audio.music("field_loop")
		_layout_title()


func _sfx(cue: String, fallback: String, pitch: float = 1.0) -> void:
	if ResourceLoader.exists(Kicker.SFX_DIR + cue + ".ogg") or ResourceLoader.exists(Kicker.SFX_DIR + cue + "_1.ogg"):
		Audio.play(cue)
	else:
		Audio.play(fallback, null, pitch)


func _layout_title() -> void:
	for p in [P1, P2]:
		balls[p].place_on_tee(_marker("Tees", p))
	_place(P1, _marker("Spawns", P1), _marker("Tees", P1))
	kickers[P1].set_waiting(false)
	_bench(P2)
	rig.frame_field(kickers[P1], _marker("Tees", P1))


func _bench(p: int) -> void:
	var chair := _marker_node("LawnChair")
	kickers[p].global_position = chair.global_position
	kickers[p].rotation.y = chair.rotation.y + PI * 0.5
	kickers[p].set_waiting(true)


func _to_cloud(p: int) -> void:
	kickers[p].global_position = _marker("Clouds", p)
	kickers[p].set_cloud()


func _place(p: int, at: Vector3, facing: Vector3) -> void:
	var k: Kicker = kickers[p]
	k.global_position = at
	k.velocity = Vector3.ZERO
	var d := facing - at
	if Vector2(d.x, d.z).length() > 0.01:
		k.rotation.y = atan2(-d.x, -d.z)


func _marker(group: String, p: int) -> Vector3:
	return (field.get_node("%s/P%d" % [group, p + 1]) as Node3D).global_position


func _marker_node(path: String) -> Node3D:
	return field.get_node(path)
