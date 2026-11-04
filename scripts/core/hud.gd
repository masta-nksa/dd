class_name Hud
extends Control
## Lebensanzeigen, Punkte und Hinweise (Port von `hud.py`). Jeder Spieler hat ein Feld (1P links, 2P rechts).
## Der Lebensbalken hat eine rote Nachlaufspur: So sieht man, wie viel ein Treffer gekostet hat.

const PANEL_SIZE := Vector2(320.0, 66.0)
const LAST_HIT_TIME := 2.5

var players: Array[Fighter] = []
var items: WorldItems
var camera: CameraRig
var director: WaveDirector
var banner_text := ""
var banner_time := 0.0
var message := ""        # bleibt stehen (GAME OVER / GESCHAFFT)

var _time := 0.0
var _trail := {}         # Figur -> angezeigter Anteil der Nachlaufspur
var _last_hit: Fighter = null
var _last_hit_time := 0.0
var _panel: StyleBoxFlat
var _hint: StyleBoxFlat

func show_banner(text: String) -> void:
	banner_text = text
	banner_time = 2.0

## Ein Gegner wurde getroffen: Sein Balken erscheint oben in der Mitte.
func note_hit(target: Fighter) -> void:
	if target.team != 0:
		_last_hit = target
		_last_hit_time = LAST_HIT_TIME

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = StyleBoxFlat.new()
	_panel.bg_color = Color8(10, 8, 20, 170)
	_panel.set_border_width_all(2)
	_panel.set_corner_radius_all(10)
	_hint = StyleBoxFlat.new()
	_hint.bg_color = Color8(20, 18, 30)
	_hint.set_border_width_all(2)
	_hint.set_corner_radius_all(6)
	for i in players.size():
		var portrait := Portrait.new()
		portrait.skin = players[i].skin
		portrait.background = Art.darker(players[i].body_color, 0.45)
		portrait.position = _panel_rect(i).position + Vector2(7.0, 7.0)
		portrait.size = Vector2(52.0, 52.0)
		add_child(portrait)

func _panel_rect(index: int) -> Rect2:
	return Rect2(10.0 if index == 0 else 960.0 - PANEL_SIZE.x - 10.0, 8.0, PANEL_SIZE.x, PANEL_SIZE.y)

func _process(delta: float) -> void:
	_time += delta
	banner_time = maxf(banner_time - delta, 0.0)
	_last_hit_time = maxf(_last_hit_time - delta, 0.0)
	if _last_hit != null and not is_instance_valid(_last_hit):
		_last_hit = null
	for f in _trail.keys():
		if not is_instance_valid(f):
			_trail.erase(f)
	for f in players:
		_update_trail(f, delta)
	if director != null:
		for g in director.enemies:
			_update_trail(g, delta)

func _physics_process(_delta: float) -> void:
	queue_redraw()

func _update_trail(f: Fighter, delta: float) -> void:
	var ratio := _ratio(f)
	var old: float = _trail.get(f, ratio)
	_trail[f] = ratio if ratio > old else maxf(ratio, old - delta * 0.6)

func _ratio(f: Fighter) -> float:
	return clampf(float(f.current_health) / float(f.max_health), 0.0, 1.0)

func _draw() -> void:
	for i in players.size():
		_draw_player(players[i], _panel_rect(i), i + 1)
	_draw_enemies()
	for i in players.size():
		var f := players[i]
		if f.carried == null or not f.carried.heavy:
			if items != null and camera != null and f.current_health > 0:
				_draw_grab_hint(f, i + 1)
	if banner_time > 0.0:
		var fly_in := minf(1.0, (2.0 - banner_time) * 5.0)
		Art.title(self, banner_text, 84.0, Vector2(480.0 + (1.0 - fly_in) * 960.0, 200.0))
	if message != "":
		Art.title(self, message, 84.0, Vector2(480.0, 200.0), Art.YELLOW if message != "GAME OVER" else Art.RED)

func _draw_player(f: Fighter, rect: Rect2, number: int) -> void:
	_panel.border_color = f.body_color
	draw_style_box(_panel, rect)
	var x := rect.position.x + 69.0
	var top := rect.position.y
	Art.text(self, "%dP %s" % [number, f.skin["name"]], 24.0, Vector2(x, top + 8.0), f.body_color, Art.Anchor.TOP_LEFT)
	Art.text(self, "%07d" % f.score, 24.0, Vector2(rect.end.x - 10.0, top + 8.0), Art.TEXT, Art.Anchor.TOP_RIGHT)
	if f.is_out():
		if int(_time * 2.0) % 2 == 0:
			Art.text(self, "GAME OVER", 28.0, Vector2(x + 100.0, top + 44.0), Art.RED)
		return
	draw_bar(self, Rect2(x, top + 30.0, 190.0, 16.0), _ratio(f), _trail.get(f, _ratio(f)))
	for i in f.lives:
		_draw_heart(Vector2(x + 6.0 + i * 16.0, top + 54.0))
	if f.carried != null:
		_draw_carried(f.carried, rect, number)
	if f.combo >= 2:
		Art.text(self, "%d HITS!" % f.combo, 30.0, Vector2(rect.get_center().x, rect.end.y + 16.0), Art.YELLOW)

func _draw_heart(at: Vector2) -> void:
	draw_circle(at + Vector2(-3.0, -2.0), 4.0, Art.RED)
	draw_circle(at + Vector2(3.0, -2.0), 4.0, Art.RED)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-7.0, -1.0), at + Vector2(7.0, -1.0), at + Vector2(0.0, 6.0)]), Art.RED)

## Was der Spieler trägt: Symbol und bei Waffen ein Haltbarkeitsbalken (blinkt, wenn sie fast kaputt ist).
func _draw_carried(carried: Carry, rect: Rect2, number: int) -> void:
	var symbol := Rect2(rect.position.x + 109.0, rect.position.y + 47.0, 28.0, 16.0)
	WeaponPickup.draw_symbol(self, carried.kind, symbol)
	var right := symbol.end.x + 8.0
	if carried.heavy:
		Art.text(self, "%s: werfen" % carried.display_name(), 18.0, Vector2(right, symbol.get_center().y), Art.TEXT, Art.Anchor.MID_LEFT, false)
		return
	var ratio := carried.ratio()
	var flash: Variant = Color.WHITE if ratio < 0.25 and int(_time * 6.0) % 2 == 1 else null
	draw_bar(self, Rect2(right, symbol.position.y + 3.0, 100.0, 10.0), ratio, ratio, flash)
	Art.text(self, "%s Abwehr" % InputSetup.key_hint(number, "kick"), 16.0, Vector2(right + 106.0, symbol.get_center().y), Art.TEXT, Art.Anchor.MID_LEFT, false)

func _draw_enemies() -> void:
	if director == null:
		return
	var boss: Enemy = null
	for g in director.enemies:
		if g.type_id == &"boss" and g.current_health > 0:
			boss = g
	if boss != null:
		var bar := Rect2(260.0, 506.0, 440.0, 18.0)
		Art.text(self, boss.skin["name"], 26.0, Vector2(480.0, bar.position.y - 12.0), Color8(150, 255, 150))
		draw_bar(self, bar, _ratio(boss), _trail.get(boss, _ratio(boss)), Color8(110, 220, 90))
	if _last_hit != null and _last_hit != boss and _last_hit_time > 0.0:
		Art.text(self, _last_hit.skin["name"], 22.0, Vector2(480.0, 18.0), Color8(170, 240, 170))
		draw_bar(self, Rect2(390.0, 30.0, 180.0, 12.0), _ratio(_last_hit), _trail.get(_last_hit, _ratio(_last_hit)), Color8(110, 220, 90))
	else:
		Art.text(self, "LEVEL %d" % director.level_index, 22.0, Vector2(480.0, 22.0), Art.GRAY)

## Kleine Taste über dem Ding, das man mit Greifen aufheben würde.
func _draw_grab_hint(f: Fighter, player_number: int) -> void:
	var target := items.find_grabbable(f)
	if target == null:
		return
	var top := 22.0
	if target is Prop:
		top = (target as Prop).height
	var sx: float = target.pos_x - camera.position.x + 480.0
	var sy: float = target.pos_z - top - 26.0 - 3.0 * sin(_time * 6.0)
	var key := InputSetup.key_hint(player_number, "grab")
	var w := maxf(26.0, 12.0 * key.length() + 12.0)
	_hint.border_color = f.body_color
	draw_style_box(_hint, Rect2(sx - w * 0.5, sy - 12.0, w, 24.0))
	Art.text(self, key, 20.0, Vector2(sx, sy), Art.TEXT, Art.Anchor.CENTER, false)

## Balken mit Nachlaufspur (Port von `zeichne_balken`). Ohne eigene Farbe wechselt er von grün über gelb nach rot.
static func draw_bar(ci: CanvasItem, rect: Rect2, ratio: float, trail: float, color: Variant = null) -> void:
	ci.draw_rect(rect, Color8(30, 26, 40))
	var inner := rect.grow(-2.0)
	if trail > ratio:
		ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x * trail, inner.size.y)), Color8(200, 40, 40))
	if ratio > 0.0:
		var full := Rect2(inner.position, Vector2(maxf(1.0, inner.size.x * ratio), inner.size.y))
		ci.draw_rect(full, color if color != null else _bar_color(ratio))
		ci.draw_line(full.position, Vector2(full.end.x, full.position.y), Color.WHITE, 1.0)
	ci.draw_rect(rect, Art.OUTLINE, false, 2.0)

static func _bar_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color8(90, 220, 90)
	if ratio > 0.25:
		return Color8(250, 200, 50)
	return Color8(240, 60, 50)
