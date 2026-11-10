## Worn gear (docs/contracts.md "Worn gear"): one item per slot, swap, level up, never a stack.
extends GdUnitTestSuite

const JEFF := preload("res://scenes/players/jeff.tscn")
const CHUCK := preload("res://scenes/players/chuck.tscn")
const DIR := "res://data/upgrades/"


func _card(id: String) -> UpgradeData:
	return load(DIR + id + ".tres") as UpgradeData


func _wearables() -> Array[UpgradeData]:
	var out: Array[UpgradeData] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".tres"):
			var u := load(DIR + f) as UpgradeData
			if u.slot != "none" and u.slot != "ball":
				out.append(u)
	return out


func _kicker(scene: PackedScene) -> Kicker:
	var k: Kicker = auto_free(scene.instantiate())
	add_child(k)
	k.equipment.pop_in = false
	return k


func _pieces(k: Kicker) -> int:
	var n := 0
	for s in JarlingEquipment.SLOTS:
		for c in k.equipment.slot_node(s).get_children():
			if String(c.name).begins_with("gear_") and not c.is_queued_for_deletion():
				n += 1
	return n


func test_every_wearable_card_resolves_to_gear() -> void:
	var cards := _wearables()
	assert_int(cards.size()).is_greater(30)
	for u in cards:
		var label := String(u.id)
		var gear := Kicker.gear_for(u)
		assert_object(gear).override_failure_message(label + " has no gear item").is_not_null()
		if gear == null:
			continue
		assert_str(String(gear.id)).is_equal(label)
		assert_object(gear.scene).override_failure_message(label + " gear has no scene").is_not_null()
		assert_str(u.visual.resource_path).is_equal("res://assets/gear/%s.glb" % label)
		assert_bool(gear.slots.is_empty()).is_false()
		for s in gear.slots:
			assert_bool(JarlingEquipment.SLOTS.has(s)).override_failure_message(label + " slot " + s).is_true()
		# Paired items carry one node per slot.
		if gear.slots.size() > 1:
			var inst := gear.scene.instantiate()
			for s in gear.slots:
				assert_object(inst.find_child(String(s), true, false)) \
					.override_failure_message("%s.glb has no %s node" % [label, s]).is_not_null()
			inst.free()


func test_jeff_and_chuck_have_every_slot_on_a_bone() -> void:
	for scene: PackedScene in [JEFF, CHUCK]:
		var k := _kicker(scene)
		for s in JarlingEquipment.SLOTS:
			var m := k.equipment.slot_node(s)
			assert_str(String(m.name)).is_equal("slot_%s" % s)
			assert_bool(m.get_parent() is BoneAttachment3D).is_true()
		var anim := k.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for a in ["idle", "run", "kick", "cheer"]:
			assert_bool(anim.has_animation(a)).override_failure_message("no %s animation" % a).is_true()


func test_swap_on_an_occupied_slot() -> void:
	var k := _kicker(JEFF)
	k.add_upgrade_visual(_card("spring_shoes"))
	assert_str(String(k.equipment.equipped(&"foot_l").id)).is_equal("spring_shoes")
	assert_bool(k.equipment.is_part_hidden(&"foot_l")).is_true()
	var first := k.worn_piece("feet")
	assert_object(first).is_not_null()
	k.add_upgrade_visual(_card("rocket_boots"))
	assert_str(String(k.equipment.equipped(&"foot_l").id)).is_equal("rocket_boots")
	assert_str(String(k.equipment.equipped(&"foot_r").id)).is_equal("rocket_boots")
	assert_bool(k.equipment.has_item(&"spring_shoes")).is_false()
	assert_object(k.worn_piece("feet")).is_not_same(first)
	assert_int(_pieces(k)).is_equal(2)   # one boot per foot
	# One card slot is one item: a one-foot item takes both shoes off, and the bare foot comes back.
	k.add_upgrade_visual(_card("giant_foot"))
	assert_bool(k.equipment.has_item(&"rocket_boots")).is_false()
	assert_int(_pieces(k)).is_equal(Kicker.gear_for(_card("giant_foot")).slots.size())


func test_repeat_levels_up_and_never_stacks() -> void:
	var k := _kicker(CHUCK)
	var cape := _card("super_cape")
	k.add_upgrade_visual(cape)
	assert_int(k.equipment.level(&"back")).is_equal(1)
	k.add_upgrade_visual(cape)
	assert_int(k.equipment.level(&"back")).is_equal(2)
	for i in 5:
		k.add_upgrade_visual(cape)
	assert_int(k.equipment.level(&"back")).is_equal(3)   # capped
	assert_int(_pieces(k)).is_equal(1)
	assert_float(k.worn_piece("back").scale.x).is_greater(1.0)


func test_full_outfit_is_one_item_per_slot_then_clears() -> void:
	for scene: PackedScene in [JEFF, CHUCK]:
		var k := _kicker(scene)
		for u in _wearables():
			k.add_upgrade_visual(u)
		for s in JarlingEquipment.SLOTS:
			var n := 0
			for c in k.equipment.slot_node(s).get_children():
				if String(c.name).begins_with("gear_") and not c.is_queued_for_deletion():
					n += 1
			assert_int(n).override_failure_message("%d items on %s" % [n, s]).is_less_equal(1)
		for card_slot in ["head", "face", "back", "hands", "waist", "knees", "feet"]:
			assert_object(k.worn_piece(card_slot)).override_failure_message("nothing worn on " + card_slot).is_not_null()
		k.clear_upgrade_visuals()
		assert_int(_pieces(k)).is_equal(0)
		assert_bool(k.equipment.is_part_hidden(&"foot_r")).is_false()


func test_greybox_kicker_wears_gear_too() -> void:
	var k := _kicker(preload("res://scenes/players/kicker.tscn"))
	k.add_upgrade_visual(_card("jetpack"))
	assert_str(String(k.equipment.equipped(&"back").id)).is_equal("jetpack")
	assert_str(String(k.equipment.slot_node(&"back").name)).is_equal("slot_back")
