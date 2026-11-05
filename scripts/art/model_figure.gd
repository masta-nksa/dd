class_name ModelFigure
extends Node
## Ein 3D-Kämpfer (geriggte `.glb`, 17 Knochen) im 2D-Spiel. Das Modell steht in einem eigenen `SubViewport`
## mit orthografischer Seitenkamera; das Bild zeichnet der `Fighter` an die Stelle der 2D-Figur.
## Die Haltung kommt aus denselben Gelenkwinkeln wie bei `FigureArt` (siehe `Poses`), die Spielregeln bleiben 2D.
## Hat das Modell einen Clip zum Angriff (`tools/blender/fighter_clips.py`), zeigt `set_clip` stattdessen diesen.
## Modell: Blick +Z, T-Pose, Knochennamen wie in `tools/blender/build_fighter.py`. Fehlt die Datei, gibt `create` null zurück
## und der Aufrufer zeichnet weiter mit `FigureArt`.

const VIEW_SIZE := 256            # Pixel des Teilbilds (doppelt aufgelöst, wird auf die halbe Grösse gezeichnet)
const LITE_VIEW_SIZE := 160       # Gegner: kleineres Teilbild, 2-fach geglättet und nur jedes zweite Bild neu gerechnet (Browser-Leistung)
const VIEW_METERS := 2.42         # sichtbare Höhe in Metern
const FEET_MARGIN := 0.25         # Meter zwischen Fusspunkt und unterem Bildrand
const PX_PER_M := 52.8            # Spielpixel pro Meter: FigureArt ist 95 px für 1,8 m gross
const HAND_EXTRA := 0.07          # vom Handgelenk bis zur Mitte der Faust
const BLEND_FRAMES := 5           # so viele gezeichnete Bilder dauert der Übergang von und zu einem Clip
const AIR_CLIPS: Array[StringName] = [&"jump_kick"]   # ohne stehenden Fuss: hier gilt der tiefste Fuss als Boden
const BAT_PATH := "res://assets/characters/weapon_bat.glb"
const BAT_TIP := 0.668            # von der vorderen Faust bis zur Spitze des Schlägers (Meter, `BAT_PROFILE` im Blender-Skript)

## Tests im Headless-Betrieb rendern nichts; dort bleibt es bei der 2D-Figur, ausser `force` ist gesetzt.
static var force := false
static var active_count := 0      # wie viele Modelle gerade gezeichnet werden (für die F2-Anzeige)

var fighter_id: StringName
var skeleton: Skeleton3D

var _viewport: SubViewport
var lite := false             # Gegner: kleineres Teilbild, nur jedes zweite Bild neu gerechnet
var _view_size := VIEW_SIZE
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
var _clips := {}              # "kick_high_R" -> {"anim": Animation, "rotation": {Knochen: Spur}, "hips": Spur}
var _source: StringName = &""   # was gerade gezeigt wird: leer = noch nichts, &"pose" oder der Clipname
var _source_dir := 1
var _blend_left := 0
var _blend_rotation: Array[Quaternion] = []
var _blend_hips := Vector3.ZERO
var _last_rotation: Array[Quaternion] = []
var _last_hips := Vector3.ZERO
var _active := false          # false: ausserhalb des Bilds, das Teilbild wird nicht neu gezeichnet; true ab dem Bau
var _bat: Node3D = null       # sitzt an der vorderen Hand und zeigt, wohin der Handknochen zeigt
var _bat_cracks: Node3D = null

## Pfad des Modells: Kämpfer als `player_<id>.glb`, Gegner und ihre Varianten als `enemy_<id>.glb`.
static func path_for(id: StringName) -> String:
	if FighterData.TABLE.has(id):
		return FighterData.model_path(id)
	return "res://assets/characters/enemy_%s.glb" % id

static func bat_available() -> bool:
	return (force or DisplayServer.get_name() != "headless") and ResourceLoader.exists(BAT_PATH)

static func available(id: StringName) -> bool:
	return (force or DisplayServer.get_name() != "headless") and ResourceLoader.exists(path_for(id))

static func create(id: StringName, is_lite := false) -> ModelFigure:
	if not available(id):
		return null
	var scene := load(path_for(id)) as PackedScene
	if scene == null:
		return null
	var figure := ModelFigure.new()
	figure.lite = is_lite
	figure._view_size = LITE_VIEW_SIZE if is_lite else VIEW_SIZE
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
	_viewport.size = Vector2i(_view_size, _view_size)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X if lite else Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if lite else SubViewport.UPDATE_ALWAYS
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
	_load_clips(instance)
	_active = true
	active_count += 1
	if bat_available():
		_bat = (load(BAT_PATH) as PackedScene).instantiate()
		_bat.visible = false
		skeleton.add_child(_bat)
		_bat_cracks = _bat.find_child("BatCracks", true, false)
	return true

## Merkt sich die Spuren der Clips im Modell. Abgespielt wird nicht mit dem `AnimationPlayer`: Die Zeit bestimmt der Angriff.
func _load_clips(root: Node) -> void:
	var player := _find_player(root)
	if player == null:
		return
	player.active = false
	for clip in player.get_animation_list():
		var anim := player.get_animation(clip)
		var entry := {"anim": anim, "rotation": {}, "hips": -1}
		for track in anim.get_track_count():
			var bone := skeleton.find_bone(String(anim.track_get_path(track).get_subname(0)))
			if bone < 0:
				continue
			if anim.track_get_type(track) == Animation.TYPE_ROTATION_3D:
				entry["rotation"][bone] = track
			elif anim.track_get_type(track) == Animation.TYPE_POSITION_3D and skeleton.get_bone_name(bone) == "hips":
				entry["hips"] = track
		_clips[clip] = entry

func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null

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
	_blend_from_last(&"pose", dir)
	_update_bat()

func has_clip(id: StringName) -> bool:
	return _clips.has("%s_R" % id)

## Zeigt den Clip eines Angriffs. phase: 0–1 Anlauf, 1–2 Treffer, 2–3 Erholung (`AttackData.phase_at`).
## Ein Clip enthält die ganze Körperbewegung; Füsse und Hüfte sind beim Bau schon auf den Boden gerechnet.
func set_clip(id: StringName, phase: float, facing: int, flash := false) -> void:
	if flash != _flash:
		_set_flash(flash)
	_front = "R" if facing > 0 else "L"
	_back = "L" if facing > 0 else "R"
	var entry: Dictionary = _clips["%s_%s" % [id, _front]]
	var anim: Animation = entry["anim"]
	skeleton.reset_bone_poses()
	for bone in entry["rotation"]:
		skeleton.set_bone_pose_rotation(bone, anim.rotation_track_interpolate(entry["rotation"][bone], phase))
	if entry["hips"] >= 0:
		skeleton.set_bone_pose_position(skeleton.find_bone("hips"), anim.position_track_interpolate(entry["hips"], phase))
	_model.rotation.y = facing * PI * 0.5
	_pivot.rotation.z = 0.0
	_outer.position = Vector3.ZERO
	_model.position.y = -(_lowest_foot() - _rest_foot_y) if id in AIR_CLIPS else 0.0
	_blend_from_last(id, facing)
	_update_bat()

func has_bat() -> bool:
	return _bat != null

## Schaltet das Zeichnen des Teilbilds an oder aus. Wartende Gegner ausserhalb des Bilds kosten so nichts.
func set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	active_count += 1 if on else -1
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on and not lite else SubViewport.UPDATE_DISABLED

## Gegner rechnen ihr Teilbild nur jedes zweite Bild neu (verschoben nach Figur, damit nicht alle im selben Bild dran sind).
## Gibt true zurück, wenn jetzt Haltung und Teilbild erneuert werden sollen; das Teilbild wird dann einmal gerechnet.
func update_due() -> bool:
	if not lite:
		return true
	if (Engine.get_physics_frames() + get_instance_id()) % 2 != 0 and _source != &"":
		return false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _active:
		active_count -= 1
		_active = false

## Färbt die Zonen des Modells um: palette = {Zone: Farbe}, Zonen wie im Blender-Skript (`skin`, `hair`, `top`, `pants` ...).
## Jedes Modell bekommt eigene Kopien der Materialien, die geteilten Vorlagen bleiben unverändert. Eine neue Hautfarbe
## färbt die Schattenlinien (`shade`) mit.
func apply_palette(palette: Dictionary) -> void:
	var colors := palette.duplicate()
	if colors.has("skin") and not colors.has("shade"):
		colors["shade"] = (colors["skin"] as Color).darkened(0.18)
	_recolor(_model, colors)

func _recolor(node: Node, colors: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var base := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if base == null or not base.resource_name.contains("__"):
				continue
			var zone := base.resource_name.get_slice("__", 1)
			if colors.has(zone):
				var copy := base.duplicate() as BaseMaterial3D
				copy.albedo_color = colors[zone]
				mesh_instance.set_surface_override_material(surface, copy)
	for child in node.get_children():
		_recolor(child, colors)

## Zeigt den Schläger in der Hand (ratio = Haltbarkeit, unter 30 % mit Rissen) oder blendet ihn aus (ratio < 0).
func show_bat(ratio: float) -> void:
	if _bat == null:
		return
	_bat.visible = ratio >= 0.0
	if _bat_cracks != null:
		_bat_cracks.visible = ratio >= 0.0 and ratio < 0.3

## Der Schläger folgt der vorderen Hand: Seine Richtung liest er aus dem Handknochen, so stimmt sie bei Clips und bei Posen.
func _update_bat() -> void:
	if _bat == null or not _bat.visible:
		return
	var hand := skeleton.find_bone("hand." + _front)
	var rest := _rest_global[hand]
	var along := (rest.origin - _rest_global[skeleton.find_bone("forearm." + _front)].origin).normalized()
	var pose := skeleton.get_bone_global_pose(hand)
	var dir := (pose.basis.get_rotation_quaternion() * rest.basis.get_rotation_quaternion().inverse()) * along
	_bat.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), pose.origin + dir * HAND_EXTRA)

## Wechselt die Quelle (Pose oder Clip), läuft die Figur ein paar Bilder lang aus ihrer letzten Haltung in die neue.
func _blend_from_last(source: StringName, dir: int) -> void:
	if _clips.is_empty():
		return
	var hips := skeleton.find_bone("hips")
	if source != _source:
		if _source != &"" and dir == _source_dir:
			_blend_left = BLEND_FRAMES
			_blend_rotation = _last_rotation.duplicate()
			_blend_hips = _last_hips
		_source = source
	_source_dir = dir
	if _blend_left > 0:
		var amount := 1.0 - float(_blend_left) / float(BLEND_FRAMES + 1)
		for i in skeleton.get_bone_count():
			skeleton.set_bone_pose_rotation(i, _blend_rotation[i].slerp(skeleton.get_bone_pose_rotation(i), amount))
		skeleton.set_bone_pose_position(hips, _blend_hips.lerp(skeleton.get_bone_pose_position(hips), amount))
		_blend_left -= 1
	_last_rotation.resize(skeleton.get_bone_count())
	for i in skeleton.get_bone_count():
		_last_rotation[i] = skeleton.get_bone_pose_rotation(i)
	_last_hips = skeleton.get_bone_pose_position(hips)

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

## Spitze des schlagenden Glieds (kind: &"foot", &"hand" oder &"bat"): das Glied, das am weitesten vom Körper weg ist.
func strike_point(kind: StringName, k: float) -> Vector2:
	if kind == &"bat":
		if _bat != null and _bat.visible:
			return _to_px(_skeleton_view(_bat.transform * Vector3(0.0, BAT_TIP, 0.0)), k)
		kind = &"hand"
	var best := Vector3.ZERO
	for side in ["L", "R"]:
		var p := _view_point("%s.%s" % [kind, side])
		if absf(p.x) >= absf(best.x):
			best = p
	return _to_px(best, k)

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
	return _skeleton_view(skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin)

func _skeleton_view(p: Vector3) -> Vector3:
	return (_outer.transform * _pivot.transform * _model.transform) * _model_point(p)

func _lowest_foot() -> float:
	var lowest := INF
	for bone in ["foot.L", "foot.R"]:
		lowest = minf(lowest, _model_point(skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin).y)
	return lowest

# ---------------------------------------------------------------- Zeichnen

## Zeichnet das Bild mit dem Fusspunkt bei (x, y); k = Körpergrösse (`Fighter.body_scale`).
func draw(ci: CanvasItem, x: float, y: float, k := 1.0) -> void:
	var size := PX_PER_M * VIEW_METERS * k
	var feet_v := PX_PER_M * (VIEW_METERS - FEET_MARGIN) * k
	ci.draw_texture_rect(_viewport.get_texture(), Rect2(Vector2(x - size * 0.5, y - feet_v), Vector2(size, size)), false)
