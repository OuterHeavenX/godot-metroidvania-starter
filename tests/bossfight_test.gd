extends Node

## Plays the fight instead of calling methods on it: real attack cooldowns,
## real pound, the Warden's own AI running and hitting back. The point is to
## prove the fight can actually be won, which the unit-level boss_test could
## not tell us -- it drove take_hit() directly and ignored every constraint.

const MAX_FRAMES := 2400          # 40s at 60Hz

var player: Node = null
var boss: Node = null
var failures: Array[String] = []
var t := 0
var started := false
var pounding_until := 0
var hp_low := 99
var breaks := 0
var was_guarded := true


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


func _physics_process(_delta: float) -> void:
	t += 1
	if t < 6:
		return
	if not started:
		started = true
		player = get_tree().get_first_node_in_group("player")
		boss = get_tree().get_first_node_in_group("boss")
		check(player != null and boss != null, "player and Warden in the arena")
		if player == null or boss == null:
			_finish()
			return
		player.call("gain_ability", "double_jump")
		player.call("gain_ability", "ground_pound")
		player.global_position = Vector2(6100, 0)
		return

	if not is_instance_valid(boss) or bool(boss.get("dead")):
		check(true, "the Warden was beaten in %.1fs" % (t / 60.0))
		check(int(player.get("hp")) > 0,
			"the player survived it (hp %d, lowest %d)" % [int(player.get("hp")), hp_low])
		check(breaks >= 1, "the guard was broken %d time(s)" % breaks)
		_finish()
		return

	hp_low = mini(hp_low, int(player.get("hp")))
	if bool(player.get("dead")):
		check(false, "the player died at %.1fs with the Warden on %d hp"
			% [t / 60.0, int(boss.get("hp"))])
		_finish()
		return

	var guarded: bool = bool(boss.get("guarded"))
	if was_guarded and not guarded:
		breaks += 1
	was_guarded = guarded

	var bpos: Vector2 = (boss as Node2D).global_position

	if guarded:
		act("move_right", false)
		act("move_left", false)
		# Break the guard: get above it and pound. Positioning stands in for
		# the player's platforming; the pound itself is the real mechanic.
		act("attack", false)
		if t > pounding_until:
			player.global_position = bpos + Vector2(0, -190)
			player.set("velocity", Vector2.ZERO)
			pounding_until = t + 90
			act("pound", false)
		elif t == pounding_until - 84:
			act("pound", true)
		elif t == pounding_until - 70:
			act("pound", false)
	else:
		# Open. A competent player does not stand in the swing: the Warden
		# telegraphs for ~0.25s before it strikes, so back out of its 84px
		# reach while it commits, and close again to trade.
		act("pound", false)
		var side: float = -1.0 if player.global_position.x < bpos.x else 1.0
		# Face the Warden. Attacks are direction-filtered, and without pressing
		# a movement key the player's `facing` never updates -- so every swing
		# from its left side silently whiffed.
		act("move_right", side < 0.0)
		act("move_left", side > 0.0)
		var swinging: bool = String(boss.get("state")) == "attack"
		var stand: float = 150.0 if swinging else 70.0
		player.global_position = Vector2(bpos.x + side * stand, bpos.y - 22.0)
		if not swinging and float(player.get("attack_cd")) <= 0.0:
			act("attack", true)
		else:
			act("attack", false)

	if t > MAX_FRAMES:
		check(false, "ran out of time: Warden still on %d hp after %.0fs"
			% [int(boss.get("hp")), MAX_FRAMES / 60.0])
		_finish()


func _finish() -> void:
	if failures.is_empty():
		print("BOSSFIGHT TESTS ALL PASSED")
	else:
		print("BOSSFIGHT TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
