extends Node


var frame := 0
var player: Node = null
var visual: Node = null
var sprite: AnimatedSprite2D = null
var failures: Array[String] = []
var _landed := false
var _land_frame := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		failures.append(label)
		print("FAIL: ", label)


func press_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func release_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)


func _process(_delta: float) -> void:
	frame += 1
	if frame == 5:
		player = get_tree().get_first_node_in_group("player")
		check(player != null, "player exists")
		visual = player.get_node("Visual") if player else null
		sprite = visual.get_node("HeroSprite") if visual else null
		check(sprite != null, "AnimatedSprite2D built")
	if frame == 6 and sprite:
		var sf: SpriteFrames = sprite.sprite_frames
		var want := {"idle": 8, "run": 8, "jump": 2, "fall": 2,
			"attack1": 6, "attack2": 6, "hurt": 4, "death": 6}
		for a in want:
			check(sf.has_animation(a), "anim exists: " + a)
			if sf.has_animation(a):
				check(sf.get_frame_count(a) == want[a],
					"frame count %s == %d" % [a, want[a]])

	if player and not _landed and player.is_on_floor():
		_landed = true
		_land_frame = frame
	if _landed and frame == _land_frame + 5 and sprite:
		check(sprite.animation == "idle", "idle on ground after landing, got " + sprite.animation)
	if _landed and frame == _land_frame + 6 and player:
		press_action("move_right")
	if _landed and frame == _land_frame + 25 and sprite:
		check(absf(player.velocity.x) > 20.0, "actually moving right")
		check(sprite.animation == "run", "running plays run anim, got " + sprite.animation)
		check(visual.scale.x > 0.0, "facing right keeps +x scale")
	if _landed and frame == _land_frame + 26 and player:
		release_action("move_right")
		press_action("move_left")
	if _landed and frame == _land_frame + 32 and sprite:

		check(player.get("facing") < 0.0, "facing flips left")
	if _landed and frame == _land_frame + 55 and player:
		check(visual.scale.x < 0.0, "facing left flips visual -x, got " + str(visual.scale.x))
		release_action("move_left")

		press_action("move_right")
	if _landed and frame == _land_frame + 80 and player:
		release_action("move_right")
	if _landed and frame == _land_frame + 85 and player:
		press_action("jump")
	if _landed and frame == _land_frame + 87 and player:
		release_action("jump")
	if _landed and frame == _land_frame + 95 and sprite:
		check(sprite.animation in ["jump", "fall"],
			"airborne plays jump/fall, got " + sprite.animation)
	if _landed and frame == _land_frame + 180 and sprite:
		check(player.is_on_floor(), "landed from test jump")
		check(sprite.animation == "idle", "landed back to idle, got " + sprite.animation)
		press_action("attack")
	if _landed and frame == _land_frame + 182 and player:
		release_action("attack")
	if _landed and frame == _land_frame + 188 and sprite:
		check(sprite.animation in ["attack1", "attack2"],
			"attack plays slash anim, got " + sprite.animation)
	if _landed and frame == _land_frame + 210 and player:
		player.take_damage(1, player.global_position + Vector2(50, 0))
	if _landed and frame == _land_frame + 215 and sprite:
		check(sprite.animation == "hurt", "take_damage plays hurt, got " + sprite.animation)
	if _landed and frame == _land_frame + 260 and player:
		check(int(player.get("hp")) == 4, "damage applied (hp=4)")
		player.kill()
	if _landed and frame == _land_frame + 270 and sprite:
		check(sprite.animation == "death", "kill plays death, got " + sprite.animation)
	if _landed and frame == _land_frame + 300:
		if failures.is_empty():
			print("ALL TESTS PASSED")
		else:
			print("FAILURES: %d -> %s" % [failures.size(), str(failures)])
		get_tree().quit()
