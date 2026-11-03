class_name WeaponPickup
extends GroundItem
## Eine Waffe am Boden. Wird nie automatisch eingesammelt, nur mit der Greifen-Taste.
## Der Schläger sieht überall gleich aus: Am Boden, im Flug und im HUD zeigt ein einmal gerendertes Bild des 3D-Modells.

const WOOD := Color8(201, 154, 91)
const BAT_LENGTH := 0.868        # Meter, Knauf bis Spitze
const BAT_VIEW := Vector2(0.95, 0.198)   # sichtbarer Ausschnitt des Bilds in Metern
const BAT_VIEW_MARGIN := 0.041   # vom linken Bildrand bis zum Knauf
const BAT_GROUND_PX := 46.0      # Länge im Spiel, wie in der Hand (0,868 m bei 52,8 px/m)

static var _bat_view: SubViewport = null

var kind: StringName = &"bat"
var rest := 10

func draw_item() -> void:
	WeaponPickup.draw_bat(self, Vector2(-BAT_GROUND_PX * 0.5, -5), Vector2(BAT_GROUND_PX * 0.5, -9), float(rest) / 10.0)

func shadow_width() -> float:
	return 44.0 / (1.0 + pos_y / 120.0)

## Einmal gerendertes Bild des Schlägers: Spitze nach rechts. Ohne Modell (oder headless) null.
static func _bat_texture() -> Texture2D:
	if not ModelFigure.bat_available():
		return null
	if _bat_view == null:
		_bat_view = SubViewport.new()
		_bat_view.size = Vector2i(192, 40)
		_bat_view.transparent_bg = true
		_bat_view.own_world_3d = true
		_bat_view.msaa_3d = Viewport.MSAA_4X
		_bat_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		var bat: Node3D = (load(ModelFigure.BAT_PATH) as PackedScene).instantiate()
		bat.rotation.z = -PI / 2.0
		var cracks := bat.find_child("BatCracks", true, false) as Node3D
		if cracks != null:
			cracks.visible = false
		_bat_view.add_child(bat)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.size = BAT_VIEW.x
		camera.position = Vector3(BAT_VIEW.x * 0.5 - BAT_VIEW_MARGIN - 0.2, 0.0, 2.0)
		var environment := Environment.new()
		environment.background_mode = Environment.BG_CLEAR_COLOR
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color.WHITE
		environment.ambient_light_energy = 0.6
		camera.environment = environment
		_bat_view.add_child(camera)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-42.0, 22.0, 0.0)
		sun.light_energy = 1.1
		_bat_view.add_child(sun)
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_bat_view)
	return _bat_view.get_texture()

## Baseballschläger vom Knauf (grip) zur Spitze (tip). Unter 30 % Haltbarkeit hat er Risse.
static func draw_bat(ci: CanvasItem, grip: Vector2, tip: Vector2, ratio := 1.0, s := 1.0) -> void:
	var length := maxf(grip.distance_to(tip), 1.0)
	var dir := (tip - grip) / length
	var texture := _bat_texture()
	if texture != null:
		var scale := length / BAT_LENGTH
		ci.draw_set_transform(grip, dir.angle())
		ci.draw_texture_rect(texture, Rect2(Vector2(-BAT_VIEW_MARGIN, -BAT_VIEW.y * 0.5) * scale, BAT_VIEW * scale), false)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		# Ersatz ohne Modell: dünner Griff, dicker Kopf, dunkles Griffband
		Art.capsule(ci, grip, tip, 1.1 * s, WOOD, Art.OUTLINE, 2.6 * s)
		ci.draw_line(grip + dir * length * 0.6, grip + dir * length * 0.92, Art.lighter(WOOD), maxf(1.0, 1.4 * s))
		ci.draw_line(grip + dir * length * 0.03, grip + dir * length * 0.27, Color8(38, 34, 42), maxf(1.5, 2.2 * s))
		ci.draw_circle(grip, maxf(1.5, 2.4 * s), Art.darker(WOOD, 0.5))
	if ratio < 0.3:
		var n := Vector2(-dir.y, dir.x)
		for f: float in [0.62, 0.78]:
			var m := grip + dir * length * f
			ci.draw_line(m + n * 4.0 * s, m - n * 2.0 * s, Art.OUTLINE, 2.0)

## Kleines Bild der Waffe fürs HUD.
static func draw_symbol(ci: CanvasItem, kind_id: StringName, rect: Rect2) -> void:
	var data := WeaponData.get_data(kind_id)
	if data["heavy"]:
		var box := rect.grow_individual(-4.0, 0.0, -4.0, 0.0)
		ci.draw_rect(box, data["color"])
		ci.draw_rect(box, Art.OUTLINE, false, 2.0)
	else:
		draw_bat(ci, Vector2(rect.position.x + 3.0, rect.end.y - 3.0), Vector2(rect.end.x - 3.0, rect.position.y + 3.0), 1.0, 0.6)
