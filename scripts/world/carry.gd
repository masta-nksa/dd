class_name Carry
extends RefCounted
## Was ein Kämpfer gerade in den Händen hält.

var kind: StringName
var data: Dictionary
var rest: int
var maximum: int
var heavy: bool
var prop: Prop = null   # bei Kiste, Fass, Tonne: das echte Objekt, damit es heil wieder hingestellt werden kann

func _init(new_kind: StringName, new_rest := -1, new_prop: Prop = null) -> void:
	kind = new_kind
	data = WeaponData.get_data(kind)
	maximum = data["durability"]
	rest = maximum if new_rest < 0 else new_rest
	heavy = data["heavy"]
	prop = new_prop

func ratio() -> float:
	return maxf(0.0, float(rest) / float(maximum))

func display_name() -> String:
	return data["name"]
