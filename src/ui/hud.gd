extends CanvasLayer


@onready var hearts = $TopLeft / HeartsBar
@onready var dash_chip: Label = $TopLeft / Chips / DashChip
@onready var dj_chip: Label = $TopLeft / Chips / DoubleJumpChip
@onready var pound_chip: Label = $TopLeft / Chips / PoundChip
@onready var win_panel: CenterContainer = $WinPanel
@onready var mute_button: Button = $MuteButton


func _ready() -> void:
	_refresh_mute_label()
	mute_button.pressed.connect(_on_mute_pressed)


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
	win_panel.visible = true
