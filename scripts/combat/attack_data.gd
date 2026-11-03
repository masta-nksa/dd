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
var chains := {}           # Combo: Art der Anfrage (&"punch", &"kick", &"kick_high") -> nächster Angriff
var drive := 0.0           # hält während des aktiven Teils diese Vorwärtsgeschwindigkeit (Rammen)
var chain_needs_hit := false   # Kette läuft nur weiter, wenn der Schlag getroffen hat
var durability := 0         # Haltbarkeit, die ein Treffer der Waffe kostet
var throws := false        # in der Anlaufphase fliegt das Getragene los
var pose: StringName = &"straight"  # Darstellung: Name in `Poses`
var hitstop := 0.07        # so lange frieren beide beim Treffer ein
var hit_level: StringName = &"mid"  # wo der Treffer sitzt (&"low", &"mid", &"high"): bestimmt die Reaktion des Getroffenen
var trail: StringName = &""  # Bewegungsspur am schlagenden Glied (&"foot", &"hand"), leer = keine

func total_time() -> float:
	return startup + active + recovery

## Stelle im Clip zur Angriffszeit t: 0–1 Anlauf, 1–2 Treffer, 2–3 Erholung, unabhängig vom Angriffstempo.
func phase_at(t: float) -> float:
	if t < startup:
		return t / startup
	if t < startup + active:
		return 1.0 + (t - startup) / active
	return minf(2.0 + (t - startup - active) / maxf(recovery, 0.0001), 3.0)
