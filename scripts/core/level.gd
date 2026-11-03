class_name Level
extends Node2D
## Hintergrund in drei Ebenen (Parallax): Himmel steht still, Skyline scrollt langsamer, Häuser und Strasse
## scrollen mit der Kamera. Die Ebenen werden einmal gemalt und für alle weiteren Runden aufbewahrt.

const WIDTH := 5400.0
const HEIGHT := 540.0
const NEAR_CHUNK := 1800     # Stücke statt einer einzigen 5400 Pixel breiten Textur (Grenze auf manchen Geräten)

## (Art, x, z) – z ist der Fusspunkt (Port von `REQUISITEN_PLAN`)
const PROP_PLAN := [
	[&"lamp", 300, 330], [&"crate", 760, 360], [&"bin", 1000, 340],
	[&"lamp", 1120, 330], [&"barrel", 1560, 470], [&"crate", 1700, 345],
	[&"lamp", 1950, 330], [&"barrel", 2500, 350], [&"barrel", 2540, 372], [&"crate", 2900, 480],
	[&"lamp", 2780, 330], [&"bin", 3100, 342], [&"crate", 3500, 355], [&"lamp", 3620, 330],
	[&"barrel", 3950, 470], [&"crate", 4200, 350], [&"crate", 4246, 350], [&"lamp", 4480, 330],
	[&"barrel", 5000, 360], [&"lamp", 5300, 330],
]

static var _textures := {}          # Schlüssel -> ImageTexture, bleibt über Runden hinweg
static var _painted_headless := false

var _sky: Sprite2D
var _far: Sprite2D

func _ready() -> void:
	z_index = -4000
	process_priority = 100      # nach der Kamera, sonst hinkt die Parallaxe ein Bild hinterher
	_sky = _add_sprite("sky", 0.0, self)
	_far = _add_sprite("far", 0.0, self)
	var chunks := int(WIDTH) / NEAR_CHUNK
	for i in chunks:
		_add_sprite("near%d" % i, float(i * NEAR_CHUNK), self)
	if _textures.is_empty():
		_paint_all(chunks)

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var left := camera.global_position.x - LevelPainter.SCREEN_W * 0.5
	_sky.position.x = left
	_far.position.x = left - left * LevelPainter.PARALLAX

func lane_bounds() -> Rect2:
	return Rect2(40.0, 322.0, WIDTH - 80.0, 200.0)

func _add_sprite(key: String, x: float, parent: Node) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = key
	sprite.centered = false
	sprite.position.x = x
	sprite.texture = _textures.get(key)
	parent.add_child(sprite)
	return sprite

func _paint_all(chunks: int) -> void:
	var headless := DisplayServer.get_name() == "headless"
	if headless and _painted_headless:
		return
	_painted_headless = headless
	var jobs := [
		["sky", LevelPainter.Layer.SKY, 0, LevelPainter.SCREEN_W, LevelPainter.SCREEN_H],
		["far", LevelPainter.Layer.FAR, 0, LevelPainter.FAR_WIDTH, LevelPainter.HOUSE_BOTTOM],
	]
	for i in chunks:
		jobs.append(["near%d" % i, LevelPainter.Layer.NEAR, i * NEAR_CHUNK, NEAR_CHUNK, LevelPainter.SCREEN_H])
	var viewports := []
	for job in jobs:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(job[3], job[4])
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		var painter := LevelPainter.new()
		painter.layer = job[1]
		painter.x_from = job[2]
		painter.x_to = job[2] + job[3]
		viewport.add_child(painter)
		add_child(viewport)
		viewports.append(viewport)
		if not headless:
			(get_node(String(job[0])) as Sprite2D).texture = viewport.get_texture()
	if headless:
		await get_tree().process_frame
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
		for i in jobs.size():
			var key: String = jobs[i][0]
			_textures[key] = ImageTexture.create_from_image(viewports[i].get_texture().get_image())
			(get_node(key) as Sprite2D).texture = _textures[key]
	for viewport in viewports:
		viewport.queue_free()
