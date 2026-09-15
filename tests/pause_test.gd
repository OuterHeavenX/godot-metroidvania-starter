extends Node

## Pause, resume and restart. Restart reloads the current scene, which means
## reloading this test too, so the run counter lives on the SceneTree, which
## survives the reload.

const META := "pause_test_run"

var hud: Node = null
var player: Node = null
var failures: Array[String] = []
var t := 0
var phase := 0
var frozen_at := Vector2.ZERO
var run := 0


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
	if t < 5:
		return
	if hud == null:
		run = int(get_tree().get_meta(META, 0))
		hud = get_tree().get_first_node_in_group("hud")
		player = get_tree().get_first_node_in_group("player")
		check(hud != null and player != null, "hud and player exist (run %d)" % run)
		if hud == null or player == null:
			_finish()
			return
		if run >= 1:
			# We are here because restart() reloaded the scene.
			check(not get_tree().paused, "restarted run is not paused")
			check(int(player.get("hp")) == int(player.get("MAX_HP")),
				"restarted run starts at full health")
			_finish()
			return
		return

	match phase:
		0:
			act("ui_cancel", true)
			phase = 1
			t = 0
		1:
			if t > 3:
				act("ui_cancel", false)
				check(get_tree().paused, "escape paused the run")
				check(bool(hud.get("pause_panel").visible), "pause panel shown")
				frozen_at = player.global_position
				phase = 2
				t = 0
		2:
			if t > 20:
				check(player.global_position == frozen_at, "player is frozen while paused")
				act("ui_cancel", true)
				phase = 3
				t = 0
		3:
			if t > 3:
				act("ui_cancel", false)
				check(not get_tree().paused, "escape resumed the run")
				check(not bool(hud.get("pause_panel").visible), "pause panel hidden")
				phase = 4
				t = 0
		4:
			if t > 4:
				# Damage first so the reload can be told apart from a no-op.
				player.call("take_damage", 2, player.global_position + Vector2(60, 0))
				check(int(player.get("hp")) < int(player.get("MAX_HP")), "took damage before restart")
				get_tree().set_meta(META, 1)
				hud.call("restart")
				phase = 5
				t = 0
		5:
			if t > 120:
				check(false, "restart did not reload the scene")
				_finish()


func _finish() -> void:
	get_tree().set_meta(META, 0)
	if failures.is_empty():
		print("PAUSE TESTS ALL PASSED")
	else:
		print("PAUSE TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
