"""Baut einen Low-Poly-Kämpfer in T-Pose mit Skelett und exportiert ihn als .glb.

Aufruf (Blender 5.0):
    blender -b -P tools/blender/build_fighter.py -- --fighter bruce
    blender -b -P tools/blender/build_fighter.py -- --fighter all --preview --verify
Figuren: FIGHTERS (bruce, chuck, jackie, jcvd) und zusätzlich PLAYERS (kai, ria, bruno, mika).
Gegner: ENEMIES (thug, dasher, brute, boss) und ENEMY_VARIANTS (thug_cap, dasher_spiky, brute_bare) als assets/characters/enemy_<name>.glb.
Die Materialien heissen <figur>__<zone> (z. B. thug__top): Das Spiel färbt sie je Gegner um (`ModelFigure.apply_palette`).
Godot entfernt beim Import Zeichen wie «/» aus Materialnamen, darum steht der Doppelstrich.
Vorschau (--preview, nach build/characters_preview/): je Figur Front, Seite, Testpose, Tritt (<name>_sheet.png) und
Gelenke und Kopf (<name>_detail.png), dazu jede Gruppe aus der Spielkamera (roster_<gruppe>.png, ..._ingame.png).
--verify lädt jede .glb in eine leere Szene und prüft sie.
Der Baseballschläger entsteht bei jedem Lauf mit als assets/characters/weapon_bat.glb (nicht mit --out).
Kampf-Clips (Daten und Bake in `fighter_clips.py`) bekommen die Figuren in CLIP_FIGHTERS; --clip-preview rendert sie als
Bildreihe aus der Spielkamera und von schräg vorn nach build/characters_preview/<name>_clips_<clip>.png.
Reference Sheets als Planes in die .blend legen:
    ... -- --fighter bruce --front front.png --side side.png

Koordinaten in Blender: X = rechts/links, Y = vorn (-Y ist die Blickrichtung), Z = oben.
Der glTF-Export macht daraus Y-oben, Figur schaut nach +Z (Godot-Konvention für Modelle).
Jede Figur ist ein zusammengefügtes Mesh aus Ring-Lofts mit fein abgestuften Gewichten an den Gelenken; die
Gliedmassen beginnen im Rumpf, damit beim Biegen keine Lücke aufgeht.
"""
import argparse
import json
import math
import os
import struct
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fighter_clips


def hex_color(h):
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    # Hex ist sRGB, Blender rechnet linear
    lin = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin(r), lin(g), lin(b), 1.0)


def make_material(name, color_hex):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = hex_color(color_hex)
    bsdf.inputs["Roughness"].default_value = 0.8
    mat.diffuse_color = hex_color(color_hex)
    return mat


def add_reference_planes(front, side, height):
    """Legt die Sheets als Image-Empties ab (nicht im Export), vorn und seitlich der Figur."""
    coll = bpy.data.collections.new("Reference")
    bpy.context.scene.collection.children.link(coll)
    for path, rot, loc in ((front, (math.pi / 2, 0, 0), (0, 1.5, height / 2)),
                           (side, (math.pi / 2, 0, math.pi / 2), (-1.5, 0, height / 2))):
        if not path or not os.path.exists(path):
            continue
        e = bpy.data.objects.new("Ref_" + os.path.basename(path), None)
        e.empty_display_type = "IMAGE"
        e.data = bpy.data.images.load(os.path.abspath(path))
        e.empty_display_size = height * 1.3
        e.rotation_euler, e.location = rot, loc
        coll.objects.link(e)


# ---- Spielfiguren ----------------------------------------------------------------------
# Masse in Metern. FIGHTERS folgen den Character Sheets (Kleidung, Frisur, Statur, Farbpalette).
FIGHTERS = {
    "bruce": dict(
        colors=dict(skin="E8B98F", shade="BE8A62", hair="0E0E10", pants="F2C21B", stripe="141414", sock="F0F0EC", shoes="F2C21B",
                    sole="F2F0E8", belt="141414", brow="0E0E10", shoe_band="141414"),
        hip_z=0.86, torso=0.50, neck=0.06, head_h=0.25, head_w=0.195, head_d=0.225,
        shoulder_x=0.24, chest=(0.40, 0.26), waist=(0.255, 0.185), hips=(0.29, 0.205), leg_x=0.085,
        arm=(0.25, 0.22, 0.15), arm_r=(0.056, 0.043, 0.048, 0.034), hand_w=0.047,
        leg_r=(0.094, 0.062, 0.068, 0.046), foot=(0.25, 0.056), jaw=0.85,
        sleeve="none", glove_from=None, leg_zones="track", hair_style="bowl", belt=True, belt_h=0.055, belt_u=0.21,
        bare=True, muscles=True, eye_h=0.85, leg_n=10, shoe_w=0.058, shoe_bands=(0.10, 0.27)),
    "chuck": dict(
        colors=dict(skin="D9A47C", shade="AE7A55", hair="6B4226", beard="5E3A22", top="2F4F83", trim="243E68", pants="3B5B8C",
                    shoes="7A4A26", sole="3A2414", belt="5A3A1E", buckle="C8C8CC", gloves="1A1A1A", brow="4E3019",
                    emblem="F0F0F0"),
        hip_z=0.94, torso=0.53, neck=0.06, head_h=0.27, head_w=0.21, head_d=0.24,
        shoulder_x=0.27, chest=(0.47, 0.30), waist=(0.35, 0.25), hips=(0.35, 0.25), leg_x=0.098,
        arm=(0.28, 0.25, 0.17), arm_r=(0.072, 0.056, 0.060, 0.045), hand_w=0.06,
        leg_r=(0.112, 0.076, 0.080, 0.072), foot=(0.30, 0.068), jaw=0.95,
        sleeve="none", glove_from=0.80, fingerless=True, leg_zones="bootcut", hair_style="feather", belt=True,
        belt_h=0.06, belt_u=0.19, muscles=True, neck_r=0.082, shoe="cowboy", shoe_w=0.066, beard=True, beard_off=0.018,
        beard_limit=(0.60, 0.30), moustache=True, emblem="eagle",
        jacket=dict(hem_u=0.22, inner="skin", lapels=True, collar=True)),
    "jackie": dict(
        colors=dict(skin="E3B48E", hair="0E0E12", top="33333B", trim="4A4A54", shirt="EFEBE2", pants="17171C",
                    cuff="EFEBE2", shoes="F0F0F0", sole="8A8A90", knot="3A3A42", badge="C62828", emblem="D8D8DC",
                    brow="0E0E12", shoe_band="C62828"),
        hip_z=0.87, torso=0.50, neck=0.055, head_h=0.265, head_w=0.205, head_d=0.235,
        shoulder_x=0.235, chest=(0.40, 0.265), waist=(0.31, 0.215), hips=(0.32, 0.23), leg_x=0.09,
        arm=(0.25, 0.225, 0.155), arm_r=(0.058, 0.045, 0.045, 0.035), hand_w=0.05,
        leg_r=(0.12, 0.095, 0.10, 0.05), foot=(0.26, 0.06), jaw=0.95,
        sleeve="elbow", glove_from=None, leg_zones="baggy", hair_style="mop", eye_h=0.85, brow_tilt=7, smile=True,
        mouth_w=0.50, shoe_w=0.062, shoe_bands=(0.20,), emblem="ring",
        jacket=dict(hem_u=0.10, tail_u=-0.02, inner="shirt", collar=True, lapels=True, knots=True, badge=True)),
    "jcvd": dict(
        colors=dict(skin="E0AE86", hair="6B4A2F", top="18181A", pants="4B5A3A", camo2="2F3A26", camo3="6E6A48",
                    shoes="141416", sole="0A0A0C", belt="101012", buckle="B8B8BE", gloves="17171A", brow="4E3622"),
        hip_z=0.92, torso=0.54, neck=0.055, head_h=0.265, head_w=0.205, head_d=0.235,
        shoulder_x=0.29, chest=(0.50, 0.30), waist=(0.31, 0.22), hips=(0.34, 0.25), leg_x=0.098,
        arm=(0.275, 0.245, 0.165), arm_r=(0.082, 0.06, 0.066, 0.046), hand_w=0.056,
        leg_r=(0.118, 0.08, 0.085, 0.07), foot=(0.29, 0.066), jaw=1.02,
        sleeve="none", glove_from=0.78, fingerless=True, leg_zones="combat", hair_style="slick", belt=True, belt_h=0.05,
        belt_u=0.20, neck_r=0.09, shoe="combat", shoe_w=0.072, camo=True, pockets=True),
}

# Kai/Ria aus skins.py des Pygame-Spiels (Hauptfarbe aus main.gd), Bruno/Mika aus dem Konzept in dessen
# docs/PROJEKTSTAND.md, Abschnitt 9. Alles Weitere ist hier festgelegt.
PLAYERS = {
    "kai": dict(
        colors=dict(skin="EEC49C", hair="34241A", top="3373E6", pants="1C2C6C", shoes="EBEBF0", sole="8A8F9C",
                    belt="12121C", band="6EC8FF", gloves="5AAFFF", brow="34241A"),
        hip_z=0.90, torso=0.50, neck=0.055, head_h=0.265, head_w=0.21, head_d=0.24,
        shoulder_x=0.245, chest=(0.43, 0.29), waist=(0.30, 0.22), hips=(0.325, 0.24), leg_x=0.09,
        arm=(0.255, 0.225, 0.16), arm_r=(0.062, 0.048, 0.050, 0.038), hand_w=0.056,
        leg_r=(0.104, 0.068, 0.072, 0.052), foot=(0.27, 0.062), jaw=0.92,
        sleeve="none", glove_from=0.52, leg_zones="flared", hair_style="short", headband=True, belt=True),
    "ria": dict(
        colors=dict(skin="F4CCAA", hair="EBAF37", top="E64040", pants="69161E", shoes="F0E6E1", sole="9A8E88",
                    belt="1E1012", band="FF966E", gloves="FF6E64", brow="A8742A"),
        hip_z=0.86, torso=0.445, neck=0.06, head_h=0.245, head_w=0.195, head_d=0.225,
        shoulder_x=0.195, chest=(0.33, 0.24), waist=(0.235, 0.185), hips=(0.31, 0.225), leg_x=0.082,
        arm=(0.235, 0.205, 0.145), arm_r=(0.048, 0.038, 0.040, 0.031), hand_w=0.047,
        leg_r=(0.092, 0.058, 0.060, 0.040), foot=(0.235, 0.052), jaw=0.82,
        sleeve="none", glove_from=0.52, leg_zones="slim", hair_style="ponytail", headband=True, belt=True),
    "bruno": dict(
        colors=dict(skin="C98F63", hair="9A9CA3", top="F2A51E", trim="B9700F", shirt="2B2B30", pants="3B3C44", shoes="46301F",
                    sole="1C1712", belt="1D140E", buckle="D9D9DE", brow="74767C", beard="9A9CA3"),
        hip_z=0.90, torso=0.65, neck=0.04, head_h=0.28, head_w=0.225, head_d=0.245,
        shoulder_x=0.32, chest=(0.60, 0.40), waist=(0.47, 0.36), hips=(0.43, 0.30), leg_x=0.115,
        arm=(0.30, 0.27, 0.185), arm_r=(0.092, 0.074, 0.078, 0.062), hand_w=0.078,
        leg_r=(0.128, 0.086, 0.090, 0.066), foot=(0.30, 0.072), jaw=1.05,
        sleeve="long", glove_from=None, leg_zones="boots", hair_style="flattop", headband=False, belt=False,
        jacket=dict(hem_u=0.04, inner="shirt", lapels=True, collar=True, under_belt=True), beard=True),
    "mika": dict(
        colors=dict(skin="99663F", hair="DFE3F2", top="7B3FD6", pants="3E1F78", shoes="B79BEA", sole="2A2140",
                    belt="F2F2F8", band="FFFFFF", gloves="E4DDF2", wrap="E4DDF2", brow="2A1A10"),
        hip_z=0.86, torso=0.37, neck=0.055, head_h=0.235, head_w=0.18, head_d=0.21,
        shoulder_x=0.165, chest=(0.28, 0.205), waist=(0.21, 0.165), hips=(0.26, 0.195), leg_x=0.07,
        arm=(0.215, 0.19, 0.135), arm_r=(0.042, 0.033, 0.035, 0.028), hand_w=0.042,
        leg_r=(0.078, 0.049, 0.052, 0.034), foot=(0.235, 0.048), jaw=0.78,
        sleeve="short", glove_from=0.62, leg_zones="shorts", hair_style="spikes", headband=True, belt=True, belt_h=0.032,
        tail_width=0.11, tail_length=1.15),
}
FACE_COLORS = dict(eye="F4F4F0", pupil="16121A", mouth="7A3A36", tooth="F8F8F4")

ENEMIES = {
    # Schläger: stämmiger Raufer im grünen Shirt, Stiefel
    "thug": dict(
        colors=dict(skin="CD9870", shade="A5764F", hair="19160F", top="378C41", trim="2A6E33", pants="2E3A2C", shoes="281E19",
                    sole="14100C", belt="191914", brow="19160F"),
        hip_z=0.88, torso=0.52, neck=0.065, head_h=0.255, head_w=0.205, head_d=0.235,
        shoulder_x=0.265, chest=(0.46, 0.30), waist=(0.34, 0.25), hips=(0.345, 0.25), leg_x=0.095,
        arm=(0.26, 0.23, 0.16), arm_r=(0.070, 0.054, 0.056, 0.042), hand_w=0.058,
        leg_r=(0.108, 0.070, 0.074, 0.054), foot=(0.28, 0.064), jaw=0.98, brow_tilt=22,
        sleeve="short", glove_from=None, leg_zones="boots", hair_style="short", belt=True, belt_h=0.045, shoe="combat"),
    # Flitzer: schlank und lang, grüner Irokese, gelbe Turnschuhe
    "dasher": dict(
        colors=dict(skin="E2B28C", shade="BC8C68", hair="50EB6E", top="82E178", pants="1E5F3E", shoes="F0F03C", sole="2A2A2A",
                    belt="14381E", brow="3A2A20"),
        hip_z=0.88, torso=0.46, neck=0.06, head_h=0.25, head_w=0.19, head_d=0.22,
        shoulder_x=0.21, chest=(0.36, 0.25), waist=(0.26, 0.20), hips=(0.30, 0.22), leg_x=0.08,
        arm=(0.25, 0.22, 0.15), arm_r=(0.050, 0.040, 0.043, 0.032), hand_w=0.045,
        leg_r=(0.088, 0.056, 0.060, 0.042), foot=(0.255, 0.054), jaw=0.88, brow_tilt=20,
        sleeve="none", glove_from=None, leg_zones="baggy", hair_style="mohawk", belt=True, belt_h=0.04),
    # Brocken: breit, kahl, Bart, offene grüne Weste
    "brute": dict(
        colors=dict(skin="B4805C", shade="8C5E42", hair="1E1612", beard="1E1612", top="1A5C2C", trim="124022", pants="223024",
                    shoes="1E1A16", sole="0E0C0A", belt="463214", buckle="C8A64B", brow="1E1612"),
        hip_z=0.86, torso=0.56, neck=0.05, neck_r=0.105, head_h=0.27, head_w=0.235, head_d=0.255,
        shoulder_x=0.36, chest=(0.66, 0.44), waist=(0.56, 0.42), hips=(0.50, 0.34), leg_x=0.125,
        arm=(0.30, 0.27, 0.18), arm_r=(0.100, 0.078, 0.082, 0.064), hand_w=0.082,
        leg_r=(0.140, 0.090, 0.095, 0.070), foot=(0.30, 0.074), jaw=1.08, brow_tilt=26,
        sleeve="none", glove_from=None, leg_zones="boots", hair_style="bald", belt=True, belt_h=0.06, belt_u=0.18, beard=True,
        jacket=dict(hem_u=0.06, inner="skin"), shoe="combat"),
    # Boss Granit: langer dunkelgrüner Mantel, Sonnenbrille, goldene Kette, kurze Stachelhaare
    "boss": dict(
        colors=dict(skin="C48E68", shade="9C6C4C", hair="141418", top="104A28", trim="0A2C18", shirt="1A1A20", pants="121E18",
                    shoes="0F0F0F", sole="080808", belt="DCB93C", buckle="DCB93C", brow="141418", gold="E6C250", lens="101018"),
        hip_z=0.88, torso=0.58, neck=0.06, neck_r=0.10, head_h=0.265, head_w=0.22, head_d=0.245,
        shoulder_x=0.33, chest=(0.58, 0.38), waist=(0.46, 0.33), hips=(0.44, 0.30), leg_x=0.11,
        arm=(0.30, 0.27, 0.18), arm_r=(0.088, 0.068, 0.072, 0.056), hand_w=0.070,
        leg_r=(0.126, 0.082, 0.086, 0.062), foot=(0.30, 0.070), jaw=1.04, brow_tilt=24,
        sleeve="long", glove_from=None, leg_zones="boots", hair_style="crop", belt=False, glasses=True, chain=True,
        jacket=dict(hem_u=0.02, inner="shirt", lapels=True, collar=True, under_belt=True), shoe="combat"),
}
# Zusätzliche Modelle derselben Typen: andere Mütze, Frisur oder Kleidung
ENEMY_VARIANTS = {
    "thug_cap": {**ENEMIES["thug"], "hat": True, "hair_style": "bald", "colors": {**ENEMIES["thug"]["colors"], "hat": "2A2A32"}},
    "dasher_spiky": {**ENEMIES["dasher"], "hair_style": "spikes"},
    "brute_bare": {**{k: v for k, v in ENEMIES["brute"].items() if k != "jacket"}, "bare": True, "muscles": True},
}
ALL_FIGHTERS = {**FIGHTERS, **PLAYERS, **ENEMIES, **ENEMY_VARIANTS}
GROUPS = {"fighters": list(FIGHTERS), "players": list(PLAYERS), "enemies": list(ENEMIES), "variants": list(ENEMY_VARIANTS)}


def model_file(name):
    """Zielpfad der .glb: Kämpfer als player_<name>, Gegner als enemy_<name>."""
    return f"assets/characters/{'enemy' if name in ENEMIES or name in ENEMY_VARIANTS else 'player'}_{name}.glb"

# Kopfform über die Höhe t (0 = Kinn, 1 = Scheitel): Breite, Tiefe vorn, Tiefe hinten als Anteil des Radius
HEAD_PROFILE = [
    (0.00, 0.40, 0.64, 0.25), (0.10, 0.60, 0.80, 0.38), (0.24, 0.82, 0.91, 0.58), (0.42, 0.96, 0.98, 0.88),
    (0.62, 1.00, 0.98, 1.00), (0.80, 0.93, 0.86, 0.96), (0.92, 0.66, 0.60, 0.70), (1.00, 0.24, 0.20, 0.26),
]
AXIS_X, AXIS_Y, AXIS_Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


def lerp(a, b, f):
    return a + (b - a) * f


def smooth(f):
    f = max(0.0, min(1.0, f))
    return f * f * (3 - 2 * f)


def mix_weights(a, b, f):
    out = {}
    for k, v in a.items():
        out[k] = out.get(k, 0.0) + v * (1 - f)
    for k, v in b.items():
        out[k] = out.get(k, 0.0) + v * f
    return {k: v for k, v in out.items() if v > 1e-4}


def section(center, u, v, ru, rv, n, power=2.0, start=-math.pi / 2):
    """Ring um center in der Ebene u/v. power > 2 macht aus der Ellipse ein abgerundetes Rechteck."""
    pts = []
    for i in range(n):
        a = start + 2 * math.pi * i / n
        c, s = math.cos(a), math.sin(a)
        fc = math.copysign(abs(c) ** (2.0 / power), c)
        fs = math.copysign(abs(s) ** (2.0 / power), s)
        pts.append(center + u * (ru * fc) + v * (rv * fs))
    return pts


class FighterBuilder:
    """Baut einen Kämpfer als ein Mesh: Rumpf, Glieder, Kopf und Frisur sind geschlossene Hüllen in einem Objekt."""

    def __init__(self, spec, name):
        self.spec, self.name = spec, name
        self.mats = {}
        self.verts, self.vweights, self.faces, self.face_mats = [], [], [], []
        self.armature = None
        self.parts = []
        s = spec
        self.zh = s["hip_z"]
        self.zs = self.zh + s["torso"]
        self.zhead = self.zs + s["neck"]
        self.hh = s["head_h"]
        self.rx, self.ry = s["head_w"] / 2, s["head_d"] / 2
        self.sx = s["shoulder_x"]
        self.hx = s["leg_x"]
        self.zk = self.zh * 0.53        # Knie
        self.za = s["foot"][1] * 1.5    # Knöchel
        self.knee_y = -0.015

    # ---- Grundbausteine -----------------------------------------------------------------
    def material(self, key):
        if key not in self.mats:
            color = self.spec["colors"].get(key) or FACE_COLORS[key]
            self.mats[key] = make_material(f"{self.name}__{key}", color)
        return key

    def ring(self, pts, w):
        base = len(self.verts)
        self.verts.extend(pts)
        self.vweights.extend([w] * len(pts))
        return list(range(base, base + len(pts)))

    def face(self, idx, mat):
        if callable(mat):
            c = sum((self.verts[i] for i in idx), Vector()) / len(idx)
            mat = mat(c)
        self.faces.append(tuple(idx))
        self.face_mats.append(self.material(mat))

    def loft(self, stations, mat, caps=(True, True), tip=None):
        """Verbindet Ringe zu einer geschlossenen Hülle. station = (punkte, gewichte[, material ab hier])."""
        rings = []
        cur = mat
        seg_mats = []
        for st in stations:
            rings.append(self.ring(st[0], st[1]))
            if len(st) > 2 and st[2]:
                cur = st[2]
            seg_mats.append(cur)
        n = len(rings[0])
        for r in range(len(rings) - 1):
            for i in range(n):
                j = (i + 1) % n
                self.face([rings[r][i], rings[r][j], rings[r + 1][j], rings[r + 1][i]], seg_mats[r])
        if caps[0]:
            self.face(list(reversed(rings[0])), seg_mats[0])
        if tip is not None:
            c = self.ring([tip], stations[-1][1])[0]
            for i in range(n):
                self.face([rings[-1][i], rings[-1][(i + 1) % n], c], seg_mats[-1])
        elif caps[1]:
            self.face(rings[-1], seg_mats[-1])

    def block(self, center, size, w, mat, rot=None):
        rot = rot or Matrix.Identity(3)
        pts = []
        for sz in (-1, 1):
            for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                pts.append(center + rot @ Vector((sx * size[0] / 2, sy * size[1] / 2, sz * size[2] / 2)))
        self.loft([(pts[:4], w), (pts[4:], w)], mat)

    def spike(self, base, tip, r, w, mat, n=4):
        d = (tip - base).normalized()
        u = d.cross(AXIS_X if abs(d.x) < 0.9 else AXIS_Y).normalized()
        v = d.cross(u)
        self.loft([(section(base, u, v, r, r, n, start=math.pi / 4), w)], mat, tip=tip)

    def path_tube(self, points, radii, w, mat, n=6, side=AXIS_X):
        """Röhre oder (mit kleinem ru) Band entlang eines Pfads. radii = [(ru, rv), ...], w = Gewichte oder je Punkt eine Liste"""
        stations = []
        for i, p in enumerate(points):
            d = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
            v = d.cross(side).normalized()
            ru, rv = radii[i]
            stations.append((section(p, side, v, ru, rv, n, start=math.pi / 4 if n == 4 else -math.pi / 2),
                             w[i] if isinstance(w, list) else w))
        self.loft(stations, mat)

    def zoned_tube(self, controls, zones, make_ring):
        """Glied mit Kleidungszonen. controls = [(s, ru, rv, versatz, gewichte)] aufsteigend in s,
        zones = [(s_ende, material, aufmass)]. An einer Zonengrenze springt der Radius um das Aufmass (Saum)."""
        def at(s):
            for a, b in zip(controls, controls[1:]):
                if a[0] <= s <= b[0]:
                    f = (s - a[0]) / max(b[0] - a[0], 1e-6)
                    return (lerp(a[1], b[1], f), lerp(a[2], b[2], f), lerp(a[3], b[3], f),
                            mix_weights(a[4], b[4], f))
            return controls[-1][1:] if s > controls[0][0] else controls[0][1:]

        def zone(s):
            for z in zones:
                if s < z[0] - 1e-6:
                    return z
            return zones[-1]

        limits = [z[0] for z in zones[:-1] if controls[0][0] < z[0] < controls[-1][0]]
        stations = []
        for s in sorted({c[0] for c in controls} | set(limits)):
            ru, rv, off, w = at(s)
            if s in limits:
                prev, nxt = zone(s - 1e-3), zone(s + 1e-3)
                if abs(prev[2] - nxt[2]) > 1e-4:
                    stations.append((make_ring(s, ru * prev[2], rv * prev[2], off), w, prev[1]))
                stations.append((make_ring(s, ru * nxt[2], rv * nxt[2], off), w, nxt[1]))
            else:
                z = zone(s)
                stations.append((make_ring(s, ru * z[2], rv * z[2], off), w, z[1]))
        self.loft(stations, zones[0][1])

    # ---- Skelett (fighter_3d.gd spricht die Knochen per Name an) ------------------------
    def build_armature(self):
        arm_data = bpy.data.armatures.new(f"{self.name}_Skeleton")
        arm_obj = bpy.data.objects.new(f"{self.name}_Armature", arm_data)
        bpy.context.scene.collection.objects.link(arm_obj)
        bpy.context.view_layer.objects.active = arm_obj
        arm_obj.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        eb = arm_data.edit_bones

        def bone(bname, head, tail, parent=None):
            b = eb.new(bname)
            b.head, b.tail = Vector(head), Vector(tail)
            if parent:
                b.parent = eb[parent]
            return b

        t = self.spec["torso"]
        ua, fa, ha = self.spec["arm"]
        zh, zs, zt = self.zh, self.zs, self.zhead
        bone("hips", (0, 0, zh), (0, 0, zh + 0.2 * t))
        bone("spine", (0, 0, zh + 0.2 * t), (0, 0, zh + 0.69 * t), "hips")
        bone("chest", (0, 0, zh + 0.69 * t), (0, 0, zs), "spine")
        bone("neck", (0, 0, zs), (0, 0, zt), "chest")
        bone("head", (0, 0, zt), (0, 0, zt + self.hh), "neck")
        flen = self.spec["foot"][0]
        for side, sx in (("L", 1), ("R", -1)):
            bone(f"upper_arm.{side}", (sx * self.sx, 0, zs), (sx * (self.sx + ua), 0, zs), "chest")
            bone(f"forearm.{side}", (sx * (self.sx + ua), 0, zs), (sx * (self.sx + ua + fa), 0, zs),
                 f"upper_arm.{side}")
            bone(f"hand.{side}", (sx * (self.sx + ua + fa), 0, zs), (sx * (self.sx + ua + fa + ha), 0, zs),
                 f"forearm.{side}")
            bone(f"thigh.{side}", (sx * self.hx, 0, zh), (sx * self.hx, self.knee_y, self.zk), "hips")
            bone(f"shin.{side}", (sx * self.hx, self.knee_y, self.zk), (sx * self.hx, 0, self.za), f"thigh.{side}")
            bone(f"foot.{side}", (sx * self.hx, 0, self.za), (sx * self.hx, -flen * 0.7, 0.03), f"shin.{side}")
        bpy.ops.object.mode_set(mode="OBJECT")
        self.armature = arm_obj

    # ---- Rumpf --------------------------------------------------------------------------
    def neck_radius(self):
        return self.spec.get("neck_r", self.spec["head_w"] * 0.34)

    def torso_rows(self):
        sp = self.spec
        t, zh, zs = sp["torso"], self.zh, self.zs
        (cw, cd), (ww, wd), (hw, hd) = sp["chest"], sp["waist"], sp["hips"]
        nr = self.neck_radius()
        hips, spine, chest = {"hips": 1.0}, {"spine": 1.0}, {"chest": 1.0}
        # (z, halbe Breite, halbe Tiefe, Versatz y, Gewichte)
        return [
            (zh - 0.20 * t, hw * 0.24, hd * 0.27, 0.0, hips),
            (zh - 0.12 * t, hw * 0.46, hd * 0.46, 0.0, hips),
            (zh + 0.00 * t, hw * 0.50, hd * 0.50, 0.006, hips),
            (zh + 0.13 * t, hw * 0.485, hd * 0.49, 0.004, hips),
            (zh + 0.26 * t, lerp(hw, ww, 0.75) / 2, lerp(hd, wd, 0.75) / 2, 0.0, {"hips": 0.5, "spine": 0.5}),
            (zh + 0.40 * t, ww * 0.50, wd * 0.50, 0.0, spine),
            (zh + 0.56 * t, lerp(ww, cw, 0.5) / 2, lerp(wd, cd, 0.5) / 2, -0.004, spine),
            (zh + 0.72 * t, cw * 0.48, cd * 0.48, -0.012, {"spine": 0.5, "chest": 0.5}),
            (zh + 0.88 * t, cw * 0.50, cd * 0.50, -0.014, chest),
            (zs + sp["neck"] * 0.60, cw * 0.49, cd * 0.46, -0.006, chest),
            (zs + sp["neck"] * 0.85, lerp(nr, cw * 0.45, 0.62), lerp(nr, cd * 0.42, 0.55), 0.0, chest),
            (zs + sp["neck"] * 1.05, nr * 1.12, nr * 1.10, 0.004, {"chest": 0.6, "neck": 0.4}),
        ]

    def torso_at(self, z):
        rows = self.torso_rows()
        for a, b in zip(rows, rows[1:]):
            if a[0] <= z <= b[0]:
                f = (z - a[0]) / (b[0] - a[0])
                return lerp(a[1], b[1], f), lerp(a[2], b[2], f), lerp(a[3], b[3], f), mix_weights(a[4], b[4], f)
        raise ValueError(z)

    def torso_ring(self, z, ru, rv, off, n=12):
        return section(Vector((0, off, z)), AXIS_X, AXIS_Y, ru, rv, n, power=2.5)

    def pants_mat(self):
        if not self.spec.get("camo"):
            return "pants"

        def camo(c):
            k = int((c.x + 3) * 23) * 7 + int((c.z + 3) * 19) * 3 + int((c.y + 3) * 17)
            return ("pants", "camo2", "pants", "camo3")[k % 4]
        return camo

    def build_torso(self):
        sp = self.spec
        t, zh, zs = sp["torso"], self.zh, self.zs
        rows = self.torso_rows()
        pants = self.pants_mat()
        jacket = sp.get("jacket")
        if jacket:
            # Offene Jacke oder Weste: Saum über der Hüfte, vorn sieht man Hemd oder Haut
            hem = zh + jacket["hem_u"] * t
            hw = rows[8][1]
            inner = jacket["inner"]

            def top(c):
                return inner if c.y < 0 and abs(c.x) < hw * 0.42 and c.z < zs + 0.005 else "top"
            if "tail_u" in jacket:      # Hemd schaut unter der Jacke hervor
                zones = [(zh + jacket["tail_u"] * t, pants, 1.0), (hem, inner, 1.03), (9.0, top, 1.05)]
            else:
                zones = [(hem, pants, 1.0), (hem + 0.07 * t, "trim", 1.08), (9.0, top, 1.05)]
        elif sp.get("bare"):
            zones = [(zh + 0.22 * t, pants, 1.0), (9.0, "skin", 1.0)]
        else:
            # Trägershirt: Träger über der Schulter, Hals und Schulteransatz frei
            def top(c):
                lateral = math.atan2(abs(c.x) / sp["chest"][0], abs(c.y) / sp["chest"][1])    # 0 = Mitte, 90 Grad = Seite
                if c.z > zs + sp["neck"] * 0.85:
                    return "skin"
                if c.z > zs + 0.012:
                    return "top" if lateral > math.radians(40) else "skin"
                return "top"
            zones = [(zh + 0.22 * t, pants, 1.0), (9.0, top, 1.0)]
        self.zoned_tube(rows, zones, lambda s, ru, rv, off: self.torso_ring(s, ru, rv, off))
        if sp.get("muscles"):
            self.muscles()
        if sp.get("belt"):
            self.belt(zh + sp.get("belt_u", 0.20) * t, sp.get("belt_h", 0.042))
        if jacket:
            self.jacket_details(jacket)
        if sp.get("emblem"):
            self.back_emblem(sp["emblem"])

    def belt(self, z, h):
        ru, rv, off, w = self.torso_at(z)
        lo, hi = z - h / 2, z + h / 2
        self.loft([(self.torso_ring(lo, ru, rv, off), w), (self.torso_ring(lo, ru * 1.05, rv * 1.07, off), w),
                   (self.torso_ring(hi, ru * 1.05, rv * 1.07, off), w), (self.torso_ring(hi, ru, rv, off), w)], "belt")
        # Knoten oder Schnalle vorn
        mat = "buckle" if "buckle" in self.spec["colors"] else "belt"
        self.block(Vector((0, off - rv * 1.07 - 0.006, z)), (h * 1.5, 0.026, h * 1.25), w, mat)

    def muscles(self):
        sp = self.spec
        t, zh = sp["torso"], self.zh
        bare = sp.get("bare")
        # Brust als Schattenlinien, die der Rumpfform folgen: unter den Brustmuskeln und in der Mitte
        z = zh + 0.76 * t
        ru, rv, off, w = self.torso_at(z)
        reach = 0.86 if bare else 0.50

        def on_chest(fx, dz):
            y = off - rv * 1.01 * (1 - fx ** 2.5) ** 0.4
            return Vector((fx * ru, y, z + dz))

        for sign in (1, -1):
            pts = [on_chest(f, t * 0.05 * (f / reach) ** 2) for f in (0.03, reach * 0.45, reach * 0.8, reach)]
            pts = [Vector((sign * p.x, p.y, p.z)) for p in pts]
            self.path_tube(pts, [(0.005, 0.007)] * 4, w, "shade", n=4, side=AXIS_Y)
        self.block(on_chest(0.0, t * 0.08), (0.009, 0.010, t * 0.17), w, "shade")
        if not bare:
            return
        # Bauchmuskeln als drei Reihen flacher Felder
        for u in (0.40, 0.50, 0.60):
            ru, rv, off, w = self.torso_at(zh + u * t)
            for sign in (1, -1):
                self.block(Vector((sign * ru * 0.26, off - rv * 0.96, zh + u * t)), (ru * 0.40, 0.022, t * 0.078), w, "skin")

    def jacket_details(self, jacket):
        sp, zs = self.spec, self.zs
        t = sp["torso"]
        if jacket.get("under_belt"):
            # Gürtel unter der Jacke, nur die Schnalle schaut hervor
            z = self.zh + 0.08 * t
            ru, rv, off, w = self.torso_at(z)
            self.loft([(self.torso_ring(z - 0.03, ru * 0.99, rv * 1.03, off), w),
                       (self.torso_ring(z + 0.03, ru * 0.99, rv * 1.03, off), w)], "belt")
            self.block(Vector((0, off - rv * 1.05, z)), (0.07, 0.024, 0.055), w, "buckle")
        if jacket.get("collar"):
            # Kragen als Ring um den Halsansatz
            nr = self.neck_radius()
            chest = {"chest": 1.0}
            cz = zs + sp["neck"] * 0.15
            self.loft([(section(Vector((0, 0.008, cz - 0.02)), AXIS_X, AXIS_Y, nr * 1.9, nr * 1.8, 10), chest),
                       (section(Vector((0, 0.012, cz + 0.05)), AXIS_X, AXIS_Y, nr * 1.55, nr * 1.5, 10), chest)], "trim")
        if jacket.get("lapels"):
            # Revers: gerade Bahnen genau auf der Kante zwischen Innenseite und Jacke
            start = max(0.20, jacket["hem_u"] + 0.07)
            for sign in (1, -1):
                pts, weights, radii = [], [], []
                top_u = 1.0 + sp["neck"] * 0.55 / t
                for f, fx in ((0.0, 0.574), (0.38, 0.574), (0.72, 0.574), (0.88, 0.54), (1.0, 0.34)):
                    z = self.zh + lerp(start, top_u, f) * t
                    ru, rv, off, wz = self.torso_at(z)
                    x = ru * fx
                    y = off - 1.09 * rv * (1 - fx ** 2.5) ** 0.4
                    pts.append(Vector((sign * x, y, z)))
                    weights.append(wz)
                    radii.append((0.042, 0.012))
                self.path_tube(pts, radii, weights, "trim", n=4)
        if jacket.get("knots"):
            # Stoffknöpfe auf dem Hemd
            for u in (0.42, 0.58, 0.74, 0.90):
                ru, rv, off, w = self.torso_at(self.zh + u * t)
                self.block(Vector((0, off - rv * 1.03, self.zh + u * t)), (0.036, 0.014, 0.012), w, "knot")
        if jacket.get("badge"):
            ru, rv, off, w = self.torso_at(self.zh + 0.78 * t)
            self.block(Vector((ru * 0.70, off - rv * 0.98, self.zh + 0.78 * t)), (0.028, 0.022, 0.04), w, "badge")

    def back_emblem(self, kind):
        t, zh = self.spec["torso"], self.zh
        z = zh + 0.68 * t
        ru, rv, off, w = self.torso_at(z)
        y = off + rv * 1.06

        def disc(r, depth, mat):
            self.loft([(section(Vector((0, y - 0.01, z)), AXIS_X, AXIS_Z, r, r, 10), w),
                       (section(Vector((0, y + depth, z)), AXIS_X, AXIS_Z, r, r, 10), w)], mat)
        if kind == "ring":
            disc(ru * 0.60, 0.004, "emblem")
            disc(ru * 0.40, 0.008, "top")
        else:   # Adler: Rumpf und zwei angewinkelte Schwingen
            self.block(Vector((0, y, z)), (ru * 0.20, 0.012, t * 0.20), w, "emblem")
            for sign in (1, -1):
                rot = Matrix.Rotation(math.radians(sign * 24), 3, "Y")
                self.block(Vector((sign * ru * 0.33, y, z + t * 0.05)), (ru * 0.52, 0.012, t * 0.09), w, "emblem", rot)

    # ---- Arme ---------------------------------------------------------------------------
    def build_arm(self, side, sign):
        sp = self.spec
        ua, fa, ha = sp["arm"]
        r_top, r_elbow, r_fore, r_wrist = sp["arm_r"]
        sx = self.sx
        ub, fb, hb, chest = f"upper_arm.{side}", f"forearm.{side}", f"hand.{side}", "chest"
        el = sx + ua
        wr = el + fa
        je = max(r_elbow * 0.9, 0.03)          # halbe Länge der weichen Beuge am Ellbogen
        controls = [
            (sx - r_top * 0.95, r_top * 0.55, r_top * 0.55, 0, {chest: 0.8, ub: 0.2}),
            (sx - r_top * 0.25, r_top * 0.92, r_top * 0.96, 0, {chest: 0.5, ub: 0.5}),
            (sx + r_top * 0.55, r_top * 1.05, r_top * 1.08, 0, {chest: 0.12, ub: 0.88}),
            (sx + ua * 0.45, r_top * 0.98, r_top * 1.02, 0, {ub: 1.0}),
            (el - je, r_elbow * 1.0, r_elbow * 1.03, 0, {ub: 0.85, fb: 0.15}),
            (el, r_elbow * 1.05, r_elbow * 1.08, 0, {ub: 0.5, fb: 0.5}),
            (el + je, r_elbow * 1.02, r_elbow * 1.05, 0, {ub: 0.15, fb: 0.85}),
            (el + fa * 0.35, r_fore * 1.05, r_fore * 1.05, 0, {fb: 1.0}),
            (wr - 0.015, r_wrist, r_wrist * 1.08, 0, {fb: 1.0}),
            (wr + 0.02, r_wrist * 0.95, r_wrist * 1.05, 0, {fb: 0.5, hb: 0.5}),
        ]
        sleeve = sp["sleeve"]
        if sleeve == "long":
            zones = [(wr - 0.07, "top", 1.10), (wr - 0.02, "trim", 1.16), (9.0, "skin", 1.0)]
        elif sleeve == "short":
            zones = [(sx + ua * 0.66, "top", 1.05)]
            zones += [(el + fa * sp["glove_from"], "skin", 1.0), (9.0, "gloves", 1.18)] if sp["glove_from"] else [(9.0, "skin", 1.0)]
        elif sleeve == "elbow":     # Ärmel bis zum Ellbogen, helles Hemd umgeschlagen
            zones = [(el + fa * 0.18, "top", 1.12), (el + fa * 0.40, "cuff", 1.22), (9.0, "skin", 1.0)]
        elif sp["glove_from"]:
            zones = [(el + fa * sp["glove_from"], "skin", 1.0), (9.0, "gloves", 1.18)]
        else:
            zones = [(9.0, "skin", 1.0)]

        def make_ring(s, ru, rv, off):
            return section(Vector((sign * s, off, self.zs)), AXIS_Y, AXIS_Z, ru, rv, 8)

        self.zoned_tube(controls, zones, make_ring)
        # Hand: breiter Fäustling mit Daumen. Handfläche in T-Pose unten, Breite in Y, Dicke in Z.
        hw = sp["hand_w"]
        hand_mat = "gloves" if sp["glove_from"] else "skin"
        fingers = "skin" if sp.get("fingerless") else hand_mat
        rows = [(wr - 0.01, r_wrist * 1.05, r_wrist * 0.95, {fb: 0.5, hb: 0.5}),
                (wr + ha * 0.22, hw * 0.88, hw * 0.58, {hb: 1.0}), (wr + ha * 0.55, hw, hw * 0.64, {hb: 1.0}),
                (wr + ha * 0.86, hw * 0.96, hw * 0.56, {hb: 1.0}), (wr + ha, hw * 0.64, hw * 0.34, {hb: 1.0})]
        self.loft([(section(Vector((sign * x, 0, self.zs)), AXIS_Y, AXIS_Z, ry, rz, 8, power=2.8), w,
                    fingers if i >= 2 else hand_mat) for i, (x, ry, rz, w) in enumerate(rows)], hand_mat)
        base = Vector((sign * (wr + ha * 0.34), -hw * 0.72, self.zs - hw * 0.1))
        tip = Vector((sign * (wr + ha * 0.72), -hw * 1.38, self.zs - hw * 0.28))
        self.spike(base, tip, hw * 0.38, {hb: 1.0}, fingers)

    # ---- Beine --------------------------------------------------------------------------
    def build_leg(self, side, sign):
        sp = self.spec
        r_thigh, r_knee, r_calf, r_ankle = sp["leg_r"]
        tb, sb, fb, hips = f"thigh.{side}", f"shin.{side}", f"foot.{side}", "hips"
        zh, zk, za = self.zh, self.zk, self.za
        L = zh - zk
        jk = max(r_knee * 0.95, 0.04)
        ky = self.knee_y

        def d(z):       # s läuft von oben nach unten (Abstand unter dem Hüftgelenk)
            return zh - z

        controls = [
            (d(zh + r_thigh * 0.9), r_thigh * 0.62, r_thigh * 0.62, 0.0, {hips: 0.6, tb: 0.4}),
            (d(zh + r_thigh * 0.1), r_thigh * 0.98, r_thigh * 1.04, 0.0, {hips: 0.3, tb: 0.7}),
            (d(zh - L * 0.28), r_thigh * 1.0, r_thigh * 1.06, ky * 0.3, {tb: 1.0}),
            (d(zh - L * 0.66), lerp(r_thigh, r_knee, 0.55), lerp(r_thigh, r_knee, 0.5), ky * 0.7, {tb: 1.0}),
            (d(zk + jk), r_knee * 1.0, r_knee * 1.04, ky, {tb: 0.85, sb: 0.15}),
            (d(zk), r_knee * 1.05, r_knee * 1.12, ky - r_knee * 0.05, {tb: 0.5, sb: 0.5}),
            (d(zk - jk), r_knee * 1.0, r_knee * 1.04, ky, {tb: 0.15, sb: 0.85}),
            (d(lerp(zk, za, 0.34)), r_calf * 1.04, r_calf * 1.14, ky * 0.4 + r_calf * 0.14, {sb: 1.0}),
            (d(lerp(zk, za, 0.78)), r_ankle * 1.08, r_ankle * 1.12, 0.002, {sb: 1.0}),
            (d(za + 0.01), r_ankle, r_ankle * 1.06, 0.0, {sb: 0.65, fb: 0.35}),
            (d(za - 0.02), r_ankle * 0.96, r_ankle * 1.0, 0.0, {sb: 0.2, fb: 0.8}),
        ]
        style = sp["leg_zones"]
        if style == "flared":
            # weite Hose mit Saum über dem Schuh
            zones = [(d(za + 0.03), "pants", 1.14), (9.0, "skin", 0.95)]
        elif style == "slim":
            zones = [(d(za + 0.02), "pants", 1.0), (9.0, "skin", 0.95)]
        elif style == "boots":
            zones = [(d(lerp(zk, za, 0.62)), "pants", 1.08), (9.0, "shoes", 1.16)]
        elif style == "track":
            # Trainingshose mit breitem Streifen aussen, darunter weisse Socke
            def track(c):
                return "stripe" if math.atan2(sign * c.x - self.hx, abs(c.y)) > math.radians(72) else "pants"
            zones = [(d(za + 0.05), track, 1.10), (9.0, "sock", 0.96)]
        elif style == "baggy":
            zones = [(d(za + 0.02), "pants", 1.0), (9.0, "skin", 0.95)]
        elif style == "bootcut":
            zones = [(d(za + 0.015), "pants", 1.06), (9.0, "shoes", 0.7)]
        elif style == "combat":
            # Hose in die Stiefel gesteckt, darüber bauschig
            zones = [(d(lerp(zk, za, 0.60)), self.pants_mat(), 1.10), (9.0, "shoes", 1.05)]
        else:   # Shorts, nacktes Knie, Schienbeinwickel für die langen Tritte
            zones = [(d(zh - L * 0.42), "pants", 1.05), (d(zk - jk * 0.9), "skin", 1.0), (d(za + 0.01), "wrap", 1.12),
                     (9.0, "skin", 0.95)]

        def make_ring(s, ru, rv, off):
            return section(Vector((sign * self.hx, off, zh - s)), AXIS_X, AXIS_Y, ru, rv, sp.get("leg_n", 8))

        self.zoned_tube(controls, zones, make_ring)
        if sp.get("pockets"):
            # Cargotasche aussen am Oberschenkel, mit Klappe
            z = lerp(zh, zk, 0.58)
            x = sign * (self.hx + r_thigh * 0.92)
            self.block(Vector((x, ky * 0.5, z)), (0.034, r_thigh * 1.25, 0.14), {tb: 1.0}, "camo2")
            self.block(Vector((x + sign * 0.006, ky * 0.5, z + 0.058)), (0.036, r_thigh * 1.36, 0.042), {tb: 1.0}, "camo3")
        self.build_shoe(side, sign)

    def build_shoe(self, side, sign):
        sp = self.spec
        flen, sole_h = sp["foot"][0], sp["foot"][1] * 0.42
        hw = sp.get("shoe_w", sp["leg_r"][3] * 1.45)
        za = self.za
        fb = {f"foot.{side}": 1.0}
        x = sign * self.hx
        back = flen * 0.27
        kind = sp.get("shoe", "sneaker")
        # (y, halbe Breite, Oberkante) von der Ferse zur Spitze; die Spitze läuft nach -Y
        rows = [(back, 0.74, za * 0.86), (back * 0.72, 0.96, za * 1.34), (0.0, 1.03, za * 1.40),
                (-back * 0.60, 1.08, za * 1.16), (-flen * 0.42, 1.14, za * 0.92), (-flen * 0.60, 1.08, za * 0.78),
                (-flen * 0.72, 0.76, za * 0.52)]
        s_rows = [(back * 1.04, 0.74), (0.0, 1.06), (-flen * 0.42, 1.18), (-flen * 0.60, 1.10), (-flen * 0.75, 0.70)]
        if kind == "cowboy":    # spitz zulaufend, mit Absatz
            rows = [(back, 0.74, za * 0.90), (back * 0.72, 0.95, za * 1.50), (0.0, 1.0, za * 1.60),
                    (-back * 0.60, 1.0, za * 1.20), (-flen * 0.42, 0.98, za * 0.82), (-flen * 0.60, 0.72, za * 0.58),
                    (-flen * 0.74, 0.30, za * 0.36)]
            s_rows = [(back * 1.04, 0.74), (0.0, 0.98), (-flen * 0.42, 1.0), (-flen * 0.60, 0.74), (-flen * 0.75, 0.30)]
            self.block(Vector((x, back * 0.55, sole_h * 0.9)), (hw * 1.4, back * 0.8, sole_h * 1.8), fb, "sole")
        elif kind == "combat":  # hoch und klobig, dicke Sohle
            rows = [(y, f * 1.04, top * (1.14 if y < 0 else 1.0)) for y, f, top in rows]
            sole_h *= 1.3
        bot = sole_h * 0.6
        self.loft([(section(Vector((x, y, (top + bot) / 2)), AXIS_X, AXIS_Z, hw * f, (top - bot) / 2, 8, power=3.2), fb)
                   for y, f, top in rows], "shoes")
        # Sohle als eigene flache Schicht bis zum Boden
        self.loft([(section(Vector((x, y, sole_h / 2)), AXIS_X, AXIS_Z, hw * f, sole_h / 2, 8, power=4.0), fb)
                   for y, f in s_rows], "sole")
        # Streifen quer über den Schuh
        for f in sp.get("shoe_bands", ()):
            rot = Matrix.Rotation(math.radians(24), 3, "X")
            self.block(Vector((x, -flen * f, za * 0.66)), (hw * 2.3, flen * 0.055, za * 0.62), fb, "shoe_band", rot)

    # ---- Kopf ---------------------------------------------------------------------------
    def head_shape(self, t):
        t = max(0.0, min(1.0, t))
        for a, b in zip(HEAD_PROFILE, HEAD_PROFILE[1:]):
            if a[0] <= t <= b[0]:
                f = (t - a[0]) / (b[0] - a[0])
                w, front, back = lerp(a[1], b[1], f), lerp(a[2], b[2], f), lerp(a[3], b[3], f)
                if t < 0.42:
                    w *= lerp(self.spec["jaw"], 1.0, t / 0.42)
                return w, front, back
        return HEAD_PROFILE[-1][1:]

    def head_z(self, t):
        return self.zhead + 0.012 + t * (self.hh - 0.012)

    def head_point(self, t, a, off=0.0):
        """Punkt auf der Kopfhülle. a = 0 ist vorn (-Y), a = pi hinten; off schiebt ihn nach aussen."""
        w, f, b = self.head_shape(t)
        ca, sa = math.cos(a), math.sin(a)
        p = Vector((sa * self.rx * w, -ca * self.ry * (f if ca > 0 else b), self.head_z(t)))
        if off:
            n = Vector((sa * self.ry, -ca * self.rx, (t - 0.55) * self.hh * 0.9)).normalized()
            p += n * off
        return p

    def face_y(self, t, x):
        w, f, _ = self.head_shape(t)
        return -self.ry * f * math.sqrt(max(0.0, 1 - min(1.0, (x / (self.rx * w)) ** 2)))

    def build_head(self):
        head, neck = {"head": 1.0}, {"neck": 1.0}
        # Hals: unten im Rumpf, oben im Kopf
        nr = self.neck_radius()
        zs, zt = self.zs, self.zhead
        self.loft([(section(Vector((0, 0.004, zs)), AXIS_X, AXIS_Y, nr * 1.05, nr * 1.05, 8), {"chest": 0.7, "neck": 0.3}),
                   (section(Vector((0, 0.008, lerp(zs, zt, 0.55))), AXIS_X, AXIS_Y, nr, nr, 8), neck),
                   (section(Vector((0, 0.012, zt + self.hh * 0.16)), AXIS_X, AXIS_Y, nr * 0.98, nr * 0.98, 8),
                    {"neck": 0.35, "head": 0.65})], "skin")
        n = 12
        ts = [0.0, 0.10, 0.24, 0.42, 0.62, 0.80, 0.92, 0.985]
        stations = [([self.head_point(t, 2 * math.pi * i / n) for i in range(n)], head) for t in ts]
        self.loft(stations, "skin", tip=Vector((0, 0.002, self.head_z(1.0))))
        self.build_face(head)

    def build_face(self, head):
        hh = self.hh
        eye_t, eye_x = 0.50, self.rx * 0.43
        for sign in (1, -1):
            x = sign * eye_x
            y = self.face_y(eye_t, x)
            z = self.head_z(eye_t)
            eh = self.spec.get("eye_h", 1.0)
            self.block(Vector((x, y + 0.002, z)), (self.rx * 0.40, 0.014, hh * 0.082 * eh), head, "eye")
            self.block(Vector((x - sign * self.rx * 0.05, y - 0.0035, z)), (self.rx * 0.20, 0.008, hh * 0.078 * eh), head, "pupil")
            # Brauen, zur Mitte hin gesenkt: entschlossener Blick
            rot = Matrix.Rotation(math.radians(sign * -self.spec.get("brow_tilt", 16)), 3, "Y")
            by = self.face_y(eye_t + 0.08, x)
            self.block(Vector((x, by - 0.003, self.head_z(eye_t + 0.085))), (self.rx * 0.50, 0.014, hh * 0.034), head, "brow", rot)
            # Ohr
            self.block(Vector((sign * self.rx * 1.01, 0.006, self.head_z(0.47))), (0.018, self.ry * 0.28, hh * 0.17), head, "skin")
        # Nase als kleiner Keil, Mund als Strich
        ny = self.face_y(0.34, 0.0)
        self.spike(Vector((0, ny + 0.006, self.head_z(0.38))), Vector((0, ny - self.ry * 0.11, self.head_z(0.31))),
                   self.rx * 0.10, head, "skin")
        my = self.face_y(0.19, 0.0)
        smile = self.spec.get("smile")
        self.block(Vector((0, my + (0.004 if smile else -0.001), self.head_z(0.19))),
                   (self.rx * self.spec.get("mouth_w", 0.46), 0.012, hh * (0.036 if smile else 0.022)), head, "mouth")
        if smile:
            self.block(Vector((0, my + 0.002, self.head_z(0.20))), (self.rx * 0.38, 0.012, hh * 0.018), head, "tooth")

    def hair_cap(self, offset, ts, mat="hair", n=14, zmax=None):
        """Geschlossene Hülle um den Kopf. offset(t, a) < 0 versenkt sie im Kopf, so entsteht der Haaransatz."""
        head = {"head": 1.0}
        stations = []
        for t in ts:
            pts = [self.head_point(t, 2 * math.pi * i / n, offset(t, 2 * math.pi * i / n)) for i in range(n)]
            if zmax:
                for p in pts:
                    p.z = min(p.z, zmax)
            stations.append((pts, head))
        self.loft(stations, mat)

    @staticmethod
    def hairline(a, front, back):
        """Haaransatz in t: front über der Stirn, back im Nacken, dazwischen weich über die Seiten."""
        return lerp(back, front, smooth((1 + math.cos(a)) / 2))

    def build_headband(self, t0=0.70, t1=0.80, off=0.022):
        c = {"head": 1.0}
        n = 12

        def ring(t, o):
            return [self.head_point(t, 2 * math.pi * i / n, o) for i in range(n)]

        self.loft([(ring(t0, -0.006), c), (ring(t0, off), c), (ring(t1, off), c), (ring(t1, -0.006), c)], "band")
        # Die Enden wehen nach hinten und zeigen die Blickrichtung (wie im Pygame-Spiel)
        o = self.head_point((t0 + t1) / 2, math.pi, off)
        r = self.hh * self.spec.get("tail_width", 0.085)
        lng = self.hh * self.spec.get("tail_length", 1.45)
        for dx, dz, dip in ((0.02, 0.06, 0.012), (-0.02, -0.38, -0.012)):
            pts = [o + Vector((dx * 0.3, -0.012, 0)),
                   o + Vector((dx * 0.8, lng * 0.34, lng * dz * 0.25 + dip)),
                   o + Vector((dx * 1.3, lng * 0.68, lng * dz * 0.6 - dip)),
                   o + Vector((dx * 1.8, lng, lng * dz + dip))]
            self.path_tube(pts, [(0.007, r * 0.8), (0.007, r * 1.05), (0.007, r), (0.006, r * 0.35)], c, "band", n=4)

    def build_hair(self):
        getattr(self, "hair_" + self.spec["hair_style"])()
        if self.spec.get("headband"):
            self.build_headband()
        if self.spec.get("beard"):
            self.build_beard()
        if self.spec.get("hat"):
            self.build_hat()
        if self.spec.get("glasses"):
            self.build_glasses()
        if self.spec.get("chain"):
            self.build_chain()

    def hair_bald(self):
        pass

    def hair_mohawk(self):
        # Flitzer: schmaler Streifen vom Stirnansatz bis in den Nacken, an den Seiten kahl
        def off(t, a):
            strip = smooth((0.52 - abs(math.sin(a))) / 0.22)
            return lerp(-0.02, 0.022, strip) if t > 0.55 else -0.02
        self.hair_cap(off, [0.52, 0.62, 0.72, 0.82, 0.90, 0.96, 0.985], n=16)
        L = self.hh
        self.spikes([(0.82, 0, L * 0.26, 0.15, 0.0), (0.90, 0, L * 0.34, 0.35, 0.0), (0.97, 0, L * 0.40, 0.55, 0.0),
                     (0.93, 180, L * 0.38, 1.15, 0.0), (0.82, 180, L * 0.34, 1.35, 0.0), (0.70, 180, L * 0.28, 1.5, 0.0),
                     (0.60, 180, L * 0.22, 1.6, 0.0)], self.hh * 0.105)

    def hair_crop(self):
        # Boss: kurz geschnitten, oben kleine Stacheln
        def off(t, a):
            hl = self.hairline(a, 0.72, 0.36)
            return lerp(-0.012, 0.014, smooth((t - hl + 0.05) / 0.10))
        self.hair_cap(off, [0.30, 0.42, 0.54, 0.64, 0.74, 0.84, 0.92, 0.985])
        L = self.hh
        self.spikes([(0.92, 0, L * 0.12, 0.0, 0.0), (0.92, 50, L * 0.12, 0.2, 0.1), (0.92, -50, L * 0.12, 0.2, -0.1),
                     (0.97, 120, L * 0.12, 0.7, 0.1), (0.97, -120, L * 0.12, 0.7, -0.1), (0.985, 0, L * 0.14, 0.2, 0.0)], self.hh * 0.10)

    def build_hat(self):
        # Mütze: Kappe über dem Haaransatz mit kurzem Schirm vorn
        def off(t, a):
            return lerp(-0.02, 0.030, smooth((t - 0.50) / 0.10))
        self.hair_cap(off, [0.50, 0.58, 0.68, 0.78, 0.88, 0.96, 0.99], mat="hat", n=14)
        y = self.face_y(0.58, 0.0)
        self.block(Vector((0, y - 0.034, self.head_z(0.60))), (self.rx * 1.5, 0.082, 0.014), {"head": 1.0}, "hat",
                   Matrix.Rotation(math.radians(-10), 3, "X"))

    def build_glasses(self):
        # Sonnenbrille: zwei dunkle Gläser, Steg und Bügel zu den Ohren
        head = {"head": 1.0}
        eye_t, eye_x = 0.50, self.rx * 0.43
        z = self.head_z(eye_t)
        for sign in (1, -1):
            x = sign * eye_x
            y = self.face_y(eye_t, x)
            self.block(Vector((x, y - 0.006, z)), (self.rx * 0.62, 0.016, self.hh * 0.15), head, "lens")
            self.block(Vector((sign * self.rx * 0.97, y * 0.30, z)), (0.010, self.ry * 0.9, self.hh * 0.03), head, "lens")
        self.block(Vector((0, self.face_y(eye_t, 0.0) - 0.006, z + self.hh * 0.02)), (self.rx * 0.24, 0.014, self.hh * 0.03), head, "lens")

    def build_chain(self):
        # Goldkette um den Hals, vorn auf der Brust ein Anhänger
        sp = self.spec
        nr = self.neck_radius()
        zs = self.zs
        pts, ws, radii = [], [], []
        for fx, drop in ((-1.0, 0.012), (-0.7, -0.035), (-0.35, -0.075), (0.0, -0.095), (0.35, -0.075), (0.7, -0.035), (1.0, 0.012)):
            z = zs + drop
            ru, rv, off, w = self.torso_at(min(z, zs - 0.001))
            x = fx * (nr * 1.75)
            y = off - rv * (1.0 - 0.8 * fx * fx * 0.0) * 0.96 - 0.004
            pts.append(Vector((x, y if abs(fx) < 1.0 else y * 0.2, z)))
            ws.append({"chest": 1.0})
            radii.append((0.007, 0.007))
        self.path_tube(pts, radii, ws, "gold", n=4, side=AXIS_Y)
        self.block(pts[3] + Vector((0, -0.010, -0.030)), (0.030, 0.014, 0.040), {"chest": 1.0}, "gold")

    def spikes(self, items, r):
        """items = (t, a in Grad, Länge, Neigung nach hinten, Versatz zur Seite) auf der Haarhülle."""
        c = {"head": 1.0}
        for t, deg, length, back, side in items:
            base = self.head_point(t, math.radians(deg), -0.002)
            n = (base - Vector((0, 0.0, self.head_z(0.55)))).normalized()
            d = (n + Vector((side, back, 0))).normalized()
            self.spike(base, base + d * length, r, c, "hair", n=5)

    def hair_short(self):
        # Kai: kurze dunkle Haare, vorn leicht aufgestellt
        def off(t, a):
            hl = self.hairline(a, 0.74, 0.34)
            return lerp(-0.012, 0.016, smooth((t - hl + 0.05) / 0.10))
        self.hair_cap(off, [0.26, 0.36, 0.46, 0.56, 0.66, 0.76, 0.86, 0.94, 0.985])
        L = self.hh
        self.spikes([(0.90, 0, L * 0.20, -0.10, 0.0), (0.90, 40, L * 0.19, 0.20, 0.1), (0.90, -40, L * 0.19, 0.20, -0.1),
                     (0.94, 90, L * 0.20, 0.45, 0.2), (0.94, -90, L * 0.20, 0.45, -0.2), (0.86, 140, L * 0.20, 0.9, 0.2),
                     (0.86, -140, L * 0.20, 0.9, -0.2), (0.72, 180, L * 0.18, 1.0, 0.0), (0.97, 180, L * 0.18, 0.5, 0.0)],
                    self.hh * 0.11)

    def hair_ponytail(self):
        # Ria: blonder Zopf, hoch angesetzt; seitliche Strähnen rahmen das Gesicht
        def off(t, a):
            hl = self.hairline(a, 0.76, 0.28)
            return lerp(-0.012, 0.012, smooth((t - hl + 0.05) / 0.10))
        self.hair_cap(off, [0.22, 0.32, 0.44, 0.56, 0.66, 0.76, 0.86, 0.94, 0.985])
        self.spikes([(0.94, 90, self.hh * 0.11, 1.3, 0.1), (0.94, -90, self.hh * 0.11, 1.3, -0.1),
                     (0.97, 180, self.hh * 0.12, 1.1, 0.0)], self.hh * 0.11)
        c = {"head": 1.0}
        hh = self.hh
        root = self.head_point(0.70, math.pi, 0.0)
        tie = root + Vector((0, 0.022, 0.004))
        pts = [root + Vector((0, -0.02, 0)), tie, tie + Vector((0, hh * 0.32, -hh * 0.04)),
               tie + Vector((0, hh * 0.54, -hh * 0.34)), tie + Vector((0, hh * 0.62, -hh * 0.76)),
               tie + Vector((0, hh * 0.60, -hh * 1.14)), tie + Vector((0, hh * 0.54, -hh * 1.42))]
        rad = [0.026, 0.030, 0.046, 0.050, 0.042, 0.028, 0.008]
        self.path_tube(pts, [(r * hh / 0.24, r * hh / 0.24) for r in rad], c, "hair", n=6)
        # Haarband am Zopfansatz
        self.path_tube([tie + Vector((0, -0.006, 0)), tie + Vector((0, 0.02, -0.002))], [(0.034, 0.034), (0.034, 0.034)],
                       c, "band", n=6)
        # Strähnen vor den Ohren
        for sign in (1, -1):
            a = sign * math.radians(66)
            top = self.head_point(0.74, a, 0.008)
            mid = self.head_point(0.46, a, 0.012)
            low = self.head_point(0.30, a, 0.006)
            self.path_tube([top, mid, low], [(0.009, 0.018), (0.009, 0.018), (0.004, 0.005)], c, "hair", n=4)

    def hair_flattop(self):
        # Bruno: graue Kurzhaare, kantig und oben flach
        def off(t, a):
            hl = self.hairline(a, 0.72, 0.38)
            top = lerp(0.008, 0.034, smooth((t - 0.70) / 0.2))
            return lerp(-0.012, top, smooth((t - hl + 0.05) / 0.09))
        zmax = self.head_z(1.0) + 0.014
        self.hair_cap(off, [0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90, 0.97], zmax=zmax)

    def build_beard(self):
        # Bart als Hülle um Kinn und Wangen; Mund und Oberlippenbart liegen darauf
        thick = self.spec.get("beard_off", 0.010)
        side_t, front_t = self.spec.get("beard_limit", (0.56, 0.26))

        def off(t, a):
            if math.cos(a) < -0.15:
                return -0.012
            limit = lerp(side_t, front_t, smooth(math.cos(a) * 0.5 + 0.5))
            front = smooth(1.0 - abs(math.sin(a)))
            return lerp(thick + 0.012 * front, -0.012, smooth((t - limit + 0.03) / 0.07))
        self.hair_cap(off, [-0.12, 0.02, 0.12, 0.22, 0.34, 0.46, 0.60], mat="beard")
        my = self.face_y(0.19, 0.0)
        head = {"head": 1.0}
        self.block(Vector((0, my - thick - 0.009, self.head_z(0.22))), (self.rx * 0.44, 0.012, self.hh * 0.024), head, "mouth")
        if self.spec.get("moustache"):
            ny = self.face_y(0.29, 0.0)
            self.block(Vector((0, ny - 0.006, self.head_z(0.285))), (self.rx * 0.74, 0.016, self.hh * 0.05), head, "beard")

    def locks(self, items, r):
        """Strähnen von Punkt zu Punkt auf dem Kopf: (t0, Grad0, Abstand0, t1, Grad1, Abstand1)."""
        c = {"head": 1.0}
        for t0, d0, o0, t1, d1, o1 in items:
            self.spike(self.head_point(t0, math.radians(d0), o0), self.head_point(t1, math.radians(d1), o1), r, c, "hair", n=5)

    def hair_bowl(self):
        # Bruce: glatter schwarzer Pilzkopf, Pony bis zu den Brauen, Ohren halb bedeckt
        def off(t, a):
            top = lerp(0.014, 0.028, smooth((t - 0.6) / 0.3))
            return lerp(-0.012, top, smooth((t - self.hairline(a, 0.68, 0.28) + 0.05) / 0.10))
        self.hair_cap(off, [0.22, 0.32, 0.44, 0.54, 0.64, 0.72, 0.82, 0.92, 0.985])
        fringe = [(0.82, d, 0.012, 0.60, d * 1.06, 0.022) for d in (-54, -32, -11, 11, 32, 54)]
        sides = [(0.62, g * d0, 0.018, t1, g * d1, 0.022) for g in (1, -1)
                 for d0, t1, d1 in ((86, 0.46, 88), (150, 0.18, 154))]
        self.locks(fringe, self.hh * 0.085)
        self.locks([(t0, d0, o0, t1, d1, 0.006) for t0, d0, o0, t1, d1, _ in sides] + [(0.5, 180, 0.018, 0.14, 180, 0.018)],
                   self.hh * 0.085)

    def hair_mop(self):
        # Jackie: voller, zerzauster schwarzer Schopf über den Ohren
        def off(t, a):
            top = lerp(0.026, 0.038, smooth((t - 0.6) / 0.3))
            return lerp(-0.012, top, smooth((t - self.hairline(a, 0.72, 0.16) + 0.05) / 0.10))
        self.hair_cap(off, [0.14, 0.24, 0.36, 0.48, 0.60, 0.72, 0.82, 0.92, 0.985])
        items = [(0.86, -30, 0.03, 0.58, -58, 0.03), (0.86, 10, 0.03, 0.62, 34, 0.03), (0.86, 40, 0.03, 0.58, 64, 0.03)]
        for g in (1, -1):
            items += [(0.58, g * 92, 0.024, 0.36, g * 94, 0.016), (0.45, g * 156, 0.03, 0.08, g * 158, 0.02)]
        items.append((0.45, 180, 0.03, 0.02, 180, 0.036))
        self.locks(items, self.hh * 0.10)

    def hair_feather(self):
        # Chuck: braunes, gestuftes Haar bis auf die Schultern
        def off(t, a):
            top = lerp(0.022, 0.034, smooth((t - 0.6) / 0.3))
            return lerp(-0.012, top, smooth((t - self.hairline(a, 0.76, 0.20) + 0.05) / 0.10))
        self.hair_cap(off, [0.16, 0.26, 0.38, 0.50, 0.62, 0.72, 0.82, 0.92, 0.985])
        head = {"head": 1.0}
        low = self.head_point(0.2, math.pi, 0.03)
        zs = self.zs
        self.path_tube([self.head_point(0.82, math.pi, 0.0), self.head_point(0.55, math.pi, 0.03), low,
                        Vector((0, low.y + 0.01, zs + 0.012)), Vector((0, low.y, zs - 0.045))],
                       [(0.08, 0.04), (0.10, 0.045), (0.105, 0.045), (0.09, 0.035), (0.05, 0.012)],
                       [head, head, head, {"head": 0.6, "neck": 0.4}, {"head": 0.4, "neck": 0.3, "chest": 0.3}], "hair")
        items = [(0.92, -20, 0.03, 0.76, -58, 0.02), (0.92, 30, 0.03, 0.76, 60, 0.02)]
        for g in (1, -1):
            items += [(0.70, g * 88, 0.024, 0.14, g * 90, 0.012), (0.70, g * 114, 0.024, 0.06, g * 118, 0.018)]
        self.locks(items, self.hh * 0.12)

    def hair_slick(self):
        # JCVD: kurz, an den Seiten eng, oben nach hinten gekämmt
        def off(t, a):
            top = lerp(0.008, 0.030, smooth((t - 0.66) / 0.24))
            return lerp(-0.012, top, smooth((t - self.hairline(a, 0.80, 0.40) + 0.05) / 0.10))
        self.hair_cap(off, [0.34, 0.44, 0.54, 0.64, 0.74, 0.84, 0.92, 0.985])
        L = self.hh
        self.spikes([(0.86, 10, L * 0.19, 0.55, 0.05), (0.86, -24, L * 0.17, 0.7, -0.1), (0.88, 44, L * 0.15, 0.9, 0.1),
                     (0.90, -60, L * 0.14, 1.0, -0.15)], L * 0.12)

    def hair_spikes(self):
        # Mika: weisse Stachelhaare, weit nach hinten und oben, deutlich über dem Stirnband
        def off(t, a):
            hl = self.hairline(a, 0.76, 0.40)
            return lerp(-0.012, 0.012, smooth((t - hl + 0.05) / 0.10))
        self.hair_cap(off, [0.34, 0.44, 0.54, 0.64, 0.74, 0.84, 0.92, 0.985])
        L = self.hh
        self.spikes([(0.84, 22, L * 0.22, 0.5, 0.45), (0.84, -22, L * 0.20, 0.5, -0.45), (0.92, 70, L * 0.34, 1.0, 0.25),
                     (0.92, -70, L * 0.36, 1.0, -0.25), (0.88, 120, L * 0.46, 1.5, 0.20), (0.88, -120, L * 0.42, 1.5, -0.20),
                     (0.97, 180, L * 0.52, 1.15, 0.0), (0.84, 160, L * 0.46, 1.5, 0.12), (0.84, -160, L * 0.46, 1.5, -0.12),
                     (0.66, 180, L * 0.40, 1.7, 0.0), (0.68, 125, L * 0.32, 1.6, 0.40), (0.68, -125, L * 0.32, 1.6, -0.40)], self.hh * 0.13)

    # ---- Zusammenbau --------------------------------------------------------------------
    def build_body(self):
        self.build_torso()
        for side, sign in (("L", 1), ("R", -1)):
            self.build_arm(side, sign)
            self.build_leg(side, sign)
        self.build_head()
        self.build_hair()

    def bind(self):
        mesh = bpy.data.meshes.new(f"{self.name}_Mesh")
        mesh.from_pydata([tuple(v) for v in self.verts], [], self.faces)
        keys = list(self.mats)
        for k in keys:
            mesh.materials.append(self.mats[k])
        index = {k: i for i, k in enumerate(keys)}
        for poly, key in zip(mesh.polygons, self.face_mats):
            poly.material_index = index[key]
            poly.use_smooth = False
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        obj = bpy.data.objects.new(f"{self.name}_Body", mesh)
        bpy.context.scene.collection.objects.link(obj)
        groups = {}
        for i, w in enumerate(self.vweights):
            total = sum(w.values())
            for bone, v in w.items():
                if bone not in groups:
                    groups[bone] = obj.vertex_groups.new(name=bone)
                groups[bone].add([i], v / total, "REPLACE")
        obj.parent = self.armature
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = self.armature
        self.parts = [obj]


# ---- Bauen und Export -------------------------------------------------------------------
def build_figure(name):
    b = FighterBuilder(ALL_FIGHTERS[name], name)
    b.build_armature()
    b.build_body()
    b.bind()
    return b


# ---- Baseballschläger -------------------------------------------------------------------
# (Höhe, Radius, Material) in Metern. Nullpunkt ist die vordere Faust, der Schläger zeigt nach +Z, im Export nach +Y.
# Rund 87 cm lang wie ein Erwachsenenschläger; der Kopf ist mit 9 cm etwas dicker als die erlaubten 6,6 cm, damit er im Spiel sichtbar bleibt.
BAT_PROFILE = [
    (-0.200, 0.000, "knob"), (-0.200, 0.022, "knob"), (-0.190, 0.030, "knob"), (-0.175, 0.030, "knob"),
    (-0.165, 0.019, "tape"), (0.050, 0.018, "wood"), (0.300, 0.024, "wood"), (0.450, 0.037, "band"), (0.470, 0.039, "wood"),
    (0.580, 0.045, "wood"), (0.630, 0.046, "end"), (0.655, 0.040, "end"), (0.665, 0.025, "end"), (0.668, 0.000, "end"),
]
BAT_COLORS = dict(knob="5E3C22", tape="26222A", wood="C99A5B", band="7A5230", end="B5864C", crack="1C1410")
BAT_SIDES = 12


def build_bat():
    """Schläger als Rotationskörper, dazu die Risse als eigenes Objekt: Das Spiel blendet sie bei wenig Haltbarkeit ein."""
    mats = {k: make_material(f"bat_{k}", v) for k, v in BAT_COLORS.items()}
    names = [k for k in BAT_COLORS if k != "crack"]
    mesh = bpy.data.meshes.new("Bat")
    for k in names:
        mesh.materials.append(mats[k])
    bm = bmesh.new()
    rings = []
    for z, r, _ in BAT_PROFILE:
        if r <= 0.0:
            rings.append([bm.verts.new((0.0, 0.0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / BAT_SIDES), r * math.sin(2 * math.pi * i / BAT_SIDES), z))
                          for i in range(BAT_SIDES)])
    for j in range(len(rings) - 1):
        a, b = rings[j], rings[j + 1]
        for i in range(BAT_SIDES):
            if len(a) == 1:
                verts = (a[0], b[(i + 1) % BAT_SIDES], b[i])
            elif len(b) == 1:
                verts = (a[i], a[(i + 1) % BAT_SIDES], b[0])
            else:
                verts = (a[i], a[(i + 1) % BAT_SIDES], b[(i + 1) % BAT_SIDES], b[i])
            face = bm.faces.new(verts)
            face.material_index = names.index(BAT_PROFILE[j + 1][2])
            face.smooth = True
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    bat = bpy.data.objects.new("Bat", mesh)
    bpy.context.scene.collection.objects.link(bat)

    cracks = bpy.data.meshes.new("BatCracks")
    cracks.materials.append(mats["crack"])
    bm = bmesh.new()
    for angle, z0, z1, drift in ((0.4, 0.40, 0.50, 0.02), (0.4, 0.50, 0.60, -0.015), (2.5, 0.46, 0.60, 0.018), (4.4, 0.36, 0.52, -0.02)):
        quad = []
        for z, ang, r in ((z0, angle, 0.0395), (z1, angle + drift / 0.04, 0.047)):
            n = Vector((math.cos(ang), math.sin(ang), 0.0))
            side = Vector((-n.y, n.x, 0.0)) * 0.0035
            quad += [n * r + side + Vector((0, 0, z)), n * r - side + Vector((0, 0, z))]
        verts = [bm.verts.new(p) for p in quad]
        bm.faces.new((verts[0], verts[1], verts[3], verts[2]))
    bm.normal_update()
    bm.to_mesh(cracks)
    bm.free()
    crack_obj = bpy.data.objects.new("BatCracks", cracks)
    bpy.context.scene.collection.objects.link(crack_obj)
    return [bat, crack_obj]


def export_bat(out, save_blend):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    parts = build_bat()
    if save_blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(os.path.splitext(out)[0] + ".blend"))
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_yup=True, export_animations=False)
    pts = [v.co for v in parts[0].data.vertices]
    print(f"OK: {out} (Schläger {max(p.z for p in pts) - min(p.z for p in pts):.3f} m lang, "
          f"Kopf {2 * max(max(abs(p.x), abs(p.y)) for p in pts if p.z > 0.2):.3f} m dick, "
          f"{sum(len(f.vertices) - 2 for f in parts[0].data.polygons)} Dreiecke)")


def export_glb(b, out):
    bpy.ops.object.select_all(action="DESELECT")
    for o in b.parts + [b.armature]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = b.armature
    # Die Clips sind schon Bild für Bild berechnet: nichts nachsampeln, nur die belegten Spuren schreiben
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_yup=True,
                              export_skins=True, export_apply=False, export_animations=bool(bpy.data.actions),
                              export_animation_mode="ACTIONS", export_force_sampling=False)


# ---- Vorschau ---------------------------------------------------------------------------
def rotate_bone(arm, bone, axis, degrees):
    """Dreht einen Knochen um sein Gelenk; die Achse gilt im Raum der Armature."""
    pb = arm.pose.bones[bone]
    head = pb.matrix.translation.copy()
    r = Matrix.Rotation(math.radians(degrees), 4, axis)
    pb.matrix = Matrix.Translation(head) @ r @ Matrix.Translation(-head) @ pb.matrix
    bpy.context.view_layer.update()


def apply_test_pose(arm):
    """Testpose: Arme gesenkt, linkes Knie gebeugt."""
    rotate_bone(arm, "upper_arm.L", AXIS_Y, 72)
    rotate_bone(arm, "upper_arm.R", AXIS_Y, -72)
    rotate_bone(arm, "forearm.L", AXIS_X, -30)
    rotate_bone(arm, "forearm.R", AXIS_X, -30)
    rotate_bone(arm, "thigh.L", AXIS_X, -62)
    rotate_bone(arm, "shin.L", AXIS_X, 88)


def apply_kick_pose(arm):
    """Belastungsprobe: hoher Tritt und Schlag, Ellbogen und Hüfte stark gebogen."""
    rotate_bone(arm, "thigh.L", AXIS_X, -100)
    rotate_bone(arm, "shin.L", AXIS_X, 25)
    rotate_bone(arm, "shin.R", AXIS_X, 18)
    rotate_bone(arm, "upper_arm.L", AXIS_Z, -70)
    rotate_bone(arm, "forearm.L", AXIS_Z, 95)
    rotate_bone(arm, "upper_arm.R", AXIS_Y, -60)
    rotate_bone(arm, "forearm.R", AXIS_X, -115)


def setup_render(size):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = False
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.image_settings.file_format = "PNG"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    world = bpy.data.worlds.new("Preview")
    world.use_nodes = True
    sc.world = world
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.45, 0.47, 0.50, 1)
    bg.inputs[1].default_value = 0.85
    for name, energy, rot in (("Key", 2.4, (32, 0, -30)), ("Fill", 0.8, (60, 0, 60)), ("Rim", 0.9, (115, 0, 180))):
        light = bpy.data.lights.new(name, "SUN")
        light.energy = energy
        o = bpy.data.objects.new(name, light)
        o.rotation_euler = [math.radians(v) for v in rot]
        sc.collection.objects.link(o)
    ground = bpy.data.meshes.new("Ground")
    ground.from_pydata([(-20, -20, 0), (20, -20, 0), (20, 20, 0), (-20, 20, 0)], [], [(0, 1, 2, 3)])
    mat = bpy.data.materials.new("Ground")
    mat.use_nodes = True
    mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.32, 0.33, 0.35, 1)
    ground.materials.append(mat)
    sc.collection.objects.link(bpy.data.objects.new("Ground", ground))
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.type = "ORTHO"
    cam.data.clip_end = 100
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def aim(cam, location, target, ortho):
    cam.location = location
    d = Vector(target) - Vector(location)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = ortho


def render(path):
    bpy.context.scene.render.filepath = os.path.abspath(path)
    bpy.ops.render.render(write_still=True)


def montage(paths, out):
    """Hängt die Einzelbilder nebeneinander, damit eine Figur auf einen Blick beurteilt werden kann."""
    arrays = []
    for p in paths:
        img = bpy.data.images.load(os.path.abspath(p))
        w, h = img.size
        a = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        arrays.append(a.reshape(h, w, 4))
        bpy.data.images.remove(img)
    sheet = np.concatenate(arrays, axis=1)
    h, w, _ = sheet.shape
    img = bpy.data.images.new("sheet", w, h, alpha=False)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = os.path.abspath(out)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def preview_figure(name, b, outdir):
    arm = b.armature
    bpy.context.view_layer.update()
    pts = [v.co for o in b.parts for v in o.data.vertices]
    h = max(p.z for p in pts)
    span = max(abs(p.x) for p in pts) * 2
    cam = setup_render((640, 640))
    mid = h * 0.5
    files = []

    def shot(view, location, ortho):
        aim(cam, location, (0, 0, mid), ortho)
        files.append(os.path.join(outdir, f"{name}_{view}.png"))
        render(files[-1])

    shot("front", (0, -6, mid), max(h, span) * 1.08)
    shot("side", (-6, 0, mid), h * 1.12)
    apply_test_pose(arm)
    shot("pose", (3.2, -5, 1.4 + mid), h * 1.12)
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    apply_kick_pose(arm)
    shot("kick", (-5, -3.5, 1.0 + mid), h * 1.25)
    montage(files, os.path.join(outdir, f"{name}_sheet.png"))

    # Detail: Kopf, dann Schulter und Hüfte aus Blickwinkeln, die Lücken verraten würden
    details = []

    def detail(view, location, target, ortho):
        aim(cam, location, target, ortho)
        details.append(os.path.join(outdir, f"{name}_{view}.png"))
        render(details[-1])

    detail("kick_back", (4.5, 4.5, 1.0 + h * 0.6), (0, 0, h * 0.6), h * 0.72)
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    apply_test_pose(arm)
    detail("pose_back", (-3.5, 5, 1.2 + h * 0.6), (0, 0, h * 0.6), h * 0.72)
    head_z = b.zhead + b.hh * 0.55
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    detail("head", (2.2, -5, head_z + 0.6), (0, 0, head_z), b.hh * 2.6)
    montage(details, os.path.join(outdir, f"{name}_detail.png"))


def preview_clips(name, b, outdir, only=None):
    """Jeder Clip als Bildreihe: oben aus der Spielkamera (Blick nach rechts), unten von schräg vorn."""
    arm = b.armature
    cam = setup_render((260, 260))
    bpy.context.scene.cycles.samples = 12
    arm.rotation_euler.z = math.pi / 2
    h = max(v.co.z for o in b.parts for v in o.data.vertices)
    for clip_id, clip in fighter_clips.CLIPS.items():
        if only and clip_id not in only:
            continue
        arm.animation_data.action = bpy.data.actions[f"{clip_id}_R"]
        show_bat(arm, clip.get("bat", False))
        times = (0.0, 0.35, 0.7, 1.0, 1.5, 2.0, 2.35, 2.7, 3.0)
        rows = []
        for view, location in (("side", (0.45, -8, h * 0.56)), ("angle", (5.6, -5.6, h * 0.8))):
            files = []
            for i, t in enumerate(times):
                bpy.context.scene.frame_set(int(round(t * fighter_clips.FPS)))
                aim(cam, location, (0.45 if view == "side" else 0.0, 0, h * 0.56), h * 1.4)
                files.append(os.path.join(outdir, f"_clip_{clip_id}_{view}_{i}.png"))
                render(files[-1])
            rows.append(os.path.join(outdir, f"_clip_{clip_id}_{view}.png"))
            montage(files, rows[-1])
            for f in files:
                os.remove(f)
        stack_rows(rows, os.path.join(outdir, f"{name}_clips_{clip_id}.png"))
        for f in rows:
            os.remove(f)
    arm.animation_data.action = None
    show_bat(arm, False)
    fighter_clips.reset_pose(arm)
    arm.rotation_euler.z = 0.0


def show_bat(arm, visible):
    """Vorschau: Schläger an der vorderen Hand, so wie ihn `ModelFigure` im Spiel setzt."""
    bat = bpy.data.objects.get("Bat")
    if bat is None:
        bat = build_bat()[0]
        bpy.data.objects.remove(bpy.data.objects["BatCracks"])
        bat.parent = arm
        bat.parent_type = "BONE"
        bat.parent_bone = "hand.R"
        length = arm.data.bones["hand.R"].length
        bat.location = (0.0, fighter_clips.HAND_EXTRA - length, 0.0)
        bat.rotation_euler = (-math.pi / 2, 0.0, 0.0)
    bat.hide_render = not visible


def stack_rows(paths, out):
    arrays = []
    for p in paths:
        img = bpy.data.images.load(os.path.abspath(p))
        w, h = img.size
        a = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        arrays.append(a.reshape(h, w, 4))
        bpy.data.images.remove(img)
    # Blender speichert Bilder von unten nach oben: die erste Zeile kommt also ans Ende
    sheet = np.concatenate(arrays[::-1], axis=0)
    h, w, _ = sheet.shape
    img = bpy.data.images.new("rows", w, h, alpha=False)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = os.path.abspath(out)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def preview_roster(names, label, outdir):
    """Eine Gruppe nebeneinander aus der Spielkamera, einmal gross und einmal in Spielgrösse."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    x = -3.0
    for name in names:
        b = build_figure(name)
        rotate_bone(b.armature, "upper_arm.L", AXIS_Y, 55)
        rotate_bone(b.armature, "upper_arm.R", AXIS_Y, -55)
        b.armature.location.x = x
        b.armature.rotation_euler.z = math.pi / 2      # läuft wie im Spiel nach rechts
        x += 2.0
    cam = setup_render((1440, 540))
    aim(cam, (0, -8, 3.2), (0, 0, 0.95), 7.4)
    render(os.path.join(outdir, f"roster_{label}.png"))
    # Spielgrösse: Figuren etwa 100 px hoch bei 1,8 m
    bpy.context.scene.render.resolution_x, bpy.context.scene.render.resolution_y = 416, 156
    render(os.path.join(outdir, f"roster_{label}_ingame.png"))


# ---- Prüfung ----------------------------------------------------------------------------
GLTF_COMPONENT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
GLTF_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
EXPECTED_BONES = {"hips", "spine", "chest", "neck", "head"} | {
    f"{b}.{s}" for b in ("upper_arm", "forearm", "hand", "thigh", "shin", "foot") for s in "LR"}


def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, _, _ = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError("keine GLB-Datei: " + path)
    jlen, _ = struct.unpack_from("<II", data, 12)
    doc = json.loads(data[20:20 + jlen])
    blen, _ = struct.unpack_from("<II", data, 20 + jlen)
    return doc, data[28 + jlen:28 + jlen + blen]


def accessor(doc, blob, idx):
    acc = doc["accessors"][idx]
    view = doc["bufferViews"][acc["bufferView"]]
    dtype = np.dtype("<" + GLTF_COMPONENT[acc["componentType"]])
    n = GLTF_COUNT[acc["type"]]
    offset = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    arr = np.frombuffer(blob, dtype=dtype, count=acc["count"] * n, offset=offset)
    return arr.reshape(acc["count"], n) if n > 1 else arr


def check_glb_raw(path):
    """Liest die Datei ohne Blender: Y oben, Blickrichtung +Z (Fussspitze gegenüber dem Knöchel)."""
    doc, blob = read_glb(path)
    skin = doc["skins"][0]
    joints = [doc["nodes"][j]["name"] for j in skin["joints"]]
    # glTF speichert spaltenweise, darum transponieren
    ibm = accessor(doc, blob, skin["inverseBindMatrices"]).reshape(-1, 4, 4)
    foot = joints.index("foot.L")
    ankle = np.linalg.inv(ibm[foot].T)[:3, 3]
    tris = 0
    ymin, ymax = 1e9, -1e9
    foot_pts = []
    for prim in doc["meshes"][0]["primitives"]:
        pos = accessor(doc, blob, prim["attributes"]["POSITION"])
        tris += len(accessor(doc, blob, prim["indices"])) // 3
        ymin, ymax = min(ymin, pos[:, 1].min()), max(ymax, pos[:, 1].max())
        jt = accessor(doc, blob, prim["attributes"]["JOINTS_0"])
        wt = accessor(doc, blob, prim["attributes"]["WEIGHTS_0"])
        wt = wt.astype(np.float64) if wt.dtype.kind == "f" else wt / 255.0
        mask = ((jt == foot) * wt).sum(axis=1) > 0.9
        if mask.any():
            foot_pts.append(pos[mask])
    foot_pts = np.concatenate(foot_pts)
    return dict(tris=tris, ymin=float(ymin), ymax=float(ymax), toe=float(foot_pts[:, 2].max() - ankle[2]),
                heel=float(ankle[2] - foot_pts[:, 2].min()), materials=len(doc.get("materials", [])),
                textures=len(doc.get("textures", [])), meshes=len(doc["meshes"]))


def verify(name, path):
    """Importiert die .glb in eine leere Szene und vergleicht mit der Erwartung."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.find_armature()]
    bones = {b.name for b in arm.data.bones}
    bpy.context.view_layer.update()
    zs = [(m.matrix_world @ v.co).z for m in meshes for v in m.data.vertices]
    foot = arm.data.bones["foot.L"]
    raw = check_glb_raw(path)
    facing = "+Z" if foot.tail_local.y < foot.head_local.y and raw["toe"] > raw["heel"] else "FALSCH"
    return dict(name=name, bones=len(bones), missing=sorted(EXPECTED_BONES - bones), extra=sorted(bones - EXPECTED_BONES),
                tris=sum(len(p.vertices) - 2 for m in meshes for p in m.data.polygons), height=max(zs), floor=min(zs),
                objects=len(meshes), facing=facing, raw=raw,
                parents={b.name: b.parent.name if b.parent else None for b in arm.data.bones})


def print_report(rows):
    print("| Figur | Knochen | Namen | Dreiecke | Höhe (m) | Blick | Materialien | Texturen | Objekte |")
    print("|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        names = "vollständig" if not r["missing"] and not r["extra"] else f"NEIN {r['missing']} {r['extra']}"
        print(f"| {r['name']} | {r['bones']} | {names} | {r['tris']} | {r['height']:.3f} | {r['facing']} "
              f"| {r['raw']['materials']} | {r['raw']['textures']} | {r['objects']} |")
    for r in rows:
        print(f"{r['name']}: Boden {r['floor']:.3f}, Rohdatei Y {r['raw']['ymin']:.3f}..{r['raw']['ymax']:.3f}, "
              f"Dreiecke {r['raw']['tris']}, Fussspitze +Z {r['raw']['toe']:.3f}, Ferse -Z {r['raw']['heel']:.3f}, "
              f"Eltern: {r['parents']}")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--fighter", default="bruce", choices=sorted(ALL_FIGHTERS) + list(GROUPS) + ["all"],
                    help="eine Figur, eine Gruppe ('fighters', 'players') oder 'all'")
    ap.add_argument("--out", default=None, help="Ziel .glb (Standard: assets/characters/player_<name>.glb)")
    ap.add_argument("--front")
    ap.add_argument("--side")
    ap.add_argument("--no-blend", action="store_true", help="keine .blend neben die .glb schreiben")
    ap.add_argument("--preview", action="store_true", help="Vorschaubilder rendern")
    ap.add_argument("--preview-dir", default="build/characters_preview")
    ap.add_argument("--clip-preview", nargs="*", default=None, help="Clips als Bildreihe rendern (ohne Namen: alle)")
    ap.add_argument("--verify", action="store_true", help="jede .glb neu importieren und prüfen")
    args = ap.parse_args(argv)

    groups = list(GROUPS) if args.fighter == "all" else [args.fighter] if args.fighter in GROUPS else []
    names = [n for g in groups for n in GROUPS[g]] or [args.fighter]
    if args.out and len(names) > 1:
        ap.error("--out geht nur mit einer einzelnen Figur")
    outs = {}
    for name in names:
        out = args.out or model_file(name)
        outs[name] = out
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)

        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.preferences.filepaths.save_version = 0     # keine .blend1 neben die Modelle
        b = build_figure(name)
        add_reference_planes(args.front, args.side, ALL_FIGHTERS[name]["hip_z"] * 2)
        if name in fighter_clips.CLIP_FIGHTERS:
            slip, dip, reach = fighter_clips.bake_clips(b.armature)
            print(f"{name}: {len(bpy.data.actions)} Clips, stehende Füsse rutschen {slip * 1000:.2f} mm, "
                  f"Füsse tauchen {dip * 1000:.1f} mm in den Boden, Hände liegen {reach * 1000:.1f} mm neben dem Griff")
            if slip > 0.005 or dip > 0.02 or reach > 0.025:
                raise RuntimeError(f"{name}: Clip-Fehler, Fuss rutscht {slip:.4f} m, im Boden {dip:.4f} m, Griff {reach:.4f} m")

        if not args.no_blend:
            bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(os.path.splitext(out)[0] + ".blend"))
        export_glb(b, out)
        print(f"OK: {out} ({len(b.parts)} Teile, {len(b.armature.data.bones)} Knochen)")

        if args.preview:
            os.makedirs(args.preview_dir, exist_ok=True)
            preview_figure(name, b, args.preview_dir)

        if args.clip_preview is not None and name in fighter_clips.CLIP_FIGHTERS:
            os.makedirs(args.preview_dir, exist_ok=True)
            preview_clips(name, b, args.preview_dir, args.clip_preview)

    if args.preview:
        for g in groups:
            preview_roster(GROUPS[g], g, args.preview_dir)

    if not args.out:
        export_bat("assets/characters/weapon_bat.glb", not args.no_blend)

    if args.verify:
        print_report([verify(name, outs[name]) for name in names])


main()
