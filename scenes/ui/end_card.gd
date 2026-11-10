## End card: confetti, then two buttons. A on the big green one (focused) goes back to the lobby
## (restart_requested); stick right onto the door and A goes back to the launcher (Game.quit()).
## The characters are the 3D kickers, framed by the camera's space orbit. Each player's shelf (P1
## top-left, P2 top-right, a tile per upgrade picked this run in the player's colour, no text) pops
## in one item at a time: the run's collection. Across the top, the profile's whole collection: every
## card in the game as a small icon, the ones ever drawn in colour and the rest as dark silhouettes
## still to find. Systems owns structure, Art the look.
extends Control

signal restart_requested()

const ACCEPT_AFTER := 1.2
## The run's collection: tile size, gap, columns, and the pop-in rhythm.
const TILE := 84.0
const TILE_GAP := 8.0
const SHELF_COLUMNS := 3
const SHELF_MARGIN := Vector2(60, 110)
const POP_START := 0.5
const POP_EACH := 0.12
## The all-time collection band across the top.
const BADGE := 46.0
const BADGE_COLUMNS := 22
const BADGE_TOP := 22.0
const UNSEEN := Color(0.12, 0.12, 0.3, 0.7)

var _t := 0.0
var door_focused := false
## Player -> GridContainer of this run's upgrade tiles (rebuilt on every open).
var shelves := {}
## GridContainer of every card's badge (rebuilt on every open); badge meta `seen` true/false.
var collection: GridContainer
var _collection_panel: PanelContainer

@onready var confetti: CPUParticles2D = $Confetti
@onready var button_hint: Control = $ButtonHint
@onready var door: Control = $Door


func _ready() -> void:
	visible = false
	set_process(false)


func open() -> void:
	_t = 0.0
	_focus_door(false, false)
	visible = true
	confetti.emitting = true
	Audio.play("confetti")
	_build_shelves()
	_build_collection()
	set_process(true)


func _build_shelves() -> void:
	for g in shelves.values():
		if is_instance_valid(g):
			g.queue_free()
	shelves.clear()
	var width := SHELF_COLUMNS * TILE + (SHELF_COLUMNS - 1) * TILE_GAP
	var screen := size if size.x > 0.0 else get_viewport_rect().size
	for p in [Players.P1, Players.P2]:
		var ups: Array[UpgradeData] = Run.upgrades_of(p)
		if ups.is_empty():
			continue
		var grid := GridContainer.new()
		grid.name = "Shelf%d" % (p + 1)
		grid.columns = SHELF_COLUMNS
		grid.add_theme_constant_override("h_separation", int(TILE_GAP))
		grid.add_theme_constant_override("v_separation", int(TILE_GAP))
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(grid)
		move_child(grid, 1)   # under the buttons, over the confetti layer's first slot
		grid.position = SHELF_MARGIN if p == Players.P1 \
				else Vector2(screen.x - SHELF_MARGIN.x - width, SHELF_MARGIN.y)
		for i in ups.size():
			grid.add_child(_tile(ups[i], Players.COLOR[p], i))
		shelves[p] = grid


func _build_collection() -> void:
	if is_instance_valid(_collection_panel):
		_collection_panel.queue_free()
	Run._ensure_data()
	var cards: Array[UpgradeData] = Run.pool
	if cards.is_empty():
		collection = null
		return
	var seen: Array = Save.get_value("upgrades_seen", [])
	# A soft light band behind it, so the silhouettes read on the night sky.
	_collection_panel = PanelContainer.new()
	_collection_panel.name = "CollectionPanel"
	_collection_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.55)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(10)
	_collection_panel.add_theme_stylebox_override("panel", sb)
	add_child(_collection_panel)
	move_child(_collection_panel, 1)
	collection = GridContainer.new()
	collection.name = "Collection"
	collection.columns = BADGE_COLUMNS
	collection.add_theme_constant_override("h_separation", 6)
	collection.add_theme_constant_override("v_separation", 6)
	collection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collection_panel.add_child(collection)
	var screen := size if size.x > 0.0 else get_viewport_rect().size
	var width := BADGE_COLUMNS * BADGE + (BADGE_COLUMNS - 1) * 6.0 + 20.0
	_collection_panel.position = Vector2((screen.x - width) * 0.5, BADGE_TOP)
	for u in cards:
		var pic := TextureRect.new()
		pic.texture = u.icon
		pic.custom_minimum_size = Vector2(BADGE, BADGE)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var got := seen.has(String(u.id))
		pic.set_meta(&"seen", got)
		pic.set_meta(&"upgrade_id", u.id)
		pic.modulate = Color.WHITE if got else UNSEEN
		collection.add_child(pic)
	_collection_panel.modulate.a = 0.0
	_collection_panel.create_tween().tween_property(_collection_panel, "modulate:a", 1.0, 0.4).set_delay(POP_START)


func _tile(u: UpgradeData, color: Color, i: int) -> Control:
	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(TILE, TILE)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.92)
	sb.border_color = color
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(20)
	tile.add_theme_stylebox_override("panel", sb)
	var pic := TextureRect.new()
	pic.texture = u.icon
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(pic)
	tile.set_meta(&"upgrade_id", u.id)
	tile.pivot_offset = Vector2(TILE, TILE) * 0.5
	tile.scale = Vector2.ONE * 0.01
	var tw := tile.create_tween()
	tw.tween_interval(POP_START + i * POP_EACH)
	tw.tween_callback(Audio.play.bind("card_move", null, 1.0 + i * 0.04))
	tw.tween_property(tile, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tile


func close() -> void:
	visible = false
	confetti.emitting = false
	set_process(false)


func _process(delta: float) -> void:
	_t += delta
	button_hint.visible = _t > ACCEPT_AFTER
	door.visible = button_hint.visible and not Run.demo
	button_hint.scale = Vector2.ONE * (1.0 + (0.0 if door_focused else 0.1 * sin(_t * 6.0)))
	if _t < ACCEPT_AFTER:
		return
	if Run.demo and _t > ACCEPT_AFTER + 1.0:
		_accept()
		return
	for p in [Players.P1, Players.P2]:
		if Input.is_action_just_pressed(Players.action(p, "move_right")) \
				or Input.is_action_just_pressed(Players.action(p, "move_down")):
			_focus_door(true)
		elif Input.is_action_just_pressed(Players.action(p, "move_left")) \
				or Input.is_action_just_pressed(Players.action(p, "move_up")):
			_focus_door(false)
		if Input.is_action_just_pressed(Players.action(p, "action")):
			press()
			return


## A on whatever is focused: the big button back to the lobby, or the door to the launcher.
func press() -> void:
	if door_focused:
		door.press()
		Audio.play("ui_back")
		Game.quit()
	else:
		_accept()


func _focus_door(on: bool, sound := true) -> void:
	if sound:
		Audio.play("ui_move")
	door_focused = on
	door.focused = on
	button_hint.modulate = Color(1, 1, 1, 0.55) if on else Color.WHITE


func _accept() -> void:
	Audio.play("ui_confirm")
	Fx.flash(button_hint)
	close()
	restart_requested.emit()
