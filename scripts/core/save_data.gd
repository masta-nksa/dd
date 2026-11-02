class_name SaveData
extends RefCounted
## Was über mehrere Spiele erhalten bleibt: Rekord (getrennt nach 1 und 2 Spielern) und Musik an/aus.
## `user://` liegt im Browser in IndexedDB. Klappt das Speichern nicht, läuft das Spiel ohne Speicherstand weiter.

static var file_path := "user://doppelfaust.cfg"

var music_on := true
var _best := {1: 0, 2: 0}

func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(file_path) != OK:
		return
	for players in _best:
		_best[players] = maxi(int(cfg.get_value("record", "players_%d" % players, 0)), 0)
	music_on = bool(cfg.get_value("audio", "music", true))

func save_file() -> void:
	var cfg := ConfigFile.new()
	for players in _best:
		cfg.set_value("record", "players_%d" % players, _best[players])
	cfg.set_value("audio", "music", music_on)
	cfg.save(file_path)

func best(players: int) -> int:
	return _best.get(players, 0)

## Trägt die Gesamtpunktzahl ein. Gibt true zurück, wenn sie ein neuer Rekord ist.
func submit(players: int, points: int) -> bool:
	if points <= best(players):
		return false
	_best[players] = points
	save_file()
	return true
