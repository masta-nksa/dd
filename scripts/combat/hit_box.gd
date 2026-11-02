class_name HitBox
extends Node
## Schadensfläche des gerade laufenden Angriffs. Jeder Angriff trifft jedes Ziel höchstens einmal.

var active := false
var attack: AttackData
var hit_targets: Array[Fighter] = []

func world_box() -> AABB:
	var f := get_parent() as Fighter
	var a := attack
	var w := a.box_size
	var x_min: float
	if a.both_sides:
		x_min = f.pos_x - w.x * 0.5
	elif f.facing > 0:
		x_min = f.pos_x + a.reach - w.x
	else:
		x_min = f.pos_x - a.reach
	return AABB(Vector3(x_min, f.pos_y + a.box_y, f.pos_z - w.z * 0.5), w)
