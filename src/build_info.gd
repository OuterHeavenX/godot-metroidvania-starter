class_name MVBuild
extends RefCounted

## Stamped into the title screen and the HUD corner.
##
## Three rounds of "the boss is unbeatable" were spent on a build that did not
## contain the fixes: the game is served from a committed web export, and there
## was no way for either side of the conversation to tell which export was
## actually live. Bump this whenever the published build changes, and the
## answer is on screen.
const VERSION := "v18"
const NOTE := "enemies telegraph"


static func label() -> String:
	return "%s · %s" % [VERSION, NOTE]
