extends Node

## Captures the boss fight at the moments that matter: guard up, a blow ringing
## off it, and the guard broken. The point is to check the fight is legible,
## which no headless assertion can tell us.

var player: Node = null
var boss: Node = null
var t := 0
var shot := 0
var out_dir := "res://tools/shots"


func _ready() -> void:
	var d := OS.get_environment("SHOT_DIR")
	if d != "":
		out_dir = d


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/boss_%d_%s.png" % [out_dir, shot, label])
	print("SHOT ", label)
	shot += 1


func _process(_delta: float) -> void:
	t += 1
	if t < 10:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		boss = get_tree().get_first_node_in_group("boss")
		if player == null or boss == null:
			get_tree().quit(1)
			return
		player.call("gain_ability", "double_jump")
		player.call("gain_ability", "ground_pound")
		player.global_position = Vector2(6180, -20)
		return
	if not is_instance_valid(boss):
		get_tree().quit(0)
		return

	match t:
		60:
			await _capture("guard_up")
		68:
			# A real swing, so the slash arc is in the shot and can be checked
			# against the hitbox it is supposed to represent.
			player.set("facing", 1.0)
			player.call("_do_attack")
		69:
			await _capture("swing")
		74:
			await _capture("blocked")
		110:
			boss.call("squash")
		116:
			await _capture("guard_broken")
		150:
			boss.call("take_hit", player.global_position)
			boss.call("take_hit", player.global_position)
			boss.call("take_hit", player.global_position)
		156:
			await _capture("damaged")
		200:
			get_tree().quit(0)
