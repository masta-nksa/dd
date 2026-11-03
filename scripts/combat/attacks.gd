class_name Attacks
extends RefCounted
## Alle Angriffe als Daten (entspricht `ANGRIFFE` im Pygame-Spiel).

## Pose jedes Angriffs (siehe `Poses`); alle anderen nutzen &"straight".
const POSES := {&"punch2": &"hook", &"punch3": &"uppercut", &"kick": &"kick", &"spin": &"whirl", &"jump_kick": &"jump_kick",
	&"g_haken": &"hook", &"g_tritt": &"kick", &"g_flinktritt": &"high_kick", &"g_hammer": &"hammer", &"g_rammen": &"ram",
	&"w_bat1": &"swing", &"w_bat2": &"homerun", &"w_homerun": &"homerun", &"throw": &"throw"}

static var _table: Dictionary = {}

static func get_attack(id: StringName) -> AttackData:
	if _table.is_empty():
		_build()
	return _table[id]

static func _make(id: StringName, values: Dictionary) -> void:
	var a := AttackData.new()
	a.id = id
	a.pose = POSES.get(id, &"straight")
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
		"hitstun": 0.4, "reach": 66.0, "box_size": Vector3(52, 30, 40), "box_y": 20.0, "lunge": 30.0})
	_make(&"spin", {"startup": 0.07, "active": 0.22, "recovery": 0.3, "damage": 10, "knockback": 200.0,
		"knockdown": true, "reach": 62.0, "box_size": Vector3(124, 80, 56), "box_y": 10.0,
		"both_sides": true, "health_cost": 4})
	_make(&"jump_kick", {"startup": 0.05, "active": 0.25, "recovery": 0.1, "damage": 14, "knockback": 200.0,
		"knockdown": true, "reach": 58.0, "box_size": Vector3(50, 40, 40), "box_y": 10.0})

	# --- Gegner ---
	_make(&"g_schlag", {"startup": 0.30, "active": 0.08, "recovery": 0.30, "damage": 7, "knockback": 70.0,
		"hitstun": 0.30, "reach": 50.0, "box_size": Vector3(40, 26, 40), "box_y": 50.0,
		"chain_to": &"g_haken", "chain_needs_hit": true})
	_make(&"g_haken", {"startup": 0.18, "active": 0.08, "recovery": 0.40, "damage": 8, "knockback": 180.0,
		"knockdown": true, "reach": 52.0, "box_size": Vector3(42, 26, 40), "box_y": 50.0, "lunge": 40.0})
	_make(&"g_tritt", {"startup": 0.34, "active": 0.10, "recovery": 0.36, "damage": 9, "knockback": 140.0,
		"hitstun": 0.34, "reach": 58.0, "box_size": Vector3(34, 34, 40), "box_y": 24.0})
	_make(&"g_flinktritt", {"startup": 0.22, "active": 0.09, "recovery": 0.30, "damage": 7, "knockback": 150.0,
		"hitstun": 0.32, "reach": 60.0, "box_size": Vector3(48, 48, 40), "box_y": 40.0})
	_make(&"g_hammer", {"startup": 0.50, "active": 0.12, "recovery": 0.50, "damage": 15, "knockback": 300.0,
		"knockdown": true, "reach": 62.0, "box_size": Vector3(54, 70, 44), "box_y": 30.0})
	_make(&"g_rammen", {"startup": 0.40, "active": 0.45, "recovery": 0.45, "damage": 13, "knockback": 320.0,
		"knockdown": true, "reach": 52.0, "box_size": Vector3(52, 70, 50), "box_y": 20.0, "drive": 430.0})

	# --- Baseballschläger ---
	_make(&"w_bat1", {"startup": 0.10, "active": 0.08, "recovery": 0.20, "damage": 12, "knockback": 140.0,
		"hitstun": 0.38, "reach": 78.0, "box_size": Vector3(64, 52, 40), "box_y": 40.0,
		"chain_to": &"w_bat2", "durability": 1})
	_make(&"w_bat2", {"startup": 0.14, "active": 0.09, "recovery": 0.30, "damage": 18, "knockback": 380.0,
		"knockdown": true, "reach": 82.0, "box_size": Vector3(70, 60, 44), "box_y": 36.0, "lunge": 70.0,
		"durability": 1})
	_make(&"w_homerun", {"startup": 0.14, "active": 0.09, "recovery": 0.30, "damage": 18, "knockback": 380.0,
		"knockdown": true, "reach": 82.0, "box_size": Vector3(70, 60, 44), "box_y": 36.0, "lunge": 70.0,
		"durability": 2})
	# --- Werfen: der Wurf selbst richtet keinen Schaden an, erst das fliegende Geschoss ---
	_make(&"throw", {"startup": 0.12, "active": 0.02, "recovery": 0.22, "damage": 0, "throws": true})
	_make(&"t_bat", {"damage": 14, "knockback": 200.0, "hitstun": 0.6})
	_make(&"t_crate", {"damage": 18, "knockback": 140.0, "hitstun": 1.2})
	_make(&"t_barrel", {"damage": 24, "knockback": 300.0, "knockdown": true})
	_make(&"t_bin", {"damage": 12, "knockback": 120.0, "hitstun": 1.0})
