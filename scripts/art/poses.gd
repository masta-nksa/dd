class_name Poses
extends RefCounted
## Posen der Figuren (Port von `posen.py`): Jede Pose ist eine Sammlung von Gelenkwinkeln.
## Winkel in Grad, gemessen von «gerade nach unten», positiv heisst nach vorne.
##   lean    Oberkörper (positiv = nach vorne gebeugt)
##   low     Hüfte wird um so viele Pixel abgesenkt
##   head    Kopf zusätzlich neigen
##   fs, fe  vorderer Arm: Schulter und Ellbogen    bs, be  hinterer Arm
##   fh, fk  vorderes Bein: Hüfte und Knie          bh, bk  hinteres Bein
##   turn    die ganze Figur kippen (nach hinten fallen = negativ)
##   flip    > 0,5: Figur schaut kurz in die andere Richtung
## Animation entsteht, indem man zwischen zwei Posen mischt.

const BASE := {"lean": 6.0, "low": 2.0, "head": 0.0, "fs": 28.0, "fe": 110.0, "bs": 12.0, "be": 120.0,
	"fh": 12.0, "fk": 10.0, "bh": -12.0, "bk": 12.0, "turn": 0.0, "flip": 0.0}
const KICKS: Array[StringName] = [&"kick", &"low_kick", &"high_kick", &"spin_kick", &"jump_kick", &"whirl"]

static var _attacks := {}
static var _hit := {}
static var _hit_high := {}
static var _hit_low := {}
static var _lying := {}
static var _getting_up := {}

static func make(changes: Dictionary) -> Dictionary:
	var pose := BASE.duplicate()
	pose.merge(changes, true)
	return pose

static func mix(a: Dictionary, b: Dictionary, amount: float) -> Dictionary:
	var out := {}
	for key in a:
		out[key] = lerpf(a[key], b[key], amount)
	return out

## Ease-in-out: langsam los, schnell in der Mitte, langsam am Ende.
static func soft(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func stand(t: float) -> Dictionary:
	var breath := sin(t * 3.2)
	return make({"low": 2.0 + 1.5 * breath, "fs": 28.0 + 3.0 * breath, "bs": 12.0 + 3.0 * breath, "fe": 110.0 - 3.0 * breath})

static func walk(t: float) -> Dictionary:
	var w := sin(t * 11.0)
	return make({"lean": 9.0, "low": 2.0 + 2.0 * absf(cos(t * 11.0)),
		"fh": 24.0 * w, "fk": 12.0 + 28.0 * maxf(0.0, -w),
		"bh": -24.0 * w, "bk": 12.0 + 28.0 * maxf(0.0, w),
		"fs": 30.0 - 12.0 * w, "bs": 14.0 + 12.0 * w})

static func jump() -> Dictionary:
	return make({"lean": 12.0, "fh": 55.0, "fk": 85.0, "bh": -5.0, "bk": 75.0, "fs": 55.0, "fe": 70.0, "bs": -35.0, "be": 60.0})

## level: wo der Treffer sitzt. Oben fliegt der Kopf zurück, unten knickt die Figur nach vorn ein.
static func hit(t: float, level: StringName = &"mid") -> Dictionary:
	var pose: Dictionary
	match level:
		&"high":
			if _hit_high.is_empty():
				_hit_high = make({"lean": -34.0, "head": -30.0, "fs": -40.0, "fe": 60.0, "bs": -62.0, "be": 40.0, "fh": 20.0, "fk": 18.0, "bh": -24.0, "bk": 8.0})
			pose = _hit_high.duplicate()
		&"low":
			if _hit_low.is_empty():
				_hit_low = make({"lean": 22.0, "head": 8.0, "low": 9.0, "fs": 12.0, "fe": 70.0, "bs": -18.0, "be": 60.0, "fh": 34.0, "fk": 52.0, "bh": -10.0, "bk": 26.0})
			pose = _hit_low.duplicate()
		_:
			pose = _hit_pose().duplicate()
	pose["lean"] += sin(t * 40.0) * 4.0
	return pose

## t = 0 (gerade getroffen) bis 1 (am Boden).
static func fall(t: float) -> Dictionary:
	var pose := _hit_pose().duplicate()
	pose.merge({"turn": -25.0 - 60.0 * soft(t), "fh": 40.0, "fk": 50.0, "bh": 10.0, "bk": 30.0}, true)
	return pose

static func lying() -> Dictionary:
	if _lying.is_empty():
		_lying = make({"lean": 0.0, "head": -10.0, "low": 0.0, "fs": -150.0, "fe": 10.0, "bs": -170.0, "be": 20.0,
			"fh": 8.0, "fk": 20.0, "bh": -6.0, "bk": 4.0, "turn": -90.0})
	return _lying

## t = 0 (liegt noch) bis 1 (steht).
static func get_up(t: float) -> Dictionary:
	if _getting_up.is_empty():
		_getting_up = make({"low": 22.0, "lean": 38.0, "fh": 50.0, "fk": 95.0, "bh": -15.0, "bk": 80.0, "fs": 55.0, "fe": 40.0, "bs": 20.0, "be": 60.0})
	if t < 0.5:
		return mix(lying(), _getting_up, soft(t * 2.0))
	return mix(_getting_up, BASE, soft(t * 2.0 - 1.0))

static func cheer(t: float) -> Dictionary:
	var hops := absf(sin(t * 6.0))
	return make({"lean": -4.0, "head": -12.0, "fs": 165.0 - 20.0 * hops, "fe": 15.0, "bs": 150.0, "be": 25.0,
		"fh": 10.0, "bh": -10.0, "low": 6.0 * hops})

## Abwehr mit dem Schläger: Der Unterarm hält ihn schräg vor den Körper.
static func block() -> Dictionary:
	return make({"lean": 4.0, "low": 6.0, "fs": 40.0, "fe": 62.0, "bs": 34.0, "be": 84.0, "fh": 18.0, "fk": 20.0, "bh": -16.0, "bk": 18.0})

static func bend() -> Dictionary:
	return make({"lean": 38.0, "low": 10.0, "fs": 104.0, "fe": 14.0, "bs": 96.0, "be": 16.0, "fh": 34.0, "fk": 44.0, "bh": -22.0, "bk": 30.0})

## Etwas Schweres mit beiden Händen über dem Kopf tragen.
static func carry(pose: Dictionary) -> Dictionary:
	var out := pose.duplicate()
	out.merge({"fs": 172.0, "fe": 6.0, "bs": 168.0, "be": 8.0, "lean": pose["lean"] - 4.0}, true)
	return out

## t = Fortschritt 0..1 durch den ganzen Angriff. Im Anlauf: Grundstellung, Ausholen, Treffen;
## in der aktiven Phase die Treffpose halten; in der Erholung zurück zur Grundstellung.
static func attack(id: StringName, t: float, startup_end: float, active_end: float) -> Dictionary:
	var pair: Array = _attack_table()[id]
	var windup: Dictionary = pair[0]
	var strike: Dictionary = pair[1]
	var out: Dictionary
	if t < startup_end:
		var f := t / startup_end
		if f < 0.65:
			out = mix(BASE, windup, soft(f / 0.65))
		else:
			out = mix(windup, strike, soft((f - 0.65) / 0.35))
	elif t < active_end:
		out = strike.duplicate()
	else:
		out = mix(strike, BASE, soft((t - active_end) / maxf(0.0001, 1.0 - active_end)))
	if id == &"whirl":
		# Einmal ganz herum: in der Mitte der Drehung schaut die Figur nach hinten
		var spin := (t - startup_end) / maxf(0.0001, active_end - startup_end)
		out["flip"] = 1.0 if spin > 0.25 and spin < 0.75 else 0.0
	elif id == &"spin_kick":
		out["flip"] = 1.0 if t < startup_end * 0.8 else 0.0
	return out

static func _hit_pose() -> Dictionary:
	if _hit.is_empty():
		_hit = make({"lean": -24.0, "head": -18.0, "fs": -30.0, "fe": 45.0, "bs": -55.0, "be": 30.0, "fh": 16.0, "fk": 22.0, "bh": -20.0, "bk": 10.0})
	return _hit

static func _attack_table() -> Dictionary:
	if not _attacks.is_empty():
		return _attacks
	_attacks = {
		&"straight": [make({"fs": 12.0, "fe": 135.0, "lean": 2.0}),
			make({"fs": 90.0, "fe": 0.0, "lean": 16.0, "bs": 6.0, "be": 125.0, "fh": 20.0, "bh": -22.0})],
		&"hook": [make({"bs": -15.0, "be": 110.0, "lean": -4.0, "fs": 30.0, "fe": 120.0}),
			make({"bs": 92.0, "be": 4.0, "fs": 18.0, "fe": 125.0, "lean": 24.0, "fh": 26.0, "fk": 16.0, "bh": -26.0, "bk": 18.0})],
		&"uppercut": [make({"low": 12.0, "fs": -15.0, "fe": 95.0, "lean": 16.0, "fk": 35.0, "bk": 35.0, "fh": 22.0, "bh": -20.0}),
			make({"fs": 150.0, "fe": 22.0, "lean": -8.0, "head": -12.0, "low": -3.0, "fh": 8.0, "bh": -14.0})],
		&"kick": [make({"fh": 60.0, "fk": 105.0, "lean": -4.0, "fs": 10.0, "fe": 120.0}),
			make({"fh": 92.0, "fk": 0.0, "lean": -18.0, "bh": -6.0, "bk": 12.0, "fs": 0.0, "fe": 120.0, "bs": -20.0, "be": 90.0})],
		&"low_kick": [make({"fh": 56.0, "fk": 98.0, "lean": 3.0, "fs": 12.0, "fe": 125.0, "bs": 26.0, "be": 112.0}),
			make({"fh": 58.0, "fk": 4.0, "lean": 13.0, "low": 4.0, "fs": -12.0, "fe": 98.0, "bs": 46.0, "be": 92.0, "bk": 20.0})],
		&"high_kick": [make({"fh": 70.0, "fk": 115.0, "lean": -8.0, "fs": 10.0, "fe": 120.0}),
			make({"fh": 122.0, "fk": 0.0, "lean": -34.0, "bh": -8.0, "bk": 10.0, "fs": -25.0, "fe": 80.0, "bs": 40.0, "be": 70.0})],
		&"spin_kick": [make({"fh": 40.0, "fk": 90.0, "lean": 10.0, "flip": 1.0, "fs": -20.0, "bs": 40.0}),
			make({"fh": 112.0, "fk": 4.0, "lean": -30.0, "bh": -6.0, "bk": 10.0, "fs": -30.0, "fe": 70.0, "bs": 50.0, "be": 60.0})],
		&"jump_kick": [make({"fh": 45.0, "fk": 95.0, "bh": -25.0, "bk": 95.0, "fs": 40.0, "fe": 70.0, "bs": -30.0, "be": 70.0}),
			make({"fh": 96.0, "fk": 0.0, "bh": 12.0, "bk": 115.0, "lean": -22.0, "fs": -35.0, "fe": 60.0, "bs": 40.0, "be": 80.0})],
		&"jump_punch": [make({"fh": 50.0, "fk": 85.0, "bh": -5.0, "bk": 75.0, "fs": -30.0, "fe": 100.0, "lean": 0.0}),
			make({"fh": 40.0, "fk": 80.0, "bh": -10.0, "bk": 60.0, "fs": 112.0, "fe": 10.0, "lean": 14.0, "bs": -20.0})],
		&"whirl": [make({"fh": 40.0, "fk": 60.0, "low": 8.0, "lean": 10.0}),
			make({"fh": 95.0, "fk": 0.0, "bh": -10.0, "bk": 10.0, "lean": -24.0, "fs": -40.0, "fe": 40.0, "bs": 60.0, "be": 40.0})],
		&"swing": [make({"fs": 165.0, "fe": -30.0, "bs": 160.0, "be": -25.0, "lean": -14.0, "head": -6.0, "low": 1.0}),
			make({"fs": 88.0, "fe": 6.0, "bs": 82.0, "be": 10.0, "lean": 24.0, "low": 8.0, "fh": 30.0, "fk": 22.0, "bh": -34.0, "bk": 20.0})],
		&"homerun": [make({"fs": -35.0, "fe": 60.0, "bs": -40.0, "be": 55.0, "lean": -6.0, "low": 8.0, "fh": 20.0, "bh": -26.0, "fk": 20.0, "bk": 24.0}),
			make({"fs": 98.0, "fe": -4.0, "bs": 92.0, "be": 0.0, "lean": 30.0, "low": 10.0, "fh": 40.0, "fk": 30.0, "bh": -40.0, "bk": 26.0})],
		&"throw": [make({"fs": 168.0, "fe": 36.0, "bs": 164.0, "be": 40.0, "lean": -12.0, "low": 2.0}),
			make({"fs": 100.0, "fe": -14.0, "bs": 96.0, "be": -10.0, "lean": 22.0, "low": 6.0, "fh": 26.0, "fk": 16.0, "bh": -30.0, "bk": 14.0})],
		&"hammer": [make({"fs": 175.0, "fe": 30.0, "bs": 165.0, "be": 30.0, "lean": -16.0, "head": -10.0, "low": -2.0}),
			make({"fs": 80.0, "fe": 10.0, "bs": 70.0, "be": 15.0, "lean": 30.0, "low": 10.0, "fh": 30.0, "fk": 30.0, "bh": -30.0, "bk": 20.0})],
		&"ram": [make({"low": 10.0, "lean": 20.0, "fs": -20.0, "fe": 90.0, "bs": -30.0, "be": 90.0, "fk": 40.0, "bk": 40.0}),
			make({"lean": 42.0, "low": 6.0, "fs": 70.0, "fe": 80.0, "bs": 50.0, "be": 70.0, "fh": 40.0, "fk": 30.0, "bh": -42.0, "bk": 25.0})],
	}
	return _attacks
