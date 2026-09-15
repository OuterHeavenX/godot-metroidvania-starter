class_name MVDamage
extends RefCounted

enum Kind { SLASH, IMPACT, CONTACT }
var amount: int
var origin: Vector2
var kind: Kind

func _init(value: int = 1, from: Vector2 = Vector2.ZERO, type: Kind = Kind.SLASH) -> void:
	amount = value
	origin = from
	kind = type

## All damage sources use the same typed receiver component.
static func deliver(target: Node, hit: MVDamage) -> bool:
	if not is_instance_valid(target):
		return false
	var receiver := target.get_node_or_null("Combat") as MVCombat
	return receiver.receive(hit) if receiver != null else false
