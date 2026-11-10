## Spaceballs' lobby character for the Showtime podium (data/menu_skin.tres p1/p2_character): the
## same rigged Jarling as on the field (jarling_rig.gd, no kicker, so it idles), able to wear the
## same gear (JarlingEquipment). The kit's CharacterSlot shows it in its own lit SubViewport and
## calls set_joined(), wave() and cheer(); main.gd calls dress() with what he wears on the field.
extends Node3D

@export var player := Players.P1

var equipment: JarlingEquipment

@onready var _rig: Node3D = $Jarling
@onready var _anim: AnimationPlayer = $Jarling/Model.find_child("AnimationPlayer", true, false)


func _ready() -> void:
	equipment = JarlingEquipment.new()
	equipment.name = "Equipment"
	equipment.jarling = _rig
	equipment.pop_in = false
	add_child(equipment)
	_anim.animation_finished.connect(func(_a: StringName) -> void: _anim.play(&"idle", 0.2))


func set_joined(_on: bool) -> void:
	_idle()


## Readied: arms up and he stays happy until un-readied (main.gd calls set_joined() then).
func wave() -> void:
	_anim.play(&"cheer", 0.1)


## The round is starting: arms up until the wipe covers him.
func cheer() -> void:
	_anim.play(&"cheer", 0.1)


func _idle() -> void:
	if is_inside_tree() and _anim.current_animation != "idle":
		_anim.play(&"idle", 0.2)


## Wear exactly these gear items (Kicker.gear_for), one per slot, as the field kicker would.
func dress(items: Array) -> void:
	equipment.unequip_all()
	for g: JarlingGear in items:
		if g:
			equipment.equip(g)
