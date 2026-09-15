class_name MVLevelPresentation
extends RefCounted

static func background(level: Node2D, data: MVLevelData) -> void:
	MVBackdrop.build(level, data.theme, data.background_span)

static func dress(level: Node2D, data: MVLevelData, player: MVPlayer, orbs: Array) -> void:
	AudioMan.play_music(data.music)
	for h in data.hints:
		var hint := Label.new()
		hint.text = h.text
		hint.position = h.position
		hint.add_theme_font_size_override("font_size", 26)
		hint.add_theme_color_override("font_color", Color("cfe0ff"))
		hint.add_theme_color_override("font_outline_color", Color("0a0d18"))
		hint.add_theme_constant_override("outline_size", 8)
		hint.modulate = Color(1.75, 1.75, 1.75)
		level.add_child(hint)
	var torches: Array = data.checkpoints.duplicate()
	torches.append(data.goal_position)
	if data.has_boss:
		torches.append(data.boss_position)
	MVAtmosphere.build_v11(level, player, orbs, torches, data.platforms)
