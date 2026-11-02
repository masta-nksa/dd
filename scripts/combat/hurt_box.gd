class_name HurtBox
extends Node
## Trefferfläche eines Fighters (Quader im Raum: x, y = Höhe, z = Tiefe).

var size := Vector3(36, 90, 30)

func is_enabled() -> bool:
	var f := get_parent() as Fighter
	return f != null and not f.is_invulnerable()

func world_box() -> AABB:
	var f := get_parent() as Fighter
	return AABB(Vector3(f.pos_x - size.x * 0.5, f.pos_y, f.pos_z - size.z * 0.5), size)
