class_name PauseScreen
extends Screen
## Pausenmenü: Weiter, Neustart, zurück zum Menü.

signal resume_requested
signal restart_requested
signal menu_requested

var reason := ""       # z. B. «Controller 2 getrennt»

func _build() -> void:
	add_text("PAUSE", 56, YELLOW)
	if reason != "":
		add_text(reason, 20, RED)
	add_gap(10.0)
	add_button("Weiter", func(): resume_requested.emit())
	add_button("Neustart", func(): restart_requested.emit())
	add_button("Menü", func(): menu_requested.emit())
