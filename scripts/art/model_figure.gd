class_name ModelFigure
extends Node
## Ein 3D-Kämpfer (geriggte `.glb`, 17 Knochen) im 2D-Spiel. Das Modell steht in einem eigenen `SubViewport`
## mit orthografischer Seitenkamera; das Bild zeichnet der `Fighter` an die Stelle der 2D-Figur.
## Die Haltung kommt aus denselben Gelenkwinkeln wie bei `FigureArt` (siehe `Poses`), die Spielregeln bleiben 2D.
## Modell: Blick +Z, T-Pose, Knochennamen wie in `tools/blender/build_fighter.py`. Fehlt die Datei, gibt `create` null zurück
## und der Aufrufer zeichnet weiter mit `FigureArt`.

const VIEW_SIZE := 256            # Pixel des Teilbilds (doppelt aufgelöst, wird auf die halbe Grösse gezeichnet)
const VIEW_METERS := 2.42         # sichtbare Höhe in Metern
const FEET_MARGIN := 0.25         # Meter zwischen Fusspunkt und unterem Bildrand
const PX_PER_M := 52.8            # Spielpixel pro Meter: FigureArt ist 95 px für 1,8 m gross
const DRAW_K := PX_PER_M * VIEW_METERS / VIEW_SIZE
const HAND_EXTRA := 0.07          # vom Handgelenk bis zur Mitte der Faust

## Tests im Headless-Betrieb rendern nichts; dort bleibt es bei der 2D-Figur, ausser `force` ist gesetzt.
static var force := false

var fighter_id: StringName
var skeleton: Skeleton3D

var _viewport: SubViewport
var _outer: Node3D            # Versatz in Bildschirmrichtung (Fallen)
var _pivot: Node3D            # Kippen um die Bildachse (turn)
var _model: Node3D            # Blickrichtung (Drehung um die Hochachse), Bodenabstand
var _environment: Environment
var _sun: DirectionalLight3D
var _rest_global: Array[Transform3D] = []   # Rast-Pose im Skelett-Raum (`get_bone_global_rest` ist in Godot 4.4 nicht verlässlich)
var _rest_foot_y := 0.0
var _flash := false
var _front := "R"
var _back := "L"

static func available(id: StringName) -> bool:
	return (force or DisplayServer.get_name() != "headless") and ResourceLoader.exists(FighterData.model_path(id))

static func create(id: StringName) -> ModelFigure:
	if not available(id):
		return null
	var scene := load(FighterData.model_path(id)) as PackedScene
	if scene == null:
		return null
	var figure := ModelFigure.new()
	if not figure._build(id, scene.instantiate()):
		figure.free()
		return null
	return figure

func _build(id: StringName, instance: Node) -> bool:
	fighter_id = id
	skeleton = _find_skeleton(instance)
	if skeleton == null or skeleton.find_bone("hips") < 0:
		instance.free()
		return false
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(VIEW_SIZE, VIEW_SIZE)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_outer = Node3D.new()
	_pivot = Node3D.new()
	_model = instance as Node3D
	_viewport.add_child(_outer)
	_outer.add_child(_pivot)
	_pivot.add_child(_model)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VIEW_METERS
	camera.position = Vector3(0.0, VIEW_METERS * 0.5 - FEET_MARGIN, 5.0)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_CLEAR_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color.WHITE
	camera.environment = _environment
	_viewport.add_child(camera)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-42.0, 22.0, 0.0)
	_viewport.add_child(_sun)
	_set_flash(false)
	skeleton.reset_bone_poses()
	for i in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(i)
		_rest_global.append((_rest_global[parent] if parent >= 0 else Transform3D.IDENTITY) * skeleton.get_bone_rest(i))
	_rest_foot_y = _lowest_foot()
	return true

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _set_flash(on: bool) -> void:
	_flash = on
	_environment.ambient_light_energy = 9.0 if on else 0.6
	_sun.light_energy = 4.0 if on else 1.1

# ---------------------------------------------------------------- Haltung

## Stellt die Figur in die Haltung `pose` (Gelenkwinkel wie in `FigureArt`). Blickt sie nach links, ist das linke
## Körperteil das vordere, weil die Kamera von der Seite auf diese Körperhälfte schaut.
func set_pose(pose: Dictionary, facing: int, flash := false) -> void:
	if flash != _flash:
		_set_flash(flash)
	var dir := -facing if pose["flip"] > 0.5 else facing
	_front = "R" if dir > 0 else "L"
	_back = "L" if dir > 0 else "R"
	skeleton.reset_bone_poses()
	var hips := skeleton.find_bone("hips")
	skeleton.set_bone_pose_position(hips, skeleton.get_bone_rest(hips).origin - Vector3(0.0, pose["low"] / PX_PER_M, 0.0))
	_tilt("spine", pose["lean"])
	_tilt("head", pose["head"])
	_aim("upper_arm." + _front, pose["fs"])
	_aim("forearm." + _front, pose["fs"] + pose["fe"])
	_aim("upper_arm." + _back, pose["bs"])
	_aim("forearm." + _back, pose["bs"] + pose["be"])
	_aim("thigh." + _front, pose["fh"])
	_aim("shin." + _front, pose["fh"] - pose["fk"])
	_aim("thigh." + _back, pose["bh"])
	_aim("shin." + _back, pose["bh"] - pose["bk"])

	var turn: float = pose["turn"]
	var turn_rad := deg_to_rad(turn)
	_model.rotation.y = dir * PI * 0.5
	_pivot.rotation.z = -dir * turn_rad
	_outer.position = Vector3(dir * -sin(turn_rad) * 40.0 / PX_PER_M, absf(sin(turn_rad)) * 7.0 / PX_PER_M, 0.0)
	# Steht die Figur, kommt der tiefste Fuss genau auf den Boden
	_model.position.y = 0.0 if absf(turn) >= 1.0 else -(_lowest_foot() - _rest_foot_y)

## Vordere Hand, vorderer Ellbogen, hintere Hand, hinterer Ellbogen: Spielpixel um den Fusspunkt, wie `FigureArt` sie liefert.
func hands(k: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for side in [_front, _back]:
		var wrist := _view_point("hand." + side)
		var elbow := _view_point("forearm." + side)
		var hand := wrist + (wrist - elbow).normalized() * HAND_EXTRA
		out.append(_to_px(hand, k))
		out.append(_to_px(elbow, k))
	return out

func _to_px(view: Vector3, k: float) -> Vector2:
	return Vector2(view.x, -view.y) * PX_PER_M * k

## Knochen um die Seitenachse neigen (positiv = nach vorn, +Z), unabhängig von der Rast-Ausrichtung.
func _tilt(bone: String, degrees: float) -> void:
	var i := skeleton.find_bone(bone)
	if i < 0 or is_zero_approx(degrees):
		return
	var q := Quaternion(Vector3.RIGHT, deg_to_rad(degrees))
	var rest_global := _rest_global[i].basis.get_rotation_quaternion()
	var rest_local := skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(i, rest_local * (rest_global.inverse() * q * rest_global))

## Richtet einen Knochen auf den nächsten (Kindknochen = Index + 1) aus. Winkel: 0 = gerade nach unten, positiv = nach vorn.
## Die Eltern müssen vorher gesetzt sein (Reihenfolge der Aufrufe in `set_pose`).
func _aim(bone: String, degrees: float) -> void:
	var i := skeleton.find_bone(bone)
	if i < 0:
		return
	var rest_dir := (_rest_global[i + 1].origin - _rest_global[i].origin).normalized()
	var a := deg_to_rad(degrees)
	var target := Vector3(0.0, -cos(a), sin(a))
	var parent_global := skeleton.get_bone_global_pose(skeleton.get_bone_parent(i)).basis.get_rotation_quaternion()
	var rest_global := _rest_global[i].basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(i, parent_global.inverse() * (Quaternion(rest_dir, target) * rest_global))

## Punkt in Modellkoordinaten: vom Skelett aufwärts bis zur Wurzel des Modells.
func _model_point(p: Vector3) -> Vector3:
	var n: Node = skeleton
	while n != _model:
		p = (n as Node3D).transform * p
		n = n.get_parent()
	return p

## Ort eines Knochens im Bildraum (Meter, Fusspunkt = Nullpunkt, +y oben).
func _view_point(bone: String) -> Vector3:
	var p := _model_point(skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin)
	return (_outer.transform * _pivot.transform * _model.transform) * p

func _lowest_foot() -> float:
	var lowest := INF
	for bone in ["foot.L", "foot.R"]:
		lowest = minf(lowest, _model_point(skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin).y)
	return lowest

# ---------------------------------------------------------------- Zeichnen

## Zeichnet das Bild mit dem Fusspunkt bei (x, y); k = Körpergrösse (`Fighter.body_scale`).
func draw(ci: CanvasItem, x: float, y: float, k := 1.0) -> void:
	var size := VIEW_SIZE * DRAW_K * k
	var feet_v := (VIEW_SIZE - FEET_MARGIN * VIEW_SIZE / VIEW_METERS) * DRAW_K * k
	ci.draw_texture_rect(_viewport.get_texture(), Rect2(Vector2(x - size * 0.5, y - feet_v), Vector2(size, size)), false)
