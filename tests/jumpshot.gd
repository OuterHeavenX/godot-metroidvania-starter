extends Node

## Two frames at the same x, one on the ground and one high above it. With the
## parallax locked vertically the backdrop and the terrain must shift by the
## same number of pixels between them; a layer that scrolls slower than the
## world stays put instead, and that is the backdrop riding up with the jump.

const X := 1200.0

var player: Node = null
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
	img.save_png("%s/jump_%d_%s.png" % [out_dir, shot, label])
	print("SHOT ", label)
	shot += 1


func _process(_delta: float) -> void:
	t += 1
	if t < 10:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			get_tree().quit(1)
			return
	match t:
		20:
			player.global_position = Vector2(X, -120)
		80:
			await _capture("ground")
		90:
			# Straight up, no horizontal movement: only the vertical axis changes.
			# Physics off, or it falls back to the ground before the camera has
			# settled and the two frames come out identical.
			player.global_position = Vector2(X, -420)
			player.set("velocity", Vector2.ZERO)
			player.set_physics_process(false)
		150:
			await _capture("high")
		160:
			get_tree().quit(0)
