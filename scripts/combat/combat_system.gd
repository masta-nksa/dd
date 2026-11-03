class_name CombatSystem
extends Node
## Prüft jede Physik-Runde alle aktiven HitBoxen gegen alle HurtBoxen anderer Teams.
## Muss im Szenenbaum NACH den Fightern stehen (dann läuft es nach deren Aktualisierung).

signal hit_landed(attacker: Fighter, target: Fighter, attack: AttackData)

var fighters: Array[Fighter] = []
var items: WorldItems = null

func _physics_process(_delta: float) -> void:
	for attacker in fighters:
		var hb := attacker.hit_box
		if not hb.active or hb.attack == null:
			continue
		var box := hb.world_box()
		for target in fighters:
			if target == attacker or target.team == attacker.team or target in hb.hit_targets or target in hb.blocked_targets:
				continue
			if not target.hurt_box.is_enabled():
				continue
			if box.intersects(target.hurt_box.world_box()):
				if target.try_block(hb.attack, attacker):
					hb.blocked_targets.append(target)
				elif target.take_hit(hb.attack, attacker):
					hb.hit_targets.append(target)
					hit_landed.emit(attacker, target, hb.attack)
					attacker.on_hit_landed(hb.attack)
		if items != null and attacker.team == 0:
			for prop in items.props.duplicate():
				if prop.breakable and not prop in hb.hit_props and box.intersects(prop.hit_aabb()):
					hb.hit_props.append(prop)
					prop.hit(items)
					attacker.on_hit_landed(hb.attack)
	if items != null:
		_check_projectiles()

func _check_projectiles() -> void:
	for proj in items.projectiles.duplicate():
		if not proj.dangerous or not is_instance_valid(proj):
			continue
		var box: AABB = proj.box()
		for target in fighters:
			if target.team == proj.team or target in proj.hit_targets or not target.hurt_box.is_enabled():
				continue
			if box.intersects(target.hurt_box.world_box()):
				if target.take_hit(proj.attack, proj.owner_fighter, proj.pos_x):
					proj.on_hit(target)
					hit_landed.emit(proj.owner_fighter, target, proj.attack)
					break
