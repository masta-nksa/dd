class_name InputSetup
## Legt die Eingabe-Aktionen im Code an (Tastatur). Controller folgt in einer späteren Stufe.

const BELEGUNG := {
	1: {"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S, "jump": KEY_SPACE,
		"punch": KEY_F, "kick": KEY_G, "special": KEY_R, "grab": KEY_E},
	2: {"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN, "jump": KEY_O,
		"punch": KEY_K, "kick": KEY_L, "special": KEY_I, "grab": KEY_J},
}

static func einrichten() -> void:
	for spieler in BELEGUNG:
		for aktion in BELEGUNG[spieler]:
			var name := "p%d_%s" % [spieler, aktion]
			if not InputMap.has_action(name):
				InputMap.add_action(name, 0.5)
			var ev := InputEventKey.new()
			ev.physical_keycode = BELEGUNG[spieler][aktion]
			InputMap.action_add_event(name, ev)
