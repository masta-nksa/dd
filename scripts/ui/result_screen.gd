class_name ResultScreen
extends Screen
## Game Over oder Sieg: Punkte je Spieler, Gesamtpunktzahl, Rekord und Zeit.

signal restart_requested
signal menu_requested

const LOCK_TIME := 1.0   # Sekunden, damit man nicht aus Versehen sofort weiterdrückt

var won := false
var lines: Array[String] = []     # eine Zeile pro Spieler
var total := 0
var best := 0
var new_record := false
var play_time := 0.0
var player_count := 1

func _build() -> void:
	if won:
		add_text("GESCHAFFT!", 60, YELLOW)
		add_text("Die Strassen sind wieder sicher.", 20)
	else:
		add_text("GAME OVER", 60, RED)
		add_text("Die Bande war zu stark. Nochmal?", 20)
	add_gap(10.0)
	for line in lines:
		add_text(line, 22)
	add_text("Gesamt: %d" % total, 28, YELLOW)
	var record := "Rekord (%s): %d" % ["1 Spieler" if player_count == 1 else "2 Spieler", best]
	add_text(record + ("   NEU!" if new_record else ""), 20, YELLOW if new_record else LIGHT)
	var seconds := int(play_time)
	add_text("Zeit %d:%02d" % [seconds / 60, seconds % 60], 18, GRAY)
	add_gap(10.0)
	add_button("Nochmal", func(): restart_requested.emit())
	add_button("Menü", func(): menu_requested.emit())
	for button in buttons:
		button.disabled = true
	get_tree().create_timer(LOCK_TIME).timeout.connect(_unlock)

func _unlock() -> void:
	for button in buttons:
		button.disabled = false
	focus_first()
