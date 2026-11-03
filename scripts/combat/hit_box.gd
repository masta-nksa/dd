class_name HitBox
extends Node
## Schadensfläche des gerade laufenden Angriffs. Jeder Angriff trifft jedes Ziel höchstens einmal.

var active := false
var attack: AttackData
var hit_targets: Array[Fighter] = []
var blocked_targets: Array[Fighter] = []   # abgewehrt: zählt nicht als Treffer, wird aber auch nur einmal geprüft
var hit_props: Array[Prop] = []

func world_box() -> AABB:
	var f := get_parent() as Fighter
	var a := attack
	var k := f.body_scale
	var w := Vector3(a.box_size.x * k, a.box_size.y * k, a.box_size.z)
	var reach := a.reach * k
	var x_min: float
	if a.both_sides:
		x_min = f.pos_x - w.x * 0.5
	elif f.facing > 0:
		x_min = f.pos_x + reach - w.x
	else:
		x_min = f.pos_x - reach
	return AABB(Vector3(x_min, f.pos_y + a.box_y * k, f.pos_z - w.z * 0.5), w)
