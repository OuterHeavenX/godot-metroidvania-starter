extends Node

var actor: Node2D
var kind := ""

func _ready() -> void:
	actor = get_parent() as Node2D
	match kind:
		"orb", "heart": actor.connect("collected", _collected)
		"floor": actor.connect("broken", _broken)
		"checkpoint": actor.connect("claimed", _checkpoint)
		"arrow": actor.connect("impacted", _arrow)
		"goal":
			actor.connect("won", _won)
			actor.connect("unlocked", _unlocked)

func _collected() -> void:
	if kind == "heart":
		AudioMan.play("orb_pickup", -3.0, 1.25)
		JuiceMan.burst(actor.global_position, Color("ff5d73"), 16, 210.0, 0.55, 220.0, 4.0)
	else:
		AudioMan.play("orb_pickup")
		JuiceMan.burst(actor.global_position, actor.get("tint"), 18, 240.0, 0.7, 200.0, 5.0, "magic")
		JuiceMan.shake(0.2)

func _broken() -> void:
	AudioMan.play("pound", -2.0, 0.7)
	JuiceMan.shake(0.4)
	var castle: bool = actor.get("theme") == "castle"
	var dust := Color(0.45, 0.50, 0.68) if castle else Color(0.62, 0.52, 0.38)
	var chips := Color(0.70, 0.76, 0.92) if castle else Color(0.9, 0.75, 0.5)
	JuiceMan.burst(actor.global_position, dust, 26, 360.0, 0.7, 1100.0, 6.0)
	JuiceMan.burst(actor.global_position, chips, 10, 200.0, 0.4, 500.0, 4.0)

func _checkpoint() -> void:
	AudioMan.play("checkpoint")
	JuiceMan.burst(actor.global_position + Vector2(0, -48), Color(0.95, 0.75, 0.3), 12, 200.0, 0.5, 300.0, 4.0)
	var tween := create_tween()
	tween.tween_property(actor, "scale", Vector2(1.25, 1.25), 0.12)
	tween.tween_property(actor, "scale", Vector2.ONE, 0.14)

func _arrow() -> void:
	JuiceMan.burst(actor.global_position, Color(0.7, 0.65, 0.5), 6, 140.0, 0.3, 400.0, 3.0)

func _won() -> void:
	AudioMan.play("goal_win")
	JuiceMan.shake(0.25)

func _unlocked() -> void:
	AudioMan.play("checkpoint", 0.0, 0.7)
	JuiceMan.shake(0.3)
	JuiceMan.burst(actor.global_position + Vector2(0, -40), Color(0.6, 0.95, 1.0), 22, 280.0, 0.7, 260.0, 5.0)
