extends CanvasLayer


func _ready() -> void:
	add_to_group("touch_controls")
	visible = DisplayServer.is_touchscreen_available()
	_bind($Attack, "attack")
	_bind($Dash, "dash")
	_bind($Jump, "jump")
	_bind($Pound, "pound")
	_bind($Throw, "throw")


func _bind(btn: BaseButton, action: String) -> void:
	btn.button_down.connect(func () -> void: Input.action_press(action))
	btn.button_up.connect(func () -> void: Input.action_release(action))
