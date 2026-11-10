## Spaceballs' lobby character for the Showtime podium (data/menu_skin.tres p1/p2_character): the
## same rigged Jarling as on the field (jarling_rig.gd, no kicker, so it idles), able to wear the
## same gear (JarlingEquipment). The kit's CharacterSlot shows it in its own lit SubViewport, tells it
## the Roster pick with set_character(id) (before it enters the tree, and again on every swap) and
## calls set_joined(), wave() and cheer(); main.gd calls dress() with what he wears on the field.
extends Node3D

const RIG := preload("res://art/scripts/jarling_rig.gd")

var equipment: JarlingEquipment
## The Roster character standing here ("" until set_character).
var id := ""

var _rig: Node3D
var _anim: AnimationPlayer
var _items: Array = []


func _ready() -> void:
	_rig = Node3D.new()
	_rig.name = "Jarling"
	_rig.scale = Vector3.ONE * 1.3
	_rig.set_script(RIG)
	add_child(_rig)
	_put_on(id)


## Become Roster character `id` in place (its vendored .glb), still wearing the same gear.
func set_character(to: String) -> void:
	var who := Roster.info(to)
	if who.is_empty() or not ResourceLoader.exists(str(who.glb)):
		return
	id = to
	if _rig:
		_put_on(id)


func _put_on(to: String) -> void:
	var who := Roster.info(to)
	if who.is_empty():
		return
	if equipment:
		equipment.unequip_all()
		remove_child(equipment)
		equipment.free()
	_rig.set_model(load(str(who.glb)) as PackedScene, to + "_hat")
	_anim = _rig.model.find_child("AnimationPlayer", true, false)
	_anim.animation_finished.connect(func(_a: StringName) -> void: _anim.play(&"idle", 0.2))
	equipment = JarlingEquipment.new()
	equipment.name = "Equipment"
	equipment.jarling = _rig
	equipment.pop_in = false
	add_child(equipment)
	dress(_items)


func set_joined(_on: bool) -> void:
	_idle()


## Readied: arms up and he stays happy until un-readied (main.gd calls set_joined() then).
func wave() -> void:
	if _anim:
		_anim.play(&"cheer", 0.1)


## The round is starting: arms up until the wipe covers him.
func cheer() -> void:
	if _anim:
		_anim.play(&"cheer", 0.1)


func _idle() -> void:
	if is_inside_tree() and _anim and _anim.current_animation != "idle":
		_anim.play(&"idle", 0.2)


## Wear exactly these gear items (Kicker.gear_for), one per slot, as the field kicker would.
func dress(items: Array) -> void:
	_items = items.duplicate()
	if equipment == null:
		return
	equipment.unequip_all()
	for g: JarlingGear in items:
		if g:
			equipment.equip(g)
