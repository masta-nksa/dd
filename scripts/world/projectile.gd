class_name Projectile
extends Node2D
## Ein geworfenes Ding im Flug. Trifft Gegner wie ein Schlag (jeden nur einmal).

var owner_fighter: Fighter
var carry: Carry
var attack: AttackData
var team := 0
var items: WorldItems
var pos_x := 0.0
var pos_z := 0.0
var pos_y := 70.0
var vx := 0.0
var vy := 0.0
var dangerous := true
var hit_targets: Array[Fighter] = []
var _age := 0.0
var _spin := 0.0
var _dir := 1

func setup(thrower: Fighter, thrown: Carry, new_items: WorldItems) -> void:
	owner_fighter = thrower
	carry = thrown
	items = new_items
	team = thrower.team
	_dir = thrower.facing
	attack = Attacks.get_attack(carry.data["throw_attack"])
	pos_x = thrower.pos_x + _dir * 18.0
	pos_z = thrower.pos_z
	var v: Vector2 = carry.data["v"]
	vx = v.x * _dir
	vy = v.y
	_apply()

func box_size() -> Vector3:
	if carry.heavy:
		return Vector3(carry.prop.width, carry.prop.height, 28.0)
	return Vector3(56.0, 14.0, 28.0)

func box() -> AABB:
	var s := box_size()
	return AABB(Vector3(pos_x - s.x * 0.5, pos_y, pos_z - s.z * 0.5), s)

func _apply() -> void:
	position = Vector2(pos_x, pos_z - pos_y)
	z_index = int(pos_z)

func on_hit(target: Fighter) -> void:
	hit_targets.append(target)
	if carry.heavy:
		items.break_prop(carry.prop, false, pos_x, pos_z, pos_y)
		items.forget(self)
		queue_free()
	else:
		# der Schläger prallt ab und fällt zu Boden
		dangerous = false
		vx = -_dir * 70.0
		vy = maxf(vy, 160.0)

func _physics_process(delta: float) -> void:
	_age += delta
	vy -= 1800.0 * delta
	pos_x += vx * delta
	pos_y += vy * delta
	_spin += delta * 16.0 * _dir
	_apply()
	if pos_y <= 0.0 and vy < 0.0:
		pos_y = 0.0
		_land()
	elif _age > 4.0:
		items.forget(self)
		queue_free()
	queue_redraw()

func _land() -> void:
	items.forget(self)
	queue_free()
	if carry.heavy:
		items.break_prop(carry.prop, false, pos_x, pos_z, 0.0)
		return
	var x := items.clamp_to_screen(pos_x)
	if carry.rest > 0:
		items.spawn_weapon(carry.kind, carry.rest, x, pos_z, 10.0, false)
		items.effects.debris(x, pos_z, 4.0, [Art.lighter(WeaponPickup.WOOD)], 3)
	else:
		items.effects.debris(x, pos_z, 10.0, [WeaponPickup.WOOD, Art.darker(WeaponPickup.WOOD)], 10)

func _draw() -> void:
	if carry.heavy:
		Art.shadow(self, 0.0, pos_y + 2.0, maxf(18.0, carry.prop.width * 1.1 / (1.0 + pos_y / 120.0)))
		Prop.draw_art(self, carry.kind, carry.prop.width, carry.prop.height, carry.prop.color, 1.0, Vector2(0, 6))
	else:
		Art.shadow(self, 0.0, pos_y + 2.0, 44.0 / (1.0 + pos_y / 120.0))
		var d := Vector2(cos(_spin), sin(_spin)) * WeaponPickup.BAT_GROUND_PX * 0.5
		WeaponPickup.draw_bat(self, Vector2(0, -7) - d, Vector2(0, -7) + d, carry.ratio())
