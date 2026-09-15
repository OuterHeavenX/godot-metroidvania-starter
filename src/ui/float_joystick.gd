extends Control


const RADIUS := 110.0
const KNOB_RADIUS := 46.0
const DEADZONE := 0.18

var _touch_id := -1
var _base := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var half_w: float = get_viewport_rect().size.x * 0.5
		if event.pressed:
			if _touch_id == -1 and event.position.x < half_w:
				_touch_id = event.index
				_base = event.position
				_knob = Vector2.ZERO
				_push()
				queue_redraw()
		elif event.index == _touch_id:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch_id:
		var off: Vector2 = event.position - _base
		if off.length() > RADIUS:

			_base = event.position - off.normalized() * RADIUS
			off = off.normalized() * RADIUS
		_knob = off
		_push()
		queue_redraw()


func _release() -> void:
	_touch_id = -1
	_knob = Vector2.ZERO
	Input.action_release("move_left")
	Input.action_release("move_right")
	queue_redraw()


func _push() -> void:
	var v: Vector2 = _knob / RADIUS
	if v.length() < DEADZONE:
		v = Vector2.ZERO
	else:
		v = v.normalized() * minf( (v.length() - DEADZONE) / (1.0 - DEADZONE), 1.0)
	if v.x >= 0.0:
		Input.action_release("move_left")
		if v.x > 0.0:
			Input.action_press("move_right", v.x)
	else:
		Input.action_release("move_right")
		Input.action_press("move_left", -v.x)


func _draw() -> void:
	if _touch_id == -1:
		return
	draw_circle(_base, RADIUS, Color(1, 1, 1, 0.14))
	draw_arc(_base, RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.4), 3.0)
	draw_circle(_base + _knob, KNOB_RADIUS, Color(1, 1, 1, 0.42))
	draw_arc(_base + _knob, KNOB_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 2.0)
