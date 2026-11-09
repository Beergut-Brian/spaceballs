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

var _title_t := 0.0


func _ready() -> void:
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	Game.state_changed.connect(_on_state_changed)
	Run.phase_changed.connect(_on_phase_changed)
	Run.run_started.connect(_on_run_started)
	Run.reached_space.connect(_on_reached_space)
	Run.ball_stopped.connect(func(_p: int, _h: float, _t: int) -> void: rig.hold_peak())
	for p in [P1, P2]:
		balls[p].kick_zone_entered.connect(_on_kick_zone.bind(p))
		balls[p].returned.connect(_on_ball_returned.bind(p))
		kickers[p].kick_contact.connect(_on_kick_contact.bind(p))
		hud.track(p, balls[p])
	pick_ui.picked.connect(_on_picked)
	end_card.restart_requested.connect(func() -> void: Run.start_run())
	title.visible = true
	hud.visible = false
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
		balls[p].place_on_tee(_marker("Tees", p))


func _on_phase_changed(from: int, to: int) -> void:
	if from == Run.Phase.PICK and to != Run.Phase.PICK:
		pick_ui.close()
		rig.split(false)
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
	var tee := _marker("Tees", p)
	for q in [P1, P2]:
		var k: Kicker = kickers[q]
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
	if curse != null and curse.scene_override != null:
		me.set_frog(true, curse.scene_override)
	elif curse != null:
		Audio.play("curse")
		Fx.puff(me.global_position + Vector3.UP, Color(0.6, 0.4, 0.9), 1.5)
	me.begin_approach(balls[p].global_position)
	balls[p].arm(true)
	rig.frame_field(me, tee)


func _on_kick_zone(body: Node3D, p: int) -> void:
	if body != kickers[p] or Run.phase != Run.KICK_PHASE[p]:
		return
	balls[p].arm(false)
	Run.notify_kick_started(p)
	kickers[p].start_windup()


func _on_kick_contact(quality: float, p: int) -> void:
	if Run.phase != Run.KICK_PHASE[p]:
		return
	var power := Run.notify_kicked(p, quality)
	var height := Run.kick_height(p, power)
	var tier := Run.tier_of_height(height)
	Audio.play(_kick_cue(p, tier))
	Fx.puff(balls[p].global_position, Color(1, 1, 0.8), 0.8 + tier * 0.3)
	balls[p].launch(power, height)
	rig.follow(balls[p])
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
	Run.end_flight(p)


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
		var cam_from := spot + Vector3(0.6, 1.5, -3.4)
		k.rotation.y = atan2(-(cam_from - spot).x, -(cam_from - spot).z)
		pick_ui.frame(p, spot + Vector3.UP * 1.1, cam_from)
	rig.split(true)
	pick_ui.open(draws, shown)


func _on_picked(p: int, u: UpgradeData) -> void:
	if u.is_curse():
		Audio.play("curse")
		Fx.puff(kickers[p].global_position + Vector3.UP, Color(0.6, 0.4, 0.9), 2.0)
		Fx.pop(kickers[p].body, 1.4)
	else:
		kickers[p].add_upgrade_visual(u)
	Run.pick(p, u)


func _begin_end() -> void:
	rig.split(false)
	var center := _marker_node("EndSpot").global_position
	for p in [P1, P2]:
		var k: Kicker = kickers[p]
		k.set_frog(false)
		k.global_position = center + Vector3(-0.9 if p == P1 else 0.9, 0, 0)
		k.velocity = Vector3.ZERO
		k.set_waiting(false)
		k.set_space_suit(true)
		balls[p].visible = false
	rig.orbit(center)
	Audio.play("space")
	Audio.play("cheer")
	end_card.open()


func _on_reached_space(p: int) -> void:
	Audio.play("space")
	Fx.puff(balls[p].global_position, Color(1, 1, 0.6), 6.0)


# --- helpers ---------------------------------------------------------------------

func _on_state_changed(_from: int, to: int) -> void:
	title.visible = to == Game.State.TITLE
	pause_overlay.visible = to == Game.State.PAUSED


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
