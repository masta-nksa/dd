class_name Screen
extends Control
## Grundlage für Menü, Pause und Endbildschirm: abgedunkelter Hintergrund, Texte und Knöpfe untereinander.
## Knöpfe sind echte `Button`, dadurch gehen Maus, Tastatur und Controller ohne eigene Logik.

const YELLOW := Color(1.0, 0.85, 0.3)
const RED := Color(0.95, 0.3, 0.25)
const LIGHT := Color(0.94, 0.93, 0.96)
const GRAY := Color(0.68, 0.68, 0.74)

var dim := 0.65
var buttons: Array[Button] = []
var _box: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.1, dim)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	center.add_child(_box)
	_build()
	focus_first()

## Inhalt anlegen; wird in den Unterklassen überschrieben.
func _build() -> void:
	pass

func focus_first() -> void:
	if not buttons.is_empty():
		buttons[0].grab_focus()

func add_text(text: String, font_size := 18, color := LIGHT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4 if font_size >= 30 else 0)
	_box.add_child(label)
	return label

func add_gap(height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	_box.add_child(gap)

func add_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280.0, 38.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", _style(Color(0.14, 0.13, 0.22, 0.95), Color(0.35, 0.33, 0.45)))
	button.add_theme_stylebox_override("hover", _style(Color(0.22, 0.2, 0.33), Color(0.55, 0.52, 0.68)))
	button.add_theme_stylebox_override("pressed", _style(Color(0.45, 0.35, 0.1), YELLOW))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), YELLOW))
	button.add_theme_stylebox_override("disabled", _style(Color(0.1, 0.1, 0.14, 0.8), Color(0.2, 0.2, 0.26)))
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
	style.set_corner_radius_all(5)
	return style
