class_name MVOrbSpawn
extends Resource

## One ability orb. `ability_id` is passed straight to MVPlayer.gain_ability.

@export var persistence_id := ""
@export var position := Vector2.ZERO
@export_enum("double_jump", "ground_pound", "dagger") var ability_id := "double_jump"
@export var tint := Color("6ee7ff")
