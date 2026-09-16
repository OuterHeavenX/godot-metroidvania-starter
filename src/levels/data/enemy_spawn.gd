class_name MVEnemySpawn
extends Resource

## One skeleton placement. `kind` must be a key of MVSkeleton.CFG.

@export var persistence_id := ""
@export var position := Vector2.ZERO
@export_enum("warrior", "spearman", "archer", "shielder", "charger") var kind := "warrior"
