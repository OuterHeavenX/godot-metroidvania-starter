extends Node

## Health recovery. Before this the only way to regain hearts was to die, which
## does not hold up over a level this long.

var player: Node = null
var failures: Array[String] = []
var t := 0
var phase := 0
var heart_a: Node = null
var heart_b: Node = null
var checkpoint: Node = null
var hp_before := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures.append(label)
		print("  FAIL ", label)


func nearest(group: String, to: Vector2) -> Node:
	var best: Node = null
	var best_d := 1e20
	for n in get_tree().get_nodes_in_group(group):
		var d: float = (n as Node2D).global_position.distance_to(to)
		if d < best_d:
			best_d = d
			best = n
	return best


func _physics_process(_delta: float) -> void:
	t += 1
	if t < 4:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		check(player != null, "player exists")
		if player == null:
			_finish()
			return
		heart_a = nearest("heart", Vector2(1200, -130))
		heart_b = nearest("heart", Vector2(2600, -360))
		checkpoint = nearest("checkpoint", Vector2(1780, -60))
		check(heart_a != null and heart_b != null, "health pickups exist in the level")
		check(checkpoint != null, "checkpoint exists")
		if heart_a == null or heart_b == null or checkpoint == null:
			_finish()
			return
		return

	match phase:
		0:
			player.call("take_damage", 3, player.global_position + Vector2(60, 0))
			check(int(player.get("hp")) == 2, "took 3 damage (hp=%d)" % int(player.get("hp")))
			phase = 1
			t = 0
		1:
			if t > 6:
				player.global_position = (heart_a as Node2D).global_position
				phase = 2
				t = 0
		2:
			if t > 10:
				check(int(player.get("hp")) == 3,
					"heart healed one point (hp=%d)" % int(player.get("hp")))
				check(not is_instance_valid(heart_a), "heart was consumed")
				phase = 3
				t = 0
		3:
			# A heart should refuse to be spent when there is nothing to heal.
			player.set("hp", 5)
			player.global_position = (heart_b as Node2D).global_position
			phase = 4
			t = 0
		4:
			if t > 12:
				check(is_instance_valid(heart_b), "heart left alone at full health")
				check(int(player.get("hp")) == 5, "still at full health")
				phase = 5
				t = 0
		5:
			player.set("hp", 1)
			hp_before = 1
			player.global_position = (checkpoint as Node2D).global_position
			phase = 6
			t = 0
		6:
			if t > 12:
				check(bool(checkpoint.get("activated")), "checkpoint activated")
				check(int(player.get("hp")) == 5,
					"checkpoint restored health (hp=%d from %d)"
						% [int(player.get("hp")), hp_before])
				_finish()


func _finish() -> void:
	if failures.is_empty():
		print("HEALTH TESTS ALL PASSED")
	else:
		print("HEALTH TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
