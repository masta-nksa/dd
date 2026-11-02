class_name Hud
extends Control
## Lebensbalken der Spieler oben links (1P) und oben rechts (2P).

var players: Array[Fighter] = []
var names: Array[String] = ["KAI", "RIA"]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
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
