class_name CombatSystem
extends Node
## Prüft jede Physik-Runde alle aktiven HitBoxen gegen alle HurtBoxen anderer Teams.
## Muss im Szenenbaum NACH den Fightern stehen (dann läuft es nach deren Aktualisierung).

signal hit_landed(attacker: Fighter, target: Fighter, attack: AttackData)

var fighters: Array[Fighter] = []

func _physics_process(_delta: float) -> void:
	for attacker in fighters:
		var hb := attacker.hit_box
		if not hb.active or hb.attack == null:
			continue
		var box := hb.world_box()
		for target in fighters:
			if target == attacker or target.team == attacker.team or target in hb.hit_targets:
				continue
			if not target.hurt_box.is_enabled():
				continue
			if box.intersects(target.hurt_box.world_box()):
				if target.take_hit(hb.attack, attacker):
					hb.hit_targets.append(target)
					hit_landed.emit(attacker, target, hb.attack)
