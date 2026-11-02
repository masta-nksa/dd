class_name AttackData
extends RefCounted
## Daten eines Angriffs. Zeiten in Sekunden, Längen in Pixeln.

var id: StringName = &""
var startup := 0.08        # Anlauf (kein Schaden)
var active := 0.08         # Hitbox aktiv
var recovery := 0.2        # Erholung nach dem aktiven Teil (hier kann der nächste Combo-Schlag starten)
var damage := 10
var knockback := 100.0     # Rückstoss-Geschwindigkeit des Getroffenen
var hitstun := 0.3         # Trefferstarre
var knockdown := false     # wirft den Getroffenen um
var reach := 50.0          # Abstand Fighter-Mitte bis Vorderkante der Hitbox
var box_size := Vector3(40, 40, 40)   # x = Länge, y = Höhe, z = Tiefe
var box_y := 40.0          # Unterkante der Hitbox über dem Fusspunkt
var lunge := 0.0           # Schritt nach vorn beim Start
var both_sides := false    # Hitbox vor und hinter dem Fighter
var health_cost := 0       # Lebenspunkte, die der Angriff kostet
var chain_to: StringName = &""   # nächster Schlag der Kette
var drive := 0.0           # hält während des aktiven Teils diese Vorwärtsgeschwindigkeit (Rammen)
var chain_needs_hit := false   # Kette läuft nur weiter, wenn der Schlag getroffen hat
var pose: StringName = &"punch"  # Darstellung: punch, kick, spin

func total_time() -> float:
	return startup + active + recovery
