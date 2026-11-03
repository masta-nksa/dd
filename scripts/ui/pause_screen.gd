class_name PauseScreen
extends Screen
## Pausenmenü: Weiter, Neustart, zurück zum Menü.

signal resume_requested
signal restart_requested
signal menu_requested

var reason := ""       # z. B. «Controller 2 getrennt»

func _build() -> void:
	add_title("PAUSE", 96.0)
	if reason != "":
		add_text(reason, 28.0, RED)
	add_gap(10.0)
	add_button("Weiter", func(): resume_requested.emit())
	add_button("Neustart", func(): restart_requested.emit())
	add_button("Menü", func(): menu_requested.emit())
