class_name MVWorldSpawn
extends Resource

## IDs are authored once and stay with the object when it moves or is reordered.
@export var persistence_id := ""
@export var position := Vector2.ZERO
@export var size := Vector2.ZERO # Used by breakable terrain only.
