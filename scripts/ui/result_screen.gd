class_name ResultScreen
extends Screen
## Game Over oder Sieg: Figuren, Punkte je Spieler, Gesamtpunktzahl, Rekord und Zeit.

signal restart_requested
signal menu_requested

const LOCK_TIME := 1.0   # Sekunden, damit man nicht aus Versehen sofort weiterdrückt

var won := false
var lines: Array[String] = []     # eine Zeile pro Spieler
var skins: Array[Dictionary] = []
var total := 0
var best := 0
var new_record := false
var play_time := 0.0
var player_count := 1

func _build() -> void:
	if won:
		add_title("GESCHAFFT!", 96.0)
		add_text("Die Strassen sind wieder sicher.", 32.0)
	else:
		add_title("GAME OVER", 96.0, RED)
		add_text("Die Bande war zu stark. Nochmal?", 32.0)
	add_gap(8.0)
	for i in lines.size():
		add_text(lines[i], 28.0, Art.PLAYER_COLORS[i])
	add_text("Gesamt: %d" % total, 38.0, YELLOW)
	var record := "Rekord (%s): %d" % ["1 Spieler" if player_count == 1 else "2 Spieler", best]
	add_text(record + ("   NEU!" if new_record else ""), 28.0, YELLOW if new_record else LIGHT)
	var seconds := int(play_time)
	add_text("Zeit %d:%02d" % [seconds / 60, seconds % 60], 24.0, GRAY)
	add_gap(8.0)
	add_button("Nochmal", func(): restart_requested.emit())
	add_button("Menü", func(): menu_requested.emit())
	for button in buttons:
		button.disabled = true
	get_tree().create_timer(LOCK_TIME).timeout.connect(_unlock)
	for i in skins.size():
		var hero := add_hero(skins[i], Art.PLAYER_COLORS[i], Vector2(130.0 if i == 0 else 830.0, 400.0), 1 if i == 0 else -1, 1.9)
		hero.mode = HeroFigure.Mode.CHEER if won else HeroFigure.Mode.LYING

func _unlock() -> void:
	for button in buttons:
		button.disabled = false
	focus_first()
