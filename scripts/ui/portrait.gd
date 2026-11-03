class_name Portrait
extends Control
## Kopf einer Figur im Rahmen: dieselbe Zeichenfunktion, nur vergrössert und abgeschnitten.

var skin: Dictionary
var background := Color8(40, 40, 60)
var _time := 0.0
var _fill: StyleBoxFlat
var _border: StyleBoxFlat

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill = StyleBoxFlat.new()
	_fill.bg_color = background
	_fill.set_corner_radius_all(8)
	_border = StyleBoxFlat.new()
	_border.draw_center = false
	_border.border_color = Art.OUTLINE
	_border.set_border_width_all(2)
	_border.set_corner_radius_all(8)

func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	draw_style_box(_fill, Rect2(Vector2.ZERO, size))
	var scale_factor := size.y / 30.0
	var foot := FigureArt.portrait_foot(size * 0.5, scale_factor)
	FigureArt.draw(self, skin, Poses.stand(_time), foot.x, foot.y, 1, scale_factor, false, _time)
	draw_style_box(_border, Rect2(Vector2.ZERO, size))
