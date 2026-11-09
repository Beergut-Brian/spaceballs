## Frog form dressing: picks Jeff's chicken-hood frog or Chuck's trucker-hat frog from the
## kicker it lands under, and keeps the frog green (the kicker tints the node named Skin; the
## exact player accents live on the hood / hat). Art lane.
extends Node3D

@export var size := 1.3

var _skin_mat: Material


func _ready() -> void:
	var skin := get_node_or_null("Skin") as MeshInstance3D
	if skin:
		_skin_mat = skin.material_override
	_dress.call_deferred()


func _dress() -> void:
	var player := 0
	var n := get_parent()
	while n:
		if n is CharacterBody3D and &"player" in n:
			player = n.get(&"player")
			break
		n = n.get_parent()
	$JeffHood.visible = player == 0
	$ChuckHat.visible = player == 1
	var skin := get_node_or_null("Skin") as MeshInstance3D
	if skin:
		skin.material_override = _skin_mat
	# A little "boing" when the frog appears.
	scale = Vector3(1.4, 0.4, 1.4) * size
	create_tween().tween_property(self, "scale", Vector3.ONE * size, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
