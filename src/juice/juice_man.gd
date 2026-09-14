extends Node


var _trauma := 0.0
var _hit_stop_active := false

const SHAKE_MAX := 26.0


func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = maxf(_trauma - delta * 1.6, 0.0)
		var cam := get_viewport().get_camera_2d()
		if cam != null:
			if _trauma <= 0.0:
				cam.offset = Vector2.ZERO
			else:
				var s := _trauma * _trauma * SHAKE_MAX
				cam.offset = Vector2(randf_range(-s, s), randf_range(-s, s))


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func hit_stop(duration: float = 0.06, scale: float = 0.05) -> void:
	if _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_active = false


func burst(pos: Vector2, color: Color, count: int = 14, speed: float = 260.0,
		lifetime: float = 0.5, gravity: float = 700.0, size: float = 5.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = count
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 6.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.damping_min = 40.0
	p.damping_max = 120.0
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.color = color
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
