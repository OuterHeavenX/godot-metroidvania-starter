extends Node


var frame := 0
var player: Node = null
var victim: Node = null
var failures: Array[String] = []
var _pound_armed := false
var _pound_ok := false
var _crush_armed := false
var _crush_ok := false
var _ground_armed := false
var _chamber_ok := false


func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		failures.append(label)
		print("FAIL: ", label)


func press_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func release_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)


func drop(pos: Vector2) -> void:
	player.global_position = pos
	player.set("velocity", Vector2.ZERO)


func live_foe() -> Node:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not bool(e.get("dead")):
			return e
	return null


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 5:
		player = get_tree().get_nodes_in_group("player")[0]
		check(player != null, "player found")
		check(not bool(player.get("has_ground_pound")), "pound locked before orb")
		check(get_tree().get_nodes_in_group("cracked").size() == 1,
			"one cracked slab in the level")
		drop(Vector2(3180, -200))
		press_action("pound")
	if frame == 8:
		check(not bool(player.call("is_pounding")), "no pound without the ability")
		release_action("pound")
		player.call("gain_ability", "ground_pound")
		check(bool(player.get("has_ground_pound")), "pound unlocked via orb")
		drop(Vector2(3180, -200))
		press_action("pound")
		_pound_armed = true
	if _pound_armed and bool(player.call("is_pounding")):
		_pound_armed = false
		_pound_ok = true
		release_action("pound")
	if frame == 24:
		check(_pound_ok, "pound starts midair")
	if frame == 40:
		check(get_tree().get_nodes_in_group("cracked").size() == 0,
			"slab smashed by the pound")
	if player.global_position.y > 200.0:
		_chamber_ok = true
	if frame == 95:
		check(_chamber_ok,
			"player fell into the chamber (y=%.0f)" % player.global_position.y)
		check(not bool(player.call("is_pounding")), "pound state cleared after impact")

		victim = live_foe()
		check(victim != null, "a live foe exists for the crush test")
		victim.global_position = Vector2(520, -60)
		victim.set("velocity", Vector2.ZERO)
		victim.set("knock_v", 0.0)
		drop(Vector2(500, -200))
		press_action("pound")
		_crush_armed = true
	if _crush_armed and is_instance_valid(victim) and bool(victim.get("dead")):
		_crush_armed = false
		_crush_ok = true
		release_action("pound")
	if frame == 140:
		check(_crush_ok, "pound shockwave crushed the foe")
		check(not bool(player.get("dead")), "player survived its own pound")

		drop(Vector2(200, -30))
		_ground_armed = true
	if _ground_armed and player.is_on_floor():
		_ground_armed = false
		press_action("pound")
	if frame == 160:
		release_action("pound")
		check(not bool(player.call("is_pounding")), "no pound while grounded")
	if frame == 166:
		if failures.is_empty():
			print("ALL TESTS PASSED")
		else:
			print("FAILURES: %d -> %s" % [failures.size(), str(failures)])
		get_tree().quit()
