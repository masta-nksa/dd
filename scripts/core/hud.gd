class_name Hud
extends Control
## Lebensbalken der Spieler oben links (1P) und oben rechts (2P).

var players: Array[Fighter] = []
var names: Array[String] = ["KAI", "RIA"]
var items: WorldItems
var camera: CameraRig
var banner_text := ""
var banner_time := 0.0
var go_time := 0.0
var message := ""        # bleibt stehen (GAME OVER / GESCHAFFT)

func show_banner(text: String) -> void:
	banner_text = text
	banner_time = 2.0

func show_go() -> void:
	go_time = 3.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	banner_time = maxf(banner_time - delta, 0.0)
	go_time = maxf(go_time - delta, 0.0)
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for i in players.size():
		var f := players[i]
		var w := 240.0
		var x := 20.0 if i == 0 else size.x - 20.0 - w
		draw_string(font, Vector2(x, 24), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, f.body_color.lightened(0.3))
		draw_rect(Rect2(x, 30, w, 14), Color(0, 0, 0, 0.6))
		var ratio := float(f.current_health) / float(f.max_health)
		draw_rect(Rect2(x, 30, w * ratio, 14), Color(0.3, 0.9, 0.3).lerp(Color(0.95, 0.2, 0.2), 1.0 - ratio))
		draw_string(font, Vector2(x + w + 6 if i == 0 else x - 34, 43), str(f.current_health),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	for i in players.size():
		var x2 := 20.0 if i == 0 else size.x - 20.0 - 240.0
		draw_string(font, Vector2(x2, 64), "Punkte: %d" % players[i].score, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	for i in players.size():
		var f := players[i]
		var x3 := 20.0 if i == 0 else size.x - 20.0 - 240.0
		if f.carried != null:
			draw_string(font, Vector2(x3, 84), f.carried.display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.6))
			if not f.carried.heavy:
				draw_rect(Rect2(x3 + 90, 74, 100, 8), Color(0, 0, 0, 0.6))
				draw_rect(Rect2(x3 + 90, 74, 100 * f.carried.ratio(), 8), Color(0.9, 0.7, 0.3).lerp(Color(0.9, 0.2, 0.2), 1.0 - f.carried.ratio()))
		elif items != null and camera != null and f.current_health > 0:
			_draw_grab_hint(f, i + 1)
	if banner_time > 0.0:
		draw_string(font, Vector2(0, 200), banner_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 48, Color(1, 0.85, 0.3))
	if go_time > 0.0 and int(go_time * 3.0) % 2 == 0:
		draw_string(font, Vector2(size.x - 200, 270), "LOS  >>>", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1))
	if message != "":
		draw_rect(Rect2(0, 190, size.x, 90), Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(0, 250), message, HORIZONTAL_ALIGNMENT_CENTER, size.x, 56, Color(1, 0.85, 0.3))

## Kleine Taste über dem Ding, das man mit Greifen aufheben würde.
func _draw_grab_hint(f: Fighter, player_number: int) -> void:
	var target := items.find_grabbable(f)
	if target == null:
		return
	var top := 22.0
	if target is Prop:
		top = (target as Prop).height
	var sx: float = target.pos_x - camera.position.x + size.x * 0.5
	var sy: float = target.pos_z - top - 26.0 - 3.0 * sin(Time.get_ticks_msec() / 160.0)
	var key := InputSetup.key_hint(player_number, "grab")
	var box := Rect2(sx - 13.0, sy - 12.0, 26.0, 24.0)
	draw_rect(box, Color(0.08, 0.07, 0.12))
	draw_rect(box, f.body_color, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(box.position.x, sy + 5.0), key, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 14, Color.WHITE)
