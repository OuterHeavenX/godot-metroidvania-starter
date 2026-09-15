class_name MVMeleeAttack
extends Node

signal started
var cooldown := 0.0
var active := 0.0
var buffered := 0.0
var cooldown_duration := 0.38
var active_duration := 0.16
var buffer_duration := 0.14
var reach := 86.0
var half_height := 58.0
var back_grace := 14.0
var collision_mask := 2
var _hits: Dictionary = {}

func tick(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	active = maxf(active - delta, 0.0)
	buffered = maxf(buffered - delta, 0.0)

func request() -> void:
	buffered = buffer_duration

func try_start(allowed: bool) -> bool:
	if not allowed or buffered <= 0.0 or cooldown > 0.0:
		return false
	begin()
	return true

func begin() -> void:
	cooldown = cooldown_duration
	active = active_duration
	buffered = 0.0
	_hits.clear()
	started.emit()

func reset() -> void:
	cooldown = 0.0
	active = 0.0
	buffered = 0.0
	_hits.clear()

## Local broad-phase query followed by the original directional reach test.
func resolve(source: Node2D, facing: float) -> void:
	if active <= 0.0:
		return
	for foe in nearby(source, source.global_position, reach, collision_mask):
		var id := foe.get_instance_id()
		var offset := foe.global_position - source.global_position
		if _hits.has(id) or absf(offset.y) >= half_height or offset.x * facing <= -back_grace or offset.length() >= reach:
			continue
		_hits[id] = true
		MVDamage.deliver(foe, MVDamage.new(1, source.global_position))

static func nearby(source: Node2D, center: Vector2, radius: float, mask: int) -> Array[Node2D]:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = mask
	var result: Array[Node2D] = []
	for entry in source.get_world_2d().direct_space_state.intersect_shape(query, 256):
		var body := entry.collider as Node2D
		if body != null and body != source and body not in result:
			result.append(body)
	return result
