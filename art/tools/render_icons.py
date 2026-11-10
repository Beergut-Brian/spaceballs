"""Render the upgrade card icons: one studio, 44 hero shots.

Run through art/tools/render_icons.sh (it also runs icon_post.py, which adds the ink outline and the
drop shadow and writes the 512 px PNGs to assets/sprites/upgrades/). Directly:
  blender -b --factory-startup -P art/tools/render_icons.py -- [--only a,b] [--raw DIR] [--size 768] [--samples 64]

Cards with gear (assets/gear/<id>.glb) are rendered from the real model at level 1 (trim_* pieces hidden), so the
card shows the thing the kicker will wear. Ball effects and curses have no gear: each gets a small vignette built
here in the same chunky style (VIGNETTES). Everything is scaled to the same bounding sphere, shot through the same
80 mm lens and lit by the same key / fill / rim lights, which follow the camera.
"""
import bpy, json, math, os, random, sys
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
GEAR = os.path.join(ROOT, "assets", "gear")
PAL = {c["key"]: c["hex"] for c in json.load(open(os.path.join(HERE, "..", "palettes", "cool_arcade.json")))["colours"]}
PAL.update(steel="#C3CCE0", gold="#FFC93C", white="#FFFFFF", frog="#3CC24A", bread="#F2B477", crust="#B9793A")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def opt(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


ONLY = [s for s in opt("--only", "").split(",") if s]
RAW = os.path.abspath(opt("--raw", os.path.join(ROOT, ".scratch", "icons_raw")))
SIZE = int(opt("--size", "768"))
SAMPLES = int(opt("--samples", "64"))

# Camera per icon: (azimuth, elevation) in degrees. Azimuth 0 looks at the front (the kicker faces -Y in
# Blender), positive swings round the kicker's left side, 180 is from behind (back gear shows its outside).
DEFAULT_VIEW = (-32, 20)
VIEW = {
    "big_boot": (-48, 18), "spring_shoes": (-52, 14), "rocket_boots": (-48, 18), "giant_foot": (-52, 22),
    "extra_shoes": (-50, 20), "honk_horn_shoes": (-82, 14), "pogo_legs": (-35, 12), "volcano_boots": (-48, 20),
    "jetpack": (148, 12), "super_cape": (150, 10), "kangaroo_tail": (110, 14), "slingshot_buddy": (155, 12),
    "turbo_fan": (150, 12), "wind_up_key": (160, 52),
    "propeller_cap": (-35, 14), "tiny_hat": (-30, 14), "thunder_hat": (-25, 8), "moon_gravity": (-25, 18),
    "sweatband": (-25, 24),
    "googly_eyes": (-18, 6), "mustache": (-16, 4), "opera_kick": (-20, 4),
    "foam_finger": (-28, 8), "rubber_chicken": (-60, 8), "balloon_animal_ball": (-70, 10),
    "super_strength": (-30, 16), "knee_pads": (-12, 10), "cannon_leg": (-40, 16), "lucky_sock": (-60, 10),
    "dad_strength": (-25, 22), "duck_floatie": (-40, 24), "coachs_whistle": (-20, 12),
    "running_start": (-25, 16), "tornado_spin": (-20, 14),
    "trampoline_tee": (-25, 24), "shoelaces_tied": (-22, 34), "banana_peel": (-25, 26),
    "too_much_lunch": (-30, 18), "kiss_the_frog": (-18, 10), "helium_ball": (-18, 6), "hiccups": (-15, 6),
    "butterfly": (-20, 8), "confetti_kick": (-10, 10), "sneeze": (-25, 18),
}

_mats = {}


def _lin(h):
    def f(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(f(int(h[i:i + 2], 16)) for i in (1, 3, 5))


def M(col, rough=0.45, glow=0.0, metal=0.0):
    """Soft plastic by palette key, the same recipe as the gear."""
    key = (col, rough, glow, metal)
    if key not in _mats:
        m = bpy.data.materials.new("icon_" + col)
        m.use_nodes = True
        p = m.node_tree.nodes["Principled BSDF"]
        rgb = _lin(PAL[col])
        p.inputs["Base Color"].default_value = (*rgb, 1.0)
        p.inputs["Roughness"].default_value = rough
        p.inputs["Metallic"].default_value = metal
        if glow:
            p.inputs["Emission Color"].default_value = (*rgb, 1.0)
            p.inputs["Emission Strength"].default_value = glow
        _mats[key] = m
    return _mats[key]


# --- chunky primitives for the vignettes ------------------------------------------------------------------------

def _rad(rot):
    return tuple(math.radians(a) for a in rot)


def _fin(col, s=(1, 1, 1), **m):
    o = bpy.context.object
    o.scale = s
    o.data.materials.append(M(col, **m))
    if o.type == "MESH":
        for p in o.data.polygons:
            p.use_smooth = len(p.vertices) <= 4
    return o


def ball(c, r, col, s=(1, 1, 1), rot=(0, 0, 0), **m):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=r, location=c, rotation=_rad(rot))
    return _fin(col, s, **m)


def cyl(p0, p1, r0, col, r1=None, **m):
    """A cylinder or cone from p0 to p1."""
    p0, p1 = Vector(p0), Vector(p1)
    bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=r0, radius2=r0 if r1 is None else r1,
                                    depth=(p1 - p0).length, location=(p0 + p1) / 2)
    o = _fin(col, **m)
    o.rotation_euler = (p1 - p0).to_track_quat("Z", "Y").to_euler()
    return o


def torus(c, R, r, col, rot=(0, 0, 0), s=(1, 1, 1), **m):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=64, minor_segments=20,
                                     location=c, rotation=_rad(rot))
    return _fin(col, s, **m)


def box(c, size, col, rot=(0, 0, 0), bev=0.06, **m):
    bpy.ops.mesh.primitive_cube_add(size=1, location=c, rotation=_rad(rot))
    o = bpy.context.object
    for v in o.data.vertices:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    b = o.modifiers.new("bevel", "BEVEL")
    b.width, b.segments = bev, 6
    o.data.materials.append(M(col, **m))
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def tube(pts, r, col, taper=None, cyc=False, c=(0, 0, 0), rot=(0, 0, 0), s=(1, 1, 1), **m):
    """A smooth round rope through pts (a NURBS curve); taper is a radius factor per point."""
    cu = bpy.data.curves.new("tube", "CURVE")
    cu.dimensions, cu.bevel_depth, cu.bevel_resolution, cu.resolution_u, cu.use_fill_caps = "3D", r, 6, 16, True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (*p, 1.0)
        sp.points[i].radius = taper[i] if taper else 1.0
    sp.use_cyclic_u, sp.use_endpoint_u, sp.order_u = cyc, not cyc, min(4, len(pts))
    o = bpy.data.objects.new("tube", cu)
    bpy.context.collection.objects.link(o)
    o.location, o.rotation_euler, o.scale = c, _rad(rot), s
    cu.materials.append(M(col, **m))
    return o


def star(c, r, col, n=4, inner=0.36, th=0.1, rot=(90, 0, 0), **m):
    """A fat sparkle, facing the front."""
    vs = [(math.sin(i * math.pi / n) * (r if i % 2 == 0 else r * inner),
           math.cos(i * math.pi / n) * (r if i % 2 == 0 else r * inner), 0) for i in range(2 * n)]
    me = bpy.data.meshes.new("star")
    me.from_pydata(vs, [], [list(range(2 * n))])
    o = bpy.data.objects.new("star", me)
    bpy.context.collection.objects.link(o)
    o.location, o.rotation_euler = c, _rad(rot)
    sol = o.modifiers.new("solid", "SOLIDIFY")
    sol.thickness, sol.offset = th, 0.0
    bev = o.modifiers.new("bevel", "BEVEL")
    bev.width, bev.segments = th * 0.3, 3
    me.materials.append(M(col, **m))
    return o


def face(c, r, mood="smile", yaw=0.0, k=1.0):
    """Eyes and a mouth on the front (-Y) of a sphere at c with radius r."""
    c = Vector(c)
    rz = Matrix.Rotation(math.radians(yaw), 3, "Z")

    def P(u, v, lift=1.0):
        return tuple(c + rz @ (Vector((u, -math.sqrt(max(0.0, 1.0 - u * u - v * v)), v)) * r * lift))

    for sx in (-1, 1):
        ball(P(sx * 0.3 * k, 0.2 * k, 0.99), r * 0.1 * k, "ink", (1, 0.5, 1.5), (0, 0, yaw), rough=0.2)
        ball(P(sx * 0.3 * k + 0.035 * k, 0.26 * k, 1.03), r * 0.035 * k, "white", (1, 0.5, 1), (0, 0, yaw))
        ball(P(sx * 0.56 * k, -0.08 * k, 0.99), r * 0.11 * k, "comb", (1, 0.3, 0.7), (0, 0, yaw + sx * 30))
    if mood == "smile":
        tube([P(u * k, (-0.2 - 0.2 * (1 - (u / 0.32) ** 2)) * k, 1.0) for u in (-0.32, -0.2, 0, 0.2, 0.32)],
             r * 0.04 * k, "ink")
    else:   # a round "oh!"
        ball(P(0, -0.26 * k, 0.99), r * 0.13 * k, "ink", (1, 0.4, 1.25), (0, 0, yaw))


def kickball(c, r, mood="smile", s=(1, 1, 1)):
    """The game ball as a character: white with a sky-blue band."""
    ball(c, r, "cloud", s, rough=0.35)
    torus(c, r * 0.985, r * 0.055, "sky3", (90, 0, 0), (s[0], s[2], 1))
    face(c, r, mood)


# --- vignettes: cards without gear ------------------------------------------------------------------------------

def v_helium_ball():
    kickball((0, 0, 0.4), 0.6)
    cyl((0, 0, -0.17), (0, 0, -0.33), 0.03, "cloud", 0.1)
    tube([(0, 0, -0.3), (0.1, 0, -0.5), (-0.1, 0, -0.72), (0.1, 0, -0.94), (-0.04, 0, -1.15), (0.0, 0, -1.3)],
         0.04, "comb")
    for x, z, r in ((-0.82, 0.75, 0.13), (0.86, 0.3, 0.1), (0.7, 1.0, 0.07)):
        ball((x, 0, z), r, "sky1", rough=0.15)


def v_trampoline_tee():
    torus((0, 0, 0), 0.8, 0.085, "sky3")
    cyl((0, 0, -0.03), (0, 0, 0.0), 0.74, "ink", rough=0.95)
    torus((0, 0, 0.0), 0.66, 0.03, "jeff_yellow")
    for a in (45, 135, 225, 315):
        x, y = 0.74 * math.cos(math.radians(a)), 0.74 * math.sin(math.radians(a))
        cyl((x, y, -0.02), (x * 1.08, y * 1.08, -0.42), 0.055, "steel", metal=0.6, rough=0.3)
    kickball((0, 0, 0.72), 0.5, "oh")


def v_confetti_kick():
    tip, mouth = Vector((-0.5, 0, -0.85)), Vector((0.05, 0, 0.0))
    cyl(tip, mouth, 0.05, "comb", 0.47)
    for t, col in ((0.38, "jeff_yellow"), (0.7, "sky2"), (1.0, "jeff_yellow")):
        p = tip.lerp(mouth, t)
        o = torus(p, 0.05 + 0.42 * t, 0.05, col)
        o.rotation_euler = (mouth - tip).to_track_quat("Z", "Y").to_euler()
    rnd = random.Random(11)
    cols = ["sky2", "jeff_yellow", "comb", "grass", "magma", "sky5"]
    d = (mouth - tip).normalized()
    for i in range(15):
        t = rnd.uniform(0.3, 1.0)
        p = mouth + d * t + Vector((rnd.uniform(-1, 1), rnd.uniform(-0.3, 0.3), rnd.uniform(-1, 1))) * (0.25 + 0.45 * t)
        if i % 3 == 0:
            ball(p, rnd.uniform(0.09, 0.13), cols[i % 6])
        else:
            box(p, (0.3, 0.2, 0.05), cols[i % 6], (rnd.uniform(0, 360), rnd.uniform(0, 360), rnd.uniform(0, 360)), 0.012)
    for sx, col in ((-1, "sky2"), (1, "comb")):
        tube([(sx * (0.2 + 0.1 * math.cos(a * 1.6)) + 0.3 * sx * a / 6, 0.1 * math.sin(a * 1.6), 0.3 + a * 0.13)
              for a in range(8)], 0.045, col, c=(0.2, 0, 0.1))
    star((0.85, -0.2, 0.2), 0.3, "jeff_yellow", 5, 0.5)


def v_banana_peel():
    cyl((0, 0, 0.3), (0.05, 0, 0.62), 0.17, "jeff_yellow", 0.1)
    cyl((0.05, 0, 0.61), (0.09, 0, 0.76), 0.085, "boots_brown", 0.06)
    for a in (25, 115, 205, 295):
        tube([(0.06, 0, 0.4), (0.3, 0, 0.52), (0.62, 0, 0.36), (0.86, 0, 0.06), (1.12, 0, 0.0)], 0.09, "jeff_yellow",
             taper=(1.3, 1.4, 1.3, 1.0, 0.45), rot=(0, 0, a), s=(1, 2.3, 1))
    for x, y in ((0.5, -0.5), (-0.62, 0.1), (0.1, 0.66)):
        ball((x, y, 0.33 if y > 0.5 else 0.2), 0.035, "boots_brown", (1, 1, 0.5))


def v_butterfly():
    cyl((0, 0, -0.45), (0, 0, 0.3), 0.1, "sky5")
    ball((0, 0, -0.45), 0.1, "sky5")
    ball((0, 0, 0.4), 0.17, "sky5")
    for sx in (-1, 1):
        tube([(sx * 0.05, 0, 0.5), (sx * 0.14, 0, 0.8), (sx * 0.34, 0, 0.95)], 0.028, "sky5")
        ball((sx * 0.36, 0, 0.96), 0.06, "sky5")
        ball((sx * 0.07, -0.15, 0.43), 0.035, "white")
        ball((sx * 0.62, 0.1, 0.3), 0.6, "comb", (1, 0.1, 0.85), (0, sx * -22, sx * 24))
        ball((sx * 0.48, 0.08, -0.42), 0.42, "sky2", (1, 0.12, 0.9), (0, sx * 20, sx * 24))
        ball((sx * 0.7, -0.03, 0.42), 0.2, "jeff_yellow", (1, 0.15, 1), (0, 0, sx * 24))
        ball((sx * 0.52, -0.0, -0.47), 0.13, "white", (1, 0.15, 1), (0, 0, sx * 24))


def v_hiccups():
    ball((0, 0, -0.25), 0.62, "sky1", rough=0.12)
    face((0, 0, -0.25), 0.62, "oh")
    ball((-0.28, -0.42, 0.08), 0.13, "white", (1, 0.4, 0.7), (0, 30, -30))
    for x, z, r in ((0.52, 0.62, 0.3), (-0.12, 0.98, 0.2), (-0.6, 0.6, 0.13), (0.36, 1.2, 0.1)):
        ball((x, 0, z), r, "sky2" if r > 0.25 else "sky1", rough=0.12)
        ball((x - r * 0.4, -r * 0.75, z + r * 0.4), r * 0.2, "white", (1, 0.4, 0.7), (0, 30, -30))


def v_kiss_the_frog():
    ball((0, 0, 0), 0.62, "frog", (1.12, 0.95, 0.86))
    ball((0, -0.2, -0.18), 0.45, "jeff_yellow", (1.05, 0.7, 0.72))
    for sx in (-1, 1):
        ball((sx * 0.34, -0.08, 0.47), 0.26, "frog")
        ball((sx * 0.34, -0.2, 0.5), 0.2, "white", rough=0.2)
        ball((sx * 0.34, -0.37, 0.5), 0.095, "ink", rough=0.2)
        ball((sx * 0.37, -0.45, 0.54), 0.03, "white")
        ball((sx * 0.6, -0.3, -0.47), 0.2, "frog", (1.3, 1.6, 0.5), (0, 0, sx * 25))
        ball((sx * 0.72, 0.15, -0.3), 0.26, "frog", (0.7, 1.2, 0.9))
    tube([(-0.42, -0.41, 0.14), (-0.22, -0.55, 0.05), (0, -0.59, 0.03), (0.22, -0.55, 0.05), (0.42, -0.41, 0.14)],
         0.028, "ink")
    # The lipstick kiss, big on the cheek.
    k = Vector((0.4, -0.52, -0.1))
    for dx, dz, r, s in ((-0.09, 0.06, 0.13, (1.25, 0.35, 0.6)), (0.09, 0.06, 0.13, (1.25, 0.35, 0.6)),
                         (0, -0.065, 0.13, (2.1, 0.35, 0.6))):
        ball(k + Vector((dx, 0.03 * abs(dx) / 0.1, dz)), r, "comb", s, (0, 0, 28), rough=0.25)
    star((-0.86, -0.3, 0.72), 0.2, "jeff_yellow", glow=0.4)
    star((0.9, -0.3, 0.25), 0.15, "jeff_yellow", glow=0.4)
    star((0.72, -0.3, 0.95), 0.11, "jeff_yellow", glow=0.4)


def v_shoelaces_tied():
    for sx in (-1, 1):
        x = sx * 0.36
        ball((x, 0, 0.0), 0.3, "cloud", (0.95, 1.9, 0.42))
        ball((x, 0.1, 0.16), 0.3, "sky3", (0.9, 1.6, 0.85))
        ball((x, -0.36, 0.08), 0.26, "cloud", (0.98, 0.95, 0.7))
        torus((x, 0.3, 0.4), 0.15, 0.06, "jeans_blue", s=(1, 1.3, 1))
        for y in (-0.16, 0.0):
            tube([(x - 0.15, y, 0.3), (x, y - 0.02, 0.42), (x + 0.15, y, 0.3)], 0.03, "comb")
        tube([(x, -0.05, 0.42), (x * 0.6, -0.2, 0.5), (x * 0.2, -0.2, 0.52), (0, -0.2, 0.5)], 0.04, "comb")
        tube([(0, 0, 0), (0.2, 0, 0.14), (0.42, 0, 0.1), (0.42, 0, -0.1), (0.2, 0, -0.14)], 0.045, "comb", cyc=True,
             c=(0, -0.2, 0.52), rot=(0, sx * -35 + (180 if sx < 0 else 0), 0))
        tube([(0, -0.22, 0.5), (sx * 0.1, -0.3, 0.36), (sx * 0.16, -0.42, 0.22)], 0.04, "comb")
    ball((0, -0.2, 0.52), 0.085, "comb")


def v_sneeze():
    box((-0.3, 0, -0.25), (1.0, 0.7, 0.55), "sky2", bev=0.08)
    ball((-0.3, 0, 0.03), 0.3, "ink", (1.1, 0.5, 0.06))
    cyl((-0.3, 0, 0.0), (-0.24, 0, 0.5), 0.26, "white", 0.05)
    ball((-0.2, 0, 0.5), 0.14, "white", (1.2, 0.8, 0.8))
    for x, z, r in ((0.5, 0.5, 0.4), (0.85, 0.3, 0.3), (0.9, 0.72, 0.3), (0.3, 0.85, 0.27), (0.62, 0.95, 0.28)):
        ball((x, 0.1, z), r, "white")
    rnd = random.Random(5)
    for i in range(6):
        a = math.radians(-58 + i * 30 + rnd.uniform(-6, 6))
        d = rnd.uniform(0.85, 1.0)
        ball((0.62 + d * math.cos(a), -0.05, 0.6 + d * math.sin(a)), rnd.uniform(0.09, 0.13), "grass", rough=0.15)


def v_too_much_lunch():
    z = -0.75
    layers = [("bread", 0.24, 1.0), ("frog", 0.07, 1.14), ("p2_red", 0.1, 0.94), ("jeff_yellow", 0.05, 1.1),
              ("crust", 0.16, 0.98), ("bread", 0.2, 1.0), ("frog", 0.07, 1.14), ("jeff_yellow", 0.05, 1.1),
              ("comb", 0.1, 0.94), ("bread", 0.26, 1.0)]
    for i, (col, h, w) in enumerate(layers):
        if col == "frog":
            tube([(0.56 * w * math.cos(a * math.pi / 6), 0.5 * w * math.sin(a * math.pi / 6),
                   0.045 * (-1) ** a) for a in range(12)], 0.07, col, cyc=True, c=(0, 0, z + h / 2))
            cyl((0, 0, z), (0, 0, z + h), 0.5, col)
        elif col == "jeff_yellow":
            box((0, 0, z + h / 2), (1.12, 1.12, h), col, (0, 0, 45), 0.02)
        elif col in ("p2_red", "comb"):
            for x, y in ((-0.25, -0.2), (0.28, -0.15), (0, 0.25)):
                cyl((x, y, z), (x, y, z + h), 0.3, col)
        else:
            box((0, 0, z + h / 2), (1.1 * w, 0.98 * w, h), col, bev=min(0.1, h * 0.45))
        z += h
    cyl((0, 0, z - 0.1), (0, 0, z + 0.32), 0.022, "boots_brown")
    ball((0, 0, z + 0.2), 0.13, "frog", rough=0.25)
    ball((0, -0.11, z + 0.2), 0.05, "p2_red")


VIGNETTES = {
    "helium_ball": v_helium_ball, "trampoline_tee": v_trampoline_tee, "confetti_kick": v_confetti_kick,
    "banana_peel": v_banana_peel, "butterfly": v_butterfly, "hiccups": v_hiccups,
    "kiss_the_frog": v_kiss_the_frog, "shoelaces_tied": v_shoelaces_tied, "sneeze": v_sneeze,
    "too_much_lunch": v_too_much_lunch,
}


# --- studio -----------------------------------------------------------------------------------------------------

def load_gear(id):
    bpy.ops.import_scene.gltf(filepath=os.path.join(GEAR, id + ".glb"))
    objs = bpy.data.objects
    for o in objs:
        if o.name.startswith("trim_"):   # level 2+ trim: the card shows the level 1 item
            o.hide_render = True
    bpy.context.view_layer.update()
    # Left and right pieces share the origin in the glb (the game hangs them on two bones): stand them apart.
    for stem in ("foot", "knee", "hand"):
        l, r = objs.get(stem + "_l"), objs.get(stem + "_r")
        if l and r and l.children and r.children:
            lo, hi = bounds([c for c in l.children_recursive if c.type == "MESH" and not c.hide_render])
            half = (hi.x - lo.x) * 0.56
            l.location.x += half
            r.location.x -= half


def bounds(objs):
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objs:
        for corner in o.bound_box:
            w = o.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def studio(id):
    sc = bpy.context.scene
    bpy.context.view_layer.update()
    seen = [o for o in bpy.data.objects if o.type in ("MESH", "CURVE") and not o.hide_render]
    lo, hi = bounds(seen)
    centre, radius = (lo + hi) / 2, (hi - lo).length / 2
    fit = Matrix.Scale(1.0 / radius, 4) @ Matrix.Translation(-centre)
    for o in bpy.data.objects:
        if o.parent is None:
            o.matrix_world = fit @ o.matrix_world

    az, el = (math.radians(a) for a in VIEW.get(id, DEFAULT_VIEW))
    back = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))   # towards the camera
    right = Vector((0, 0, 1)).cross(back).normalized() * -1.0
    up = back.cross(right) * -1.0
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 80
    cam.location = back * 5.2
    cam.rotation_euler = back.to_track_quat("Z", "Y").to_euler()
    sc.collection.objects.link(cam)
    sc.camera = cam

    # Soft key from the upper left, cool fill from the right, warm rim from behind: all relative to the camera.
    for name, pos, energy, size, col in (
            ("key", back * 3.2 - right * 3.0 + up * 3.6, 820, 4.0, (1.0, 0.97, 0.92)),
            ("fill", back * 3.5 + right * 4.0 + up * 0.3, 150, 6.0, (0.85, 0.92, 1.0)),
            ("rim", back * -3.5 + right * 2.2 + up * 3.2, 1150, 3.0, (1.0, 0.95, 0.85))):
        li = bpy.data.lights.new(name, "AREA")
        li.energy, li.size, li.color = energy, size, col
        o = bpy.data.objects.new(name, li)
        o.location = pos
        o.rotation_euler = pos.to_track_quat("Z", "Y").to_euler()
        sc.collection.objects.link(o)

    w = bpy.data.worlds.new("studio")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.8, 0.86, 1.0, 1.0)
    bg.inputs["Strength"].default_value = 0.36
    sc.world = w

    r = sc.render
    r.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 4
    r.film_transparent = True
    r.resolution_x = r.resolution_y = SIZE
    r.resolution_percentage = 100
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    r.filepath = os.path.join(RAW, id + ".png")
    bpy.ops.render.render(write_still=True)


def main():
    ids = sorted([f[:-4] for f in os.listdir(GEAR) if f.endswith(".glb")] + list(VIGNETTES))
    os.makedirs(RAW, exist_ok=True)
    for id in ids:
        if ONLY and id not in ONLY:
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        _mats.clear()
        if id in VIGNETTES:
            VIGNETTES[id]()
        else:
            load_gear(id)
        studio(id)
        print("ICON", id)


main()
