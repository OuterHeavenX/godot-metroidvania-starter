extends Control

## Entry point. Continue only appears when there is progress worth resuming;
## the level itself never reads the save unless SaveMan.resume_requested is
## set here, so launching a level directly always starts clean.

const LEVEL := "res://src/levels/level_01.tscn"

@onready var continue_button: Button = $Center / VBox / Continue
@onready var new_button: Button = $Center / VBox / NewRun
@onready var stats: Label = $Center / VBox / Stats
@onready var mute_button: Button = $MuteButton


func _ready() -> void:
	continue_button.visible = SaveMan.has_run()
	continue_button.pressed.connect(_on_continue)
	new_button.pressed.connect(_on_new_run)
	mute_button.pressed.connect(_on_mute)
	_refresh_mute()
	stats.text = _stats_line()
	($Build as Label).text = MVBuild.label()
	apply_touch_layout(DisplayServer.is_touchscreen_available())
	if continue_button.visible:
		continue_button.grab_focus()
	else:
		new_button.grab_focus()


## See MVHud.apply_touch_layout for why this takes the flag as an argument.
func apply_touch_layout(touch: bool) -> void:
	$Hint.text = ("Tap NEW RUN — on-screen controls appear in game" if touch
		else "A/D or arrows: move · Space: jump · Shift: dash · S/↓: pound · Esc: pause")
	mute_button.add_theme_font_size_override("font_size", 20 if touch else 14)
	mute_button.offset_top = 24.0 if touch else 14.0
	mute_button.offset_bottom = 88.0 if touch else 54.0
	mute_button.offset_left = -188.0 if touch else -156.0
	mute_button.offset_right = -24.0 if touch else -16.0


func _stats_line() -> String:
	var bits: Array[String] = []
	if SaveMan.best_time > 0.0:
		bits.append("Best  %s" % SaveMan.format_time(SaveMan.best_time))
	if SaveMan.runs > 0:
		bits.append("%d clear%s" % [SaveMan.runs, "" if SaveMan.runs == 1 else "s"])
	if SaveMan.has_run() and not SaveMan.abilities.is_empty():
		bits.append("%d/2 abilities" % SaveMan.abilities.size())
	return "   ·   ".join(bits)


func _on_continue() -> void:
	AudioMan.play("ui_click")
	SaveMan.resume_requested = true
	var target: String = SaveMan.level_path if SaveMan.level_path != "" else LEVEL
	if not ResourceLoader.exists(target):
		target = LEVEL
	get_tree().change_scene_to_file(target)


func _on_new_run() -> void:
	AudioMan.play("ui_click")
	SaveMan.clear_progress()
	SaveMan.resume_requested = false
	get_tree().change_scene_to_file(LEVEL)


func _on_mute() -> void:
	AudioMan.toggle_mute()
	AudioMan.play("ui_click")
	_refresh_mute()


func _refresh_mute() -> void:
	mute_button.text = "SOUND OFF" if AudioMan.is_muted() else "SOUND ON"
