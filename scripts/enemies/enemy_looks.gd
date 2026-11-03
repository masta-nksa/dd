class_name EnemyLooks
extends RefCounted
## Aussehen der Gegner: Je Typ mehrere Varianten aus Modell und Zonenfarben. Beim Auftauchen bekommt jeder Gegner eine zufällige,
## so sieht keine Welle aus wie die andere. Die Modelle stehen in `tools/blender/build_fighter.py` (`ENEMIES`, `ENEMY_VARIANTS`),
## die Zonen heissen dort wie hier (`skin`, `hair`, `top`, `trim`, `pants`, `shoes`, `belt` ...). Fehlt eine Zone in `colors`,
## bleibt die Farbe des Modells. Ohne Modell zeichnet `FigureArt` die Figur mit den passenden Farben aus `skin_for`.
##   model   Modell der Variante (`enemy_<model>.glb`)
##   colors  {Zone: Farbe}; eine neue Hautfarbe (`skin`) färbt die Schattenlinien mit

const LOOKS := {
	&"thug": [
		{"model": &"thug", "colors": {}},
		{"model": &"thug", "colors": {"top": Color8(196, 58, 52), "trim": Color8(150, 40, 36), "pants": Color8(48, 48, 56),
			"hair": Color8(24, 20, 18), "shoes": Color8(40, 30, 26)}},
		{"model": &"thug", "colors": {"top": Color8(58, 98, 190), "trim": Color8(40, 70, 150), "pants": Color8(34, 42, 62),
			"hair": Color8(216, 178, 72), "skin": Color8(236, 196, 156)}},
		{"model": &"thug", "colors": {"top": Color8(122, 64, 152), "trim": Color8(90, 44, 120), "pants": Color8(30, 30, 40),
			"hair": Color8(20, 16, 14), "skin": Color8(132, 88, 60)}},
		{"model": &"thug_cap", "colors": {"top": Color8(130, 134, 146), "trim": Color8(96, 100, 112), "pants": Color8(44, 44, 50),
			"hat": Color8(52, 52, 62), "skin": Color8(214, 160, 120)}},
		{"model": &"thug_cap", "colors": {"top": Color8(232, 134, 44), "trim": Color8(180, 96, 28), "pants": Color8(60, 48, 40),
			"hat": Color8(232, 134, 44), "skin": Color8(190, 138, 100)}},
	],
	&"dasher": [
		{"model": &"dasher", "colors": {}},
		{"model": &"dasher", "colors": {"hair": Color8(255, 84, 178), "top": Color8(255, 150, 210), "pants": Color8(96, 34, 74),
			"shoes": Color8(255, 255, 255), "skin": Color8(238, 196, 160)}},
		{"model": &"dasher", "colors": {"hair": Color8(70, 200, 255), "top": Color8(110, 170, 255), "pants": Color8(30, 50, 110),
			"skin": Color8(152, 104, 70)}},
		{"model": &"dasher_spiky", "colors": {"hair": Color8(255, 160, 40), "top": Color8(255, 200, 90), "pants": Color8(92, 52, 30),
			"shoes": Color8(240, 240, 240)}},
		{"model": &"dasher_spiky", "colors": {"hair": Color8(180, 90, 255), "top": Color8(205, 150, 255), "pants": Color8(50, 30, 90),
			"shoes": Color8(80, 230, 120), "skin": Color8(220, 170, 130)}},
	],
	&"brute": [
		{"model": &"brute", "colors": {}},
		{"model": &"brute", "colors": {"top": Color8(150, 34, 34), "trim": Color8(100, 22, 22), "pants": Color8(50, 50, 56),
			"buckle": Color8(210, 210, 220)}},
		{"model": &"brute", "colors": {"top": Color8(40, 76, 150), "trim": Color8(26, 50, 104), "skin": Color8(204, 150, 112),
			"beard": Color8(140, 92, 52)}},
		{"model": &"brute_bare", "colors": {"pants": Color8(60, 60, 74), "belt": Color8(30, 30, 34), "skin": Color8(176, 124, 88)}},
		{"model": &"brute_bare", "colors": {"pants": Color8(74, 40, 34), "buckle": Color8(220, 190, 70), "skin": Color8(116, 76, 52)}},
	],
	&"boss": [
		{"model": &"boss", "colors": {}},
	],
}

static var _rng := RandomNumberGenerator.new()
static var _seeded := false

## Eine Variante des Typs: index < 0 würfelt (mit eigenem Zufall, der das Spielgeschehen nicht verschiebt).
static func pick(type: StringName, index := -1) -> Dictionary:
	var list: Array = LOOKS[type]
	if index < 0:
		if not _seeded:
			_rng.randomize()
			_seeded = true
		index = _rng.randi_range(0, list.size() - 1)
	return list[index % list.size()]

static func count(type: StringName) -> int:
	return LOOKS[type].size()

## Die 2D-Farben für `FigureArt` (Ersatz ohne Modell): gleiche Zonennamen, beim Brocken heisst das Oberteil `vest`.
static func skin_for(base: Dictionary, type: StringName, look: Dictionary) -> Dictionary:
	var out := base.duplicate()
	var colors: Dictionary = look["colors"]
	for key in ["skin", "hair", "top", "pants", "shoes", "belt"]:
		if colors.has(key):
			out["vest" if key == "top" and type == &"brute" else key] = colors[key]
	return out
