extends Node

## Progress persistence. Restoring happens across a scene reload, so the run
## counter lives on the SceneTree, which survives it.

const META := "save_test_run"

var player: Node = null
var failures: Array[String] = []
var t := 0
var phase := 0
var run := 0
var saved_point := Vector2.ZERO


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures.append(label)
		print("  FAIL ", label)


func _physics_process(_delta: float) -> void:
	t += 1
	if t < 5:
		return
	if player == null:
		run = int(get_tree().get_meta(META, 0))
		player = get_tree().get_first_node_in_group("player")
		check(player != null, "player exists (run %d)" % run)
		if player == null:
			_finish()
			return
		if run == 0:
			SaveMan.clear_progress()
			check(not bool(player.get("has_double_jump")),
				"a level opened directly ignores the save file")
		else:
			check(bool(player.get("has_double_jump")), "ability restored on continue")
			check(bool(player.get("has_ground_pound")), "second ability restored")
			saved_point = SaveMan.checkpoint
			check(player.global_position.distance_to(saved_point) < 4.0,
				"resumed at the saved checkpoint (%s vs %s)"
					% [str(player.global_position.round()), str(saved_point.round())])
			SaveMan.clear_progress()
			_finish()
		return

	match phase:
		0:
			player.call("gain_ability", "double_jump")
			player.call("gain_ability", "ground_pound")
			phase = 1
			t = 0
		1:
			if t > 3:
				check("double_jump" in SaveMan.abilities, "ability written to the save")
				check("ground_pound" in SaveMan.abilities, "second ability written")
				# Walk onto a checkpoint so the real signal path is exercised.
				var cp := get_tree().get_first_node_in_group("checkpoint")
				check(cp != null, "a checkpoint exists to touch")
				if cp == null:
					_finish()
					return
				player.global_position = (cp as Node2D).global_position
				phase = 2
				t = 0
		2:
			if t > 10:
				check(SaveMan.has_checkpoint, "checkpoint written to the save")
				saved_point = SaveMan.checkpoint
				get_tree().set_meta(META, 1)
				SaveMan.resume_requested = true
				get_tree().reload_current_scene()
				phase = 3
				t = 0
		3:
			if t > 120:
				check(false, "scene did not reload")
				_finish()


func _finish() -> void:
	get_tree().set_meta(META, 0)
	SaveMan.resume_requested = false
	if failures.is_empty():
		print("SAVE TESTS ALL PASSED")
	else:
		print("SAVE TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
