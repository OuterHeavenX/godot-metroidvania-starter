extends Node

## Drives the player through every jump in the Undercroft against real
## collision, so the new geometry is proven traversable rather than merely
## arithmetically plausible.
##
## Jump is held until the player starts falling: releasing early trips the
## variable-height jump cut and would not reproduce the intended arc.

# label, stand-at, press-jump-at-x, landing x range, landing platform top
const HOPS: Array = [
	["corridor -> chimney hall", Vector2(3460, 298), 3690.0, 3900.0, 4560.0, 320.0],
	["chimney top -> archer ledge", Vector2(4435, -62), 4482.0, 4620.0, 4840.0, -100.0],
	["archer ledge -> ledge 1", Vector2(4650, -122), 4832.0, 4980.0, 5110.0, -220.0],
	["ledge 1 -> ledge 2", Vector2(4995, -242), 5102.0, 5240.0, 5370.0, -340.0],
	["ledge 2 -> ledge 3", Vector2(5255, -362), 5362.0, 5500.0, 5630.0, -460.0],
]

var player: Node = null
var failures: Array[String] = []
var hop := -1
var phase := 0
var t := 0
var doorway_x := 0.0
var slab: Node = null
var slab_found := false
var climb_dir := 1.0
var climb_cd := 0
var climb_best := 0.0
var wall_jumps := 0
var walk_best := 0.0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures.append(label)
		print("  FAIL ", label)


func act(action: String, down: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = down
	Input.parse_input_event(ev)


func place(pos: Vector2) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO


func _physics_process(_delta: float) -> void:
	t += 1
	if player == null:
		if t < 4:
			return
		player = get_tree().get_first_node_in_group("player")
		check(player != null, "player exists")
		if player == null:
			_finish()
			return
		player.call("gain_ability", "double_jump")
		player.call("gain_ability", "ground_pound")
		# Walk east out of the vault-drop basement through the new doorway.
		place(Vector2(3180, 298))
		act("move_right", true)
		phase = 100
		t = 0
		return

	if phase == 100:
		doorway_x = maxf(doorway_x, player.global_position.x)
		if t > 130:
			act("move_right", false)
			check(doorway_x > 3480.0,
				"walked through the basement doorway (reached x=%.0f)" % doorway_x)
			# Walk the route rather than teleporting into the shaft: a
			# full-height pillar here would wall the chimney off, and hopping
			# between teleported waypoints would not notice.
			place(Vector2(3990, 298))
			act("move_right", true)
			phase = 150
			t = 0
		return

	if phase == 150:
		if player.is_on_floor():
			walk_best = maxf(walk_best, player.global_position.x)
		if t > 200:
			check(walk_best > 4260.0,
				"walked from the landing into the chimney shaft (reached x=%.0f)" % walk_best)
			place(Vector2(4300, 298))
			climb_best = 298.0
			climb_dir = 1.0
			act("move_right", true)
			phase = 200
			t = 0
		return

	if phase == 200:
		climb_cd -= 1
		climb_best = minf(climb_best, player.global_position.y)
		if player.is_on_floor() and climb_cd <= 0:
			act("jump", false)
			act("jump", true)
			climb_cd = 8
		elif player.call("is_on_wall_only") and climb_cd <= 0:
			act("jump", false)
			act("jump", true)
			wall_jumps += 1
			climb_cd = 10
			climb_dir = -climb_dir
			act("move_right", climb_dir > 0.0)
			act("move_left", climb_dir < 0.0)
		if t > 420 or climb_best <= -62.0:
			act("jump", false)
			act("move_right", false)
			act("move_left", false)
			check(climb_best <= -40.0,
				"wall-jumped up the chimney (reached y=%.0f after %d wall jumps)"
					% [climb_best, wall_jumps])
			hop = 0
			phase = 0
			t = 0
		return

	if hop >= 0 and hop < HOPS.size():
		var h: Array = HOPS[hop]
		if phase == 0:
			place(h[1])
			act("jump", false)
			act("move_right", true)
			phase = 1
			t = 0
		elif phase == 1:
			if player.is_on_floor() and player.global_position.x >= float(h[2]):
				act("jump", true)
				phase = 2
				t = 0
			elif t > 150:
				check(false, "%s: never reached takeoff" % h[0])
				_next_hop()
		elif phase == 2:
			if player.velocity.y > 0.0:
				act("jump", false)      # hold through the rise, release at apex
				phase = 3
				t = 0
			elif t > 90:
				check(false, "%s: never left the ground" % h[0])
				_next_hop()
		elif phase == 3:
			if player.is_on_floor():
				var p: Vector2 = player.global_position
				var want_y: float = float(h[5]) - 22.0
				var ok: bool = p.x >= float(h[3]) and p.x <= float(h[4]) and absf(p.y - want_y) < 16.0
				check(ok, "%s (landed x=%.0f y=%.0f, wanted x in [%.0f,%.0f] y=%.0f)"
					% [h[0], p.x, p.y, h[3], h[4], want_y])
				_next_hop()
			elif t > 220:
				check(false, "%s: fell into the pit (x=%.0f y=%.0f)"
					% [h[0], player.global_position.x, player.global_position.y])
				_next_hop()
		return

	if hop == HOPS.size():
		# Pound the second cracked span and drop into the goal vault.
		if phase == 0:
			for c in get_tree().get_nodes_in_group("cracked"):
				if absf((c as Node2D).global_position.x - 6100.0) < 120.0:
					slab = c
					slab_found = true
			check(slab_found, "cracked span sits above the goal vault")
			act("move_right", false)
			place(Vector2(6100, -620))
			phase = 1
			t = 0
		elif phase == 1:
			# is_on_floor() still reports the pre-teleport frame, and the pound
			# is rejected while grounded, so let the airborne state settle first.
			if t > 8:
				act("pound", true)
				phase = 2
				t = 0
		elif phase == 2:
			if t > 200:
				act("pound", false)
				# A freed Object compares equal to null in Godot 4, so the
				# "was it there" and "is it gone" checks cannot share a test.
				check(slab_found and not is_instance_valid(slab),
					"pounded through the span into the arena")
				var p: Vector2 = player.global_position
				check(p.y > -200.0, "dropped into the arena (x=%.0f y=%.0f)" % [p.x, p.y])
				# The arena is the last stretch of the cemetery now rather than a
				# boss room, so the exit stands in it and is open on arrival.
				var goal := get_tree().get_first_node_in_group("goal")
				check(goal != null and not bool(goal.get("locked")),
					"the way out is open")
				check(goal != null and absf((goal as Node2D).global_position.x - p.x) < 700.0,
					"the exit is in the arena you just dropped into")
				_finish()
		return


func _next_hop() -> void:
	hop += 1
	phase = 0
	t = 0


func _finish() -> void:
	if failures.is_empty():
		print("UNDERCROFT TESTS ALL PASSED")
	else:
		print("UNDERCROFT TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
