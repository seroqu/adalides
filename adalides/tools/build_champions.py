# Construye los diez arquetipos como miniaturas low-poly con esqueleto y
# animaciones (idle, walk, attack por arquetipo, hit, death, cheer) y los exporta como GLB.
# Se ejecuta dentro de Blender (vía el puente de Higgsfield o `blender -b -P`).
import bpy, math, os
from mathutils import Vector

OUT = os.path.expanduser("~/Adalides/adalides/assets/models")
COL_NAME = "ADALIDES_BUILD"
ONLY = globals().get("ONLY", None)  # lista de nombres a construir, o None = todos

# Miniaturas de piedra tallada (como las estatuillas del vídeo de victoria): tonos de piedra
# clara y oscura, filetes dorados y cristales de Éter azules. El color del elemento lo ponen
# los cristales del pedestal y el anillo en el juego, no el modelo.
PAL = {
    "skin": (0.74, 0.72, 0.70), "cloth": (0.40, 0.40, 0.47), "leather": (0.33, 0.31, 0.33),
    "steel": (0.62, 0.63, 0.68), "dark": (0.14, 0.13, 0.17), "bone": (0.82, 0.80, 0.74),
    "wood": (0.36, 0.32, 0.30), "brass": (0.80, 0.62, 0.30), "fur": (0.46, 0.43, 0.42),
    "white": (0.86, 0.85, 0.82), "accent": (0.86, 0.68, 0.30), "gold": (0.92, 0.76, 0.30),
    "red": (0.50, 0.40, 0.42), "purple": (0.38, 0.33, 0.46), "grey": (0.42, 0.42, 0.45),
    "teal": (0.35, 0.70, 1.0), "green": (0.40, 0.44, 0.42), "blue": (0.30, 0.34, 0.50),
    "stone": (0.56, 0.56, 0.62), "stone_dark": (0.30, 0.30, 0.36),
}
GLOW = {"teal"}  # materiales emisivos (cristales)

def mat(name):
    m = bpy.data.materials.get("CH_" + name)
    if m is None:
        m = bpy.data.materials.new("CH_" + name)
        m.use_nodes = True
        b = m.node_tree.nodes.get("Principled BSDF")
        b.inputs["Base Color"].default_value = (*PAL[name], 1)
        b.inputs["Roughness"].default_value = 0.35 if name in ("gold", "brass", "steel") else 0.9
        b.inputs["Specular IOR Level"].default_value = 0.5 if name in ("gold", "brass", "steel") else 0.2
        if name in ("gold", "brass"):
            b.inputs["Metallic"].default_value = 0.7
        if name in GLOW:
            b.inputs["Emission Color"].default_value = (*PAL[name], 1)
            b.inputs["Emission Strength"].default_value = 2.0
    return m

col = bpy.data.collections.get(COL_NAME) or bpy.data.collections.new(COL_NAME)
if COL_NAME not in [c.name for c in bpy.context.scene.collection.children]:
    bpy.context.scene.collection.children.link(col)
col.hide_viewport = False; col.hide_render = False
for o in list(col.objects):
    bpy.data.objects.remove(o, do_unlink=True)
for a in list(bpy.data.actions):
    if a.name.split(".")[0] in ("idle", "walk", "attack", "hit", "death", "cheer"):
        bpy.data.actions.remove(a)

parts = []  # (objeto, hueso)

def add(kind, name, loc, scale=(1, 1, 1), rot=(0, 0, 0), color="cloth", bone="spine", bevel=0.03, **kw):
    if kind == "cube": bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    elif kind == "sphere": bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.5, location=loc)
    elif kind == "cyl": bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get("v", 12), radius=0.5, depth=1, location=loc)
    elif kind == "cone": bpy.ops.mesh.primitive_cone_add(vertices=kw.get("v", 12), radius1=0.5, radius2=kw.get("r2", 0.0), depth=1, location=loc)
    elif kind == "torus": bpy.ops.mesh.primitive_torus_add(major_segments=20, minor_segments=8, major_radius=0.5, minor_radius=kw.get("minor", 0.08), location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.rotation_euler = tuple(math.radians(a) for a in rot)
    o.data.materials.append(mat(color))
    if bevel > 0 and kind in ("cube", "cyl", "cone"):
        mod = o.modifiers.new("Bevel", 'BEVEL')
        mod.width = bevel; mod.segments = 3; mod.limit_method = 'ANGLE'
    for c in o.users_collection: c.objects.unlink(o)
    col.objects.link(o)
    parts.append((o, bone))
    return o

# Esqueleto: hips(0.44) → spine → head; arm.L/R desde los hombros; leg.L/R desde la cadera.
def body(torso_w=0.5, torso_d=0.34, torso_h=0.55, torso_color="cloth", head_r=0.3, head_color="skin",
         leg_color="leather", arm_color="cloth", hunched=0.0, boots="dark", belt=None, trim="gold"):
    head_r = max(head_r, 0.33)  # Cabezas grandes de miniatura.
    add("cyl", "legL", (-0.11, 0, 0.24), (0.19, 0.19, 0.4), color=leg_color, bone="leg.L")
    add("cyl", "legR", (0.11, 0, 0.24), (0.19, 0.19, 0.4), color=leg_color, bone="leg.R")
    add("cube", "bootL", (-0.11, -0.04, 0.06), (0.2, 0.3, 0.12), color=boots, bone="leg.L")
    add("cube", "bootR", (0.11, -0.04, 0.06), (0.2, 0.3, 0.12), color=boots, bone="leg.R")
    z = 0.44 + torso_h / 2
    add("cube", "torso", (0, hunched * 0.08, z), (torso_w, torso_d, torso_h), rot=(hunched * 18, 0, 0), color=torso_color, bone="spine")
    add("cube", "hips", (0, 0, 0.46), (torso_w * 0.9, torso_d * 0.9, 0.12), color=belt or leg_color, bone="hips")
    add("cube", "belt_trim", (0, 0, 0.46), (torso_w * 0.94, torso_d * 0.94, 0.04), color=trim, bone="hips", bevel=0.01)
    add("cube", "buckle", (0, -torso_d * 0.48, 0.46), (0.1, 0.03, 0.09), color=trim, bone="hips", bevel=0.01)
    top = 0.44 + torso_h
    add("sphere", "head", (0, hunched * 0.2, top + head_r * 0.95), (head_r * 2, head_r * 2, head_r * 2), color=head_color, bone="head")
    add("cyl", "neck", (0, hunched * 0.1, top + 0.02), (0.14, 0.14, 0.1), color=head_color, bone="head")
    sx = torso_w / 2 + 0.1
    add("cyl", "armL", (-sx, 0, top - 0.24), (0.15, 0.15, 0.44), rot=(0, 0, -12), color=arm_color, bone="arm.L")
    add("cyl", "armR", (sx, 0, top - 0.24), (0.15, 0.15, 0.44), rot=(0, 0, 12), color=arm_color, bone="arm.R")
    add("sphere", "shoulderL", (-sx + 0.02, 0, top - 0.04), (0.2, 0.2, 0.2), color=arm_color, bone="arm.L")
    add("sphere", "shoulderR", (sx - 0.02, 0, top - 0.04), (0.2, 0.2, 0.2), color=arm_color, bone="arm.R")
    add("sphere", "handL", (-sx - 0.05, 0, top - 0.48), (0.17, 0.17, 0.17), color="skin", bone="arm.L")
    add("sphere", "handR", (sx + 0.05, 0, top - 0.48), (0.17, 0.17, 0.17), color="skin", bone="arm.R")
    return top, sx

def make_rig(name, top, sx):
    arm_data = bpy.data.armatures.new(name + "_rig")
    rig = bpy.data.objects.new(name + "_rig", arm_data)
    col.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    def bone(n, head, tail, parent=None):
        b = arm_data.edit_bones.new(n)
        b.head = Vector(head); b.tail = Vector(tail)
        if parent: b.parent = arm_data.edit_bones[parent]
        return b
    bone("root", (0, 0, 0), (0, 0, 0.2))
    bone("hips", (0, 0, 0.44), (0, 0, 0.56), "root")
    bone("spine", (0, 0, 0.56), (0, 0, top), "hips")
    bone("head", (0, 0, top), (0, 0, top + 0.5), "spine")
    bone("arm.L", (-sx + 0.02, 0, top - 0.04), (-sx - 0.05, 0, top - 0.5), "spine")
    bone("arm.R", (sx - 0.02, 0, top - 0.04), (sx + 0.05, 0, top - 0.5), "spine")
    bone("leg.L", (-0.11, 0, 0.44), (-0.11, 0, 0.02), "hips")
    bone("leg.R", (0.11, 0, 0.44), (0.11, 0, 0.02), "hips")
    bpy.ops.object.mode_set(mode='OBJECT')
    return rig

def animate(rig, top, name="melee"):
    """Clips a 24 fps: idle, walk, attack (según arquetipo), hit, death y cheer."""
    ad = rig.animation_data_create()
    scene = bpy.context.scene
    def key(action_name, frames, length):
        act = bpy.data.actions.new(action_name)
        ad.action = act
        if hasattr(ad, "action_slot") and len(act.slots) == 0:
            slot = act.slots.new('OBJECT', rig.name)
            ad.action_slot = slot
        for pb in rig.pose.bones:
            pb.rotation_mode = 'XYZ'
        for f, poses in frames:
            scene.frame_set(f)
            for pb in rig.pose.bones:
                pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)
            for bname, (rx, ry, rz, loc) in poses.items():
                pb = rig.pose.bones[bname]
                pb.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
                pb.location = loc
            for pb in rig.pose.bones:
                pb.keyframe_insert("rotation_euler", frame=f)
                pb.keyframe_insert("location", frame=f)
        act.frame_range = (frames[0][0], length)
        act.use_frame_range = True
        track = ad.nla_tracks.new(); track.name = action_name
        strip = track.strips.new(action_name, int(frames[0][0]), act)
        strip.name = action_name
        ad.action = None
        return act
    Z = (0, 0, 0)
    def R(x=0, y=0, z=0, loc=Z):
        return (x, y, z, loc)
    # idle: respira, cambia el peso de pie, mira a los lados (72 frames en bucle)
    key("idle", [
        (1, {}),
        (18, {"spine": R(2.5, 0, 1.5, (0, 0, 0.015)), "hips": R(0, 0, 0, (0.015, 0, 0)), "head": R(-2, 0, 3),
              "arm.L": R(5), "arm.R": R(-5), "leg.L": R(-2), "leg.R": R(2)}),
        (36, {"spine": R(0, 0, 0, (0, 0, 0.03)), "head": R(1)}),
        (54, {"spine": R(2.5, 0, -1.5, (0, 0, 0.015)), "hips": R(0, 0, 0, (-0.015, 0, 0)), "head": R(-2, 0, -3),
              "arm.L": R(-5), "arm.R": R(5), "leg.L": R(2), "leg.R": R(-2)}),
        (72, {}),
    ], 72)
    # walk: zancada con balanceo de brazos (24 frames en bucle)
    key("walk", [
        (1, {"leg.L": R(30), "leg.R": R(-30), "arm.L": R(-22), "arm.R": R(22), "spine": R(4), "root": R(0, 0, 0, (0, 0, 0.02))}),
        (7, {"spine": R(4), "root": R(0, 0, 0, (0, 0, 0.06)), "leg.L": R(0), "leg.R": R(8)}),
        (13, {"leg.L": R(-30), "leg.R": R(30), "arm.L": R(22), "arm.R": R(-22), "spine": R(4), "root": R(0, 0, 0, (0, 0, 0.02))}),
        (19, {"spine": R(4), "root": R(0, 0, 0, (0, 0, 0.06)), "leg.R": R(0), "leg.L": R(8)}),
        (24, {"leg.L": R(30), "leg.R": R(-30), "arm.L": R(-22), "arm.R": R(22), "spine": R(4), "root": R(0, 0, 0, (0, 0, 0.02))}),
    ], 24)
    # attack: según arquetipo (-Y es el frente; hips loc y negativa = embestida)
    if name == "arquero":
        frames = [
            (1, {}),
            (6, {"arm.L": R(85), "arm.R": R(70), "spine": R(-4, 0, -10)}),
            (12, {"arm.L": R(90), "arm.R": R(-20), "spine": R(-6, 0, -15), "head": R(0, 0, -8)}),
            (14, {"arm.L": R(88), "arm.R": R(60), "spine": R(4, 0, -8), "hips": R(0, 0, 0, (0, -0.06, 0))}),
            (20, {"arm.L": R(60), "arm.R": R(30), "spine": R(2, 0, -4)}),
            (26, {}),
        ]; length = 26
    elif name in ("mago", "mago_lowpoly_alt"):
        frames = [
            (1, {}),
            (8, {"arm.L": R(160), "arm.R": R(160), "spine": R(-10), "head": R(-12), "root": R(0, 0, 0, (0, 0, 0.06))}),
            (12, {"arm.L": R(170), "arm.R": R(170), "spine": R(-12), "head": R(-14), "root": R(0, 0, 0, (0, 0, 0.12))}),
            (16, {"arm.L": R(90), "arm.R": R(90), "spine": R(20), "head": R(10), "hips": R(0, 0, 0, (0, -0.15, 0))}),
            (20, {"arm.L": R(80), "arm.R": R(80), "spine": R(15), "head": R(6), "hips": R(0, 0, 0, (0, -0.1, 0))}),
            (28, {}),
        ]; length = 28
    elif name == "angel":
        frames = [
            (1, {}),
            (6, {"root": R(0, 0, 0, (0, 0, 0.3)), "arm.L": R(20, 0, -60), "arm.R": R(20, 0, 60), "spine": R(-8), "leg.L": R(15), "leg.R": R(15)}),
            (12, {"root": R(0, 0, 0, (0, -0.3, 0.35)), "arm.L": R(90, 0, -20), "arm.R": R(90, 0, 20), "spine": R(20), "head": R(8), "leg.L": R(10), "leg.R": R(20)}),
            (18, {"root": R(0, 0, 0, (0, -0.1, 0.2)), "arm.L": R(50, 0, -30), "arm.R": R(50, 0, 30), "spine": R(8), "leg.L": R(8), "leg.R": R(8)}),
            (26, {}),
        ]; length = 26
    elif name in ("demonio", "salvaje"):
        frames = [
            (1, {}),
            (6, {"arm.L": R(-80, 0, -30), "arm.R": R(-80, 0, 30), "spine": R(-10), "head": R(-8), "hips": R(0, 0, 0, (0, 0.1, 0)), "leg.L": R(8), "leg.R": R(-8)}),
            (10, {"arm.L": R(110, 0, -10), "arm.R": R(110, 0, 10), "spine": R(30), "head": R(12), "hips": R(0, 0, 0, (0, -0.3, 0)), "root": R(0, 0, 0, (0, 0, 0.1)), "leg.L": R(30), "leg.R": R(-30)}),
            (15, {"arm.L": R(95, 0, -10), "arm.R": R(95, 0, 10), "spine": R(24), "head": R(8), "hips": R(0, 0, 0, (0, -0.25, 0)), "leg.L": R(20), "leg.R": R(-20)}),
            (24, {}),
        ]; length = 24
    elif name == "robot":
        frames = [
            (1, {}),
            (5, {"arm.R": R(-40), "spine": R(0, 0, -10)}),
            (9, {"arm.R": R(100), "spine": R(10, 0, 15), "hips": R(0, 0, 0, (0, -0.25, 0)), "leg.R": R(25), "leg.L": R(-15)}),
            (13, {"arm.R": R(100), "spine": R(10, 0, 15), "hips": R(0, 0, 0, (0, -0.25, 0)), "leg.R": R(25), "leg.L": R(-15)}),
            (20, {}),
        ]; length = 20
    elif name == "asesino":
        frames = [
            (1, {}),
            (4, {"arm.R": R(-70), "spine": R(0, 0, -20), "head": R(0, 0, -8)}),
            (7, {"arm.R": R(100), "spine": R(18, 0, 20), "hips": R(0, 0, 0, (0, -0.3, 0)), "leg.R": R(30), "leg.L": R(-20)}),
            (10, {"arm.L": R(-70), "arm.R": R(40), "spine": R(5, 0, 25), "hips": R(0, 0, 0, (0, -0.2, 0)), "leg.R": R(20), "leg.L": R(-10)}),
            (13, {"arm.L": R(100), "arm.R": R(20), "spine": R(20, 0, -15), "hips": R(0, 0, 0, (0, -0.35, 0)), "leg.L": R(30), "leg.R": R(-20)}),
            (20, {}),
        ]; length = 20
    elif name == "muerto":
        frames = [
            (1, {}),
            (8, {"arm.R": R(-70), "arm.L": R(-30), "spine": R(-12, 0, -18), "head": R(-10), "hips": R(0, 0, 0, (0, 0.08, 0))}),
            (14, {"arm.R": R(110), "arm.L": R(20), "spine": R(28, 0, 18), "head": R(14), "hips": R(0, 0, 0, (0, -0.28, 0)), "leg.R": R(30), "leg.L": R(-20)}),
            (18, {"arm.R": R(95), "arm.L": R(10), "spine": R(22, 0, 15), "head": R(10), "hips": R(0, 0, 0, (0, -0.22, 0)), "leg.R": R(25), "leg.L": R(-15)}),
            (28, {}),
        ]; length = 28
    elif name == "defensor":
        frames = [
            (1, {}),
            (6, {"arm.L": R(-30), "arm.R": R(-95), "spine": R(-8, 0, -22), "head": R(-5, 0, -10), "hips": R(0, 0, 0, (0, 0.08, 0)), "leg.L": R(10), "leg.R": R(-10)}),
            (10, {"arm.L": R(90), "arm.R": R(110), "spine": R(28, 0, 22), "head": R(10, 0, 8), "hips": R(0, 0, 0, (0, -0.28, 0)), "leg.R": R(35), "leg.L": R(-25)}),
            (14, {"arm.L": R(80), "arm.R": R(95), "spine": R(22, 0, 18), "head": R(8, 0, 6), "hips": R(0, 0, 0, (0, -0.22, 0)), "leg.R": R(28), "leg.L": R(-20)}),
            (24, {}),
        ]; length = 24
    else:  # melee (pirata y resto)
        frames = [
            (1, {}),
            (6, {"arm.R": R(-95), "arm.L": R(25), "spine": R(-8, 0, -22), "head": R(-5, 0, -10), "hips": R(0, 0, 0, (0, 0.08, 0)), "leg.L": R(10), "leg.R": R(-10)}),
            (10, {"arm.R": R(110), "arm.L": R(-30), "spine": R(28, 0, 22), "head": R(10, 0, 8), "hips": R(0, 0, 0, (0, -0.28, 0)), "root": R(0, 0, 0, (0, 0, 0.02)), "leg.R": R(35), "leg.L": R(-25)}),
            (14, {"arm.R": R(95), "arm.L": R(-20), "spine": R(22, 0, 18), "head": R(8, 0, 6), "hips": R(0, 0, 0, (0, -0.22, 0)), "leg.R": R(28), "leg.L": R(-20)}),
            (24, {}),
        ]; length = 24
    key("attack", frames, length)
    # hit: sale despedido hacia atrás, agita los brazos y se recompone
    key("hit", [
        (1, {}),
        (3, {"spine": R(-22, 0, 6), "head": R(-20), "hips": R(0, 0, 0, (0, 0.18, 0)), "arm.L": R(-40), "arm.R": R(-40), "root": R(0, 0, 0, (0, 0, 0.03)), "leg.L": R(-10), "leg.R": R(10)}),
        (7, {"spine": R(8, 0, -3), "hips": R(0, 0, 0, (0, 0.1, 0)), "arm.L": R(15), "arm.R": R(15)}),
        (11, {"spine": R(-4, 0, 2), "hips": R(0, 0, 0, (0, 0.03, 0))}),
        (16, {}),
    ], 16)
    # death: se tambalea, se le doblan las rodillas, cae de espaldas con rebote y se hunde
    key("death", [
        (1, {}),
        (6, {"spine": R(-10), "hips": R(0, 0, 0, (0, 0.1, 0)), "head": R(-10), "arm.L": R(-30), "arm.R": R(-30)}),
        (12, {"root": R(0, 0, 0, (0, 0, -0.12)), "leg.L": R(40), "leg.R": R(-20), "spine": R(15), "head": R(20), "arm.L": R(10), "arm.R": R(10)}),
        (18, {"root": R(-75, 0, 0, (0, 0.15, 0.1)), "arm.L": R(0, 0, -60), "arm.R": R(0, 0, 60), "leg.L": R(10), "leg.R": R(-5)}),
        (22, {"root": R(-95, 0, 0, (0, 0.3, 0.0)), "arm.L": R(0, 0, -70), "arm.R": R(0, 0, 70)}),
        (26, {"root": R(-88, 0, 0, (0, 0.3, 0.03)), "arm.L": R(0, 0, -70), "arm.R": R(0, 0, 70)}),
        (40, {"root": R(-90, 0, 0, (0, 0.3, -0.6)), "arm.L": R(0, 0, -70), "arm.R": R(0, 0, 70)}),
    ], 40)
    # cheer: salta con los brazos en alto (victoria)
    key("cheer", [
        (1, {}),
        (6, {"spine": R(6), "arm.L": R(-30), "arm.R": R(-30), "root": R(0, 0, 0, (0, 0, -0.04)), "leg.L": R(10), "leg.R": R(10)}),
        (12, {"root": R(0, 0, 0, (0, 0, 0.35)), "arm.L": R(170), "arm.R": R(170), "head": R(-15), "spine": R(-6), "leg.L": R(20), "leg.R": R(20)}),
        (18, {"root": R(0, 0, 0, (0, 0, 0.0)), "arm.L": R(150), "arm.R": R(150), "head": R(-8), "spine": R(4)}),
        (24, {"root": R(0, 0, 0, (0, 0, 0.3)), "arm.L": R(170), "arm.R": R(170), "head": R(-15), "spine": R(-6), "leg.L": R(20), "leg.R": R(20)}),
        (30, {"arm.L": R(120), "arm.R": R(120), "spine": R(4)}),
        (36, {}),
    ], 36)
    scene.frame_set(1)

def finish(name, top, sx):
    global parts
    # Suavizado y aplicar bisel en cada pieza; grupo de vértices con el nombre del hueso.
    for o, bone in parts:
        bpy.ops.object.select_all(action='DESELECT')
        o.select_set(True); bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
        vg = o.vertex_groups.new(name=bone)
        vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
        for p in o.data.polygons: p.use_smooth = True
    bpy.ops.object.select_all(action='DESELECT')
    for o, _ in parts: o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0][0]
    bpy.ops.object.join()
    mesh = bpy.context.active_object
    mesh.name = name
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(45))
    except Exception:
        try: bpy.ops.object.shade_auto_smooth(angle=math.radians(45))
        except Exception: pass
    rig = make_rig(name, top, sx)
    mesh.parent = rig
    mod = mesh.modifiers.new("Armature", 'ARMATURE'); mod.object = rig
    animate(rig, top, name)
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True); mesh.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=False,
        export_animations=True, export_animation_mode='NLA_TRACKS', export_nla_strips=True,
        export_yup=True, export_materials='EXPORT', export_skins=True, export_def_bones=False,
        export_frame_range=False, export_force_sampling=True, export_optimize_animation_size=False)
    tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
    rig.hide_set(True); mesh.hide_set(True)
    parts = []
    return {"name": name, "tris": tris, "bytes": os.path.getsize(path)}

BUILDERS = {}
def builder(fn):
    BUILDERS[fn.__name__] = fn
    return fn

@builder
def defensor():
    top, sx = body(0.62, 0.42, 0.6, "steel", 0.28, "steel", leg_color="steel", arm_color="steel", belt="leather")
    add("cube", "helmet", (0, 0, top + 0.3), (0.52, 0.52, 0.36), color="steel", bone="head")
    add("cube", "crest", (0, 0.02, top + 0.55), (0.08, 0.4, 0.16), color="accent", bone="head")
    add("cube", "visor", (0, -0.27, top + 0.26), (0.42, 0.06, 0.1), color="dark", bone="head")
    add("cube", "shield", (-0.64, -0.06, 0.6), (0.1, 0.56, 1.0), color="accent", bone="arm.L", bevel=0.04)
    add("cube", "shield_rim", (-0.68, -0.06, 0.6), (0.05, 0.64, 1.1), color="steel", bone="arm.L", bevel=0.04)
    add("cube", "shield_boss", (-0.72, -0.06, 0.6), (0.06, 0.2, 0.2), rot=(45, 0, 0), color="gold", bone="arm.L")
    add("cube", "chest_trim", (0, -0.22, 0.92), (0.4, 0.04, 0.05), color="gold", bone="spine", bevel=0.01)
    add("cyl", "mace_handle", (sx + 0.05, -0.12, top - 0.5), (0.07, 0.07, 0.7), rot=(90, 0, 0), color="wood", bone="arm.R")
    add("sphere", "mace_head", (sx + 0.05, -0.52, top - 0.5), (0.3, 0.3, 0.3), color="steel", bone="arm.R")
    add("cube", "pauldronL", (-sx + 0.02, 0, top - 0.02), (0.28, 0.32, 0.16), color="steel", bone="arm.L")
    add("cube", "pauldronR", (sx - 0.02, 0, top - 0.02), (0.28, 0.32, 0.16), color="steel", bone="arm.R")
    add("cube", "tabard", (0, -0.22, 0.7), (0.3, 0.04, 0.5), color="accent", bone="spine")
    return top, sx

@builder
def robot():
    top, sx = body(0.56, 0.44, 0.58, "brass", 0.0, "brass", leg_color="steel", arm_color="brass", boots="steel", belt="dark")
    add("cube", "head", (0, 0, top + 0.26), (0.48, 0.42, 0.44), color="brass", bone="head")
    add("cyl", "lens", (0, -0.23, top + 0.28), (0.22, 0.22, 0.06), rot=(90, 0, 0), color="dark", bone="head")
    add("cyl", "lens_glow", (0, -0.26, top + 0.28), (0.13, 0.13, 0.04), rot=(90, 0, 0), color="accent", bone="head")
    add("cyl", "core", (0, -0.24, 0.8), (0.22, 0.22, 0.06), rot=(90, 0, 0), color="accent", bone="spine")
    add("cyl", "core_rim", (0, -0.23, 0.8), (0.3, 0.3, 0.04), rot=(90, 0, 0), color="dark", bone="spine")
    add("cyl", "antenna", (0.14, 0, top + 0.56), (0.04, 0.04, 0.24), color="steel", bone="head")
    add("sphere", "antenna_tip", (0.14, 0, top + 0.7), (0.11, 0.11, 0.11), color="accent", bone="head")
    add("cube", "wrench", (sx + 0.05, -0.36, top - 0.5), (0.1, 0.62, 0.12), color="steel", bone="arm.R")
    add("cube", "wrench_head", (sx + 0.05, -0.7, top - 0.5), (0.28, 0.14, 0.32), color="steel", bone="arm.R")
    add("cube", "vent", (-0.16, -0.23, 0.68), (0.12, 0.03, 0.2), color="dark", bone="spine")
    add("cube", "vent2", (0.16, -0.23, 0.68), (0.12, 0.03, 0.2), color="dark", bone="spine")
    add("cyl", "pipe", (-0.3, 0.2, 0.9), (0.08, 0.08, 0.3), rot=(30, 0, 0), color="steel", bone="spine")
    return top, sx

@builder
def salvaje():
    top, sx = body(0.66, 0.44, 0.5, "fur", 0.3, "fur", leg_color="fur", arm_color="fur", hunched=1.0, boots="fur", belt="leather")
    add("cube", "snout", (0, -0.31, top + 0.2), (0.24, 0.22, 0.18), color="skin", bone="head")
    add("cone", "tuskL", (-0.09, -0.42, top + 0.14), (0.05, 0.05, 0.14), rot=(-90, 0, 0), color="bone", bone="head")
    add("cone", "tuskR", (0.09, -0.42, top + 0.14), (0.05, 0.05, 0.14), rot=(-90, 0, 0), color="bone", bone="head")
    add("cone", "earL", (-0.23, 0.05, top + 0.52), (0.1, 0.06, 0.2), color="fur", bone="head")
    add("cone", "earR", (0.23, 0.05, top + 0.52), (0.1, 0.06, 0.2), color="fur", bone="head")
    add("cube", "eyes", (0, -0.26, top + 0.34), (0.3, 0.04, 0.05), color="accent", bone="head")
    add("cube", "loincloth", (0, -0.22, 0.4), (0.42, 0.06, 0.28), color="leather", bone="hips")
    add("cyl", "club", (sx + 0.05, -0.2, top - 0.5), (0.1, 0.1, 0.72), rot=(80, 0, 0), color="bone", bone="arm.R")
    add("sphere", "club_end", (sx + 0.05, -0.55, top - 0.44), (0.24, 0.24, 0.24), color="bone", bone="arm.R")
    for i, x in enumerate((-0.16, -0.08, 0.0, 0.08, 0.16)):
        add("cone", f"spine{i}", (x, 0.22, top + 0.02), (0.06, 0.06, 0.16), rot=(-40, 0, 0), color="bone", bone="spine")
    add("cube", "clawL", (-sx - 0.08, -0.08, top - 0.52), (0.06, 0.16, 0.05), color="bone", bone="arm.L")
    return top, sx

@builder
def angel():
    top, sx = body(0.44, 0.3, 0.62, "white", 0.27, "skin", leg_color="white", arm_color="white", boots="gold", belt="gold")
    add("torus", "halo", (0, 0, top + 0.74), (0.5, 0.5, 0.5), color="gold", bone="head")
    add("sphere", "hair", (0, 0.04, top + 0.34), (0.5, 0.5, 0.4), color="gold", bone="head")
    for side, s in (("L", -1), ("R", 1)):
        add("cube", f"wing{side}", (s * 0.56, 0.22, 0.98), (0.72, 0.08, 0.5), rot=(0, 0, -s * 25), color="white", bone="spine", bevel=0.04)
        add("cube", f"wing{side}2", (s * 0.92, 0.24, 1.2), (0.52, 0.06, 0.32), rot=(0, 0, -s * 40), color="white", bone="spine", bevel=0.04)
        add("cube", f"wing{side}3", (s * 0.7, 0.26, 0.7), (0.4, 0.05, 0.22), rot=(0, 0, s * 20), color="white", bone="spine", bevel=0.04)
    add("cone", "robe", (0, 0, 0.3), (0.62, 0.44, 0.5), color="white", bone="hips", r2=0.4)
    add("cube", "sword", (sx + 0.05, -0.05, top - 0.75), (0.07, 0.025, 0.72), color="steel", bone="arm.R")
    add("cube", "guard", (sx + 0.05, -0.05, top - 0.4), (0.24, 0.07, 0.06), color="gold", bone="arm.R")
    add("cube", "pauldronL", (-sx + 0.02, 0, top - 0.03), (0.22, 0.26, 0.1), color="gold", bone="arm.L")
    add("cube", "pauldronR", (sx - 0.02, 0, top - 0.03), (0.22, 0.26, 0.1), color="gold", bone="arm.R")
    return top, sx

@builder
def demonio():
    top, sx = body(0.54, 0.36, 0.58, "red", 0.28, "red", leg_color="red", arm_color="red", boots="dark", belt="dark")
    add("cone", "hornL", (-0.19, 0, top + 0.5), (0.13, 0.13, 0.38), rot=(0, -25, 0), color="bone", bone="head")
    add("cone", "hornR", (0.19, 0, top + 0.5), (0.13, 0.13, 0.38), rot=(0, 25, 0), color="bone", bone="head")
    add("cube", "eyes", (0, -0.26, top + 0.3), (0.28, 0.04, 0.06), color="gold", bone="head")
    add("cube", "mouth", (0, -0.27, top + 0.14), (0.18, 0.03, 0.04), color="dark", bone="head")
    for side, s in (("L", -1), ("R", 1)):
        add("cube", f"wing{side}", (s * 0.44, 0.24, 0.92), (0.48, 0.05, 0.38), rot=(0, 0, -s * 30), color="dark", bone="spine", bevel=0.04)
        add("cube", f"wing{side}b", (s * 0.72, 0.26, 1.08), (0.3, 0.04, 0.2), rot=(0, 0, -s * 50), color="dark", bone="spine", bevel=0.04)
    add("cyl", "tail", (0, 0.3, 0.32), (0.07, 0.07, 0.62), rot=(60, 0, 0), color="red", bone="hips")
    add("cone", "tail_tip", (0, 0.58, 0.1), (0.13, 0.13, 0.18), rot=(120, 0, 0), color="dark", bone="hips")
    add("cube", "blade", (sx + 0.05, 0.05, top - 0.1), (0.1, 0.05, 0.92), rot=(0, 20, 0), color="steel", bone="arm.R")
    add("cube", "blade_edge", (sx + 0.11, 0.05, top + 0.1), (0.18, 0.05, 0.32), rot=(0, 20, 0), color="dark", bone="arm.R")
    add("cube", "chest_plate", (0, -0.2, 0.82), (0.42, 0.05, 0.32), color="dark", bone="spine")
    return top, sx

@builder
def arquero():
    top, sx = body(0.44, 0.3, 0.58, "leather", 0.26, "skin", leg_color="dark", arm_color="leather", boots="leather", belt="dark")
    add("cone", "hood", (0, 0.02, top + 0.36), (0.7, 0.68, 0.6), color="green", bone="head", r2=0.16)
    add("cube", "hood_lip", (0, -0.2, top + 0.4), (0.56, 0.3, 0.1), rot=(-20, 0, 0), color="green", bone="head", bevel=0.04)
    add("cube", "cape", (0, 0.2, 0.76), (0.5, 0.06, 0.62), color="green", bone="spine", bevel=0.04)
    add("torus", "bow", (-sx - 0.05, -0.1, top - 0.48), (1.0, 1.0, 1.0), rot=(0, 90, 0), color="wood", bone="arm.L", minor=0.04)
    add("cyl", "string", (-sx - 0.05, 0.16, top - 0.48), (0.015, 0.015, 1.0), color="bone", bone="arm.L", bevel=0)
    add("cyl", "quiver", (0.18, 0.22, 0.95), (0.17, 0.17, 0.52), rot=(15, 0, 0), color="leather", bone="spine")
    for i, x in enumerate((0.12, 0.18, 0.24)):
        add("cyl", f"arrow{i}", (x, 0.27, 1.27), (0.02, 0.02, 0.32), rot=(15, 0, 0), color="wood", bone="spine", bevel=0)
        add("cone", f"fletch{i}", (x, 0.3, 1.42), (0.05, 0.05, 0.08), rot=(15, 0, 0), color="accent", bone="spine", bevel=0)
    add("cube", "bracer", (sx + 0.05, 0, top - 0.36), (0.19, 0.19, 0.16), color="leather", bone="arm.R")
    return top, sx

@builder
def asesino():
    top, sx = body(0.42, 0.28, 0.56, "cloth", 0.3, "dark", leg_color="dark", arm_color="cloth", boots="dark", belt="leather")
    add("cube", "eyes", (0, -0.27, top + 0.3), (0.26, 0.04, 0.05), color="teal", bone="head")
    add("cone", "hood", (0, 0.03, top + 0.4), (0.74, 0.7, 0.62), color="cloth", bone="head", r2=0.18)
    add("cube", "hood_lip", (0, -0.2, top + 0.42), (0.6, 0.3, 0.1), rot=(-20, 0, 0), color="cloth", bone="head", bevel=0.04)
    add("cone", "cloak", (0, 0.1, 0.5), (0.8, 0.6, 0.8), color="cloth", bone="hips", r2=0.34)
    add("cube", "cloak_trim", (0, -0.05, 0.8), (0.5, 0.42, 0.04), color="gold", bone="spine", bevel=0.01)
    add("cube", "daggerL", (-sx - 0.05, -0.3, top - 0.48), (0.04, 0.32, 0.05), rot=(0, 0, -10), color="steel", bone="arm.L", bevel=0.01)
    add("cube", "daggerR", (sx + 0.05, -0.3, top - 0.48), (0.04, 0.32, 0.05), rot=(0, 0, 10), color="steel", bone="arm.R", bevel=0.01)
    add("cube", "bandL", (-sx, 0, top - 0.3), (0.18, 0.18, 0.16), color="bone", bone="arm.L")
    add("cube", "bandR", (sx, 0, top - 0.3), (0.18, 0.18, 0.16), color="bone", bone="arm.R")
    add("cube", "strap", (0, -0.15, 0.78), (0.08, 0.04, 0.56), rot=(0, 0, -30), color="leather", bone="spine")
    return top, sx

@builder
def pirata():
    top, sx = body(0.54, 0.36, 0.56, "red", 0.28, "skin", leg_color="cloth", arm_color="red", boots="leather", belt="gold")
    add("cone", "hat", (0, 0, top + 0.4), (0.92, 0.72, 0.32), color="dark", bone="head", r2=0.26)
    add("cube", "hat_brim", (0, 0, top + 0.27), (0.95, 0.78, 0.05), color="dark", bone="head", bevel=0.02)
    add("cube", "hat_badge", (0, -0.36, top + 0.4), (0.12, 0.03, 0.12), color="gold", bone="head")
    add("cube", "coat", (0, 0.1, 0.5), (0.62, 0.32, 0.6), color="cloth", bone="hips", bevel=0.04)
    add("cube", "bandolier", (0, -0.2, 0.78), (0.1, 0.04, 0.6), rot=(0, 0, 30), color="leather", bone="spine")
    add("cube", "cutlass", (sx + 0.05, -0.2, top - 0.1), (0.06, 0.03, 0.62), rot=(20, 0, 0), color="steel", bone="arm.R", bevel=0.01)
    add("cube", "cutlass_guard", (sx + 0.05, -0.1, top - 0.44), (0.16, 0.08, 0.06), color="gold", bone="arm.R")
    add("torus", "hook", (-sx - 0.05, -0.06, top - 0.5), (0.2, 0.2, 0.2), color="steel", bone="arm.L", minor=0.08)
    add("cyl", "peg", (0.11, 0, 0.18), (0.1, 0.1, 0.36), color="wood", bone="leg.R")
    add("cube", "eyepatch", (0.1, -0.27, top + 0.3), (0.13, 0.03, 0.1), color="dark", bone="head")
    add("cube", "beard", (0, -0.24, top + 0.06), (0.26, 0.08, 0.16), color="leather", bone="head")
    return top, sx

@builder
def muerto():
    top, sx = body(0.4, 0.26, 0.56, "bone", 0.27, "bone", leg_color="bone", arm_color="bone", hunched=0.6, boots="grey", belt="dark")
    add("cube", "eyeL", (-0.1, -0.25, top + 0.3), (0.1, 0.06, 0.1), color="dark", bone="head")
    add("cube", "eyeR", (0.1, -0.25, top + 0.3), (0.1, 0.06, 0.1), color="dark", bone="head")
    add("cube", "jaw", (0, -0.2, top + 0.08), (0.26, 0.1, 0.06), color="dark", bone="head")
    add("cone", "cloak", (0, 0.12, 0.56), (0.92, 0.72, 0.92), color="purple", bone="spine", r2=0.3)
    add("cube", "breastplate", (0, -0.17, 0.78), (0.42, 0.06, 0.4), color="grey", bone="spine")
    add("cube", "sword", (sx + 0.05, -0.05, top - 0.7), (0.07, 0.03, 0.72), rot=(0, 0, 15), color="grey", bone="arm.R", bevel=0.01)
    for i, x in enumerate((-0.12, 0.0, 0.12)):
        add("cube", f"rib{i}", (x, -0.14, 0.62), (0.05, 0.03, 0.2), color="dark", bone="spine")
    add("cube", "crown", (0, 0, top + 0.5), (0.3, 0.3, 0.08), color="gold", bone="head")
    return top, sx

@builder
def mago_lowpoly_alt():
    top, sx = body(0.46, 0.32, 0.6, "purple", 0.3, "skin", leg_color="purple", arm_color="purple", boots="dark", belt="leather")
    add("cone", "hat", (0, 0, top + 0.64), (0.64, 0.64, 0.78), color="purple", bone="head", rot=(8, 0, 0))
    add("cyl", "hat_brim", (0, 0, top + 0.28), (1.0, 1.0, 0.05), v=14, color="purple", bone="head")
    add("cube", "hat_band", (0, 0, top + 0.34), (0.52, 0.52, 0.06), color="gold", bone="head")
    add("cone", "robe", (0, 0.04, 0.42), (0.78, 0.58, 0.66), color="purple", bone="hips", r2=0.36)
    add("cube", "robe_trim", (0, -0.2, 0.74), (0.12, 0.05, 0.6), color="gold", bone="spine", bevel=0.01)
    add("cyl", "staff", (sx + 0.05, -0.1, 0.75), (0.06, 0.06, 1.5), color="wood", bone="arm.R")
    add("cone", "crystal", (sx + 0.05, -0.1, 1.62), (0.2, 0.2, 0.42), v=6, color="teal", bone="arm.R", bevel=0)
    add("cone", "crystal_b", (sx + 0.05, -0.1, 1.3), (0.2, 0.2, 0.22), v=6, color="teal", bone="arm.R", bevel=0, rot=(180, 0, 0))
    add("cube", "pouch", (0.2, -0.2, 0.42), (0.12, 0.08, 0.12), color="leather", bone="hips")
    add("cube", "beard", (0, -0.24, top + 0.04), (0.2, 0.08, 0.22), color="white", bone="head")
    return top, sx

results = []
for name, fn in BUILDERS.items():
    if ONLY and name not in ONLY:
        continue
    top, sx = fn()
    results.append(finish(name, top, sx))
col.hide_viewport = True
result = {"built": results}
