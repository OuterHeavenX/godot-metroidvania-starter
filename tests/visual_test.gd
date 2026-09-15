extends Node
## v11 atmosphere test: verifies the visual pass builds correctly on top of
## the data-driven level — dark ambient, lights, torch posts, grass, god rays,
## camera FX, vignette, birds, dash ghosts, shock rings, skeleton dissolve.

var frame := 0
var failures: Array[String] = []


func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		failures.append(label)
		print("FAIL: ", label)


func _count_lights(n: Node) -> int:
	var c := 0
	for ch in n.get_children():
		if ch is PointLight2D:
			c += 1
		c += _count_lights(ch)
	return c


func _process(_delta: float) -> void:
	frame += 1
	if frame < 10:
		return
	if frame > 10:
		return
	var scene := get_tree().current_scene.get_node("Level")
	var atmo := scene.get_node_or_null("Atmosphere")
	check(atmo != null, "Atmosphere node exists")
	var player := scene.get_node_or_null("Player")
	check(player != null, "Player exists")
	# themed backdrop from the other branch still builds
	var has_backdrop := false
	for ch in scene.get_children():
		if ch is ParallaxBackground:
			has_backdrop = true
	check(has_backdrop, "themed ParallaxBackground present")
	if atmo != null:
		check(_count_lights(atmo) >= 4, "torch lights present (>=4), got %d" % _count_lights(atmo))
		var vig_found := false
		for ch in atmo.get_children():
			if ch is CanvasLayer and ch.layer == 4:
				vig_found = true
		check(vig_found, "vignette CanvasLayer at layer 4")
		check(atmo.get_node_or_null("GodRays") != null, "GodRays moon shafts present")
	if player != null:
		var lantern := false
		for ch in player.get_children():
			if ch is PointLight2D:
				lantern = true
		check(lantern, "player lantern light attached")
		var cam := player.get_node_or_null("Camera2D")
		var fg := false
		if cam != null:
			for ch in cam.get_children():
				if ch.name == "Foreground":
					fg = true
		check(fg, "Foreground silhouettes under Camera2D")
		# dash ghosts: call the spawner directly and watch a fading sprite appear
		var visual := player.get_node_or_null("Visual")
		if visual != null and visual.has_method("_spawn_ghost"):
			var troot := get_tree().current_scene
			var before := 0
			for ch in troot.get_children():
				if ch is Sprite2D:
					before += 1
			visual._spawn_ghost()
			var after := 0
			for ch in troot.get_children():
				if ch is Sprite2D:
					after += 1
			check(after > before, "dash ghost spawns a fading sprite")
		else:
			check(false, "player visual has _spawn_ghost")
	# --- v10 pass checks ---
	var cm_found := false
	for ch in scene.get_children():
		if ch is CanvasModulate:
			cm_found = true
	check(cm_found, "CanvasModulate dark ambient present")
	var posts := get_tree().get_nodes_in_group("torch_post").size()
	check(posts >= 4, "torch posts present (>=4), got %d" % posts)
	check(scene.get_node_or_null("Birds") != null, "Birds cross the sky")
	check(scene.get_node_or_null("PlatformGrass") != null, "PlatformGrass tufts on terrain")
	check(scene.get_node_or_null("Atmosphere/PlatformGrass") == null, "grass is a level child, not under Atmosphere")
	# shockwave ring spawns and auto-frees
	var rings_before := get_tree().get_nodes_in_group("shock_ring").size()
	JuiceMan.ring(Vector2(400, -100), Color.WHITE, 60.0, 0.2, 6.0)
	var rings_after := get_tree().get_nodes_in_group("shock_ring").size()
	check(rings_after > rings_before, "JuiceMan.ring spawns a ShockRing")
	# skeleton dissolve path exists
	var skel_script := load("res://src/enemies/skeleton_visual.gd") as GDScript
	check(skel_script != null and skel_script.can_instantiate(), "skeleton_visual loads (has dissolve)")
	# Kenney particle textures resolve
	for tex_name in ["smoke", "flame", "magic", "dot"]:
		var t := load("res://assets/particles/%s.png" % tex_name) as Texture2D
		check(t != null, "Kenney particle texture loads: %s" % tex_name)
	if failures.is_empty():
		print("ALL TESTS PASSED")
	else:
		print("FAILURES: %d -> %s" % [failures.size(), str(failures)])
	get_tree().quit()
