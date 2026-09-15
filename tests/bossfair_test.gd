extends Node

## The same fight, but the bot may only press keys.
##
## bossfight_test proves the Warden CAN be beaten; it teleports the player to
## whatever spot the next move needs, so it proves nothing about whether the
## fight is reachable through the controls a player actually has. This one
## moves, jumps and pounds like a person: if a plain heuristic can win with
## health to spare, the fight is fair.

const MAX_FRAMES := 5400          # 90s at 60Hz

var player: Node = null
var boss: Node = null
var failures: Array[String] = []
var t := 0
var started := false
var hp_low := 99
var breaks := 0
var was_guarded := true
var pounds_thrown := 0
var pounds_landed := 0
var held := {}


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures.append(label)
		print("  FAIL ", label)


## Edge-triggered, so "just_pressed" actions fire once rather than every frame.
func hold(action: String, down: bool) -> void:
	if bool(held.get(action, false)) == down:
		return
	held[action] = down
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = down
	Input.parse_input_event(ev)


func tap(action: String) -> void:
	hold(action, false)
	hold(action, true)


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
		# Dropped at the arena mouth, as a player arrives. Nothing after this
		# line moves the player except a key press.
		player.global_position = Vector2(5860, -20)
		return

	if not is_instance_valid(boss) or bool(boss.get("dead")):
		check(true, "beaten with keys alone in %.1fs" % (t / 60.0))
		check(int(player.get("hp")) > 0,
			"survived on %d hp (lowest %d)" % [int(player.get("hp")), hp_low])
		check(breaks >= 2, "broke the guard %d time(s), both phases" % breaks)
		check(pounds_landed >= 2,
			"%d of %d pounds landed on it" % [pounds_landed, pounds_thrown])
		_finish()
		return

	hp_low = mini(hp_low, int(player.get("hp")))
	if bool(player.get("dead")):
		check(false, "died at %.1fs with the Warden on %d hp"
			% [t / 60.0, int(boss.get("hp"))])
		_finish()
		return

	var guarded: bool = bool(boss.get("guarded"))
	if was_guarded and not guarded:
		breaks += 1
		pounds_landed += 1
	was_guarded = guarded

	if guarded:
		_break_guard()
	else:
		_trade()

	if t > MAX_FRAMES:
		check(false, "ran out of time: Warden still on %d hp after %.0fs"
			% [int(boss.get("hp")), MAX_FRAMES / 60.0])
		_finish()


## Get over its head and come down on it. Chasing it does not work: you burn
## both jumps closing the gap and arrive with no height left, so the bot stands
## its ground, lets the Warden walk into range, and goes up over it.
func _break_guard() -> void:
	hold("attack", false)
	var me: Vector2 = (player as Node2D).global_position
	var it: Vector2 = (boss as Node2D).global_position
	var dx: float = it.x - me.x
	var vy: float = float(player.get("velocity").y)
	var on_floor: bool = bool(player.call("is_on_floor"))

	if bool(player.get("pounding")):
		hold("move_left", false)
		hold("move_right", false)
		return

	if on_floor:
		hold("pound", false)
		if absf(dx) > 210.0:
			# Too far for it to bother closing; walk in.
			hold("move_right", dx > 0.0)
			hold("move_left", dx < 0.0)
			return
		hold("move_right", false)
		hold("move_left", false)
		if absf(dx) < 95.0:
			tap("jump")
		return

	# Airborne. Drift over it, then come down on it at the top of the arc.
	hold("move_right", dx > 20.0)
	hold("move_left", dx < -20.0)
	if absf(dx) < 80.0 and me.y < it.y - 90.0 and vy > -140.0:
		tap("pound")
		pounds_thrown += 1


## Guard is down. Trade hits, but do not stand in the swing.
func _trade() -> void:
	hold("pound", false)
	var me: Vector2 = (player as Node2D).global_position
	var it: Vector2 = (boss as Node2D).global_position
	var dx: float = it.x - me.x
	var swinging: bool = String(boss.get("state")) == "attack"
	# The player outreaches the Warden, so there is a band where you can hit it
	# and it cannot hit you. Back out while it commits.
	var reach: float = float(player.get("ATTACK_RANGE"))
	var want: float = reach + 66.0 if swinging else reach - 12.0
	var err: float = absf(dx) - want
	var toward: float = 1.0 if dx > 0.0 else -1.0

	if absf(err) > 8.0:
		# err > 0 means too far, so move toward it; too close, move away.
		var go: float = toward if err > 0.0 else -toward
		hold("move_right", go > 0.0)
		hold("move_left", go < 0.0)
		hold("attack", false)
		return

	# In position. Attacks are direction-filtered, so face it before swinging --
	# a player does this by holding toward the enemy.
	if float(player.get("facing")) != toward:
		hold("move_right", toward > 0.0)
		hold("move_left", toward < 0.0)
		return
	hold("move_right", false)
	hold("move_left", false)
	if not swinging and float(player.get("attack_cd")) <= 0.0:
		tap("attack")
	else:
		hold("attack", false)


func _finish() -> void:
	if failures.is_empty():
		print("BOSSFAIR TESTS ALL PASSED")
	else:
		print("BOSSFAIR TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
