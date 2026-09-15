extends Node

## Clearing area one should hand you to area two with your abilities intact.
## change_scene_to_file replaces the whole current scene, so before triggering
## it this node reparents itself to the tree root, where it survives.

var player: Node = null
var hud: Node = null
var failures: Array[String] = []
var t := 0
var phase := 0
## The old player is freed by the scene change, and a freed object compares
## equal to null in Godot 4 -- without this the setup block would run again
## after the transition and re-grant the abilities it is meant to be checking.
var inited := false


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
	if not inited:
		inited = true
		SaveMan.clear_progress()
		player = get_tree().get_first_node_in_group("player")
		hud = get_tree().get_first_node_in_group("hud")
		check(player != null and hud != null, "area one built")
		if player == null or hud == null:
			_finish()
			return
		player.call("gain_ability", "double_jump")
		player.call("gain_ability", "ground_pound")
		return

	match phase:
		0:
			var boss := get_tree().get_first_node_in_group("boss")
			check(boss != null, "the Warden is here")
			if boss != null:
				boss.call("die")
			phase = 1
			t = 0
		1:
			if t > 6:
				var goal := get_tree().get_first_node_in_group("goal")
				check(goal != null and not bool(goal.get("locked")), "goal unlocked")
				player.global_position = (goal as Node2D).global_position
				phase = 2
				t = 0
		2:
			if t > 10:
				check(bool(hud.get("won")), "clearing the area ends it")
				check(SaveMan.level_path == "res://src/levels/level_02.tscn",
					"save points at area two, got '%s'" % SaveMan.level_path)
				check(SaveMan.run_time > 0.0, "time banked (%.2fs)" % SaveMan.run_time)
				check(not SaveMan.has_checkpoint,
					"area one's checkpoint does not follow you")
				check(ResourceLoader.exists(SaveMan.level_path), "area two actually exists")
				var again: Button = hud.get_node("Overlay/WinPanel/Panel/VBox/Again")
				check(again.text == "NEXT AREA", "button offers the next area, got '%s'" % again.text)
				# Survive the scene change. reparent() keeps the node in the
				# tree throughout; remove_child first would detach it and make
				# get_tree() null on the very next line.
				reparent(get_tree().root)
				hud.call("_on_again")
				phase = 3
				t = 0
		3:
			if t > 20:
				var cur := get_tree().current_scene
				var path := cur.scene_file_path if cur != null else ""
				check(path == "res://src/levels/level_02.tscn",
					"arrived in area two, got '%s'" % path)
				var p2 := get_tree().get_first_node_in_group("player")
				check(p2 != null, "area two has a player")
				if p2 != null:
					check(bool(p2.get("has_double_jump")), "double jump carried over")
					check(bool(p2.get("has_ground_pound")), "ground pound carried over")
				check(not get_tree().paused, "the new area is not paused")
				SaveMan.clear_progress()
				_finish()


func _finish() -> void:
	if failures.is_empty():
		print("TRANSITION TESTS ALL PASSED")
	else:
		print("TRANSITION TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
