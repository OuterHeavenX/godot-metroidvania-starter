extends Node


var _trauma := 0.0
var shake_offset := Vector2.ZERO
var _hit_stop_active := false

const SHAKE_MAX := 26.0

# Free CC0 particle art (Kenney particle pack). White/gray so `color` tints them.
const TEX := {
	"smoke": "res://assets/particles/smoke.png",
	"flame": "res://assets/particles/flame.png",
	"magic": "res://assets/particles/magic.png",
	"dot": "res://assets/particles/dot.png",
}
var _tex_cache := {}


func _tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load(TEX[name]) as Texture2D
	return _tex_cache[name]


func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = maxf(_trauma - delta * 1.6, 0.0)
		var strength := _trauma * _trauma * SHAKE_MAX
		shake_offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	else:
		shake_offset = Vector2.ZERO


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
		lifetime: float = 0.5, gravity: float = 700.0, size: float = 5.0,
		tex: String = "") -> void:
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
	if tex != "" and TEX.has(tex):
		p.texture = _tex(tex)
		# textures are 512px: scale factor -> roughly `size` * 7 px on screen
		p.scale_amount_min = size * 0.010
		p.scale_amount_max = size * 0.018
	else:
		p.scale_amount_min = size * 0.5
		p.scale_amount_max = size
	p.color = color
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Expanding shockwave ring at a world position. Auto-frees.
func ring(pos: Vector2, color: Color = Color(1, 0.9, 0.6),
		max_r: float = 130.0, dur: float = 0.45, width: float = 9.0) -> void:
	var r := ShockRing.new()
	r.position = pos
	r.col = color
	r.max_r = max_r
	r.dur = dur
	r.width = width
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(r)


class ShockRing extends Node2D:
	var t := 0.0
	var dur := 0.45
	var max_r := 130.0
	var width := 9.0
	var col := Color(1, 0.9, 0.6)

	func _init() -> void:
		add_to_group("shock_ring")

	func _process(delta: float) -> void:
		t += delta
		if t >= dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - f, 3.0)
		draw_arc(Vector2.ZERO, max_r * eased, 0.0, TAU, 48,
			Color(col, (1.0 - f) * 0.85), width * (1.0 - f) + 2.0, true)
