class_name JarlingEquipment
extends Node
## Vendored from openjar-characters v0.1.0 (commit 6e03db9), godot/jarling_equipment.gd. Original work, Open Jar Games.
## Do not edit here: change it in openjar-characters and copy it again.
## Puts JarlingGear on a Jarling glb from this repo (docs/equipment.md).
##
## Add as a child of the instanced Jarling (or set `jarling`). One item per slot: equipping into a
## filled slot swaps it; equipping an item that is already worn levels it up instead of stacking.

signal item_equipped(slot: StringName, item: JarlingGear)
signal item_unequipped(slot: StringName, item: JarlingGear)
signal item_leveled_up(slot: StringName, item: JarlingGear, level: int)
## Hook for the game's puff / sfx: emitted on equip, swap and level up, at the slot.
signal poof(slot: StringName, at: Vector3)

const SLOTS: Array[StringName] = [&"head", &"face", &"back", &"hand_l", &"hand_r", &"waist",
		&"knee_l", &"knee_r", &"foot_l", &"foot_r"]

## The instanced Jarling glb. Defaults to the parent node.
@export var jarling: Node3D
## Scale-in tween when a piece goes on.
@export var pop_in := true

var _worn := {}     # id -> {item, level, holders: {slot: Node3D}, springs: Array}
var _slot_id := {}  # slot -> id
var _parts := {}    # body part -> Array[Node3D]
var _hidden := {}   # body part -> how many worn items hide it
var _markers := {}  # slot -> Node3D
var _scanned := false


func _ready() -> void:
	_scan()


# ------------------------------------------------------------------------------------- public API

## Wear `item`. Returns false when the item was already worn and got levelled up instead.
func equip(item: JarlingGear) -> bool:
	_scan()
	if item == null or item.slots.is_empty():
		push_warning("JarlingEquipment: item has no slots")
		return false
	if has_item(item.id):
		level_up(item.slots[0])
		return false
	var swapped := false
	for s in item.slots:
		if _slot_id.has(s):
			unequip(s)
			swapped = true
	var w := {"item": item, "level": 1, "holders": {}, "springs": []}
	var inst: Node = item.scene.instantiate() if item.scene else Node3D.new()
	for s in item.slots:
		var marker := slot_node(s)
		var piece: Node3D = inst.find_child(String(s), true, false) as Node3D
		if piece:
			piece.get_parent().remove_child(piece)
			_unown(piece)
		elif item.slots.size() == 1:
			piece = inst as Node3D
			inst = null
		else:
			piece = item.scene.instantiate() as Node3D
		piece.transform = Transform3D.IDENTITY
		var holder := Node3D.new()
		holder.name = "gear_%s" % item.id
		var pop := Node3D.new()
		pop.name = "pop"
		holder.add_child(pop)
		pop.add_child(piece)
		marker.add_child(holder)
		w.holders[s] = holder
		if not item.spring.is_empty():
			var pivot := piece.find_child(String(item.spring.get("node", "")), true, false) as Node3D
			if pivot:
				w.springs.append({"node": pivot, "angle": deg_to_rad(float(item.spring.get("rest_deg", 0.0))),
						"vel": 0.0, "prev": Vector3.INF})
	if inst:
		inst.free()
	_slot_id_set(item, w)
	_apply_level(w)
	for p in item.replaces_body_part:
		_hide_part(p, true)
	for s in item.slots:
		if pop_in and w.holders[s].is_inside_tree():
			var pop: Node3D = w.holders[s].get_node("pop")
			pop.scale = Vector3.ONE * 0.01
			pop.create_tween().tween_property(pop, "scale", Vector3.ONE, 0.3) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		item_equipped.emit(s, item)
	poof.emit(item.slots[0], _slot_pos(item.slots[0]))
	return true


## Take off whatever is in `slot` (the whole item: both shoes). Returns it, or null.
func unequip(slot: StringName) -> JarlingGear:
	if not _slot_id.has(slot):
		return null
	var id: StringName = _slot_id[slot]
	var w: Dictionary = _worn[id]
	var item: JarlingGear = w.item
	for s in item.slots:
		var h: Node3D = w.holders.get(s)
		if h:
			h.get_parent().remove_child(h)
			h.queue_free()
		_slot_id.erase(s)
	for p in item.replaces_body_part:
		_hide_part(p, false)
	_worn.erase(id)
	poof.emit(slot, _slot_pos(slot))
	for s in item.slots:
		item_unequipped.emit(s, item)
	return item


func unequip_all() -> void:
	for s in SLOTS:
		unequip(s)


## The item in `slot`, or null.
func equipped(slot: StringName) -> JarlingGear:
	return _worn[_slot_id[slot]].item if _slot_id.has(slot) else null


func has_item(id: StringName) -> bool:
	return _worn.has(id)


## Repeat pick-up of a worn item: a little bigger, trim shown. Returns the new level (0 if empty).
func level_up(slot: StringName) -> int:
	if not _slot_id.has(slot):
		return 0
	var w: Dictionary = _worn[_slot_id[slot]]
	var item: JarlingGear = w.item
	w.level = mini(w.level + 1, item.max_level())
	_apply_level(w)
	poof.emit(slot, _slot_pos(slot))
	item_leveled_up.emit(slot, item, w.level)
	return w.level


func level(slot: StringName) -> int:
	return _worn[_slot_id[slot]].level if _slot_id.has(slot) else 0


## The slot_<name> marker on the Jarling (follows its bone). Falls back to the Jarling root.
func slot_node(slot: StringName) -> Node3D:
	_scan()
	var m: Node3D = _markers.get(slot)
	if m == null:
		push_warning("JarlingEquipment: no slot_%s on %s (not a Jarling glb, or built before slots)" % [slot, _root().name])
		return _root()
	return m


## Body part meshes the Jarling has (foot_l, hand_r, headwear, tail ...).
func body_parts() -> Array:
	_scan()
	return _parts.keys()


func is_part_hidden(part: StringName) -> bool:
	return _hidden.get(part, 0) > 0


# ----------------------------------------------------------------------------------------- internals

func _root() -> Node3D:
	return jarling if jarling else get_parent() as Node3D


func _scan() -> void:
	if _scanned or _root() == null:
		return
	_scanned = true
	var stack: Array[Node] = [_root()]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not n is Node3D:
			continue
		var ex: Dictionary = n.get_meta("extras", {})
		var nm := String(n.name)
		if nm.begins_with("slot_"):
			_markers[StringName(nm.substr(5))] = n
		var part := String(ex.get("jarling_part", ""))
		if part == "" and nm.contains("_part_"):
			part = nm.get_slice("_part_", 1)
		if part != "":
			if not _parts.has(StringName(part)):
				_parts[StringName(part)] = []
			_parts[StringName(part)].append(n)


func _slot_id_set(item: JarlingGear, w: Dictionary) -> void:
	_worn[item.id] = w
	for s in item.slots:
		_slot_id[s] = item.id


func _fit_for(item: JarlingGear, slot: StringName) -> Dictionary:
	var ex: Dictionary = slot_node(slot).get_meta("extras", {})
	for key in [ex.get("jarling_id", ""), ex.get("jarling_build", "")]:
		if key != "" and item.fit.has(key):
			return item.fit[key]
	return {}


func _apply_level(w: Dictionary) -> void:
	var item: JarlingGear = w.item
	var grow: float = 1.0 + item.scale_step() * (int(w.level) - 1)
	for s in w.holders:
		var h: Node3D = w.holders[s]
		var f := _fit_for(item, s)
		var sc = f.get("scale", 1.0)
		var v := Vector3(sc[0], sc[1], sc[2]) if sc is Array else Vector3.ONE * float(sc)
		var o: Array = f.get("offset", [0, 0, 0])
		h.position = Vector3(o[0], o[1], o[2])
		h.scale = v * grow
		_show_trim(h, w.level >= 2)


func _unown(n: Node) -> void:
	n.owner = null
	for c in n.get_children():
		_unown(c)


func _show_trim(n: Node, on: bool) -> void:
	for c in n.get_children():
		if c is Node3D and String(c.name).begins_with("trim"):
			c.visible = on
		_show_trim(c, on)


func _hide_part(part: StringName, hide: bool) -> void:
	var c: int = _hidden.get(part, 0) + (1 if hide else -1)
	_hidden[part] = maxi(c, 0)
	for n in _parts.get(part, []):
		if is_instance_valid(n):
			n.visible = _hidden[part] == 0


func _slot_pos(slot: StringName) -> Vector3:
	var m := slot_node(slot)
	return m.global_position if m and m.is_inside_tree() else Vector3.ZERO


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	for id in _worn:
		var w: Dictionary = _worn[id]
		var sp: Dictionary = w.item.spring
		for st in w.springs:
			var pivot: Node3D = st.node
			if not is_instance_valid(pivot) or not pivot.is_inside_tree():
				continue
			var anchor := pivot.get_parent_node_3d()
			var pos := anchor.global_position
			var v: Vector3 = Vector3.ZERO if st.prev == Vector3.INF else (pos - st.prev) / delta
			st.prev = pos
			var fwd := anchor.global_basis.z.normalized()
			var rest := deg_to_rad(float(sp.get("rest_deg", 0.0)))
			var target := rest + float(sp.get("gain", 0.5)) * (maxf(0.0, v.dot(fwd)) + 0.5 * absf(v.y))
			target = clampf(target, rest, deg_to_rad(float(sp.get("max_deg", 60.0))))
			var acc: float = float(sp.get("stiffness", 45.0)) * (target - float(st.angle)) - float(sp.get("damping", 7.0)) * float(st.vel)
			st.vel += acc * delta
			st.angle = clampf(st.angle + st.vel * delta, 0.0, deg_to_rad(float(sp.get("max_deg", 60.0))))
			pivot.rotation.x = st.angle
