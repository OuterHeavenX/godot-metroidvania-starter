extends CanvasLayer


func _ready() -> void:
	add_to_group("touch_controls")
	# Only show touch controls on actual mobile devices (phones/tablets)
	# Steam Deck uses gamepad, not touch
	var is_mobile := OS.get_name() in ["Android", "iOS", "Web"]
	var has_touchscreen := DisplayServer.is_touchscreen_available()
	visible = is_mobile and has_touchscreen
	_bind($Attack, "attack")
	_bind($Dash, "dash")
	_bind($Jump, "jump")
	_bind($Pound, "pound")
	_bind($Throw, "throw")


func _bind(btn: BaseButton, action: String) -> void:
	btn.button_down.connect(func () -> void: Input.action_press(action))
	btn.button_up.connect(func () -> void: Input.action_release(action))
