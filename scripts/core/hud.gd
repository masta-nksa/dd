class_name Hud
extends Control
## Lebensbalken der Spieler oben links (1P) und oben rechts (2P).

var players: Array[Fighter] = []
var names: Array[String] = ["KAI", "RIA"]
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
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	if banner_time > 0.0:
		draw_string(font, Vector2(0, 200), banner_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 48, Color(1, 0.85, 0.3))
	if go_time > 0.0 and int(go_time * 3.0) % 2 == 0:
		draw_string(font, Vector2(size.x - 200, 270), "LOS  >>>", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1))
	if message != "":
		draw_rect(Rect2(0, 190, size.x, 90), Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(0, 250), message, HORIZONTAL_ALIGNMENT_CENTER, size.x, 56, Color(1, 0.85, 0.3))
