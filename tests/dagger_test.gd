extends Node

## The thrown dagger, exercised through the input it is bound to rather than by
## calling the throw directly -- the ability is gated, cooldown-limited and
## direction-filtered, and each of those is a way it can silently not work.

const LevelScene := preload("res://tests/fixtures/warden_arena.tscn")

var failures: Array[String] = []
var level: Node = null
var player: Node = null
var boss: Node = null
var t := 0
var phase := 0
var hp_at_throw := 0
var held := {}


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures.append(label)
		print("  FAIL ", label)


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


func _ready() -> void:
	level = LevelScene.instantiate()
	add_child(level)


func _daggers() -> int:
	return get_tree().get_nodes_in_group("dagger").size()


func _physics_process(_delta: float) -> void:
	t += 1
	if t < 6:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		boss = get_tree().get_first_node_in_group("boss")
		if player == null or boss == null:
			check(false, "player and target present")
			_finish()
			return
		# Physics stays on: the throw is read in the player's _physics_process,
		# so freezing it means the input is never seen and every throw silently
		# does nothing.
		return

	match phase:
		0:
			check(not bool(player.get("has_dagger")), "starts without the ability")
			tap("throw")
			phase = 1
			t = 0
		1:
			if t < 4:
				return
			check(_daggers() == 0, "throwing does nothing until the orb is found")
			hold("throw", false)
			player.call("gain_ability", "dagger")
			check(bool(player.get("has_dagger")), "the orb grants it")
			phase = 2
			t = 0
		2:
			if t < 2:
				return
			# Stand well outside sword reach so a hit can only be the dagger.
			var bpos: Vector2 = (boss as Node2D).global_position
			player.set("facing", 1.0)
			(player as Node2D).global_position = bpos - Vector2(300.0, 0.0)
			player.set("velocity", Vector2.ZERO)
			hp_at_throw = int(boss.get("hp"))
			boss.set("guarded", false)
			tap("throw")
			phase = 3
			t = 0
		3:
			if t < 3:
				return
			check(_daggers() == 1, "a dagger is in the air")
			hold("throw", false)
			tap("throw")
			phase = 4
			t = 0
		4:
			if t < 3:
				return
			check(_daggers() == 1, "the cooldown stops a second throw straight away")
			hold("throw", false)
			phase = 5
			t = 0
		5:
			# 300px at 620px/s is about half a second of travel.
			if t < 45:
				return
			check(int(boss.get("hp")) == hp_at_throw - 1,
				"it crossed 300px and took a point off (%d -> %d)"
				% [hp_at_throw, int(boss.get("hp"))])
			check(_daggers() == 0, "it is spent on impact, not left flying")
			phase = 6
			t = 0
		6:
			if t < 40:
				return
			# Cooldown is 0.55s; by now it is clear.
			check(float(player.get("throw_cd")) <= 0.0, "the cooldown clears")
			tap("throw")
			phase = 7
			t = 0
		7:
			if t < 3:
				return
			check(_daggers() == 1, "and it can be thrown again")
			hold("throw", false)
			_finish()


func _finish() -> void:
	if failures.is_empty():
		print("DAGGER TESTS ALL PASSED")
	else:
		print("DAGGER TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
