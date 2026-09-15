extends VBoxContainer

## Encounter feedback is a HUD concern; the boss owns combat state.
var boss: MVBoss
var player: MVPlayer
var caption: Label
var meter: ProgressBar

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -210
	offset_right = 210
	offset_top = 14
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_constant_override("outline_size", 6)
	add_child(caption)
	meter = ProgressBar.new()
	meter.custom_minimum_size = Vector2(0, 14)
	meter.show_percentage = false
	meter.max_value = MVBoss.MAX_HP
	add_child(meter)
	visible = false

func _process(_delta: float) -> void:
	visible = is_instance_valid(boss) and is_instance_valid(player)
	if not visible:
		return
	visible = not boss.dead and not get_tree().paused and player.global_position.distance_to(boss.global_position) < 550.0
	if not visible:
		return
	meter.value = boss.hp
	var instruction := "GUARD OPEN - STRIKE"
	if boss.guarded:
		instruction = "GUARDED - STOMP OR POUND"
	elif boss.state == "attack":
		instruction = "INCOMING - EVADE"
	caption.text = "WARDEN  /  PHASE %d\n%s" % [boss.phase, instruction]
	meter.modulate = Color("ffd28a") if boss.guarded else Color("fa7373")


func bind(encounter: MVBoss, hero: MVPlayer) -> void:
	boss = encounter
	player = hero
