class_name FighterData
extends RefCounted
## Die acht wählbaren Kämpfer: Werte, Aussehen (2D-`Skins`, Porträt und Ersatz) und Modell.
## Hauptauswahl: Bruce, Chuck, Jackie, JCVD. Zusätzlich: Kai, Ria, Bruno, Mika (Werte aus dem Pygame-Konzept,
## `docs/PROJEKTSTAND.md` Abschnitt 9, dort Kai und Ria aus `figuren.py`). Die Werte der Hauptauswahl sind ein Vorschlag.
##   hp, speed_x, speed_z, jump_speed, weight    wie `Fighter`
##   damage      Schadensfaktor        attack_speed  Faktor auf die Angriffszeiten (höher = schneller)
##   reach       Reichweite der Treffer-Quader

const MAIN := [&"bruce", &"chuck", &"jackie", &"jcvd"]
const EXTRA := [&"kai", &"ria", &"bruno", &"mika"]
const DEFAULT_PICKS: Array[StringName] = [&"kai", &"ria"]   # Tests und direkter Start über `Main`

## Spannen für die Wertebalken: [kleinster, grösster Wert] in der Auswahl.
const RANGES := {
	"hp": [90.0, 110.0], "speed_x": [145.0, 195.0], "jump_speed": [570.0, 680.0], "weight": [0.85, 1.35],
	"damage": [0.95, 1.10], "attack_speed": [0.88, 1.18], "reach": [0.93, 1.18],
}

const TABLE := {
	&"bruce": {"name": "BRUCE", "role": "Blitzschneller Schlagkämpfer", "skin": Skins.BRUCE,
		"hp": 96, "speed_x": 190.0, "speed_z": 124.0, "jump_speed": 650.0, "weight": 0.90,
		"damage": 1.00, "attack_speed": 1.15, "reach": 1.00},
	&"chuck": {"name": "CHUCK", "role": "Wuchtiges Schwergewicht", "skin": Skins.CHUCK,
		"hp": 106, "speed_x": 160.0, "speed_z": 105.0, "jump_speed": 600.0, "weight": 1.20,
		"damage": 1.06, "attack_speed": 0.95, "reach": 1.00},
	&"jackie": {"name": "JACKIE", "role": "Akrobat mit höchstem Sprung", "skin": Skins.JACKIE,
		"hp": 100, "speed_x": 180.0, "speed_z": 120.0, "jump_speed": 670.0, "weight": 0.95,
		"damage": 0.98, "attack_speed": 1.08, "reach": 1.05},
	&"jcvd": {"name": "JCVD", "role": "Trittspezialist mit langen Beinen", "skin": Skins.JCVD,
		"hp": 102, "speed_x": 170.0, "speed_z": 112.0, "jump_speed": 630.0, "weight": 1.10,
		"damage": 1.02, "attack_speed": 1.00, "reach": 1.15},
	&"kai": {"name": "KAI", "role": "Allrounder", "skin": Skins.KAI,
		"hp": 100, "speed_x": 175.0, "speed_z": 115.0, "jump_speed": 620.0, "weight": 1.00,
		"damage": 1.00, "attack_speed": 1.00, "reach": 1.00},
	&"ria": {"name": "RIA", "role": "Schnelle Kombo-Kämpferin", "skin": Skins.RIA,
		"hp": 100, "speed_x": 193.0, "speed_z": 126.0, "jump_speed": 660.0, "weight": 0.92,
		"damage": 0.97, "attack_speed": 1.12, "reach": 1.00},
	&"bruno": {"name": "BRUNO", "role": "Schwergewicht", "skin": Skins.BRUNO,
		"hp": 108, "speed_x": 150.0, "speed_z": 100.0, "jump_speed": 580.0, "weight": 1.30,
		"damage": 1.08, "attack_speed": 0.90, "reach": 0.95},
	&"mika": {"name": "MIKA", "role": "Technikerin mit weiten Tritten", "skin": Skins.MIKA,
		"hp": 98, "speed_x": 170.0, "speed_z": 118.0, "jump_speed": 640.0, "weight": 0.95,
		"damage": 0.97, "attack_speed": 1.00, "reach": 1.15},
}

static func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(MAIN + EXTRA)
	return ids

static func get_data(id: StringName) -> Dictionary:
	return TABLE[id]

static func skin_of(id: StringName) -> Dictionary:
	return TABLE[id]["skin"]

## Pfad des Blender-Modells; die Datei entsteht erst im Build (`tools/blender/build_fighter.py`).
static func model_path(id: StringName) -> String:
	return "res://assets/characters/player_%s.glb" % id

## Anteil für den Wertebalken (0,15 bis 1,0).
static func bar(id: StringName, key: String) -> float:
	var range: Array = RANGES[key]
	var v: float = TABLE[id][key]
	return 0.15 + 0.85 * clampf((v - range[0]) / (range[1] - range[0]), 0.0, 1.0)

## Überträgt Werte und Aussehen auf einen Kämpfer (vor `add_child` aufrufen).
static func apply(f: Fighter, id: StringName) -> void:
	var d: Dictionary = TABLE[id]
	f.fighter_id = id
	f.skin = d["skin"]
	f.max_health = d["hp"]
	f.current_health = d["hp"]
	f.speed_x = d["speed_x"]
	f.speed_z = d["speed_z"]
	f.jump_speed = d["jump_speed"]
	f.weight = d["weight"]
	f.damage_factor = d["damage"]
	f.attack_speed = d["attack_speed"]
	f.reach_factor = d["reach"]
