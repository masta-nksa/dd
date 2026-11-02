class_name MenuScreen
extends Screen
## Hauptmenü: 1 oder 2 Spieler, Musik, Steuerung und Rekord.

signal start_requested(two_players: bool)
signal music_requested

var save: SaveData
var music_button: Button

func _build() -> void:
	add_text("DOPPELFAUST", 64, YELLOW)
	add_text("Ein Beat-'em-up für eine oder zwei Personen", 18)
	add_gap(10.0)
	add_button("1 Spieler", func(): start_requested.emit(false))
	add_button("2 Spieler", func(): start_requested.emit(true))
	music_button = add_button("", func(): music_requested.emit())
	refresh_music()
	add_gap(10.0)
	add_text("1P:  WASD  ·  Leertaste Sprung  ·  F Schlag  ·  G Tritt  ·  R Spezial  ·  E Greifen", 15)
	add_text("2P:  Pfeile  ·  O Sprung  ·  K Schlag  ·  L Tritt  ·  I Spezial  ·  J Greifen", 15)
	add_text("Controller:  Stick/Kreuz  ·  A Sprung  ·  X Schlag  ·  B Tritt  ·  Y Spezial  ·  RB Greifen", 15, GRAY)
	add_text("Esc, P, Start Pause  ·  M Musik  ·  F1 Hitboxen", 15, GRAY)
	add_gap(6.0)
	add_text("Rekord:  1 Spieler %d  ·  2 Spieler %d" % [save.best(1), save.best(2)], 18, YELLOW)

func refresh_music() -> void:
	music_button.text = "Musik: an" if save.music_on else "Musik: aus"
