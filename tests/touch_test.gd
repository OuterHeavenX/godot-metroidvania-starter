extends Node

## Phone layout. Headless always reports no touchscreen, so the layout is
## applied explicitly and then measured.

var failures: Array[String] = []
var t := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures.append(label)
		print("  FAIL ", label)


func _process(_delta: float) -> void:
	t += 1
	if t < 6:
		return
	var hud := get_tree().get_first_node_in_group("hud")
	check(hud != null, "hud found")
	if hud == null:
		_finish()
		return

	var hint: Label = hud.get_node("Hint")
	var mute: Button = hud.get_node("MuteButton")
	var pause: Button = hud.get_node("PauseButton")

	# Headless reports a touchscreen as available, so the desktop case has to be
	# asked for rather than assumed.
	hud.call("apply_touch_layout", false)
	check(hint.visible, "keyboard legend shown without touch")
	var desktop_h: float = mute.offset_bottom - mute.offset_top

	hud.call("apply_touch_layout", true)
	check(not hint.visible, "keyboard legend hidden on touch")
	var touch_h: float = mute.offset_bottom - mute.offset_top
	check(touch_h > desktop_h,
		"top buttons grow for touch (%.0f -> %.0f)" % [desktop_h, touch_h])
	check(mute.offset_top >= 20.0,
		"top buttons inset from the edge (%.0f)" % mute.offset_top)

	# The on-screen action buttons occupy the bottom right; nothing from the
	# HUD should overlap them once the touch layout is applied.
	var touch_controls := get_tree().get_first_node_in_group("touch_controls")
	check(touch_controls != null, "touch controls present")
	if touch_controls != null:
		var jump: Button = touch_controls.get_node("Jump")
		check(jump.offset_bottom - jump.offset_top >= 100.0,
			"jump button is a large target (%.0fpx)" % (jump.offset_bottom - jump.offset_top))

	# Pause and sound must not sit on top of each other.
	check(pause.offset_right <= mute.offset_left,
		"pause and sound do not overlap (%.0f vs %.0f)" % [pause.offset_right, mute.offset_left])
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("TOUCH TESTS ALL PASSED")
	else:
		print("TOUCH TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
