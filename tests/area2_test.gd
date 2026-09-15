extends Node

## The second area: that it builds, that the new enemy kinds behave, and that
## its own traversal works. The hand-off from area one is covered by
## transition_test.

var player: Node = null
var failures: Array[String] = []
var t := 0
var phase := 0
var shielder: Node = null
var charger: Node = null


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
		check(player != null, "player exists")
		if player == null:
			_finish()
			return
		var kinds: Array[String] = []
		for e in get_tree().get_nodes_in_group("enemy"):
			kinds.append(String(e.get("kind")))
			if e.get("kind") == "shielder" and shielder == null:
				shielder = e
			if e.get("kind") == "charger" and charger == null:
				charger = e
		check(shielder != null, "a shielder is in the area")
		check(charger != null, "a charger is in the area")
		check(get_tree().get_nodes_in_group("heart").size() == 2, "two hearts placed")
		check(get_tree().get_nodes_in_group("cracked").size() == 1, "one cracked span")
		# The area is the last one, so its goal ends the run.
		var goal := get_tree().get_first_node_in_group("goal")
		check(goal != null and not bool(goal.get("locked")), "goal is open (no boss here)")
		if shielder == null or charger == null:
			_finish()
			return
		return

	match phase:
		0:
			# Sprites for the reused sheets actually resolved.
			var sv = shielder.get_node("Visual")
			var sf: SpriteFrames = sv.sprite.sprite_frames
			check(sf.has_animation("protect"), "shielder has a protect animation")
			check(sf.get_frame_count("protect") == 2, "protect is 2 frames")
			var cv = charger.get_node("Visual")
			var cf: SpriteFrames = cv.sprite.sprite_frames
			check(cf.has_animation("runattack"), "charger has a run-attack animation")
			check(cf.get_frame_count("run") == 8, "charger run is 8 frames")
			phase = 1
			t = 0
		1:
			# Frontal blows ring off the shield; from behind they land.
			var d: float = float(shielder.get("dir"))
			var hp0 := int(shielder.get("hp"))
			shielder.call("take_hit", (shielder as Node2D).global_position + Vector2(d * 60.0, 0))
			check(int(shielder.get("hp")) == hp0, "shield turns a frontal blow")
			shielder.call("take_hit", (shielder as Node2D).global_position + Vector2(-d * 60.0, 0))
			check(int(shielder.get("hp")) == hp0 - 1, "a blow from behind lands")
			phase = 2
			t = 0
		2:
			# And a pound goes straight through the guard.
			var hp1 := int(shielder.get("hp"))
			shielder.call("squash")
			check(bool(shielder.get("dead")), "pound ignores the shield (hp was %d)" % hp1)
			phase = 3
			t = 0
		3:
			# Charger: stand in range and it should wind up, then commit.
			var cpos: Vector2 = (charger as Node2D).global_position
			player.global_position = cpos + Vector2(200, 0)
			phase = 4
			t = 0
		4:
			if String(charger.get("state")) in ["windup", "charge", "recover"]:
				check(true, "charger committed (state=%s)" % String(charger.get("state")))
				phase = 5
				t = 0
			elif t > 240:
				check(false, "charger never committed (state=%s)" % String(charger.get("state")))
				phase = 5
				t = 0
		5:
			if String(charger.get("state")) == "recover":
				check(true, "charge ends in a recovery window")
				_finish()
			elif t > 300:
				check(false, "charger never reached recovery (state=%s)"
					% String(charger.get("state")))
				_finish()


func _finish() -> void:
	if failures.is_empty():
		print("AREA2 TESTS ALL PASSED")
	else:
		print("AREA2 TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
