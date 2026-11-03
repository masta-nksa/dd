class_name WeaponData
extends RefCounted
## Daten aller Dinge, die man tragen kann (Port von `ARTEN` in `waffen.py`).
##   heavy      schwer: bremst, kein Sprung, wird bei Treffern fallen gelassen, zerbricht beim Wurf
##   throw_cost Haltbarkeit, die ein Wurf kostet
##   v          Wurfgeschwindigkeit (vorwärts, hoch) in Pixel pro Sekunde

const TABLE := {
	&"bat": {"name": "SCHLÄGER", "heavy": false, "durability": 10, "throw_cost": 3, "v": Vector2(480, 120),
		"tempo": 1.0, "throw_attack": &"t_bat", "color": Color8(178, 126, 68)},
	&"crate": {"name": "KISTE", "heavy": true, "durability": 1, "throw_cost": 0, "v": Vector2(430, 200),
		"tempo": 0.75, "throw_attack": &"t_crate", "color": Color8(170, 115, 60)},
	&"barrel": {"name": "FASS", "heavy": true, "durability": 1, "throw_cost": 0, "v": Vector2(340, 140),
		"tempo": 0.65, "throw_attack": &"t_barrel", "color": Color8(40, 90, 170)},
	&"bin": {"name": "TONNE", "heavy": true, "durability": 1, "throw_cost": 0, "v": Vector2(400, 180),
		"tempo": 0.75, "throw_attack": &"t_bin", "color": Color8(150, 155, 160)},
}

static func get_data(kind: StringName) -> Dictionary:
	return TABLE[kind]
