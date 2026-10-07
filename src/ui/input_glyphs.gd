class_name MVInputGlyphs
extends RefCounted

## Names each action's control on whichever device is in use, so authored text
## can say {POUND} and read "S / ↓" on a keyboard or "A" on a gamepad.

const KEYBOARD := {
	"MOVE": "A/D or arrows", "JUMP": "Space", "DASH": "Shift", "ATTACK": "J",
	"POUND": "S / ↓", "THROW": "K", "PAUSE": "Esc",
}
const GAMEPAD := {
	"MOVE": "D-pad / stick", "JUMP": "Y", "DASH": "LB", "ATTACK": "X",
	"POUND": "A", "THROW": "B", "PAUSE": "START",
}


static func gamepad() -> bool:
	return not Input.get_connected_joypads().is_empty()


static func fmt(text: String) -> String:
	return fmt_for(text, gamepad())


static func fmt_for(text: String, pad: bool) -> String:
	var table: Dictionary = GAMEPAD if pad else KEYBOARD
	var out := text
	for key in table:
		out = out.replace("{%s}" % key, table[key])
	return out
