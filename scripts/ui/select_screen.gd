class_name SelectScreen
extends Screen
## Kämpferwahl: oben die Hauptfiguren, darunter die weiteren. Jeder Spieler hat einen eigenen Cursor (1P blau, 2P rot)
## und bestätigt mit Schlag oder Sprung, «Tritt» nimmt die Wahl zurück. Jede Figur gehört nur einem Spieler:
## Wer bestätigt, sperrt sie für den anderen, dessen Cursor springt dann zur nächsten freien Figur.
## Die Figuren zeigen ihr 3D-Modell, solange die Datei da ist, sonst die 2D-Figur mit demselben Aussehen.

signal picked(ids: Array)
signal back_requested

const COLUMNS := 4
const CARD_SIZE := Vector2(222.0, 196.0)
const GAP := 10.0
const ROW_Y := [78.0, 304.0]
const START_DELAY := 0.5      # Sekunden, in denen man die fertige Wahl noch sieht
const INPUT_LOCK := 0.3       # der Tastendruck, der das Menü verlassen hat, zählt nicht mit
const BAR_LABELS := {"hp": "LEBEN", "speed_x": "TEMPO", "jump_speed": "SPRUNG", "weight": "WUCHT",
	"damage": "KRAFT", "attack_speed": "HIEBE", "reach": "REICHW."}

var player_count := 1
var cursors: Array[int] = [0, 1]
var picks: Array[int] = [-1, -1]          # bestätigte Karte je Spieler, -1 = noch keine
var ids: Array[StringName] = FighterData.all_ids()

var _board: Control
var _models: Array = []                   # ModelFigure oder null, je Karte
var _time := 0.0
var _countdown := -1.0
var _poses := {}                          # Karte -> Pose des letzten Bildes (nur zum Testen)

func _init() -> void:
	dim = 0.6

func _build() -> void:
	InputSetup.einrichten()
	_board = Control.new()
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.draw.connect(_draw_board)
	for id in ids:
		var model := ModelFigure.create(id)
		_models.append(model)
		if model != null:
			add_child(model)

func _process(delta: float) -> void:
	_time += delta
	if _countdown >= 0.0:
		_countdown -= delta
		if _countdown < 0.0:
			picked.emit(_chosen_ids())
		_board.queue_redraw()
		return
	if _time > INPUT_LOCK:
		if Input.is_action_just_pressed("ui_cancel"):
			back_requested.emit()
			return
		for p in player_count:
			var prefix := "p%d_" % (p + 1)
			if Input.is_action_just_pressed(prefix + "left"):
				move_cursor(p, -1, 0)
			if Input.is_action_just_pressed(prefix + "right"):
				move_cursor(p, 1, 0)
			if Input.is_action_just_pressed(prefix + "up") or Input.is_action_just_pressed(prefix + "down"):
				move_cursor(p, 0, 1)
			if Input.is_action_just_pressed(prefix + "punch") or Input.is_action_just_pressed(prefix + "jump"):
				confirm(p)
			if Input.is_action_just_pressed(prefix + "kick"):
				release(p)
	_update_models()
	_board.queue_redraw()

# ---------------------------------------------------------------- Wahl

## Spieler, der die Karte bestätigt hat, oder -1.
func owner_of(card: int) -> int:
	for p in player_count:
		if picks[p] == card:
			return p
	return -1

func is_taken_by_other(card: int, p: int) -> bool:
	var o := owner_of(card)
	return o >= 0 and o != p

func is_ready() -> bool:
	for p in player_count:
		if picks[p] < 0:
			return false
	return true

## dx: eine Figur weiter in der Reihe (springt über Figuren des anderen Spielers); dy: in die andere Reihe.
func move_cursor(p: int, dx: int, dy: int) -> void:
	if picks[p] >= 0:
		return   # wer bestätigt hat, muss die Wahl erst zurücknehmen
	var card := cursors[p]
	var row := card / COLUMNS
	var col := card % COLUMNS
	var target := card
	if dy != 0:
		target = (1 - row) * COLUMNS + col
		if is_taken_by_other(target, p):
			return
	else:
		for step in COLUMNS:
			col = posmod(col + dx, COLUMNS)
			if not is_taken_by_other(row * COLUMNS + col, p):
				target = row * COLUMNS + col
				break
	if target != card:
		cursors[p] = target
		SoundBank.play(&"whoosh")

func confirm(p: int) -> bool:
	if picks[p] >= 0 or is_taken_by_other(cursors[p], p):
		return false
	picks[p] = cursors[p]
	SoundBank.play(&"grab")
	var other := 1 - p
	if player_count > 1 and cursors[other] == picks[p]:   # der andere steht auf der gerade vergebenen Figur
		move_cursor(other, 1, 0)
	if is_ready():
		_countdown = START_DELAY
	return true

func release(p: int) -> void:
	if picks[p] >= 0:
		picks[p] = -1
		SoundBank.play(&"jump")

func _chosen_ids() -> Array:
	var out := []
	for p in player_count:
		out.append(ids[picks[p]])
	return out

# ---------------------------------------------------------------- Zeichnen

func _card_rect(card: int) -> Rect2:
	var row := card / COLUMNS
	var col := card % COLUMNS
	var x0 := (960.0 - (COLUMNS * CARD_SIZE.x + (COLUMNS - 1) * GAP)) * 0.5
	return Rect2(Vector2(x0 + col * (CARD_SIZE.x + GAP), ROW_Y[row]), CARD_SIZE)

func _card_pose(card: int) -> Dictionary:
	var active := false
	for p in player_count:
		if cursors[p] == card or picks[p] == card:
			active = true
	if not active:
		return Poses.stand(_time + card)
	var t := fmod(_time + card * 0.3, 2.0)
	if t < 0.5:
		return Poses.attack(&"straight" if card % 2 == 0 else &"high_kick", t / 0.5, 0.3, 0.55)
	return Poses.stand(_time)

func _update_models() -> void:
	for card in ids.size():
		var pose := _card_pose(card)
		_poses[card] = pose
		if _models[card] != null:
			(_models[card] as ModelFigure).set_pose(pose, 1)

func _draw_board() -> void:
	Art.title(_board, "KÄMPFER WÄHLEN", 52.0, Vector2(480.0, 32.0))
	Art.text(_board, "HAUPTFIGUREN", 20.0, Vector2(480.0, 64.0), Art.YELLOW)
	Art.text(_board, "WEITERE KÄMPFER", 20.0, Vector2(480.0, ROW_Y[1] - 14.0), Art.GRAY)
	for card in ids.size():
		_draw_card(card)
	var hint := "1P:  A/D wählen · F bestätigen · G zurück"
	if player_count > 1:
		hint += "          2P:  ←/→ wählen · K bestätigen · L zurück"
	Art.text(_board, hint, 18.0, Vector2(480.0, 520.0), Art.GRAY)
	if _countdown >= 0.0:
		Art.title(_board, "LOS!", 64.0, Vector2(480.0, 275.0))
	elif player_count > 1 and (picks[0] >= 0) != (picks[1] >= 0):
		var waiting := 2 if picks[0] >= 0 else 1
		Art.text(_board, "Warten auf %dP ..." % waiting, 22.0, Vector2(790.0, 64.0), Art.PLAYER_COLORS[waiting - 1])

func _draw_card(card: int) -> void:
	var r := _card_rect(card)
	var id := ids[card]
	var data := FighterData.get_data(id)
	var owner := owner_of(card)
	var fill := Color8(16, 14, 30, 225)
	if owner >= 0:
		fill = Art.darker(Art.PLAYER_COLORS[owner], 0.34)
		fill.a = 0.95
	_board.draw_style_box(_card_style(fill, Color8(70, 66, 96), 2), r)
	# Figur
	var feet := Vector2(r.position.x + r.size.x * 0.5, r.position.y + 106.0)
	Art.shadow(_board, feet.x, feet.y, 62.0)
	var pose: Dictionary = _poses.get(card, Poses.stand(0.0))
	if _models[card] != null:
		(_models[card] as ModelFigure).draw(_board, feet.x, feet.y, 1.0)
	else:
		FigureArt.draw(_board, data["skin"], pose, feet.x, feet.y, 1, 1.0, false, _time)
	Art.text(_board, data["name"], 28.0, Vector2(feet.x, r.position.y + 122.0), Art.YELLOW if card < 4 else Art.TEXT)
	Art.text(_board, data["role"], 15.0, Vector2(feet.x, r.position.y + 139.0), Art.GRAY, Art.Anchor.CENTER, false)
	_draw_bars(id, r)
	# Cursor und Besitz
	for p in player_count:
		var color: Color = Art.PLAYER_COLORS[p]
		var mine := picks[p] == card
		if cursors[p] == card or mine:
			var inset := 2.0 + 4.0 * p
			_board.draw_style_box(_card_style(Color(0, 0, 0, 0), color, 4 if not mine else 6), r.grow(-inset))
			var tag := Rect2(r.position + Vector2(8.0 + p * (r.size.x - 66.0), 8.0), Vector2(50.0, 22.0))
			_board.draw_style_box(_card_style(color if mine else Color8(10, 8, 20, 220), color, 2), tag)
			Art.text(_board, "%dP" % (p + 1), 18.0, tag.get_center(), Art.OUTLINE if mine else color)
	if owner >= 0:
		Art.text(_board, "BEREIT", 20.0, Vector2(feet.x, r.position.y + 44.0), Art.TEXT)

func _draw_bars(id: StringName, r: Rect2) -> void:
	var keys := BAR_LABELS.keys()
	for i in keys.size():
		var col := i % 2
		var row := i / 2
		var x := r.position.x + 12.0 + col * 102.0
		var y := r.position.y + 152.0 + row * 11.0
		Art.text(_board, BAR_LABELS[keys[i]], 13.0, Vector2(x, y), Art.GRAY, Art.Anchor.MID_LEFT, false)
		var bar := Rect2(x + 40.0, y - 3.0, 52.0, 6.0)
		_board.draw_rect(bar, Color8(10, 8, 20))
		_board.draw_rect(Rect2(bar.position, Vector2(bar.size.x * FighterData.bar(id, keys[i]), bar.size.y)), Art.YELLOW)

func _card_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	return style
