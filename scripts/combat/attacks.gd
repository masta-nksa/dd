class_name Attacks
extends RefCounted
## Alle Angriffe als Daten (entspricht `ANGRIFFE` im Pygame-Spiel).

static var _table: Dictionary = {}

static func get_attack(id: StringName) -> AttackData:
	if _table.is_empty():
		_build()
	return _table[id]

static func _make(id: StringName, values: Dictionary) -> void:
	var a := AttackData.new()
	a.id = id
	for key in values:
		a.set(key, values[key])
	_table[id] = a

static func _build() -> void:
	_make(&"punch1", {"startup": 0.06, "active": 0.06, "recovery": 0.2, "damage": 10, "knockback": 60.0,
		"reach": 52.0, "box_size": Vector3(40, 40, 40), "box_y": 40.0, "lunge": 40.0, "chain_to": &"punch2"})
	_make(&"punch2", {"startup": 0.06, "active": 0.06, "recovery": 0.2, "damage": 12, "knockback": 80.0,
		"reach": 54.0, "box_size": Vector3(42, 40, 40), "box_y": 40.0, "lunge": 50.0, "chain_to": &"punch3"})
	_make(&"punch3", {"startup": 0.09, "active": 0.07, "recovery": 0.3, "damage": 18, "knockback": 260.0,
		"knockdown": true, "reach": 60.0, "box_size": Vector3(48, 44, 44), "box_y": 36.0, "lunge": 70.0})
	_make(&"kick", {"startup": 0.1, "active": 0.08, "recovery": 0.28, "damage": 14, "knockback": 160.0,
		"hitstun": 0.4, "reach": 66.0, "box_size": Vector3(52, 30, 40), "box_y": 20.0, "lunge": 30.0, "pose": &"kick"})
	_make(&"spin", {"startup": 0.07, "active": 0.22, "recovery": 0.3, "damage": 10, "knockback": 200.0,
		"knockdown": true, "reach": 62.0, "box_size": Vector3(124, 80, 56), "box_y": 10.0,
		"both_sides": true, "health_cost": 4, "pose": &"spin"})
	_make(&"jump_kick", {"startup": 0.05, "active": 0.25, "recovery": 0.1, "damage": 14, "knockback": 200.0,
		"knockdown": true, "reach": 58.0, "box_size": Vector3(50, 40, 40), "box_y": 10.0, "pose": &"kick"})
