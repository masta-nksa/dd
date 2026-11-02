class_name WeaponData
extends RefCounted
## Daten aller Dinge, die man tragen kann (Port von `ARTEN` in `waffen.py`).
##   heavy      schwer: bremst, kein Sprung, wird bei Treffern fallen gelassen, zerbricht beim Wurf
##   throw_cost Haltbarkeit, die ein Wurf kostet
##   v          Wurfgeschwindigkeit (vorwärts, hoch) in Pixel pro Sekunde

const TABLE := {
	&"bat": {"name": "SCHLÄGER", "heavy": false, "durability": 10, "throw_cost": 3, "v": Vector2(480, 120),
		"tempo": 1.0, "throw_attack": &"t_bat", "color": Color(0.70, 0.49, 0.27)},
	&"crate": {"name": "KISTE", "heavy": true, "durability": 1, "throw_cost": 0, "v": Vector2(430, 200),
		"tempo": 0.75, "throw_attack": &"t_crate", "color": Color(0.67, 0.45, 0.24)},
	&"barrel": {"name": "FASS", "heavy": true, "durability": 1, "throw_cost": 0, "v": Vector2(340, 140),
		"tempo": 0.65, "throw_attack": &"t_barrel", "color": Color(0.16, 0.35, 0.67)},
	&"bin": {"name": "TONNE", "heavy": true, "durability": 1, "throw_cost": 0, "v": Vector2(400, 180),
		"tempo": 0.75, "throw_attack": &"t_bin", "color": Color(0.59, 0.61, 0.63)},
}

static func get_data(kind: StringName) -> Dictionary:
	return TABLE[kind]
