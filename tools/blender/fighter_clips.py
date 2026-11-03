"""Kampf-Clips der 3D-Kämpfer: Schlüsselposen als Text und ihr Bake auf das Skelett einer Figur.

Die `.glb` entstehen im Workflow aus diesen Daten, darum leben die Keyframes hier und nicht in einer `.blend`.
Winkel in Grad wie in `scripts/art/poses.gd`, Längen in Spielpixeln (52,8 px = 1 m):
    lean, head            Oberkörper und Kopf (positiv = nach vorn)
    pitch, yaw, twist     Becken kippen, Becken drehen, Brust zusätzlich drehen (positiv = Blick zur Kamera)
    shift, low            Hüfte nach vorn schieben, Hüfte absenken
    fs, fe / bs, be       vorderer / hinterer Arm: Schulter und Ellbogen, gemessen von «gerade nach unten»
    fsl, fel / bsl, bel   Oberarm und Unterarm seitlich (positiv = vom Körper weg)
    fh, fk / bh, bk       vorderes / hinteres Bein: Hüfte und Knie
    fl / bl               Bein seitlich (positiv = vom Körper weg)
    ff / bf               Fussspitze strecken
    fp / bp               1 = Fuss steht fest am Boden (Bein folgt der Hüfte per IK, reicht es nicht, hebt sich die Ferse),
                          0 = Bein folgt den Winkeln
    pf / pb               Drehung des stehenden Fusses
    look                  wie stark der Kopf trotz Körperdrehung zum Gegner schaut (0 bis 1)
«Vorn» ist die Körperseite zur Kamera; jeder Clip entsteht darum als `<id>_R` (Blick nach rechts) und `<id>_L`.

Zeitachse: Jeder Clip dauert 3 Sekunden: 0–1 Anlauf, 1–2 Treffer, 2–3 Erholung. `ModelFigure` bildet die echten
Zeiten des Angriffs (`AttackData`) darauf ab; so bleibt der Treffermoment bei jedem Angriffstempo exakt.
"""
import math

import bpy
from bpy_extras import anim_utils
from mathutils import Matrix, Quaternion, Vector

PX_PER_M = 52.8     # wie `ModelFigure.PX_PER_M`
FPS = 60
CLIP_FIGHTERS = ("bruce",)

STANCE = dict(lean=6.0, head=0.0, pitch=0.0, yaw=0.0, twist=0.0, shift=0.0, low=2.0,
              fs=28.0, fe=110.0, fsl=0.0, fel=0.0, bs=12.0, be=120.0, bsl=0.0, bel=0.0,
              fh=12.0, fk=10.0, fl=0.0, ff=0.0, pf=0.0, fp=1.0,
              bh=-12.0, bk=12.0, bl=0.0, bf=0.0, pb=0.0, bp=1.0, look=0.8)


def P(**changes):
    return {**STANCE, **changes}


# Kurz nach dem Absprung, so wie `Poses.jump`
AIR = P(lean=12.0, fs=55.0, fe=70.0, bs=-35.0, be=60.0, fh=55.0, fk=85.0, bh=-5.0, bk=75.0, fp=0.0, bp=0.0)

_LOW_CHAMBER = P(fh=56.0, fk=98.0, fp=0.0, ff=-28.0, shift=-5.0, low=5.0, lean=3.0, yaw=-8.0, twist=12.0,
                 fs=12.0, fe=125.0, bs=26.0, be=112.0)
_LOW_HIT = P(fh=58.0, fk=4.0, fp=0.0, ff=38.0, shift=7.0, low=4.0, lean=13.0, pitch=7.0, yaw=-20.0, twist=16.0, head=-6.0,
             fs=-12.0, fe=98.0, bs=46.0, be=92.0)

_HIGH_LOAD = P(shift=7.0, low=6.0, lean=12.0, yaw=-12.0, twist=-10.0, pf=-10.0, fs=34.0, fe=118.0, bs=2.0, be=112.0)
_HIGH_CHAMBER = P(shift=5.0, low=4.0, lean=-4.0, pitch=-4.0, yaw=48.0, twist=-14.0, pf=34.0,
                  bh=108.0, bk=118.0, bl=32.0, bp=0.0, bf=18.0, fs=40.0, fe=112.0, bs=-8.0, be=92.0)
_HIGH_HIT = P(shift=7.0, low=3.0, lean=-30.0, pitch=-10.0, yaw=72.0, twist=-26.0, pf=52.0, head=8.0, look=0.95,
              bh=140.0, bk=4.0, bl=46.0, bp=0.0, bf=44.0, fh=8.0, fk=14.0,
              fs=44.0, fe=72.0, fsl=14.0, bs=-34.0, be=48.0, bsl=18.0)
_HIGH_FOLLOW = {**_HIGH_HIT, "bh": 146.0, "bl": 50.0, "yaw": 78.0, "lean": -33.0}
_HIGH_RECHAMBER = P(shift=2.0, low=5.0, lean=-8.0, pitch=-3.0, yaw=44.0, twist=-14.0, pf=30.0,
                    bh=98.0, bk=122.0, bl=26.0, bp=0.0, bf=12.0, fs=42.0, fe=110.0, bs=0.0, be=98.0)
_HIGH_LAND = P(low=7.0, lean=5.0, yaw=10.0, pf=8.0, bh=16.0, bk=62.0, bp=0.0, bf=-16.0, fs=30.0, fe=112.0, bs=14.0, be=116.0)

_JAB_LOAD = P(lean=2.0, low=3.0, shift=-3.0, twist=20.0, fs=12.0, fe=135.0, bs=14.0, be=118.0)
_JAB_HIT = P(lean=15.0, low=5.0, shift=12.0, yaw=-14.0, twist=-26.0, head=-5.0, pf=-6.0, pb=-14.0,
             fs=90.0, fe=2.0, bs=8.0, be=125.0)

_HOOK_LOAD = P(lean=3.0, low=5.0, shift=-2.0, yaw=-14.0, twist=-24.0, pf=-8.0, fs=32.0, fe=118.0, bs=-14.0, be=112.0, bsl=14.0)
_HOOK_HIT = P(lean=18.0, low=7.0, shift=13.0, yaw=26.0, twist=34.0, pf=14.0, pb=26.0, head=-6.0, look=0.9,
              fs=20.0, fe=122.0, bs=82.0, be=8.0, bsl=52.0, bel=-30.0)

_UPPER_LOAD = P(low=15.0, lean=15.0, shift=2.0, twist=22.0, yaw=8.0, fs=-12.0, fe=98.0, fsl=8.0, bs=22.0, be=112.0)
_UPPER_HIT = P(low=1.0, lean=-6.0, pitch=-4.0, shift=10.0, yaw=-12.0, twist=-24.0, head=-14.0, pb=-14.0,
               fs=100.0, fe=48.0, fsl=6.0, bs=-4.0, be=118.0)

_FLY_LOAD = {**AIR, "fh": 62.0, "fk": 112.0, "bh": -18.0, "bk": 92.0, "lean": 4.0, "yaw": 14.0, "twist": 10.0}
_FLY_HIT = P(lean=-22.0, pitch=-10.0, yaw=-22.0, twist=20.0, head=6.0, low=0.0, fp=0.0, bp=0.0,
             fh=88.0, fk=0.0, ff=42.0, bh=8.0, bk=118.0, bf=20.0, fs=-34.0, fe=62.0, bs=44.0, be=82.0)
_FLY_TUCK = {**AIR, "fh": 62.0, "fk": 58.0, "bh": 4.0, "bk": 96.0, "lean": 4.0}

_SPIN_LOAD = P(low=9.0, lean=10.0, yaw=-34.0, twist=-18.0, pf=-20.0, pb=-30.0, fs=30.0, fe=88.0, fsl=26.0, bs=26.0, be=90.0, bsl=26.0)


def _spin(yaw):
    return P(low=7.0, lean=-10.0, yaw=yaw, look=0.0, pb=yaw, fp=0.0, ff=34.0,
             fh=96.0, fk=6.0, fl=66.0, fs=70.0, fe=16.0, fsl=62.0, bs=68.0, be=20.0, bsl=62.0)


# (Zeit, Pose, Kurve auf dem Weg zu dieser Pose). out = schnell los und abfedern, in = beschleunigen, soft = beides
CLIPS = {
    "kick_low": dict(samples=(8, 4, 10), keys=[
        (0.0, STANCE, "soft"), (0.5, _LOW_CHAMBER, "soft"), (1.0, _LOW_HIT, "out"),
        (2.0, {**_LOW_HIT, "fh": 60.0, "shift": 8.0}, "lin"), (2.4, _LOW_CHAMBER, "out"),
        (2.75, P(fh=30.0, fk=60.0, fp=0.0, ff=-14.0, low=4.0), "soft"), (3.0, STANCE, "soft")]),
    "kick_high": dict(samples=(10, 4, 12), keys=[
        (0.0, STANCE, "soft"), (0.35, _HIGH_LOAD, "soft"), (0.72, _HIGH_CHAMBER, "in"), (1.0, _HIGH_HIT, "out"),
        (2.0, _HIGH_FOLLOW, "lin"), (2.3, _HIGH_RECHAMBER, "out"), (2.72, _HIGH_LAND, "soft"), (3.0, STANCE, "soft")]),
    "punch1": dict(samples=(6, 3, 8), keys=[
        (0.0, STANCE, "soft"), (0.55, _JAB_LOAD, "soft"), (1.0, _JAB_HIT, "out"),
        (2.0, {**_JAB_HIT, "shift": 13.0}, "lin"), (3.0, STANCE, "soft")]),
    "punch2": dict(samples=(6, 3, 8), keys=[
        (0.0, STANCE, "soft"), (0.55, _HOOK_LOAD, "soft"), (1.0, _HOOK_HIT, "out"),
        (2.0, {**_HOOK_HIT, "yaw": 32.0, "twist": 38.0}, "lin"), (3.0, STANCE, "soft")]),
    "punch3": dict(samples=(8, 3, 10), keys=[
        (0.0, STANCE, "soft"), (0.6, _UPPER_LOAD, "soft"), (1.0, _UPPER_HIT, "out"),
        (2.0, {**_UPPER_HIT, "fs": 112.0, "fe": 42.0, "lean": -9.0}, "lin"), (2.5, P(low=6.0, lean=2.0), "soft"), (3.0, STANCE, "soft")]),
    "jump_kick": dict(air=True, samples=(5, 4, 5), keys=[
        (0.0, AIR, "soft"), (0.5, _FLY_LOAD, "soft"), (1.0, _FLY_HIT, "out"),
        (2.0, {**_FLY_HIT, "fh": 92.0}, "lin"), (3.0, _FLY_TUCK, "soft")]),
    "spin": dict(samples=(6, 18, 8), keys=[
        (0.0, STANCE, "soft"), (0.7, _SPIN_LOAD, "soft"), (1.0, _spin(-14.0), "in"),
        (2.0, _spin(346.0), "lin"), (2.6, {**_spin(360.0), "fh": 44.0, "fk": 78.0, "fl": 8.0, "ff": -20.0}, "out"),
        (3.0, {**STANCE, "yaw": 360.0, "pb": 360.0}, "soft")]),
}

_EASES = {
    "lin": lambda f: f,
    "soft": lambda f: f * f * (3.0 - 2.0 * f),
    "out": lambda f: 1.0 - (1.0 - f) ** 3,
    "in": lambda f: f ** 3,
}


def channels_at(clip, t):
    """Mischt die Kanäle aller Schlüsselposen zur logischen Zeit t (0 bis 3)."""
    keys = clip["keys"]
    if t <= keys[0][0]:
        return dict(keys[0][1])
    for (t0, a, _), (t1, b, ease) in zip(keys, keys[1:]):
        if t <= t1:
            f = _EASES[ease]((t - t0) / (t1 - t0))
            return {k: a[k] + (b[k] - a[k]) * f for k in a}
    return dict(keys[-1][1])


def sample_times(clip):
    out = []
    for phase, count in enumerate(clip["samples"]):
        out += [phase + i / count for i in range(count)]
    return out + [3.0]


def _rx(deg):
    return Quaternion((1.0, 0.0, 0.0), math.radians(deg))


def _rz(deg):
    return Quaternion((0.0, 0.0, 1.0), math.radians(deg))


def _limb_dir(pitch, lateral, side_x):
    """Richtung im Körperrahmen: pitch 0 = nach unten, 90 = nach vorn (-Y), lateral = von der Körpermitte weg."""
    p, l = math.radians(pitch), math.radians(lateral)
    return Vector((side_x * math.sin(l), -math.sin(p) * math.cos(l), -math.cos(p) * math.cos(l)))


def _chain(frame, rest_dir, target):
    """Drehung eines Knochens: übernimmt den Rahmen des Elternknochens und richtet sich dann auf das Ziel aus."""
    return (frame @ rest_dir).rotation_difference(target) @ frame


class ClipRig:
    """Ruhe-Daten eines Skeletts und die Berechnung einer Haltung aus den Kanälen."""

    def __init__(self, arm):
        self.arm = arm
        bones = arm.data.bones
        self.head = {b.name: b.head_local.copy() for b in bones}
        self.foot_vec = {s: bones[f"foot.{s}"].tail_local - bones[f"foot.{s}"].head_local for s in "LR"}
        self.rest = {b.name: b.matrix_local.to_quaternion() for b in bones}
        self.parent = {b.name: b.parent.name if b.parent else None for b in bones}
        self.order = [b.name for b in bones]
        self.child = {"upper_arm": "forearm", "forearm": "hand", "thigh": "shin", "shin": "foot"}
        self._targets = {}

    def _dir(self, bone, side):
        child = self.child[bone]
        return (self.head[f"{child}.{side}"] - self.head[f"{bone}.{side}"]).normalized()

    def _length(self, bone, side):
        child = self.child[bone]
        return (self.head[f"{child}.{side}"] - self.head[f"{bone}.{side}"]).length

    def _plant_target(self, side, near):
        """Ort des Knöchels in der Grundstellung; der stehende Fuss bleibt dort, auf seiner Ruhe-Höhe."""
        key = (side, near)
        if key not in self._targets:
            f = "f" if side == near else "b"
            side_x = 1.0 if side == "L" else -1.0
            hip, a, b = self.head[f"thigh.{side}"], self._length("thigh", side), self._length("shin", side)
            ankle = hip + _limb_dir(STANCE[f + "h"], 0.0, side_x) * a + _limb_dir(STANCE[f + "h"] - STANCE[f + "k"], 0.0, side_x) * b
            self._targets[key] = Vector((ankle.x, ankle.y, self.head[f"foot.{side}"].z))
        return self._targets[key]

    def ball_point(self, side, near, flat):
        """Fussballen des stehenden Fusses: dieser Punkt bleibt am Boden."""
        return self._plant_target(side, near) + flat @ self.foot_vec[side]

    def _lift_heel(self, ball, flat, hip, reach, side):
        """Reicht das Bein nicht bis zum Boden, hebt sich die Ferse, der Ballen bleibt stehen."""
        vec = self.foot_vec[side]
        ankle = ball - flat @ vec
        if (ankle - hip).length <= reach:
            return ankle, flat
        low, high = 0.0, 70.0
        for _ in range(14):
            mid = (low + high) * 0.5
            if (ball - flat @ _rx(mid) @ vec - hip).length > reach:
                low = mid
            else:
                high = mid
        tilted = flat @ _rx(high)
        return ball - tilted @ vec, tilted

    def _two_bone(self, hip, ankle, a, b, pole):
        """Richtungen von Oberschenkel und Schienbein, damit das Bein von der Hüfte zum Knöchel reicht; das Knie zeigt zu pole."""
        to_foot = ankle - hip
        d = max(min(to_foot.length, (a + b) * 0.9995), abs(a - b) + 0.001)
        u = to_foot.normalized()
        v = (pole - u * pole.dot(u)).normalized()
        cos_a = max(-1.0, min(1.0, (a * a + d * d - b * b) / (2.0 * a * d)))
        knee = u * (a * cos_a) + v * (a * math.sqrt(max(0.0, 1.0 - cos_a * cos_a)))
        return knee.normalized(), (u * d - knee).normalized()

    def _leg(self, side, f, ch, near, hips_pos, r_hips, yaw_frame, near_x):
        side_x = 1.0 if side == "L" else -1.0
        a, b = self._length("thigh", side), self._length("shin", side)
        pitch, knee, lateral, plant = ch[f + "h"], ch[f + "k"], ch[f + "l"], ch[f + "p"]
        thigh_dir = yaw_frame @ _limb_dir(pitch, lateral, side_x)
        shin_dir = yaw_frame @ _limb_dir(pitch - knee, lateral, side_x)
        hip = hips_pos + r_hips @ (self.head[f"thigh.{side}"] - self.head["hips"])
        pole = yaw_frame @ Vector((0.0, -1.0, 0.0))
        flat = _rz(near_x * ch["p" + f])
        if plant > 0.0:
            ankle, flat = self._lift_heel(self.ball_point(side, near, flat), flat, hip, (a + b) * 0.9995, side)
            ik_thigh, ik_shin = self._two_bone(hip, ankle, a, b, pole)
            thigh_dir = thigh_dir.lerp(ik_thigh, plant).normalized()
            shin_dir = shin_dir.lerp(ik_shin, plant).normalized()
        # Boden: Der Knöchel bleibt über seiner Ruhe-Höhe, die Fussspitze wird notfalls flacher gehalten
        floor = self._plant_target(side, near).z
        ankle = hip + thigh_dir * a + shin_dir * b
        if ankle.z < floor:
            ankle.z = floor
            thigh_dir, shin_dir = self._two_bone(hip, ankle, a, b, pole)
            ankle = hip + thigh_dir * a + shin_dir * b
        r_thigh = _chain(r_hips, self._dir("thigh", side), thigh_dir)
        r_shin = _chain(r_thigh, self._dir("shin", side), shin_dir)
        r_foot = (r_shin @ _rx(ch[f + "f"])).slerp(flat, plant)
        vec = self.foot_vec[side]
        if (ankle + r_foot @ vec).z < floor + vec.z:
            low, high = 0.0, 1.0
            for _ in range(10):
                mid = (low + high) * 0.5
                if (ankle + r_foot.slerp(flat, mid) @ vec).z < floor + vec.z:
                    low = mid
                else:
                    high = mid
            r_foot = r_foot.slerp(flat, high)
        return {f"thigh.{side}": r_thigh, f"shin.{side}": r_shin, f"foot.{side}": r_foot}

    def _arm_pose(self, side, f, ch, r_chest, yaw_frame):
        side_x = 1.0 if side == "L" else -1.0
        upper = yaw_frame @ _limb_dir(ch[f + "s"], ch[f + "sl"], side_x)
        lower = yaw_frame @ _limb_dir(ch[f + "s"] + ch[f + "e"], ch[f + "el"], side_x)
        r_upper = _chain(r_chest, self._dir("upper_arm", side), upper)
        r_lower = _chain(r_upper, self._dir("forearm", side), lower)
        return {f"upper_arm.{side}": r_upper, f"forearm.{side}": r_lower, f"hand.{side}": r_lower}

    def solve(self, ch, near):
        """Absolute Drehung jedes Knochens gegenüber der Rest-Pose (im Raum der Armature) und Versatz der Hüfte."""
        far = "L" if near == "R" else "R"
        near_x = -1.0 if near == "R" else 1.0       # die rechte Körperhälfte liegt bei -X
        yaw_hips = _rz(near_x * ch["yaw"])
        yaw_chest = _rz(near_x * (ch["yaw"] + ch["twist"]))
        half_twist = _rz(near_x * ch["twist"] * 0.5)
        r_hips = yaw_hips @ _rx(ch["pitch"])
        r_spine = r_hips @ half_twist @ _rx(ch["lean"] * 0.55)
        r_chest = r_spine @ half_twist @ _rx(ch["lean"] * 0.45)
        offset = Vector((0.0, -ch["shift"] / PX_PER_M, -ch["low"] / PX_PER_M))
        hips_pos = self.head["hips"] + offset
        look = _rx(ch["head"])
        out = {"hips": r_hips, "spine": r_spine, "chest": r_chest,
               "neck": r_chest.slerp(look, ch["look"] * 0.5), "head": r_chest.slerp(look, ch["look"])}
        out.update(self._leg(near, "f", ch, near, hips_pos, r_hips, yaw_hips, near_x))
        out.update(self._leg(far, "b", ch, near, hips_pos, r_hips, yaw_hips, near_x))
        out.update(self._arm_pose(near, "f", ch, r_chest, yaw_chest))
        out.update(self._arm_pose(far, "b", ch, r_chest, yaw_chest))
        return out, offset

    def basis(self, rotations):
        """Rechnet die absoluten Drehungen in die lokalen Quaternionen der Pose-Knochen um."""
        out = {}
        for name in self.order:
            pose = rotations[name] @ self.rest[name]
            parent = self.parent[name]
            if parent is None:
                out[name] = self.rest[name].inverted() @ pose
            else:
                parent_pose = rotations[parent] @ self.rest[parent]
                rest_rel = self.rest[parent].inverted() @ self.rest[name]
                out[name] = rest_rel.inverted() @ parent_pose.inverted() @ pose
        return out


def bake_clips(arm):
    """Legt jeden Clip für beide Blickrichtungen als Action an. Gibt zurück (Meter): den grössten Fehler der stehenden
    Füsse und wie tief ein Fuss höchstens in den Boden taucht."""
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.render.fps_base = 1.0
    rig = ClipRig(arm)
    bpy.context.view_layer.objects.active = arm
    arm.animation_data_create()
    bones = arm.pose.bones
    for pb in bones:
        pb.rotation_mode = "QUATERNION"
    worst, dip = 0.0, 0.0
    for clip_id, clip in CLIPS.items():
        for near in ("R", "L"):
            action = bpy.data.actions.new(f"{clip_id}_{near}")
            action.use_fake_user = True
            arm.animation_data.action = action
            last = {}
            for t in sample_times(clip):
                frame = t * FPS
                rotations, offset = rig.solve(channels_at(clip, t), near)
                basis = rig.basis(rotations)
                for name, q in basis.items():
                    if name in last and last[name].dot(q) < 0.0:
                        q = -q
                    last[name] = q
                    bones[name].rotation_quaternion = q
                    bones[name].keyframe_insert("rotation_quaternion", frame=frame)
                bones["hips"].location = rig.rest["hips"].inverted() @ offset
                bones["hips"].keyframe_insert("location", frame=frame)
            # Die Posen sind dicht berechnet: linear verbinden, Kurven würden überschwingen und die Datei verdreifachen
            channels = anim_utils.action_get_channelbag_for_slot(action, arm.animation_data.action_slot)
            for curve in channels.fcurves:
                for point in curve.keyframe_points:
                    point.interpolation = "LINEAR"
            slip, deep = _check_feet(arm, rig, clip, near)
            worst, dip = max(worst, slip), max(dip, deep)
    arm.animation_data.action = None
    reset_pose(arm)
    sc.frame_set(0)
    return worst, dip


def _check_feet(arm, rig, clip, near):
    """Misst im ausgewerteten Skelett, wie weit die Ballen stehender Füsse von ihrem Platz abweichen und ob ein Fuss
    unter den Boden gerät."""
    worst, dip = 0.0, 0.0
    floor = {s: min(arm.data.bones[f"foot.{s}"].tail_local.z, arm.data.bones[f"foot.{s}"].head_local.z) for s in "LR"}
    far = "L" if near == "R" else "R"
    near_x = -1.0 if near == "R" else 1.0
    for t in sample_times(clip):
        ch = channels_at(clip, t)
        frame = t * FPS
        bpy.context.scene.frame_set(int(frame), subframe=frame - int(frame))
        bpy.context.view_layer.update()
        for side, f, pivot in ((near, "fp", "pf"), (far, "bp", "pb")):
            if ch[f] >= 1.0:
                ball = arm.pose.bones[f"foot.{side}"].tail
                worst = max(worst, (ball - rig.ball_point(side, near, _rz(near_x * ch[pivot]))).length)
            if not clip.get("air"):
                dip = max(dip, floor[side] - arm.pose.bones[f"foot.{side}"].tail.z)
    return worst, dip


def reset_pose(arm):
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
