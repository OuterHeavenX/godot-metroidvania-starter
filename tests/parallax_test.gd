extends Node

## Measures what actually moves when the camera rises.
##
## The backdrop riding up with a jump has now been reported twice, and both
## times I fixed the layers I happened to look at. This checks every one of
## them instead: raise the camera by a known amount and compare each layer's
## on-screen displacement against a plain world-space node's. Anything that
## does not match is drifting relative to the world, which is the artefact.
##
## Screen-pinned CanvasLayers are legitimate for a flat sky wash and a
## vignette -- neither carries a parallax cue -- so they are allow-listed by
## name and anything new has to be added deliberately.

const LEVEL := preload("res://src/levels/level_01.tscn")
const RISE := 260.0
const TOLERANCE := 1.0
## Layers that are meant to be glued to the screen rather than the world.
const PINNED_OK := ["SkyLayer", "VignetteLayer", "HUD", "TouchControls", "Overlay"]

var failures: Array[String] = []
var level: Node = null
var player: Node = null
var reference: Node2D = null
var before: Dictionary = {}
var before_reference := 0.0
var t := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures.append(label)
		print("  FAIL ", label)


func _ready() -> void:
	level = LEVEL.instantiate()
	add_child(level)


func _collect() -> Dictionary:
	var out: Dictionary = {}
	for node in _walk(level):
		if node is ParallaxLayer:
			var probe := _probe(node)
			if probe != null:
				out[node.get_path()] = probe.get_global_transform_with_canvas().origin.y
	return out


func _walk(root: Node) -> Array:
	var out: Array = [root]
	for child in root.get_children():
		out.append_array(_walk(child))
	return out


## A ParallaxLayer has no size of its own; measure one of its children.
func _probe(layer: Node) -> CanvasItem:
	for child in layer.get_children():
		if child is CanvasItem:
			return child
	return null


func _physics_process(_delta: float) -> void:
	t += 1
	if t == 4:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			check(false, "player present")
			_finish()
			return
		var cam: Camera2D = player.get_node("Camera2D")
		# Smoothing would leave the camera mid-flight when the frame is measured.
		cam.position_smoothing_enabled = false
		player.set_physics_process(false)
		player.global_position = Vector2(1200, -120)
		# A plain world-space node to measure the camera's real displacement.
		reference = Node2D.new()
		level.add_child(reference)
		reference.global_position = Vector2(1200, 0)
		return
	if t == 10:
		before = _collect()
		before_reference = reference.get_global_transform_with_canvas().origin.y
		player.global_position = Vector2(1200, -120 - RISE)
		return
	if t == 16:
		var after := _collect()
		# The camera adds its own offset and lookahead, so it does not travel
		# exactly RISE. What matters is that everything matches whatever it did.
		var moved: float = reference.get_global_transform_with_canvas().origin.y \
			- before_reference
		check(moved > 50.0,
			"the camera rose, dropping world content %.0fpx on screen" % moved)
		check(before.size() > 0, "found %d parallax layers to check" % before.size())
		for path in before:
			if not after.has(path):
				continue
			var delta: float = float(after[path]) - float(before[path])
			var drift: float = delta - moved
			var name := String(path).get_file()
			check(absf(drift) < TOLERANCE,
				"%s moved %.0fpx, world moved %.0fpx (drift %.0f)" % [name, delta, moved, drift])
		_check_pinned()
		_check_camera_children()
		_finish()


## Anything on a CanvasLayer is glued to the screen, so relative to the world it
## travels with the camera at full rate -- the same artefact by another route.
func _check_pinned() -> void:
	for node in _walk(level):
		if node is ParallaxBackground or not (node is CanvasLayer):
			continue
		var name: String = node.name
		var kids := ""
		for child in node.get_children():
			kids += ("" if kids == "" else ", ") + child.get_class()
			if child is Node2D or child is Control:
				var script: Script = child.get_script()
				if script != null:
					kids += "(" + script.resource_path.get_file() + ")"
		check(PINNED_OK.has(name),
			"screen-pinned CanvasLayer '%s' [layer %d: %s] is known-good"
			% [name, (node as CanvasLayer).layer, kids])


## The third way to escape world space, and the one that actually caused the
## second report: parent a node to the Camera2D. It then holds its screen
## position while the world scrolls past, which reads as the thing rising with
## you every time you jump. Diffuse particle emitters are pinned on purpose --
## they drift on their own velocity, so they never read as a fixed image -- but
## anything that draws a shape does not belong here. If drift is ever reported
## again, these emitters are the next suspects.
func _check_camera_children() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var cam := player.get_node_or_null("Camera2D")
	if cam == null:
		check(false, "camera found")
		return
	for child in cam.get_children():
		if not (child is CanvasItem):
			continue
		var ok: bool = child is CPUParticles2D or child is GPUParticles2D
		check(ok, "camera-parented '%s' (%s) draws no fixed shape"
			% [child.name, child.get_class()])


func _finish() -> void:
	if failures.is_empty():
		print("PARALLAX TESTS ALL PASSED")
	else:
		print("PARALLAX TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
