class_name InputSetup
## Legt die Eingabe-Aktionen im Code an: Tastatur und je ein Controller pro Spieler
## (erster Controller = Spieler 1, zweiter = Spieler 2).

const BELEGUNG := {
	1: {"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S, "jump": KEY_SPACE,
		"punch": KEY_F, "kick": KEY_G, "special": KEY_R, "grab": KEY_E},
	2: {"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN, "jump": KEY_O,
		"punch": KEY_K, "kick": KEY_L, "special": KEY_I, "grab": KEY_J},
}

const PAD_BUTTONS := {"jump": [JOY_BUTTON_A], "punch": [JOY_BUTTON_X, JOY_BUTTON_LEFT_SHOULDER], "kick": [JOY_BUTTON_B],
	"special": [JOY_BUTTON_Y], "grab": [JOY_BUTTON_RIGHT_SHOULDER], "left": [JOY_BUTTON_DPAD_LEFT],
	"right": [JOY_BUTTON_DPAD_RIGHT], "up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN]}
const PAD_AXES := {"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
	"up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0]}
const PAD_HINTS := {"jump": "A", "punch": "X", "kick": "B", "special": "Y", "grab": "RB"}

static var _done := false

static func einrichten() -> void:
	if _done:
		return
	_done = true
	for spieler in BELEGUNG:
		var device: int = spieler - 1
		for aktion in BELEGUNG[spieler]:
			var name := "p%d_%s" % [spieler, aktion]
			if not InputMap.has_action(name):
				InputMap.add_action(name, 0.5)
			var ev := InputEventKey.new()
			ev.physical_keycode = BELEGUNG[spieler][aktion]
			InputMap.action_add_event(name, ev)
			for knopf in PAD_BUTTONS[aktion]:
				InputMap.action_add_event(name, _pad_button(knopf, device))
			if PAD_AXES.has(aktion):
				InputMap.action_add_event(name, _pad_axis(PAD_AXES[aktion][0], PAD_AXES[aktion][1], device))
	_add_action("pause", [_key(KEY_ESCAPE), _key(KEY_P), _pad_button(JOY_BUTTON_START, -1)])
	_add_action("music_toggle", [_key(KEY_M)])
	# Menüs: Knöpfe bedienen über die eingebauten ui_*-Aktionen, hier ergänzt um WASD und jeden Controller
	_add_action("ui_up", [_key(KEY_W), _pad_button(JOY_BUTTON_DPAD_UP, -1), _pad_axis(JOY_AXIS_LEFT_Y, -1.0, -1)])
	_add_action("ui_down", [_key(KEY_S), _pad_button(JOY_BUTTON_DPAD_DOWN, -1), _pad_axis(JOY_AXIS_LEFT_Y, 1.0, -1)])
	_add_action("ui_accept", [_pad_button(JOY_BUTTON_A, -1)])

## Beschriftung für Hinweise: der Controller-Knopf, wenn dieser Spieler einen hat, sonst die Taste.
static func key_hint(spieler: int, aktion: String) -> String:
	if Input.get_connected_joypads().has(spieler - 1):
		return PAD_HINTS[aktion]
	return OS.get_keycode_string(BELEGUNG[spieler][aktion])

static func _add_action(name: String, events: Array) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.5)
	for ev in events:
		InputMap.action_add_event(name, ev)

static func _key(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	return ev

static func _pad_button(button: JoyButton, device: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = device
	return ev

static func _pad_axis(axis: JoyAxis, value: float, device: int) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	ev.device = device
	return ev
