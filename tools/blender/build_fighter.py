"""Baut einen Low-Poly-Kämpfer in T-Pose mit Skelett und exportiert ihn als .glb.

Aufruf (Blender 3.6 oder neuer):
    blender -b -P tools/blender/build_fighter.py -- --fighter bruce --out assets/characters/player_bruce.glb
Optional, um die Reference Sheets als Planes in der .blend zu haben:
    ... -- --front front.png --side side.png

Koordinaten in Blender: X = rechts/links, Y = vorn (-Y ist die Blickrichtung), Z = oben.
Der glTF-Export macht daraus Y-oben, Figur schaut nach +Z (Godot-Konvention für Modelle).
Die Figur ist eine stilisierte Basis aus Quadern, Kegelstümpfen und Kugeln; Gesicht und Details
werden später von Hand modelliert, die Proportionen und Farben stammen aus den Sheets.
"""
import argparse
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

# Farben (sRGB-Näherung aus den Sheets). build = Breite von Oberkörper und Gliedern.
FIGHTERS = {
    "bruce": dict(height=1.72, build=0.92, skin="E8B98F", top=None, arms="skin", pants="F2C21B",
                  shoes="F2C21B", hair="0B0B0B", shoe_stripe="111111"),
    "chuck": dict(height=1.84, build=1.12, skin="D9A47C", top="2F4F83", arms="skin", pants="3B5B8C",
                  shoes="6B4226", hair="6B4226", shoe_stripe="6B4226"),
    "jackie": dict(height=1.74, build=0.95, skin="E3B48E", top="1C1C22", arms="top", pants="1C1C22",
                   shoes="F0F0F0", hair="0B0B0B", shoe_stripe="C62828"),
    "jcvd": dict(height=1.82, build=1.08, skin="E0AE86", top="18181A", arms="skin", pants="4B5A3A",
                 shoes="111111", hair="6B4A2F", shoe_stripe="111111"),
}


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


class Builder:
    def __init__(self, spec, name):
        self.spec = spec
        self.name = name
        self.scale = spec["height"] / 1.8       # alle Masse sind für 1,80 m entworfen
        self.w = spec["build"]
        self.mats = {}
        self.parts = []
        self.armature = None

    def p(self, x, y, z):
        s = self.scale
        return Vector((x * s, y * s, z * s))

    def mat(self, key, color_hex):
        if key not in self.mats:
            self.mats[key] = make_material(f"{self.name}_{key}", color_hex)
        return self.mats[key]

    # ---- Primitive ---------------------------------------------------------------------
    def _finish(self, part_name, bm, bone, material):
        mesh = bpy.data.meshes.new(part_name)
        bm.to_mesh(mesh)
        bm.free()
        for poly in mesh.polygons:
            poly.use_smooth = False
        mesh.materials.append(material)
        obj = bpy.data.objects.new(part_name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        vg = obj.vertex_groups.new(name=bone)
        vg.add([v.index for v in mesh.vertices], 1.0, "REPLACE")
        self.parts.append(obj)
        return obj

    def box(self, part_name, bone, center, size, material):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        s = self.scale
        m = Matrix.Translation(self.p(*center)) @ Matrix.Diagonal((size[0] * s, size[1] * s, size[2] * s, 1.0))
        bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
        return self._finish(part_name, bm, bone, material)

    def sphere(self, part_name, bone, center, radii, material):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=1.0)
        s = self.scale
        m = Matrix.Translation(self.p(*center)) @ Matrix.Diagonal((radii[0] * s, radii[1] * s, radii[2] * s, 1.0))
        bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
        return self._finish(part_name, bm, bone, material)

    def limb(self, part_name, bone, a, b, r0, r1, material):
        """Kegelstumpf von Punkt a (Radius r0) nach Punkt b (Radius r1)."""
        pa, pb = self.p(*a), self.p(*b)
        direction = pb - pa
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=10,
                              radius1=r0 * self.scale, radius2=r1 * self.scale, depth=direction.length)
        rot = Vector((0, 0, 1)).rotation_difference(direction.normalized()).to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=Matrix.Translation((pa + pb) / 2) @ rot, verts=bm.verts)
        return self._finish(part_name, bm, bone, material)

    # ---- Skelett -----------------------------------------------------------------------
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
            b.head, b.tail = self.p(*head), self.p(*tail)
            if parent:
                b.parent = eb[parent]
            return b

        bone("hips", (0, 0, 0.95), (0, 0, 1.05))
        bone("spine", (0, 0, 1.05), (0, 0, 1.30), "hips")
        bone("chest", (0, 0, 1.30), (0, 0, 1.46), "spine")
        bone("neck", (0, 0, 1.46), (0, 0, 1.56), "chest")
        bone("head", (0, 0, 1.56), (0, 0, 1.80), "neck")
        for side, sx in (("L", 1), ("R", -1)):
            bone(f"upper_arm.{side}", (sx * 0.20, 0, 1.46), (sx * 0.48, 0, 1.46), "chest")
            bone(f"forearm.{side}", (sx * 0.48, 0, 1.46), (sx * 0.74, 0, 1.46), f"upper_arm.{side}")
            bone(f"hand.{side}", (sx * 0.74, 0, 1.46), (sx * 0.86, 0, 1.46), f"forearm.{side}")
            bone(f"thigh.{side}", (sx * 0.10, 0, 0.95), (sx * 0.10, 0.02, 0.50), "hips")
            bone(f"shin.{side}", (sx * 0.10, 0.02, 0.50), (sx * 0.10, 0, 0.09), f"thigh.{side}")
            bone(f"foot.{side}", (sx * 0.10, 0, 0.09), (sx * 0.10, -0.20, 0.04), f"shin.{side}")
        bpy.ops.object.mode_set(mode="OBJECT")
        self.armature = arm_obj

    # ---- Körper ------------------------------------------------------------------------
    def build_body(self):
        sp, w = self.spec, self.w
        skin = self.mat("skin", sp["skin"])
        pants = self.mat("pants", sp["pants"])
        shoes = self.mat("shoes", sp["shoes"])
        hair = self.mat("hair", sp["hair"])
        top = self.mat("top", sp["top"]) if sp["top"] else skin
        arms = top if sp["arms"] == "top" else skin

        # Rumpf
        self.box("Pelvis", "hips", (0, 0, 0.98), (0.34 * w, 0.20, 0.18), pants)
        self.box("Abdomen", "spine", (0, 0, 1.14), (0.32 * w, 0.19, 0.22), top)
        self.box("Chest", "chest", (0, 0, 1.34), (0.42 * w, 0.23, 0.26), top)
        self.limb("Neck", "neck", (0, 0, 1.48), (0, 0, 1.56), 0.05 * w, 0.045 * w, skin)
        # Kopf (-Y ist vorn: Nase/Gesicht kommt später, hier nur die Form)
        self.sphere("Head", "head", (0, 0, 1.67), (0.095, 0.11, 0.12), skin)
        self.sphere("Hair", "head", (0, 0.015, 1.70), (0.105, 0.12, 0.115), hair)
        self.box("Nose", "head", (0, -0.115, 1.66), (0.025, 0.03, 0.04), skin)

        for side, sx in (("L", 1), ("R", -1)):
            # Arme in T-Pose
            self.limb(f"UpperArm.{side}", f"upper_arm.{side}", (sx * 0.20, 0, 1.46), (sx * 0.48, 0, 1.46),
                      0.058 * w, 0.050 * w, arms)
            self.limb(f"Forearm.{side}", f"forearm.{side}", (sx * 0.48, 0, 1.46), (sx * 0.74, 0, 1.46),
                      0.048 * w, 0.040 * w, arms if sp["arms"] == "top" else skin)
            self.box(f"Hand.{side}", f"hand.{side}", (sx * 0.80, 0, 1.46), (0.12, 0.07, 0.08),
                     self.mat("glove", "1A1A1A") if self.name in ("chuck", "jcvd") else skin)
            # Beine
            self.limb(f"Thigh.{side}", f"thigh.{side}", (sx * 0.10, 0, 0.95), (sx * 0.10, 0.02, 0.50),
                      0.095 * w, 0.065 * w, pants)
            self.limb(f"Shin.{side}", f"shin.{side}", (sx * 0.10, 0.02, 0.50), (sx * 0.10, 0, 0.10),
                      0.062 * w, 0.045 * w, pants)
            self.box(f"Foot.{side}", f"foot.{side}", (sx * 0.10, -0.05, 0.045), (0.10, 0.27, 0.09), shoes)
            if sp["shoe_stripe"] != sp["shoes"]:
                self.box(f"ShoeStripe.{side}", f"foot.{side}", (sx * 0.10, -0.03, 0.05),
                         (0.104, 0.05, 0.05), self.mat("stripe", sp["shoe_stripe"]))

    def bind(self):
        for obj in self.parts:
            obj.parent = self.armature
            mod = obj.modifiers.new("Armature", "ARMATURE")
            mod.object = self.armature


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


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--fighter", default="bruce", choices=sorted(FIGHTERS))
    ap.add_argument("--out", default=None, help="Ziel .glb (Standard: assets/characters/player_<name>.glb)")
    ap.add_argument("--front")
    ap.add_argument("--side")
    ap.add_argument("--no-blend", action="store_true", help="keine .blend neben die .glb schreiben")
    args = ap.parse_args(argv)

    out = args.out or f"assets/characters/player_{args.fighter}.glb"
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    b = Builder(FIGHTERS[args.fighter], args.fighter)
    b.build_armature()
    b.build_body()
    b.bind()
    add_reference_planes(args.front, args.side, FIGHTERS[args.fighter]["height"])

    if not args.no_blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(out)[0] + ".blend")

    bpy.ops.object.select_all(action="DESELECT")
    for o in b.parts + [b.armature]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = b.armature
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_yup=True,
                              export_skins=True, export_animations=False, export_apply=False)
    print(f"OK: {out} ({len(b.parts)} Teile, {len(b.armature.data.bones)} Knochen)")


main()
