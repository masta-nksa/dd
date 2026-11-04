class_name WorldItems
extends Node
## Verwaltet alles Bewegliche in der Welt ausser den Kämpfern: Requisiten, Waffen am Boden, Heilung/Geld,
## Wurfgeschosse und Effekte. Enthält auch den Waffenverteiler (Port von `Waffenverteiler`):
##   - höchstens so viele Waffen am Boden wie Spieler
##   - mindestens 12 s zwischen zwei Drops, nach 90 s ohne Drop dreifache Chance
##   - trägt schon jemand eine Waffe, ist die Chance halbiert
##   - die erste zerschlagene Kiste enthält immer einen Schläger

const CHANCES := {&"thug": 0.10, &"dasher": 0.12, &"brute": 0.30, &"boss": 0.0,
	&"crate": 0.22, &"barrel": 0.12, &"bin": 0.15}
const MIN_DROP_GAP := 12.0
const PITY_TIME := 90.0
const PITY_FACTOR := 3.0
const WEAPON_GROUND_TIME := 12.0
const DEATH_WEAPON_TIME := 8.0
const GRAB_REACH := Vector2(34.0, 18.0)

var props: Array[Prop] = []
var weapons: Array[WeaponPickup] = []
var pickups: Array[Pickup] = []
var projectiles: Array[Projectile] = []
var effects: Effects
var players: Array[Fighter] = []
var camera: CameraRig = null
var keep_on_screen := false
var elapsed := 0.0

var _last_drop := -1.0
var _crate_guaranteed := true

func _init() -> void:
	effects = Effects.new()
	add_child(effects)

func _physics_process(delta: float) -> void:
	elapsed += delta
	for item in pickups.duplicate():
		for p in players:
			if p.current_health > 0 and absf(p.pos_x - item.pos_x) < 28.0 and absf(p.pos_z - item.pos_z) < 18.0 \
					and p.pos_y < 20.0 and item.pos_y < 30.0:
				item.collect(p)
				break

# ------------------------------------------------------------ Erzeugen / Entfernen

func add_prop(kind: StringName, x: float, z: float) -> Prop:
	var p := Prop.create(kind, x, z)
	add_child(p)
	props.append(p)
	return p

func spawn_weapon(kind: StringName, rest: int, x: float, z: float, life := WEAPON_GROUND_TIME, blink := false) -> WeaponPickup:
	var w := WeaponPickup.new()
	w.kind = kind
	w.rest = rest
	w.lifetime = life
	w.blinking = blink
	w.items = self
	w.place(x, z)
	add_child(w)
	weapons.append(w)
	return w

func spawn_pickup(kind: StringName, x: float, z: float) -> Pickup:
	var item := Pickup.new()
	item.kind = kind
	item.items = self
	item.place(x, z)
	add_child(item)
	pickups.append(item)
	return item

func spawn_projectile(thrower: Fighter, carry: Carry) -> Projectile:
	var p := Projectile.new()
	p.setup(thrower, carry, self)
	add_child(p)
	projectiles.append(p)
	return p

## Räumt alles ab (beim Levelwechsel): Requisiten, Waffen, Beute und Geschosse.
func clear_world() -> void:
	for list: Array in [props, weapons, pickups, projectiles]:
		for node in list.duplicate():
			if is_instance_valid(node):
				node.queue_free()
		list.clear()

func forget(node: Node) -> void:
	if node is WeaponPickup:
		weapons.erase(node)
	elif node is Pickup:
		pickups.erase(node)
	elif node is Projectile:
		projectiles.erase(node)
	elif node is Prop:
		props.erase(node)

func clamp_to_screen(x: float) -> float:
	if camera == null or not keep_on_screen:
		return x
	return clampf(x, camera.position.x - 450.0, camera.position.x + 450.0)

## Requisit geht kaputt (zerschlagen oder beim Wurf). Beute und Waffen-Drop werden ausgewürfelt.
func break_prop(prop: Prop, smashed: bool, at_x := NAN, at_z := NAN, at_y := NAN) -> void:
	var x := prop.pos_x if is_nan(at_x) else at_x
	var z := prop.pos_z if is_nan(at_z) else at_z
	var y := prop.height * 0.5 if is_nan(at_y) else at_y + prop.height * 0.5
	effects.debris(x, z, y, prop.debris_colors(), 16)
	SoundBank.play(&"smash")
	forget(prop)
	prop.queue_free()
	if smashed:
		roll_weapon(prop.kind, x, z)
	# geworfen und zerbrochen: nur halb so oft Beute
	if smashed or randf() < 0.5:
		var loot := _loot_for(prop.kind)
		if loot != &"":
			spawn_pickup(loot, clamp_to_screen(x), z)

func _loot_for(kind: StringName) -> StringName:
	match kind:
		&"crate": return [&"chicken", &"apple", &"money"].pick_random()
		&"barrel": return [&"money", &"chicken"].pick_random()
		&"bin": return [&"apple", &"apple", &""].pick_random()
	return &""

# ------------------------------------------------------------ Greifen

## Was liegt in Reichweite und passt zur Greifen-Taste? Mit einer Kiste in den Händen: nichts.
func find_grabbable(f: Fighter) -> Node2D:
	if (f.carried != null and f.carried.heavy) or f.pos_y > 10.0:
		return null
	var best: Node2D = null
	var best_cost := INF
	for w in weapons:
		var dx := absf(w.pos_x - f.pos_x)
		var dz := absf(w.pos_z - f.pos_z)
		if dx < GRAB_REACH.x and dz < GRAB_REACH.y and w.pos_y < 30.0 and dx + 2.0 * dz < best_cost:
			best = w
			best_cost = dx + 2.0 * dz
	if f.carried == null:
		for p in props:
			if not p.grabbable or p.in_hands:
				continue
			var dx2 := absf(p.pos_x - f.pos_x)
			var dz2 := absf(p.pos_z - f.pos_z)
			if dx2 < p.width * 0.5 + 30.0 and dz2 < p.depth + 20.0 and dx2 + 2.0 * dz2 < best_cost:
				best = p
				best_cost = dx2 + 2.0 * dz2
	return best

func take(f: Fighter, target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	SoundBank.play(&"grab")
	if f.carried != null:
		f.lay_down(false)   # Tauschen: die alte Waffe fällt vor die Füsse
	if target is WeaponPickup:
		f.carried = Carry.new(target.kind, target.rest)
		target.remove()
	elif target is Prop:
		f.carried = Carry.new(StringName(target.kind), -1, target)
		target.in_hands = true
		props.erase(target)
		target.visible = false

## Das Getragene fällt auf den Boden.
func put_down(f: Fighter, died: bool) -> void:
	var c := f.carried
	f.carried = null
	if c == null:
		return
	if c.heavy:
		var p := c.prop
		p.in_hands = false
		p.visible = true
		p.pos_x = clamp_to_screen(f.pos_x + f.facing * 34.0)
		p.pos_z = f.pos_z
		p.place()
		props.append(p)
	elif died:
		spawn_weapon(c.kind, c.rest, f.pos_x, f.pos_z, DEATH_WEAPON_TIME, true)
	else:
		spawn_weapon(c.kind, c.rest, f.pos_x, f.pos_z)

# ------------------------------------------------------------ Waffenverteiler

func roll_weapon(source: StringName, x: float, z: float) -> bool:
	var active: Array[Fighter] = []
	for p in players:
		if p.current_health > 0:
			active.append(p)
	if active.is_empty():
		return false
	if source == &"crate" and _crate_guaranteed:
		_crate_guaranteed = false
		return _drop(x, z)
	var chance: float = CHANCES.get(source, 0.0)
	if chance <= 0.0:
		return false
	if weapons.size() >= active.size():
		return false
	if _last_drop >= 0.0 and elapsed - _last_drop < MIN_DROP_GAP:
		return false
	for p in active:
		if p.carried != null and not p.carried.heavy:
			chance *= 0.5
			break
	if elapsed - maxf(_last_drop, 0.0) > PITY_TIME:
		chance *= PITY_FACTOR
	if randf() >= chance:
		return false
	return _drop(x, z)

func _drop(x: float, z: float) -> bool:
	_last_drop = elapsed
	spawn_weapon(&"bat", WeaponData.get_data(&"bat")["durability"], clamp_to_screen(x), z)
	return true
