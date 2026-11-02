class_name Fighter3D
extends CharacterBody3D
## 3D-Kämpfer für das 2.5D-Spiel. X = horizontal, Z = Tiefe/Spur, Y = Sprung.
## Lädt ein Modell (z. B. `player_bruce.glb`, Blickrichtung +Z, T-Pose) und steuert es per Tastatur.
## Angriffe sind Platzhalter: Zustand, Zeiten und Signale stehen, Schaden und Hitboxen folgen,
## sobald dieser Kämpfer ans bestehende Kampfsystem (`AttackData`/`CombatSystem`) angeschlossen wird.
## Hinweis: Das Spiel selbst nutzt bisher `Fighter` (Node2D). Dies ist die 3D-Variante daneben.

signal attack_started(attack_id: StringName)
signal attack_finished(attack_id: StringName)

enum State { IDLE, WALK, JUMP, ATTACK }

@export_range(1, 2) var player_index := 1             # nutzt die Aktionen p1_* bzw. p2_* aus `InputSetup`
@export var model_scene: PackedScene                   # z. B. res://assets/characters/player_bruce.glb
@export var move_speed := 4.0                          # m/s in X
@export var depth_speed := 2.6                         # m/s in Z
@export var jump_velocity := 6.5
@export var gravity := 18.0
@export var depth_range := Vector2(-1.5, 1.5)          # erlaubte Z-Spur
@export var model_scale := 1.0

## Platzhalter-Angriffe: Zeiten in Sekunden, Schaden/Reichweite nur als Richtwert.
const ATTACKS := {
	&"power_punch": {"action": &"punch", "startup": 0.10, "active": 0.08, "recovery": 0.25, "damage": 14, "reach": 0.9, "height": 1.3},
	&"high_kick": {"action": &"kick", "startup": 0.14, "active": 0.10, "recovery": 0.32, "damage": 16, "reach": 1.2, "height": 1.6},
}

var state := State.IDLE
var facing := 1                  # 1 = rechts (+X), -1 = links
var attack_id: StringName = &""
var attack_time := 0.0

var _model: Node3D
var _skeleton: Skeleton3D

func _ready() -> void:
	if model_scene:
		_model = model_scene.instantiate()
		_model.scale = Vector3.ONE * model_scale
		add_child(_model)
		_skeleton = _find_skeleton(_model)
	_apply_facing()

func _physics_process(delta: float) -> void:
	match state:
		State.ATTACK:
			_tick_attack(delta)
		_:
			_tick_movement(delta)
	_apply_pose()

# --- Bewegung -------------------------------------------------------------------------

func _tick_movement(delta: float) -> void:
	var dir := Input.get_vector(_a("left"), _a("right"), _a("up"), _a("down"))
	velocity.x = dir.x * move_speed
	velocity.z = dir.y * depth_speed       # "hoch" = weiter weg (-Z), "runter" = zur Kamera (+Z)
	if dir.x != 0.0:
		facing = 1 if dir.x > 0.0 else -1
		_apply_facing()

	if is_on_floor():
		if Input.is_action_just_pressed(_a("jump")):
			velocity.y = jump_velocity
		else:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	for action in ATTACKS:
		if Input.is_action_just_pressed(_a(ATTACKS[action]["action"])):
			start_attack(action)
			return

	move_and_slide()
	global_position.z = clampf(global_position.z, depth_range.x, depth_range.y)
	if not is_on_floor():
		state = State.JUMP
	else:
		state = State.WALK if dir != Vector2.ZERO else State.IDLE

func start_attack(id: StringName) -> void:
	if not ATTACKS.has(id):
		return
	attack_id = id
	attack_time = 0.0
	state = State.ATTACK
	velocity.x = 0.0
	velocity.z = 0.0
	attack_started.emit(id)

func _tick_attack(delta: float) -> void:
	attack_time += delta
	var data: Dictionary = ATTACKS[attack_id]
	# Am Boden bleiben, in der Luft weiter fallen
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	if attack_time >= data["startup"] + data["active"] + data["recovery"]:
		var finished := attack_id
		attack_id = &""
		state = State.IDLE
		attack_finished.emit(finished)

## true, solange die Hitbox des laufenden Angriffs wirken soll (hier später `HitBox` anbinden).
func is_attack_active() -> bool:
	if state != State.ATTACK:
		return false
	var data: Dictionary = ATTACKS[attack_id]
	return attack_time >= data["startup"] and attack_time < data["startup"] + data["active"]

# --- Darstellung ----------------------------------------------------------------------

func _apply_facing() -> void:
	if _model:
		_model.rotation.y = PI / 2.0 * facing     # Modell schaut +Z, Spiel läuft entlang X

## Einfache Posen über das Skelett (Knochennamen aus `tools/blender/build_fighter.py`).
## Fehlt das Skelett, passiert nichts. Echte Animationen ersetzen das später.
func _apply_pose() -> void:
	if _skeleton == null:
		return
	_skeleton.reset_bone_poses()
	match attack_id:
		&"power_punch":
			_rotate_bone("upper_arm.L", Vector3(0, 1, 0), -deg_to_rad(70.0) * _swing())
			_rotate_bone("chest", Vector3(0, 1, 0), deg_to_rad(20.0) * _swing())
		&"high_kick":
			_rotate_bone("thigh.L", Vector3(1, 0, 0), -deg_to_rad(100.0) * _swing())
		_:
			pass
	# T-Pose ist Rest-Pose: Arme für den Kampf etwas nach unten nehmen
	_rotate_bone("upper_arm.L", Vector3(0, 0, 1), -deg_to_rad(55.0) if attack_id != &"power_punch" else 0.0)
	_rotate_bone("upper_arm.R", Vector3(0, 0, 1), deg_to_rad(55.0))

func _swing() -> float:
	## 0 -> 1 -> 0 über die Angriffsdauer, Höhepunkt in der aktiven Phase
	if attack_id == &"":
		return 0.0
	var data: Dictionary = ATTACKS[attack_id]
	var total: float = data["startup"] + data["active"] + data["recovery"]
	return sin(clampf(attack_time / total, 0.0, 1.0) * PI)

## Dreht einen Knochen aus der Rest-Pose heraus. Die Achse gilt im Knochen-Raum (Knochen zeigt
## entlang seiner Y-Achse); die Winkel hier sind Startwerte und müssen am echten Modell feinjustiert werden.
func _rotate_bone(bone_name: String, axis: Vector3, angle: float) -> void:
	var idx := _skeleton.find_bone(bone_name)
	if idx < 0:
		return
	var q := _skeleton.get_bone_pose_rotation(idx)
	_skeleton.set_bone_pose_rotation(idx, Quaternion(axis.normalized(), angle) * q)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _a(action: String) -> StringName:
	return StringName("p%d_%s" % [player_index, action])
