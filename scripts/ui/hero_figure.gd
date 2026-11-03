class_name HeroFigure
extends Node2D
## Eine grosse Figur in Menü und Endbildschirm. Fusspunkt ist die Position des Knotens.

enum Mode { SHOWCASE, CHEER, LYING }

var skin: Dictionary = Skins.KAI
var color := Art.PLAYER_COLORS[0]
var facing := 1
var figure_scale := 2.2
var mode := Mode.SHOWCASE
var showcase_attack: StringName = &"straight"
var showcase_offset := 0.0
var label := ""
var caption := ""

var _time := 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _pose() -> Dictionary:
	match mode:
		Mode.CHEER:
			return Poses.cheer(_time)
		Mode.LYING:
			return Poses.lying()
	var t := fmod(_time + showcase_offset, 2.0)
	if t < 0.5:
		return Poses.attack(showcase_attack, t / 0.5, 0.3, 0.55)
	return Poses.stand(_time)

func _draw() -> void:
	Art.shadow(self, 0.0, 0.0, 46.0 * figure_scale)
	if mode == Mode.SHOWCASE:
		Art.player_ring(self, 0.0, 0.0, 54.0 * figure_scale, color, facing)
	FigureArt.draw(self, skin, _pose(), 0.0, 0.0, facing, figure_scale, false, _time)
	if label != "":
		Art.text(self, label, 34.0, Vector2(0.0, 30.0), color)
	if caption != "":
		Art.text(self, caption, 22.0, Vector2(0.0, 54.0), Art.GRAY, Art.Anchor.CENTER, false)
