extends CanvasLayer


@onready var hearts = $TopLeft / HeartsBar
@onready var dash_chip: Label = $TopLeft / Chips / DashChip
@onready var dj_chip: Label = $TopLeft / Chips / DoubleJumpChip
@onready var pound_chip: Label = $TopLeft / Chips / PoundChip
@onready var win_panel: CenterContainer = $Overlay / WinPanel
@onready var pause_panel: CenterContainer = $Overlay / PausePanel
@onready var mute_button: Button = $MuteButton
@onready var pause_button: Button = $PauseButton
@onready var resume_button: Button = $Overlay / PausePanel / Panel / VBox / Resume
@onready var restart_button: Button = $Overlay / PausePanel / Panel / VBox / Restart
@onready var again_button: Button = $Overlay / WinPanel / Panel / VBox / Again
@onready var title_button: Button = $Overlay / PausePanel / Panel / VBox / Title2
@onready var win_time: Label = $Overlay / WinPanel / Panel / VBox / Time
@onready var key_hint: Label = $Hint
@onready var win_title: Label = $Overlay / WinPanel / Panel / VBox / Title
@onready var win_sub: Label = $Overlay / WinPanel / Panel / VBox / Sub
@onready var boss_bar = $BossBar

var won := false
var _next_level := ""


func _ready() -> void:
	add_to_group("hud")
	_refresh_mute_label()
	mute_button.pressed.connect(_on_mute_pressed)
	pause_button.pressed.connect(func () -> void: _set_pause(true))
	resume_button.pressed.connect(func () -> void: _set_pause(false))
	restart_button.pressed.connect(restart)
	again_button.pressed.connect(_on_again)
	title_button.pressed.connect(quit_to_title)
	apply_touch_layout(DisplayServer.is_touchscreen_available())


## Phone layout. Taken as an argument rather than read from DisplayServer so a
## test can exercise it -- headless always reports no touchscreen.
func apply_touch_layout(touch: bool) -> void:
	# The keyboard legend is noise on a phone, and it runs under the on-screen
	# buttons at the bottom right.
	key_hint.visible = not touch
	# Bigger targets on touch, inset further from the top edge to clear browser
	# chrome and notches in landscape.
	var top := 24.0 if touch else 14.0
	var height := 64.0 if touch else 40.0
	for b: Button in [mute_button, pause_button]:
		b.add_theme_font_size_override("font_size", 20 if touch else 14)
		b.offset_top = top
		b.offset_bottom = top + height
	mute_button.offset_left = -188.0 if touch else -156.0
	mute_button.offset_right = -24.0 if touch else -16.0
	pause_button.offset_left = -324.0 if touch else -240.0
	pause_button.offset_right = -200.0 if touch else -166.0


func _unhandled_input(event: InputEvent) -> void:
	if won:
		return
	if event.is_action_pressed("ui_cancel"):
		_set_pause(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _set_pause(p: bool) -> void:
	if won:
		return
	get_tree().paused = p
	pause_panel.visible = p
	_show_touch_controls(not p)
	AudioMan.play("ui_click")


## The on-screen sticks sit on their own layer above this one, so they are
## hidden behind a panel rather than left tappable under it.
func _show_touch_controls(vis: bool) -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	for n in get_tree().get_nodes_in_group("touch_controls"):
		(n as CanvasLayer).visible = vis


func _on_again() -> void:
	if _next_level != "":
		AudioMan.play("ui_click")
		get_tree().paused = false
		SaveMan.resume_requested = true
		get_tree().change_scene_to_file(_next_level)
		return
	restart()


## Between areas: same panel, but it carries you onward instead of restarting.
func show_area_cleared(next_level: String, banked: float) -> void:
	won = true
	_next_level = next_level
	win_title.text = "AREA CLEAR!"
	win_sub.text = "The way ahead opens."
	win_time.text = "Run so far  %s" % SaveMan.format_time(banked)
	win_time.visible = true
	again_button.text = "NEXT AREA"
	win_panel.visible = true
	pause_panel.visible = false
	_show_touch_controls(false)
	get_tree().paused = true


func quit_to_title() -> void:
	AudioMan.play("ui_click")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/ui/title.tscn")


func restart() -> void:
	AudioMan.play("ui_click")
	# Unpause first: the reloaded scene would otherwise come up frozen.
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_mute_pressed() -> void:
	AudioMan.toggle_mute()
	_refresh_mute_label()
	AudioMan.play("ui_click")


func _refresh_mute_label() -> void:
	mute_button.text = "SOUND OFF" if AudioMan.is_muted() else "SOUND ON"


func set_hearts(hp: int, max_hp: int) -> void:
	hearts.set_values(hp, max_hp)


func boss_engaged(who: String, hp: int, max_hp: int, guarded: bool) -> void:
	boss_bar.engage(who, hp, max_hp, guarded)


func boss_hp(hp: int, max_hp: int) -> void:
	boss_bar.set_hp(hp, max_hp)


func boss_guard(guarded: bool) -> void:
	boss_bar.set_guard(guarded)


func boss_blocked() -> void:
	boss_bar.blocked()


func boss_defeated() -> void:
	boss_bar.dismiss()


func on_ability_gained(ability_id: String) -> void:
	if ability_id == "double_jump":
		dj_chip.add_theme_color_override("font_color", Color("6ee7ff"))
	elif ability_id == "ground_pound":
		pound_chip.add_theme_color_override("font_color", Color("ff9a3c"))


func show_win(seconds: float = 0.0, previous_best: float = 0.0) -> void:
	won = true
	_next_level = ""
	again_button.text = "PLAY AGAIN"
	if seconds > 0.0:
		var line := "Time  %s" % SaveMan.format_time(seconds)
		if previous_best > 0.0 and seconds < previous_best:
			line += "   — new best"
		elif previous_best > 0.0:
			line += "   (best %s)" % SaveMan.format_time(previous_best)
		win_time.text = line
		win_time.visible = true
	else:
		win_time.visible = false
	win_panel.visible = true
	pause_panel.visible = false
	_show_touch_controls(false)
	get_tree().paused = true
