extends Node2D
## Startpunkt von Doppelfaust. Stufe 1: nur Gerüst, zeigt den Titel an.

func _ready() -> void:
	var title := Label.new()
	title.text = "DOPPELFAUST (Godot)"
	title.position = Vector2(300, 250)
	add_child(title)
