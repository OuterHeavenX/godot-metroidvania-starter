extends Node

var actor: MVSkeleton

func _ready() -> void:
	actor = get_parent() as MVSkeleton
	actor.feedback.connect(_on_feedback)

func _on_feedback(event: StringName, details: Dictionary) -> void:
	var pos := actor.global_position
	match event:
		&"animation": actor.visual.play(details.name)
		&"attack": AudioMan.play("attack", -6.0, 0.8)
		&"shoot": AudioMan.play("attack", -8.0, 0.7)
		&"windup": AudioMan.play("attack", -12.0, 0.6)
		&"charge": AudioMan.play("dash", -8.0, 0.7)
		&"hit": AudioMan.play("hit_enemy", -2.0, randf_range(0.9, 1.1))
		&"block":
			AudioMan.play("hit_enemy", -12.0, 0.5)
			JuiceMan.burst(pos + Vector2(actor.dir * 22.0, -40.0), Color(0.8, 0.85, 0.95), 5, 110.0, 0.25, 140.0, 3.0)
		&"guard_break":
			AudioMan.play("pound", -4.0, 0.85)
			JuiceMan.shake(0.35)
			JuiceMan.hit_stop(0.07)
			JuiceMan.burst(pos + Vector2(0, -60), Color(1.0, 0.85, 0.5), 20, 300.0, 0.6, 500.0, 5.0)
		&"phase_two":
			JuiceMan.shake(0.4)
			JuiceMan.burst(pos + Vector2(0, -60), Color(1.0, 0.45, 0.4), 24, 330.0, 0.7, 600.0, 5.0)
		&"boss_death":
			JuiceMan.shake(0.7)
			JuiceMan.hit_stop(0.12)
			JuiceMan.burst(pos + Vector2(0, -60), Color(1.0, 0.8, 0.45), 34, 420.0, 0.9, 700.0, 7.0)
		&"death":
			AudioMan.play("enemy_die", -2.0, randf_range(0.9, 1.15))
			JuiceMan.shake(0.22)
			JuiceMan.hit_stop(0.06)
			JuiceMan.burst(pos + Vector2(0, -30), Color(0.85, 0.82, 0.7), 16, 260.0, 0.5, 700.0, 5.0)
			actor.visual.dissolve()
