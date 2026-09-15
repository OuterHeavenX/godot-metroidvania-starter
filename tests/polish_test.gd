extends Node


var frame := 0
var player: Node = null
var foe: Node = null
var failures: Array[String] = []
var _am: Node
var _jm: Node
var _jump_armed := false
var _jump_ok := false
var _slash1_armed := false
var _slash1_ok := false
var _slash2_armed := false
var _slash2_ok := false


func _ready() -> void:
	_am = get_node("/root/AudioMan")
	_jm = get_node("/root/JuiceMan")


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


func count_bursts() -> int:
	return get_tree().root.find_children("*", "CPUParticles2D", true, false).size()


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 5:
		check(_am != null, "AudioMan autoload present")
		check(_jm != null, "JuiceMan autoload present")
		check(not _am.is_muted(), "starts unmuted")
		check(_am.get("_music").playing, "music loop playing")
		check(int(_am.get("_sfx").size()) == 14, "14 sfx loaded (got %d)" % _am.get("_sfx").size())
		_am.toggle_mute()
		check(_am.is_muted(), "mute toggles on")
		_am.toggle_mute()
		check(not _am.is_muted(), "mute toggles off")
		player = get_tree().get_nodes_in_group("player")[0]
		foe = get_tree().get_nodes_in_group("enemy")[0]
		check(player != null and foe != null, "actors found")
		press_action("jump")
		_jump_armed = true
	if _jump_armed and int(player.get("jumps_used")) >= 1:
		_jump_armed = false
		_jump_ok = true
	if frame == 9:
		foe.global_position = player.global_position + Vector2(60, 0)
		foe.set("velocity", Vector2.ZERO)
		press_action("attack")
		_slash1_armed = true
	if frame == 11:
		release_action("attack")
	if _slash1_armed and int(foe.get("hp")) == 1:
		_slash1_armed = false
		_slash1_ok = true
	if frame == 16:
		check(_jump_ok, "jump fired through sfx path")
		check(_slash1_ok, "first slash hit (hp=1)")
	if frame == 38:
		foe.global_position = player.global_position + Vector2(60, 0)
		foe.set("velocity", Vector2.ZERO)
		press_action("attack")
		_slash2_armed = true
	if frame == 40:
		release_action("attack")
	if _slash2_armed and bool(foe.get("dead")):
		_slash2_armed = false
		_slash2_ok = true
		check(count_bursts() >= 1, "death burst particles spawned")
		check(float(_jm.get("_trauma")) > 0.0, "screenshake trauma added")
	if frame == 70:
		check(_slash2_ok, "foe died from second slash")
		check(Engine.time_scale == 1.0, "time_scale restored after hit-stop")
	if frame == 74:
		if failures.is_empty():
			print("ALL TESTS PASSED")
		else:
			print("FAILURES: %d -> %s" % [failures.size(), str(failures)])
		get_tree().quit()
