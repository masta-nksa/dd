class_name PerfOverlay
extends Control
## Messanzeige auf F2: Bildzeit, Bildrate und wie viele 3D-Figuren gerade gezeichnet werden.
## So lässt sich im Browser prüfen, ob viele Gegner auf dem Bildschirm das Spiel bremsen.

const WINDOW := 0.5     # Sekunden, über die gemittelt wird

var _time := 0.0
var _frames := 0
var _ms := 0.0
var _fps := 0.0
var _worst := 0.0
var _worst_shown := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_frames += 1
	_worst = maxf(_worst, delta * 1000.0)
	if _time >= WINDOW:
		_ms = _time * 1000.0 / _frames
		_fps = _frames / _time
		_worst_shown = _worst
		_time = 0.0
		_frames = 0
		_worst = 0.0
		queue_redraw()

func _draw() -> void:
	var text := "%.0f FPS · %.1f ms (schlechtestes %.0f ms) · 3D-Figuren %d" % [_fps, _ms, _worst_shown, ModelFigure.active_count]
	Art.text(self, text, 16.0, Vector2(10.0, 528.0), Art.TEXT, Art.Anchor.MID_LEFT)
