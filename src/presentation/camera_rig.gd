class_name MVCameraRig
extends Camera2D

const LOOKAHEAD := 60.0
const LOOKAHEAD_RATE := 4.0
var _lead := 0.0

func update_view(delta: float, facing: float) -> void:
	_lead = lerpf(_lead, facing * LOOKAHEAD, 1.0 - exp(-LOOKAHEAD_RATE * delta))
	offset = Vector2(_lead, 0.0) + JuiceMan.shake_offset
