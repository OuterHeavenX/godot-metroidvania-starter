extends Node

## The Warden: guard, pound-to-break, phase change, and the goal it holds shut.

var player: Node = null
var boss: Node = null
var goal: Node = null
var failures: Array[String] = []
var t := 0
var phase := 0
var saw_defeat := false
var hp_after_guarded := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures.append(label)
		print("  FAIL ", label)


func _physics_process(_delta: float) -> void:
	t += 1
	if t < 6:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		boss = get_tree().get_first_node_in_group("boss")
		goal = get_tree().get_first_node_in_group("goal")
		check(player != null and boss != null and goal != null,
			"player, Warden and goal all present")
		if player == null or boss == null or goal == null:
			_finish()
			return
		boss.connect("defeated", func () -> void: saw_defeat = true)
		check(bool(goal.get("locked")), "goal starts locked")
		check(int(boss.get("hp")) == boss.MAX_HP, "Warden at full health (%d)" % int(boss.get("hp")))
		check(bool(boss.get("guarded")), "Warden starts guarded")
		# Keep the player clear so the Warden's own AI does not interfere.
		player.global_position = Vector2(5900, -20)
		return

	match phase:
		0:
			# Blades ring off the guard.
			boss.call("take_hit", player.global_position)
			boss.call("take_hit", player.global_position)
			hp_after_guarded = int(boss.get("hp"))
			check(hp_after_guarded == boss.MAX_HP,
				"attacks do nothing while guarded (hp=%d)" % hp_after_guarded)
			phase = 1
			t = 0
		1:
			# A pound breaks it open.
			boss.call("squash")
			check(not bool(boss.get("guarded")), "pound breaks the guard")
			check(not bool(boss.get("dead")), "pound does not kill it outright")
			phase = 2
			t = 0
		2:
			if t > 2:
				for i in range(5):
					boss.call("take_hit", player.global_position)
				check(int(boss.get("hp")) == boss.MAX_HP - 5,
					"unguarded hits land (hp=%d)" % int(boss.get("hp")))
				check(int(boss.get("phase")) == 2,
					"dropped into phase two at half health")
				phase = 3
				t = 0
		3:
			if t > 2:
				for i in range(5):
					boss.call("take_hit", player.global_position)
				check(saw_defeat, "defeated signal fired")
				check(bool(boss.get("dead")), "Warden is down")
				phase = 4
				t = 0
		4:
			if t > 4:
				check(not bool(goal.get("locked")), "the goal unlocked when it fell")
				player.global_position = (goal as Node2D).global_position
				phase = 5
				t = 0
		5:
			if t > 10:
				var hud := get_tree().get_first_node_in_group("hud")
				check(hud != null and bool(hud.get("won")), "reaching the unlocked goal wins")
				_finish()


func _finish() -> void:
	if failures.is_empty():
		print("BOSS TESTS ALL PASSED")
	else:
		print("BOSS TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
