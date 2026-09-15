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

var won := false


func _ready() -> void:
	add_to_group("hud")
	_refresh_mute_label()
	mute_button.pressed.connect(_on_mute_pressed)
	pause_button.pressed.connect(func () -> void: _set_pause(true))
	resume_button.pressed.connect(func () -> void: _set_pause(false))
	restart_button.pressed.connect(restart)
	again_button.pressed.connect(restart)


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


func on_ability_gained(ability_id: String) -> void:
	if ability_id == "double_jump":
		dj_chip.add_theme_color_override("font_color", Color("6ee7ff"))
	elif ability_id == "ground_pound":
		pound_chip.add_theme_color_override("font_color", Color("ff9a3c"))


func show_win() -> void:
	won = true
	win_panel.visible = true
	pause_panel.visible = false
	_show_touch_controls(false)
	get_tree().paused = true
