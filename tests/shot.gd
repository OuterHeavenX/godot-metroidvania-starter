extends Node

## Screenshot rig: parks the player at a series of x positions and saves a PNG
## of each, so the art can actually be looked at instead of guessed about.

const SETTLE := 45

var shots: Array = []
var i := 0
var t := 0
var settle := 0
var player: Node = null
var out_dir := "res://tools/shots"


func _ready() -> void:
	var raw := OS.get_environment("SHOT_POINTS")
	if raw == "":
		raw = "300,1800,3500"
	for part in raw.split(","):
		shots.append(float(part))
	var d := OS.get_environment("SHOT_DIR")
	if d != "":
		out_dir = d


func _process(_delta: float) -> void:
	t += 1
	if t < 12:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			get_tree().quit(1)
			return
	if i >= shots.size():
		get_tree().quit(0)
		return
	# Park first, then wait. The camera uses position smoothing, so capturing on
	# the same frame as the teleport photographs wherever the camera still was
	# -- every shot came out one position behind.
	if settle == 0:
		player.global_position = Vector2(float(shots[i]), player.global_position.y)
		player.set("velocity", Vector2.ZERO)
		settle = SETTLE
		return
	settle -= 1
	if settle > 0:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var name := "%s/%s_%04d.png" % [out_dir, OS.get_environment("SHOT_NAME"), int(shots[i])]
	img.save_png(name)
	print("SHOT ", name)
	i += 1
