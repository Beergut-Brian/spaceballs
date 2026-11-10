## Boot scene and round director: the lobby (template start screen) with Jeff and Chuck on the tees,
## drop-in, and the scene side of Run's phases (who stands where, which ball is armed, which camera,
## which UI). Game rules live in Run. Systems lane owns.
## CLI (after --): --demo plays itself (no lobby), --timescale=<x> speeds it up, --gear=a,b / --gear2=c.
extends Node3D

const P1 := Players.P1
const P2 := Players.P2
const KICK_CUES := ["kick_1", "kick_2", "kick_3", "kick_4"]

@onready var field: Node3D = $Field
@onready var rig: Node3D = $CameraRig
@onready var hud: Control = $UI/HUD
@onready var pick_ui: Control = $UI/UpgradePick
@onready var end_card: Control = $UI/EndCard
@onready var lobby: Control = $UI/Lobby
@onready var kickers := {P1: $Kickers/Jeff, P2: $Kickers/Chuck}
@onready var balls := {P1: $Balls/P1, P2: $Balls/P2}

## Space moment: the ball circles the planet this long before the next kick.
const ORBIT_SHOW := 2.0
## After the last card is picked, the split screen stays this long so the item is seen landing.
const PICK_BEAT := 0.9
## Lobby shot: Jeff and Chuck stand this far behind and outside their tees (P2 mirrored), so
## each is in the middle of his spot with the ball at his inner side; the camera looks from in front.
const LOBBY_KICKER := preload("res://scenes/ui/lobby_kicker.gd")
const BallScript := preload("res://scenes/ball.gd")
const LOBBY_STAND := Vector3(-0.8, 0, -1.3)
const LOBBY_CAMERA := Vector3(0, 1.5, 4.6)
const LOBBY_LOOK := Vector3(0, 1.05, 0)
## A kick starts only this close to the ball (flat metres). The kick zone's overlap list can be a
## physics frame stale after a teleport (lobby -> spawn), which would kick on the round's first frame.
const KICK_REACH := 1.7
## A hop over his own ball: within this flat distance of it and no higher than this over its top
## (about one ball-height, plus the kick zone's reach), he is snapped down in front and kicks anyway.
## Higher (a jetpack or rocket jump), he flies over.
const SNAP_REACH := 1.0
const SNAP_OVER := 0.8
const BALL_TOP := 0.65
## Where he lands when snapped: this far before the ball, on the side he came from.
const SNAP_GAP := 0.75
## The bystander bumping the kicker's ball: a boop and a little shove, nothing else.
const BUMP_PUSH := 4.0
## The field's picket fence is 30 m long; the long run-up (spawns 30 m out) gets a second length.
const FENCE_LENGTH := 30.0

var _turn: TurnMarker
var _crowd: CrowdReactions
var _bystander_arrow: OffscreenArrow
var _bump_t := 0.0
## The highest tier any ball has reached this run (a new one gets the crowd's roar).
var _run_top_tier := 1
var _confetti: CPUParticles2D
## -- --gear=a,b (P1) / --gear2=c (P2): start every run wearing these (playtests, screenshots).
var _gear := {P1: [], P2: []}


func _ready() -> void:
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	Players.solo_changed.connect(_on_solo_changed)
	Game.state_changed.connect(_on_state_changed)
	Game.lobby_ready.connect(_on_lobby_ready)
	Game.round_started.connect(_on_round_started)
	lobby.player_readied.connect(_on_lobby_readied)
	_adopt_lobby()
	Run.phase_changed.connect(_on_phase_changed)
	Run.run_started.connect(_on_run_started)
	Run.reached_space.connect(_on_reached_space)
	Run.ball_tier_reached.connect(func(_p: int, tier: int) -> void: Audio.music_level((tier - 1) / 2))
	Run.ball_stopped.connect(func(_p: int, _h: float, _t: int) -> void: rig.hold_peak())
	for p in [P1, P2]:
		balls[p].kick_zone_entered.connect(_on_kick_zone.bind(p))
		balls[p].returned.connect(_on_ball_returned.bind(p))
		kickers[p].kick_contact.connect(_on_kick_contact.bind(p))
		kickers[p].slipped.connect(_start_kick.bind(p))
		hud.track(p, balls[p])
	pick_ui.picked.connect(_on_picked)
	end_card.restart_requested.connect(_on_end_accepted)
	Run.ball_stopped.connect(_on_ball_stopped)
	_turn = TurnMarker.new()
	add_child(_turn)
	_lengthen_field()
	_crowd = CrowdReactions.new()
	add_child(_crowd)
	_crowd.setup(field.find_child("Crowd", true, false))
	Run.ball_tier_reached.connect(_on_tier_reached)
	_bystander_arrow = OffscreenArrow.new()
	$UI.add_child(_bystander_arrow)
	_bystander_arrow.hide_arrow()
	_confetti = end_card.get_node("Confetti").duplicate()
	_confetti.one_shot = true
	_confetti.explosiveness = 0.6
	_confetti.amount = 120
	_confetti.lifetime = 3.0
	$UI.add_child(_confetti)
	hud.visible = false
	Audio.music("field_loop")
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo":
			Run.demo = true
		elif arg.begins_with("--gear=") or arg.begins_with("--gear2="):
			var who := P2 if arg.begins_with("--gear2=") else P1
			_gear[who] = Array(arg.get_slice("=", 1).split(",", false))
		elif arg.begins_with("--timescale="):
			Engine.time_scale = clampf(float(arg.trim_prefix("--timescale=")), 0.1, 8.0)
	if Run.demo:
		Game.demo = true   # the lobby stays out of the way
	if Game.demo:
		Run.demo = true
		(func() -> void:
			Players.join_virtual(P1)
			Players.join_virtual(P2)
			Run.start_run()).call_deferred()
	elif Game.state != Game.State.LOBBY:
		Game.to_lobby()
	else:
		_layout_lobby()


# --- players -------------------------------------------------------------------

func _on_player_joined(player: int, _device: int) -> void:
	if Game.state == Game.State.LOBBY:
		return   # the lobby readies them
	if player == P2 and not Run.in_run(P2):
		# Stands up from the lawn chair; gets a ball at the start of the next round.
		kickers[P2].global_position = _marker("Sidelines", P2)
		kickers[P2].set_waiting(false)
		kickers[P2].cheer()
		Fx.puff(kickers[P2].global_position + Vector3.UP, Players.COLOR[P2], 1.5)


## Solo (playtest): turned on before P1's first kick, restart so both play from round 1.
func _on_solo_changed(on: bool) -> void:
	if on and Game.state != Game.State.LOBBY and Run.round_index <= 1 \
			and Run.phase == Run.Phase.KICK_P1 and not Run.in_run(P2):
		Run.start_run()


func _on_player_left(player: int) -> void:
	if player == P2 and not Run.in_run(P2) and Game.state != Game.State.LOBBY:
		_bench(P2)


# --- lobby -----------------------------------------------------------------------

## The lobby countdown finished: these players play from round 1 (Game starts it right after).
func _on_lobby_ready(players: Array) -> void:
	Run.plan_run(players)


func _on_round_started(index: int) -> void:
	# Joined in the lobby but never readied: on the sidelines for round 1, in from round 2.
	if index == 1:
		for p in Players.active_players():
			if not Run.in_run(p):
				Run.join_next_round(p)


func _on_lobby_readied(player: int, on: bool) -> void:
	if not on:
		lobby.get_node("Spots/P%d/Character" % (player + 1)).rest()


## Jeff left, Chuck right, each standing just behind his tee and facing the camera, which looks
## along the field from the spawn side: the sunny field is the lobby's backdrop.
func _layout_lobby() -> void:
	rig.split(false)
	_turn.hide_marker()
	var cam_at := LOBBY_CAMERA
	for p in [P1, P2]:
		var k: Kicker = kickers[p]
		k.set_frog(false)
		k.dance(false)
		k.set_space_suit(false)
		k.clear_upgrade_visuals()
		k.bot = false
		balls[p].arm(false)
		balls[p].visible = true
		balls[p].place_on_tee(_marker("Tees", p))
		var stand := LOBBY_STAND * Vector3(1 if p == P1 else -1, 1, 1)
		_place(p, _marker("Tees", p) + stand, field.global_position + cam_at)
		k.set_idle()
	rig.hold_peak()   # a still shot: the rig leaves the camera alone
	rig.camera.global_position = field.global_position + cam_at
	rig.camera.look_at(field.global_position + LOBBY_LOOK)


# --- phases ----------------------------------------------------------------------

func _on_run_started() -> void:
	_run_top_tier = 1
	end_card.close()
	pick_ui.close()
	hud.visible = true
	for p in [P1, P2]:
		kickers[p].clear_upgrade_visuals()
		kickers[p].set_frog(false)
		kickers[p].set_space_suit(false)
		kickers[p].dance(false)
		balls[p].place_on_tee(_marker("Tees", p))
		for id in _gear[p]:
			var u := Run.upgrade_by_id(StringName(id))
			if u:
				Run.give(p, u)
				kickers[p].add_upgrade_visual(u)
		kickers[p].apply_effects(Run.effects_of(p))


func _on_phase_changed(from: int, to: int) -> void:
	if from == Run.Phase.PICK and to != Run.Phase.PICK:
		pick_ui.close()
		rig.split(false)
	if to != Run.Phase.KICK_P1 and to != Run.Phase.KICK_P2:
		_turn.hide_marker()
	if to == Run.Phase.PICK or to == Run.Phase.END or to == Run.Phase.IDLE:
		_bystander_arrow.hide_arrow()
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
		# The bystander's ball is not on its tee yet: nothing of his to kick.
		balls[q].visible = false
		balls[q].arm(false)
		if Run.in_space(q):
			_to_cloud(q)
		elif Run.in_run(q) or Players.is_active(q):
			_place(q, _marker("Sidelines", q), tee)
			k.set_waiting(false)
			# The bystander runs about with all his gear (trails, bounce, jets); only the
			# kicker's own body starts a kick, so he can't kick anything.
			k.apply_effects(Run.effects_of(q))
			k.roam = true
			k.bot = Run.demo
			_bystander_arrow.show_for(k, Players.COLOR[q])
		else:
			_bench(q)
			_bystander_arrow.hide_arrow()
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
	me.effects = Run.effects_of(p)
	me.bot = Run.demo
	me.begin_approach(balls[p].global_position)
	balls[p].arm(true)
	rig.frame_close(frog_round)
	rig.frame_field(me, tee)
	_turn.show_for(me, tee, Players.COLOR[p])
	_turn.set_ball(balls[p])


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
	if Run.phase != Run.KICK_PHASE[p]:
		return
	if body is Kicker and body != kickers[p]:
		_bump(body as Kicker, p)
		return
	if body != kickers[p]:
		return
	var gap: Vector3 = body.global_position - balls[p].global_position
	if Vector2(gap.x, gap.z).length() > KICK_REACH:
		return
	if not kickers[p].is_on_floor():
		_snap_in_front(p)
	_start_kick(p)


## The kick starts: his own ball's zone, a low hop over it, or a banana peel a few metres out.
func _start_kick(p: int) -> void:
	if Run.phase != Run.KICK_PHASE[p] or not balls[p].is_armed() or kickers[p].state != Kicker.State.APPROACH:
		return
	balls[p].arm(false)
	Run.notify_kick_started(p)
	kickers[p].start_windup()
	_turn.hide_marker()
	if Kicker.gag_of(kickers[p].windup) != &"" and not kickers[p].frog:
		rig.frame_close(true)   # move in so the gag reads


func _physics_process(delta: float) -> void:
	_bump_t = maxf(_bump_t - delta, 0.0)
	var p := Run.phase_player()
	if p < 0 or Run.phase != Run.KICK_PHASE[p] or not balls[p].is_armed():
		return
	if over_ball(kickers[p], balls[p]):
		_snap_in_front(p)
		_start_kick(p)


## Kaden: "if you're close to the top of the ball and you're having to jump over it, maybe we just
## snap the animation to in front of the ball and still have you kick it anyway."
static func over_ball(k: Kicker, ball: Node3D) -> bool:
	if k.is_on_floor() or k.state != Kicker.State.APPROACH or k.is_slipping():
		return false
	var gap := k.global_position - ball.global_position
	var top := ball.global_position.y - BallScript.TEE_HEIGHT + BALL_TOP
	return Vector2(gap.x, gap.z).length() < SNAP_REACH and k.global_position.y - top <= SNAP_OVER


func _snap_in_front(p: int) -> void:
	var k: Kicker = kickers[p]
	var ball: Vector3 = balls[p].global_position
	var come := Vector3(k.velocity.x, 0.0, k.velocity.z)
	if come.length() < 0.3:
		come = Vector3(ball.x - k.global_position.x, 0.0, ball.z - k.global_position.z)
	if come.length() < 0.01:
		come = Vector3.FORWARD
	var ground := _marker("Tees", p).y
	k.global_position = Vector3(ball.x, ground, ball.z) - come.normalized() * SNAP_GAP
	k.velocity = Vector3.ZERO
	Fx.puff(k.global_position + Vector3.UP * 0.2, Color(0.85, 0.75, 0.6), 0.6)
	Audio.play("land", null, 1.2)


## The bystander ran into the kicker's ball: a boop, the ball wobbles, he bounces off.
func _bump(k: Kicker, p: int) -> void:
	if _bump_t > 0.0:
		return
	_bump_t = 0.6
	var away: Vector3 = k.global_position - balls[p].global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	k.velocity = away * BUMP_PUSH + Vector3.UP * 3.0
	Audio.play("squeak", null, 0.8)
	Fx.pop(balls[p].mesh, 1.25)
	Fx.puff(balls[p].global_position, Players.COLOR[k.player].lightened(0.4), 0.4)


func _on_kick_contact(quality: float, p: int) -> void:
	if Run.phase != Run.KICK_PHASE[p]:
		return
	var power := Run.notify_kicked(p, quality)
	var height := Run.kick_height(p, power)
	var tier := Run.tier_of_height(height)
	Audio.play(_kick_cue(p, tier))
	var fx: Dictionary = kickers[p].effects
	balls[p].effects.assign(fx.get(&"ball_effects", []) if not kickers[p].frog else [])
	if not kickers[p].frog:
		Fx.puff(balls[p].global_position, Color(1, 1, 0.8), 0.8 + tier * 0.3)
		var juice := field.get_node_or_null("Juice")
		if juice and juice.has_method("shake") and float(fx.get(&"shake", 0.0)) > 0.0:
			juice.call_deferred("shake", float(fx.get(&"shake", 0.0)))   # after its own kick shake
	balls[p].launch(power, height)
	if not balls[p].dribbles(Run.curse_of(p)):
		rig.follow(balls[p])   # the frog's and the banana's dribble stays in the close-up
	_crowd.react(CrowdReactions.kick_level(tier, Run.tier_of_height(Run.best_height(p)), quality,
			Run.curse_of(p) != null))
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


## A new tier for the whole run: the crowd roars.
func _on_tier_reached(p: int, tier: int) -> void:
	if tier > _run_top_tier and Run.phase == Run.FLIGHT_PHASE[p] and Run.curse_of(p) == null:
		_run_top_tier = tier
		_crowd.react(CrowdReactions.Level.ROAR)


## A curse's payoff: the ball goes nowhere and the whole crowd goes "awww". The frog also
## plops a "bloop" and laughs it off.
func _on_ball_stopped(p: int, _height: float, _tier: int) -> void:
	if Run.in_space(p) and balls[p].flight == balls[p].Flight.FLOATING:
		rig.orbit(balls[p].orbit_center, 4.4, 1.2, false)
		_celebrate_orbit()
		return
	var curse := Run.curse_of(p)
	if curse == null:
		return
	_crowd.react(CrowdReactions.Level.AWW)
	if curse.scene_override == null:
		return
	_sfx("bloop", "frog", 0.6)
	Fx.puff(balls[p].global_position + Vector3.UP * 0.3, Color(0.6, 0.9, 0.4), 0.4)
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
		var spot := _marker("PickSpots", p)
		if Run.in_space(p):
			_to_cloud(p)
			spot = k.global_position
		elif shown.has(p):
			k.global_position = spot
			k.set_waiting(false)
		else:
			_bench(p)
		k.set_frog(false)   # here, so the poof back happens in his own half
		var view := pick_view(spot, _stack_height(k), pick_ui.camera_of(p).fov)
		k.rotation.y = atan2(-(view[0] - spot).x, -(view[0] - spot).z)
		pick_ui.frame(p, view[1], view[0])
	rig.split(true)
	pick_ui.open(draws, shown)


## Pick camera [from, look_at]: low and a little to the side, pulled back far enough that the
## whole pile (feet to top hat, `height` metres) sits between about 8 % and 56 % of the half's height,
## clear of the cards along the bottom.
static func pick_view(spot: Vector3, height: float, fov_deg: float = 50.0) -> Array:
	var h := maxf(height, 1.6)
	var view_h := h / 0.48                      # metres of world the half shows, top to bottom
	var dist := view_h / (2.0 * tan(deg_to_rad(fov_deg) * 0.5))
	var look := spot + Vector3.UP * (h * 0.5 - 0.17 * view_h)
	# From the spawn side (+Z): the tees, balls and landing puffs stay behind him, not in the lens.
	var from := look + Vector3(-0.22, 0.12, 1.0).normalized() * dist
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
	# Hidden curses: now and then the card turns out to be a curse (Run decides, the card flips).
	var curse := Run.reveal_curse(p) if not u.is_curse() else null
	if curse != null:
		await pick_ui.reveal_curse(p, curse)
		if Run.phase != Run.Phase.PICK:
			return
		u = curse
	if u.is_curse():
		Audio.play("curse")
		Fx.puff(kickers[p].global_position + Vector3.UP, Color(0.6, 0.4, 0.9), 2.0)
		Fx.pop(kickers[p].body, 1.4)
	else:
		kickers[p].add_upgrade_visual(u)
		var ups := Run.upgrades_of(p)
		ups.append(u)
		kickers[p].apply_effects(Run.resolve_effects(ups))   # Super Strength bulks up right here
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
	# Deferred: the same A press must not ready anybody in the lobby this frame.
	Game.to_lobby.call_deferred()


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
	if to == Game.State.LOBBY:
		# Back from the end card or the pause menu's Restart: a clean field, nobody mid-run.
		Run.stop_run()
		end_card.close()
		pick_ui.close()
		hud.visible = false
		Audio.music("field_loop")
		_layout_lobby()


func _sfx(cue: String, fallback: String, pitch: float = 1.0) -> void:
	if ResourceLoader.exists(Kicker.SFX_DIR + cue + ".ogg") or ResourceLoader.exists(Kicker.SFX_DIR + cue + "_1.ogg"):
		Audio.play(cue)
	else:
		Audio.play(fallback, null, pitch)


## The long run-up: a second length of picket fence along the back of the lawn.
func _lengthen_field() -> void:
	var fence := field.get_node_or_null("Fence") as Node3D
	if fence == null or field.has_node("Fence2"):
		return
	var more := fence.duplicate() as Node3D
	more.name = "Fence2"
	field.add_child(more)
	more.position = fence.position + Vector3(0, 0, FENCE_LENGTH)


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


## Hook Spaceballs into the template lobby in code, not only through main.tscn overrides: the exported
## build dropped the overrides on the instanced lobby's children (Backdrop, TitleArt, Character script),
## so the release showed the template's dark placeholder lobby while the editor showed the field.
func _adopt_lobby() -> void:
	lobby.get_node("Backdrop").visible = false
	lobby.get_node("TitleArt").visible = false
	for p in [P1, P2]:
		var spot: Node = lobby.get_node("Spots/P%d" % (p + 1))
		spot.fill_alpha = 0.18   # see-through, so the real kicker on the field shows inside the spot
		spot.queue_redraw()
		var who: Node = spot.get_node_or_null("Character")
		if who == null or who.get_script() != LOBBY_KICKER:
			var c := Control.new()
			c.set_script(LOBBY_KICKER)
			if who:
				c.layout_mode = who.layout_mode
				c.anchor_left = who.anchor_left
				c.anchor_top = who.anchor_top
				c.anchor_right = who.anchor_right
				c.anchor_bottom = who.anchor_bottom
				c.offset_left = who.offset_left
				c.offset_top = who.offset_top
				c.offset_right = who.offset_right
				c.offset_bottom = who.offset_bottom
				var at := who.get_index()
				spot.remove_child(who)
				who.queue_free()
				c.name = "Character"
				spot.add_child(c)
				spot.move_child(c, at)
			else:
				c.name = "Character"
				spot.add_child(c)
			who = c
		who.player = p
		who.kicker = kickers[p]

