class_name Screen
extends Control
## Grundlage für Menü, Pause und Endbildschirm: abgedunkelter Hintergrund, Texte und Knöpfe untereinander.
## Knöpfe sind echte `Button`, dadurch gehen Maus, Tastatur und Controller ohne eigene Logik.

const YELLOW := Art.YELLOW
const RED := Art.RED
const LIGHT := Art.TEXT
const GRAY := Art.GRAY

var dim := 0.63
var buttons: Array[Button] = []
var _box: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color8(8, 6, 18, int(dim * 255.0))
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	center.add_child(_box)
	_build()
	focus_first()

## Inhalt anlegen; wird in den Unterklassen überschrieben.
func _build() -> void:
	pass

func focus_first() -> void:
	if not buttons.is_empty():
		buttons[0].grab_focus()

## Grösse wie im Original (siehe `Art.font_size`).
func add_text(text: String, size := 24.0, color := LIGHT, parent: Container = null) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var settings := LabelSettings.new()
	settings.font = Art.font()
	settings.font_size = Art.font_size(size)
	settings.font_color = color
	settings.outline_color = Art.OUTLINE
	settings.outline_size = maxi(2, int(size) / 8)
	label.label_settings = settings
	(parent if parent != null else _box).add_child(label)
	return label

## Grosser Titel mit Schatten wie im Original.
func add_title(text: String, size: float, color := YELLOW) -> Label:
	var label := add_text(text, size, color)
	label.label_settings.shadow_color = Art.TITLE_SHADOW
	label.label_settings.shadow_offset = Vector2(4.0, 5.0)
	label.label_settings.shadow_size = 1
	return label

func add_gap(height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	_box.add_child(gap)

## Dunkler Kasten für mehrere Textzeilen; gibt den Behälter für `add_text` zurück.
func add_panel() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color8(10, 8, 20, 190)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", style)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 1)
	panel.add_child(inner)
	_box.add_child(panel)
	return inner

func add_hero(skin: Dictionary, color: Color, at: Vector2, facing := 1, figure_scale := 2.2) -> HeroFigure:
	var hero := HeroFigure.new()
	hero.skin = skin
	hero.color = color
	hero.facing = facing
	hero.figure_scale = figure_scale
	hero.position = at
	add_child(hero)
	return hero

func add_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280.0, 34.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", Art.font())
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_stylebox_override("normal", _style(Color8(20, 18, 34, 235), Color8(90, 84, 115)))
	button.add_theme_stylebox_override("hover", _style(Color8(50, 44, 76), Color8(140, 132, 175)))
	button.add_theme_stylebox_override("pressed", _style(Color8(115, 90, 25), YELLOW))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), YELLOW))
	button.add_theme_stylebox_override("disabled", _style(Color8(25, 25, 35, 200), Color8(50, 50, 66)))
	button.pressed.connect(func(): SoundBank.play(&"grab"))
	button.pressed.connect(action)
	_box.add_child(button)
	buttons.append(button)
	return button

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style
