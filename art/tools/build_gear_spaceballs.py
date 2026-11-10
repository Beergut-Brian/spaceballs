"""Spaceballs gear: one .glb + one .json per wearable upgrade card, for the Jarling equipment slots.

    blender -b --factory-startup -P art/tools/build_gear_spaceballs.py -- [--outdir assets/gear] [--only jetpack,tiny_hat]

Format: openjar-characters docs/equipment.md (v0.1.0). Every piece is modelled in *slot space* for the
reference Jarling: Blender axes (Z up, front -Y, the character's left +X); the glTF export turns that
into Godot's +Y up, +Z front. Paired items have one node per slot (foot_l, foot_r). `trim*` nodes show
from level 2. `fx_flame*` / `fx_spin*` / `fx_orbit*` nodes are driven by the kicker (docs/contracts.md).
Look: chunky, smooth, soft plastic, 2-3 colours per item from art/palettes/cool_arcade.json.
"""
import sys, os, json, math, argparse
import bpy, bmesh
from mathutils import Vector, Matrix, Euler
from math import sin, cos, pi, radians

HERE = os.path.dirname(os.path.abspath(__file__))
PAL = {c["key"]: c["hex"] for c in json.load(open(os.path.join(HERE, "..", "palettes", "cool_arcade.json")))["colours"]}
# palette short names; steel and gold are the two off-palette neutrals every item may share
COL = dict(white=PAL["cloud"], dark=PAL["hat_black"], ink=PAL["ink"], slate=PAL["stone"], aqua=PAL["sky1"],
           cyan=PAL["sky2"], blue=PAL["sky3"], violet=PAL["sky4"], indigo=PAL["sky5"], teal=PAL["grass"],
           plum=PAL["topsoil"], peach=PAL["clay"], orange=PAL["magma"], pink=PAL["comb"], yellow=PAL["jeff_yellow"],
           jeans=PAL["jeans_blue"], brown=PAL["boots_brown"], steel="#C3CEE6", gold="#FFC53A")
_mats = {}


def _lin(h):
    def f(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(f(int(h[i:i + 2], 16)) for i in (1, 3, 5))


def mat(col, rough=0.45, glow=0.0, metal=0.0):
    """Flat soft-plastic material by palette name; glow > 0 is emissive."""
    key = (col, rough, glow, metal)
    if key not in _mats:
        m = bpy.data.materials.new("gear_%s%s" % (col, "_glow" if glow else ("_shiny" if rough < 0.3 else "")))
        m.use_nodes = True
        p = m.node_tree.nodes["Principled BSDF"]
        rgb = _lin(COL[col])
        p.inputs["Base Color"].default_value = (*rgb, 1.0)
        p.inputs["Roughness"].default_value = rough
        p.inputs["Metallic"].default_value = metal
        if glow:
            p.inputs["Emission Color"].default_value = (*rgb, 1.0)
            p.inputs["Emission Strength"].default_value = glow
        _mats[key] = m
    return _mats[key]


def R(x=0.0, y=0.0, z=0.0):
    return Euler((radians(x), radians(y), radians(z))).to_matrix()


def _xf(bm, c, rot):
    m = Matrix.Translation(c) @ (rot.to_4x4() if rot else Matrix.Identity(4))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    for f in bm.faces:
        f.smooth = True
    return bm


def _skin(bm, rows, close=True):
    for a, b in zip(rows, rows[1:]):
        n = max(len(a), len(b))
        for j in range(n if close else n - 1):
            k = (j + 1) % n
            q = list(dict.fromkeys([a[j % len(a)], a[k % len(a)], b[k % len(b)], b[j % len(b)]]))
            if len(q) >= 3:
                try:
                    bm.faces.new(q)
                except ValueError:
                    pass


def sq(c, r, e1=1.0, e2=1.0, rot=None, segs=28, rings=14, floor=None):
    """Superellipsoid: e = 1 round, e < 1 boxy (0.3 = rounded box), e2 squares the outline seen from above."""
    r = (r, r, r) if isinstance(r, (int, float)) else r
    f = lambda w, e: math.copysign(abs(w) ** e, w)
    bm = bmesh.new()
    rows = []
    for i in range(rings + 1):
        v = -pi / 2 + pi * i / rings
        cv, sv = f(cos(v), e1), f(sin(v), e1)
        z = r[2] * sv
        if floor is not None:
            z = max(z, floor - c[2])
        if i in (0, rings):
            rows.append([bm.verts.new((0, 0, z))])
        else:
            rows.append([bm.verts.new((r[0] * cv * f(cos(u), e2), r[1] * cv * f(sin(u), e2), z))
                         for u in (2 * pi * j / segs for j in range(segs))])
    _skin(bm, rows)
    return _xf(bm, c, rot)


def rev(prof, c=(0, 0, 0), rot=None, segs=28, sx=1.0, sy=1.0, e=1.0):
    """Lathe around Z: prof = [(z, radius)], radius 0 closes an end. sx/sy stretch, e < 1 squares it."""
    f = lambda w: math.copysign(abs(w) ** e, w)
    bm = bmesh.new()
    rows = []
    for z, rad in prof:
        if rad <= 1e-6:
            rows.append([bm.verts.new((0, 0, z))])
        else:
            rows.append([bm.verts.new((rad * sx * f(cos(u)), rad * sy * f(sin(u)), z)) for u in (2 * pi * j / segs for j in range(segs))])
    _skin(bm, rows)
    return _xf(bm, c, rot)


def cyl(p0, p1, r0, r1=None, bev=0.25, segs=24):
    """Rounded cylinder / cone between two points."""
    r1 = r0 if r1 is None else r1
    p0, p1 = Vector(p0), Vector(p1)
    L = (p1 - p0).length
    b0, b1 = min(bev * r0, L * 0.3), min(bev * r1, L * 0.3)
    prof = [(0, 0), (0, max(r0 - b0, 1e-4) * 0.6), (0, max(r0 - b0, 1e-4)), (b0 * 0.3, r0 - b0 * 0.3), (b0, r0),
            (L - b1, r1), (L - b1 * 0.3, r1 - b1 * 0.3), (L, max(r1 - b1, 1e-4)), (L, max(r1 - b1, 1e-4) * 0.6), (L, 0)]
    rot = Vector((0, 0, 1)).rotation_difference((p1 - p0).normalized()).to_matrix()
    return rev(prof, p0, rot, segs)


def smooth(pts, n=6, cyc=False):
    """Catmull-Rom through the points."""
    P = [Vector(p) for p in pts]
    m = len(P)
    out = []
    for i in range(m if cyc else m - 1):
        p0, p1, p2, p3 = (P[(i + k) % m] if cyc else P[min(max(i + k, 0), m - 1)] for k in (-1, 0, 1, 2))
        for s in range(n):
            t = s / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    if not cyc:
        out.append(P[-1])
    return out


def tube(pts, r, cyc=False, segs=12, sm=0):
    """Round tube along a path. r is a radius or a function of 0..1 along the path."""
    P = smooth(pts, sm, cyc) if sm else [Vector(p) for p in pts]
    n = len(P)
    rf = r if callable(r) else (lambda t: r)
    bm = bmesh.new()
    rows = []
    up = None
    for i, p in enumerate(P):
        a, b = P[(i - 1) % n] if (cyc or i > 0) else p, P[(i + 1) % n] if (cyc or i < n - 1) else p
        t = (b - a).normalized()
        if up is None:
            up = t.orthogonal().normalized()
        up = (up - t * up.dot(t)).normalized()
        side = t.cross(up)
        rad = max(rf(i / max(n - 1, 1)), 1e-4)
        ring = [bm.verts.new(p + (up * cos(u) + side * sin(u)) * rad) for u in (2 * pi * j / segs for j in range(segs))]
        if i == 0 and not cyc:
            rows.append([bm.verts.new(p - t * rad * 0.7)])
            rows.append([bm.verts.new(p - t * rad * 0.5 + (v.co - p) * 0.7) for v in ring])
        rows.append(ring)
        if i == n - 1 and not cyc:
            rows.append([bm.verts.new(p + t * rad * 0.5 + (v.co - p) * 0.7) for v in ring])
            rows.append([bm.verts.new(p + t * rad * 0.7)])
    if cyc:
        rows.append(rows[0])
    _skin(bm, rows)
    return _xf(bm, (0, 0, 0), None)


def loop(c, rx, ry, r, n=40, e=1.0, rot=None, segs=12):
    """A ring (torus) in the XY plane around c; e < 1 squares it like the torso."""
    f = lambda w: math.copysign(abs(w) ** e, w)
    bm = tube([(rx * f(cos(a)), ry * f(sin(a)), 0) for a in (2 * pi * i / n for i in range(n))], r, cyc=True, segs=segs)
    return _xf(bm, c, rot)


def coil(c, rad, h, turns, wire, rad1=None, rot=None, per=18):
    """A coil spring rising along Z from c."""
    rad1 = rad if rad1 is None else rad1
    n = int(turns * per)
    pts = [((rad + (rad1 - rad) * i / n) * cos(2 * pi * i / per), (rad + (rad1 - rad) * i / n) * sin(2 * pi * i / per), h * i / n) for i in range(n + 1)]
    return _xf(tube(pts, wire, segs=10), c, rot)


def sheet(fn, nu, nv, th):
    """A thick sheet from fn(u, v) -> point, u and v in 0..1."""
    bm = bmesh.new()
    top = [[bm.verts.new(fn(i / nu, j / nv)) for i in range(nu + 1)] for j in range(nv + 1)]
    _skin(bm, top, close=False)
    bm.normal_update()
    bot = [[bm.verts.new(v.co - v.normal * th) for v in row] for row in top]
    _skin(bm, bot, close=False)
    edge = [r[0] for r in top] + top[-1][1:] + [r[-1] for r in reversed(top[:-1])] + list(reversed(top[0][1:-1]))
    edge2 = [r[0] for r in bot] + bot[-1][1:] + [r[-1] for r in reversed(bot[:-1])] + list(reversed(bot[0][1:-1]))
    _skin(bm, [edge, edge2])
    return _xf(bm, (0, 0, 0), None)


def prism(poly, depth, c=(0, 0, 0), rot=None, bev=0.004):
    """A flat-shaded slab: poly is [(x, z)], extruded along Y (bolts, stars, arrows)."""
    bm = bmesh.new()
    a = [bm.verts.new((x, -depth / 2, z)) for x, z in poly]
    b = [bm.verts.new((x, depth / 2, z)) for x, z in poly]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    _skin(bm, [a, b])
    if bev:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bev, segments=2, affect="EDGES", profile=0.5)
    _xf(bm, c, rot)
    for f in bm.faces:
        f.smooth = False
    return bm


def star(r0, r1, n=5):
    return [((r0 if i % 2 == 0 else r1) * sin(pi * i / n), (r0 if i % 2 == 0 else r1) * cos(pi * i / n)) for i in range(2 * n)]


def moved(bm, c=(0, 0, 0), rot=None, s=1.0):
    """Move / turn / scale a finished part."""
    bmesh.ops.transform(bm, matrix=Matrix.Translation(c) @ (rot.to_4x4() if rot else Matrix.Identity(4)) @ Matrix.Scale(s, 4), verts=bm.verts)
    return bm


def group(parts, c=(0, 0, 0), rot=None, s=1.0, mirror=False):
    """Transform a list of (bmesh, material) parts together; mirror flips X."""
    for bm, _ in parts:
        if mirror:
            bmesh.ops.transform(bm, matrix=Matrix.Scale(-1, 4, (1, 0, 0)), verts=bm.verts)
        moved(bm, c, rot, s)
    return parts


def empty(name, parent=None, loc=(0, 0, 0), rot=None):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    if rot:
        e.rotation_euler = rot.to_euler()
    return e


def obj(name, parts, parent, at=(0, 0, 0)):
    """Join (bmesh, material) parts into one mesh object whose origin is `at` (parts stay where they were built)."""
    out = bmesh.new()
    mats = []
    for pbm, m in parts:
        bmesh.ops.recalc_face_normals(pbm, faces=pbm.faces)
        if m not in mats:
            mats.append(m)
        vmap = {v: out.verts.new(v.co - Vector(at)) for v in pbm.verts}
        for f in pbm.faces:
            try:
                nf = out.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf.material_index = mats.index(m)
            nf.smooth = f.smooth
        pbm.free()
    out.normal_update()
    me = bpy.data.meshes.new(name)
    out.to_mesh(me)
    out.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    ob.location = at
    return ob


def flame(name, parent, at, length=0.09, r=0.03, rot=None):
    """An fx_flame node: origin at the nozzle, burning along -Z unless turned."""
    parts = [(rev([(0, 0), (-0.01, r), (-length * 0.45, r * 0.8), (-length, 0)], rot=rot, segs=16), mat("orange", 0.6, 4.0)),
             (rev([(-0.004, 0), (-0.012, r * 0.55), (-length * 0.3, r * 0.45), (-length * 0.62, 0)], rot=rot, segs=12), mat("yellow", 0.6, 6.0))]
    for bm, _ in parts:
        moved(bm, at)
    return obj(name, parts, parent, at)


# The two metals: only lightly metallic, so they stay bright without sky reflections.
GOLD = lambda: mat("gold", 0.32, 0.0, 0.3)
STEEL = lambda: mat("steel", 0.3, 0.0, 0.35)
ITEMS = {}


def item(name, slots, replaces=(), **extra):
    """Register a builder: fn(node_for_slot...) fills the slot nodes."""
    def deco(fn):
        ITEMS[fn.__name__] = dict(name=name, slots=list(slots), replaces_body_part=list(replaces), fn=fn, **extra)
        return fn
    return deco


FEET, HANDS, KNEES = ("foot_l", "foot_r"), ("hand_l", "hand_r"), ("knee_l", "knee_r")
SIDES = (("l", 1), ("r", -1))

# ------------------------------------------------------------------------------------------ feet
# Foot slot: origin on the ground under the ankle (ankle z 0.075, leg radius 0.05). Toe is -Y.

def shoe(body, sole, toe=None, L=0.128, H=0.06, W=0.074):
    parts = [(sq((0, -0.035, H), (W, L, H), 0.8, 0.85, floor=0.022), mat(body)),
             (sq((0, -0.038, 0.022), (W + 0.006, L + 0.008, 0.022), 0.45, 0.85, floor=0.0), mat(sole, 0.7))]
    if toe:
        parts.append((sq((0, -0.035 - L * 0.55, H * 0.9), (W * 0.9, L * 0.5, H * 0.72), floor=0.03), mat(toe)))
    return parts


def shaft(col, cuff, top=0.15, r=0.078):
    return [(rev([(0.03, 0), (0.03, r * 0.94), (top - 0.03, r), (top, r), (top, 0)]), mat(col)),
            (loop((0, 0, top), r + 0.002, r + 0.002, 0.014), mat(cuff))]


@item("Rocket Boots", FEET, FEET)
def rocket_boots(n, side, s):
    parts = shoe("white", "dark", "orange") + shaft("white", "orange")
    parts += [(cyl((0, 0.06, 0.1), (0, 0.105, 0.045), 0.03, 0.046), STEEL()),          # nozzle bell
              (sq((0, 0.108, 0.041), (0.036, 0.012, 0.036), rot=R(40)), mat("cyan", 0.5, 3.0))]            # glowing throat
    for a in (-1, 0, 1):   # three swept fins
        parts.append((prism([(0, 0.06), (0.062, -0.035), (0.062, -0.075), (0, -0.03)], 0.014, (a * 0.07, 0.03 + (0.03 if a == 0 else 0), 0.105),
                            R(0, 0, 90 - a * 62)), mat("orange")))
    obj("rocket_boot_" + side, parts, n)
    flame("fx_flame_" + side, n, (0, 0.112, 0.036), 0.1, 0.034, R(-50))
    obj("trim_rocket_" + side, [(loop((0, 0, 0.1), 0.081, 0.081, 0.008), GOLD())], n)


@item("Spring Shoes", FEET, FEET)
def spring_shoes(n, side, s):
    parts = group(shoe("cyan", "white", "white", H=0.05), (0, 0, 0.062))
    parts += [(coil((0, -0.03, 0.012), 0.05, 0.062, 2.6, 0.011), STEEL()),
              (sq((0, -0.03, 0.01), (0.07, 0.085, 0.012), 0.5), mat("pink")),
              (loop((0, 0, 0.165), 0.066, 0.066, 0.016), mat("pink")),
              (cyl((0, 0, 0.09), (0, 0, 0.165), 0.064), mat("cyan"))]
    obj("spring_shoe_" + side, parts, n)
    obj("trim_spring_" + side, [(loop((0, -0.035, 0.1), 0.082, 0.136, 0.007), GOLD())], n)


@item("Big Boot", FEET, FEET, level_up={"max": 3, "scale_step": 0.08})
def big_boot(n, side, s):
    parts = shoe("brown", "dark", "steel", L=0.15, H=0.075, W=0.088) + shaft("brown", "orange", 0.19, 0.09)
    for y in (-0.15, -0.09, -0.03, 0.03, 0.09):   # chunky tread
        parts.append((sq((0, y - 0.015, 0.012), (0.099, 0.022, 0.016), 0.4, 0.4), mat("dark", 0.7)))
    for z in (0.085, 0.115, 0.145):
        parts.append((tube([(-0.04, -0.082, z), (0, -0.095, z + 0.006), (0.04, -0.082, z)], 0.008), mat("orange")))
    obj("big_boot_" + side, group(parts, s=1.18), n)
    obj("trim_bigboot_" + side, [(loop((0, 0, 0.15), 0.11, 0.11, 0.009), GOLD())], n)


@item("Giant Foot", ["foot_r"], ["foot_r"], level_up={"max": 3, "scale_step": 0.1})
def giant_foot(n, side, s):
    parts = [(sq((-0.05, -0.12, 0.085), (0.15, 0.25, 0.085), 0.85, 0.9, floor=0.0), mat("peach", 0.55)),
             (cyl((0, 0, 0.05), (0, 0, 0.13), 0.075), mat("peach", 0.55))]
    for i, (x, r) in enumerate(((0.07, 0.062), (-0.02, 0.05), (-0.085, 0.045), (-0.14, 0.04), (-0.185, 0.034))):
        y = -0.36 + abs(i - 0.5) * 0.028
        parts += [(sq((x, y, r * 0.95), r, floor=0.0), mat("peach", 0.55)),
                  (sq((x, y - r * 0.55, r * 1.5), (r * 0.62, r * 0.5, r * 0.4), rot=R(-35)), mat("pink", 0.3))]
    obj("giant_foot", parts, n)
    obj("trim_giant_foot", [(loop((0, 0, 0.13), 0.078, 0.078, 0.012), GOLD())], n)


@item("Extra Shoes", FEET, FEET)
def extra_shoes(n, side, s):
    # A sneaker giving a smaller sneaker a piggyback: two clear shoe shapes, one silhouette.
    parts = shoe("pink", "white", "white") + [(loop((0, 0, 0.112), 0.056, 0.056, 0.013), mat("white"))]
    parts += [(tube([(-0.034, y, z), (0, y - 0.004, z + 0.012), (0.034, y, z)], 0.007, sm=3), mat("white")) for y, z in ((-0.058, 0.108), (-0.085, 0.1))]
    rider = shoe("cyan", "white", "yellow") + [(loop((0, 0, 0.112), 0.054, 0.054, 0.015), mat("white")), (sq((0, 0, 0.116), (0.044, 0.044, 0.008)), mat("ink"))]
    parts += group(rider, (0, -0.112, 0.098), R(-12), 0.62)
    obj("extra_shoe_" + side, parts, n)
    obj("trim_extra_" + side, [(prism(star(0.03, 0.013), 0.01, (s * 0.079, -0.035, 0.062), R(0, 0, 90)), GOLD())], n)


@item("Honk Horn Shoes", FEET, FEET)
def honk_horn_shoes(n, side, s):
    parts = shoe("yellow", "white", L=0.14) + [(sq((0, -0.15, 0.07), (0.088, 0.09, 0.07), floor=0.02), mat("pink")),
                                               (loop((0, 0, 0.112), 0.056, 0.056, 0.013), mat("white"))]
    horn = [(rev([(0, 0), (0.0, 0.05), (0.012, 0.052), (0.05, 0.02), (0.1, 0.014), (0.1, 0)]), GOLD()),
            (sq((0, 0, 0.125), 0.036), mat("indigo")), (sq((0, 0, 0.004), (0.04, 0.04, 0.006)), mat("dark"))]
    parts += group(horn, (s * 0.03, -0.215, 0.165), R(105, 0, s * 20))
    obj("honk_shoe_" + side, parts, n)
    obj("trim_honk_" + side, [(loop((0, -0.038, 0.045), 0.081, 0.146, 0.007), GOLD())], n)


@item("Pogo Legs", FEET, FEET)
def pogo_legs(n, side, s):
    parts = [(cyl((0, 0, 0.085), (0, 0, 0.19), 0.07), mat("indigo")), (loop((0, 0, 0.185), 0.07, 0.07, 0.014), mat("yellow")),
             (loop((0, 0, 0.095), 0.07, 0.07, 0.014), mat("yellow")), (cyl((0, 0, 0.02), (0, 0, 0.1), 0.022), STEEL()),
             (coil((0, 0, 0.03), 0.042, 0.055, 3.2, 0.009), STEEL()), (sq((0, 0, 0.024), (0.05, 0.05, 0.026), floor=0.0), mat("pink")),
             (cyl((-s * 0.12, 0, 0.14), (s * 0.02, 0, 0.14), 0.016), mat("yellow"))]                       # foot peg
    obj("pogo_leg_" + side, parts, n)
    obj("trim_pogo_" + side, [(loop((0, 0, 0.14), 0.073, 0.073, 0.008), GOLD())], n)


@item("Volcano Boots", FEET, FEET)
def volcano_boots(n, side, s):
    # Dark rock with glowing cracks; the leg stands in the crater.
    rock, lava, hot = mat("dark", 0.9), mat("orange", 0.5, 0.9), mat("orange", 0.5, 1.4)
    prof = [(0.02, 0.108), (0.07, 0.1), (0.13, 0.082), (0.185, 0.068)]
    def rad(z):
        for (z0, r0), (z1, r1) in zip(prof, prof[1:]):
            if z <= z1:
                return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
        return prof[-1][1]
    parts = [(sq((0, -0.035, 0.062), (0.082, 0.136, 0.062), 0.8, 0.85, floor=0.02), rock),
             (sq((0, -0.038, 0.02), (0.09, 0.146, 0.022), 0.45, 0.85, floor=0.0), mat("ink", 0.9)),
             (rev([(0.02, 0)] + prof + [(0.2, 0.066), (0.193, 0.052), (0.18, 0.048), (0.18, 0)], sy=1.05), rock),
             (sq((0, 0, 0.184), (0.054, 0.056, 0.012)), lava)]
    for x, y, z, r in ((0.085, 0.045, 0.04, 0.04), (-0.08, 0.06, 0.035, 0.036), (0.02, 0.105, 0.04, 0.038), (-0.05, -0.16, 0.035, 0.034)):   # crags
        parts.append((sq((x, y, z), (r, r, r * 1.15), 0.7, 0.7, floor=0.0), rock))
    for i, a0 in enumerate((-100, -35, 40, 115, 190)):   # cracks down the cone
        pts = []
        for j in range(7):
            z = 0.176 - 0.022 * j
            a = radians(a0) + (0.2 if j % 2 else -0.2) * (0.5 if j in (0, 6) else 1.0)
            pts.append(((rad(z) + 0.003) * cos(a), (rad(z) + 0.003) * 1.05 * sin(a), z))
        parts.append((tube(pts[:7 - i % 2 * 2], lambda t: 0.0085 - 0.004 * t), lava))
    parts.append((tube([(0.03 * (1 if j % 2 else -1) * (0 if j in (0, 5) else 1), -0.045 - 0.024 * j,
                         0.006 + 0.062 * (1 + max(0.0, 1 - (0.03 / 0.082) ** 2 - ((0.01 + 0.024 * j) / 0.136) ** 2) ** 0.5)) for j in range(6)], 0.0085), lava))   # and across the toe
    for a, ln in ((-70, 0.07), (20, 0.05), (150, 0.085)):   # lava spilling over the rim
        d = Vector((cos(radians(a)), 1.05 * sin(radians(a)), 0))
        parts.append((tube([d * 0.058 + Vector((0, 0, 0.196)), d * 0.07 + Vector((0, 0, 0.2)), d * (rad(0.19 - ln * 0.5) + 0.006) + Vector((0, 0, 0.19 - ln * 0.5)),
                            d * (rad(0.19 - ln) + 0.008) + Vector((0, 0, 0.19 - ln))], lambda t: 0.011 + 0.007 * t, sm=3), hot))
    obj("volcano_boot_" + side, parts, n)
    obj("trim_volcano_" + side, [(loop((0, 0, 0.2), 0.067, 0.07, 0.008), GOLD())], n)


# ------------------------------------------------------------------------------------------ back
# Back slot: origin on the back surface at shoulder height, behind is +Y, torso half-width 0.152,
# waist at z -0.22, ground at z -0.5. The head is above and in front: stay behind y 0.14 above z 0.05.

@item("Jetpack", ["back"], ["tail"])
def jetpack(n, side, s):
    parts = [(sq((0, 0.04, -0.1), (0.1, 0.045, 0.13), 0.5, 0.5), mat("indigo"))]
    for x in (-0.068, 0.068):
        parts += [(cyl((x, 0.095, -0.23), (x, 0.095, 0.0), 0.058), mat("white", 0.35)), (sq((x, 0.095, 0.005), (0.056, 0.056, 0.085), floor=0.005), mat("orange")),
                  (loop((x, 0.095, -0.07), 0.06, 0.06, 0.009), mat("cyan")), (loop((x, 0.095, -0.15), 0.06, 0.06, 0.009), mat("cyan")),
                  (cyl((x, 0.095, -0.22), (x, 0.095, -0.275), 0.03, 0.048), mat("dark", 0.35, 0, 0.3)),
                  (sq((x, 0.095, -0.272), (0.04, 0.04, 0.008)), mat("cyan", 0.5, 3.0)),
                  (tube([(x, 0.0, -0.03), (x, -0.01, 0.045), (x * 1.05, -0.06, 0.09), (x * 1.08, -0.14, 0.082), (x * 1.08, -0.215, 0.03), (x * 1.06, -0.235, -0.04)], 0.013, sm=3), mat("dark", 0.7))]
    parts.append((sq((0, 0.088, -0.1), (0.022, 0.02, 0.03)), mat("pink", 0.5, 2.0)))
    obj("jetpack_body", parts, n)
    for sd, x in (("l", 0.068), ("r", -0.068)):
        flame("fx_flame_" + sd, n, (x, 0.095, -0.275), 0.15, 0.04)
    obj("trim_jetpack", [(loop((x, 0.095, -0.11), 0.061, 0.061, 0.008), GOLD()) for x in (-0.068, 0.068)], n)


@item("Super Cape", ["back"], ["tail"], spring={"node": "cape_pivot", "stiffness": 40.0, "damping": 5.0, "gain": 0.14, "rest_deg": 5.0, "max_deg": 48.0})
def super_cape(n, side, s):
    pivot = empty("cape_pivot", n, (0, 0.006, 0.035))
    def pt(u, v, off=0.0):
        x = u * 2 - 1
        w = 0.125 + 0.105 * v
        return (x * w, 0.004 + 0.07 * v - 0.055 * x * x * (1 - 0.6 * v) + 0.016 * v * sin(x * pi * 3.5) + off,
                -0.4 * v - 0.02 * (1 - cos(x * pi * 3.5)) * v ** 3)
    obj("cape_cloth", [(sheet(pt, 28, 16, 0.012), mat("indigo", 0.6))], pivot)
    top = [pt(u, 0.02, 0.004) for u in (i / 15 for i in range(16))]
    obj("cape_collar", [(tube(top, 0.013), mat("yellow")), (sq(top[0], 0.022), mat("yellow")), (sq(top[-1], 0.022), mat("yellow")),
                        (prism(star(0.075, 0.033), 0.012, pt(0.5, 0.42, 0.012), R(-8)), mat("yellow", 0.4, 0.6))], pivot)
    obj("trim_cape_hem", [(tube([pt(i / 40, 0.985, 0.008) for i in range(41)], 0.008), GOLD())], pivot)


@item("Kangaroo Tail", ["back"], ["tail"])
def kangaroo_tail(n, side, s):
    path = [(0, -0.01, -0.2), (0, 0.09, -0.27), (0, 0.2, -0.4), (0, 0.33, -0.455), (0, 0.45, -0.42), (0, 0.52, -0.33)]
    obj("kangaroo_tail", [(tube(path, lambda t: 0.085 - 0.06 * t, sm=5, segs=16), mat("brown", 0.6)),
                          (tube(smooth(path, 5)[-7:], lambda t: 0.036 - 0.012 * t, segs=16), mat("peach", 0.6)),
                          (loop((0, 0.0, -0.2), 0.17, 0.14, 0.02, e=0.75), mat("orange"))], n)
    obj("trim_tail", [(loop((0, 0.33, -0.455), 0.055, 0.02, 0.01, rot=R(90, 0, 90)), GOLD())], n)


@item("Slingshot Buddy", ["back"], ["tail"])
def slingshot_buddy(n, side, s):
    wood, band = mat("brown", 0.6), mat("pink")
    parts = [(cyl((0, 0.1, -0.22), (0, 0.12, 0.06), 0.036), wood), (loop((0, 0.105, -0.13), 0.038, 0.038, 0.01, rot=R(4)), mat("yellow"))]
    for x in (-1, 1):
        tip = Vector((x * 0.27, 0.19, 0.43))
        parts += [(tube([(0, 0.12, 0.05), (x * 0.14, 0.13, 0.14), (x * 0.24, 0.17, 0.3), tip], 0.03, sm=5), wood), (sq(tip, 0.04), mat("yellow")),
                  (tube([tip, (x * 0.14, 0.29, 0.3), (x * 0.04, 0.34, 0.24)], 0.012, sm=4), band),
                  (sq((x * 0.03, 0.085, -0.04), 0.03), mat("white", 0.3)), (sq((x * 0.034, 0.063, -0.045), 0.014), mat("ink", 0.3)),
                  (tube([(x * 0.03, 0.1, -0.2), (x * 0.1, 0.02, -0.12), (x * 0.1, 0.0, 0.0)], 0.012, sm=3), mat("dark", 0.7))]
    parts.append((sq((0, 0.345, 0.235), (0.06, 0.022, 0.045)), mat("yellow")))
    obj("slingshot", parts, n)
    obj("trim_slingshot", [(sq((0, 0.365, 0.235), 0.035), GOLD())], n)


@item("Turbo Fan", ["back"], ["tail"])
def turbo_fan(n, side, s):
    c = (0, 0.12, -0.08)
    parts = [(loop(c, 0.21, 0.21, 0.026, rot=R(90)), mat("white", 0.35)), (cyl((0, 0.0, -0.08), (0, 0.11, -0.08), 0.05), mat("indigo")),
             (sq((0, 0.045, -0.08), (0.13, 0.04, 0.15), 0.5, 0.5), mat("indigo"))]
    for a in (0, 60, 120):
        d = Vector((cos(radians(a)), 0, sin(radians(a)))) * 0.21
        parts.append((tube([Vector(c) + d + Vector((0, 0.05, 0)), Vector(c) - d + Vector((0, 0.05, 0))], 0.008), mat("slate")))
    obj("fan_cage", parts, n)
    spin = empty("fx_spin_fan", n, (0, 0.125, -0.08), R(90))
    blades = [(sq((0.1 * cos(radians(a)), 0.1 * sin(radians(a)), 0), (0.095, 0.045, 0.01), rot=R(0, 0, a) @ R(28)), mat("cyan")) for a in (0, 90, 180, 270)]
    obj("fan_blades", blades + [(sq((0, 0, 0), (0.04, 0.04, 0.035)), mat("orange"))], spin)
    obj("trim_fan", [(loop(c, 0.238, 0.238, 0.008, rot=R(90)), GOLD())], n)


@item("Wind-Up Key", ["back"], ["tail"])
def wind_up_key(n, side, s):
    obj("key_socket", [(cyl((0, -0.005, -0.08), (0, 0.035, -0.08), 0.06), mat("indigo")), (loop((0, 0.03, -0.08), 0.06, 0.06, 0.012, rot=R(90)), mat("pink"))], n)
    spin = empty("fx_spin_key", n, (0, 0.03, -0.08), R(-90))
    parts = [(cyl((0, 0, 0), (0, 0, 0.17), 0.026), GOLD()), (sq((0, 0, 0.19), (0.05, 0.03, 0.035)), GOLD())]
    for x in (-1, 1):
        parts.append((loop((x * 0.15, 0, 0.19), 0.105, 0.085, 0.03, rot=R(90), segs=14), GOLD()))
    obj("key", parts, spin)
    obj("trim_key", [(sq((x * 0.15, 0, 0.19), 0.04), mat("pink", 0.4, 1.5)) for x in (-1, 1)], spin)


# ------------------------------------------------------------------------------------------ head
# Head slot: origin at the head centre, head radius 0.235, crown (top of hair or hood) 0.27 above.

def dome(col, z0=0.08, r=0.262, top=0.305):
    return (rev([(z0, r - 0.012), (z0 + 0.02, r), (0.17, r * 0.985), (0.25, r * 0.86), (0.29, r * 0.6), (top, r * 0.25), (top + 0.003, 0)], segs=40), mat(col))


@item("Propeller Cap", ["head"], ["headwear"])
def propeller_cap(n, side, s):
    obj("cap", [dome("blue"), (loop((0, 0, 0.09), 0.264, 0.264, 0.02), mat("yellow")),
                (sq((0, -0.3, 0.085), (0.19, 0.14, 0.016), rot=R(-8)), mat("pink")), (sq((0, 0, 0.31), 0.035), mat("yellow")),
                (cyl((0, 0, 0.31), (0, 0, 0.4), 0.012), STEEL())], n)
    spin = empty("fx_spin_prop", n, (0, 0, 0.4))
    obj("propeller", [(sq((x * 0.11, 0, 0), (0.115, 0.04, 0.009), rot=R(x * 22)), mat(c)) for x, c in ((-1, "pink"), (1, "yellow"))]
        + [(sq((0, 0, 0.004), 0.026), mat("orange"))], spin)
    obj("trim_cap", [(prism(star(0.045, 0.02), 0.012, (0, -0.262, 0.17), R(-12)), GOLD())], n)


@item("Tiny Hat", ["head"], ["headwear"])
def tiny_hat(n, side, s):
    parts = [(cyl((0, 0, 0), (0, 0, 0.012), 0.085, bev=0.5), mat("dark")), (cyl((0, 0, 0.004), (0, 0, 0.105), 0.048, 0.056, 0.15), mat("dark")),
             (loop((0, 0, 0.026), 0.05, 0.05, 0.011), mat("pink"))]
    obj("tiny_hat", group(parts, (0.05, -0.02, 0.262), R(0, 14, 0)), n)
    obj("trim_tiny_hat", group([(prism(star(0.022, 0.01), 0.008, (0, -0.052, 0.06)), GOLD())], (0.05, -0.02, 0.262), R(0, 14, 0)), n)


@item("Thunder Hat", ["head"], ["headwear"])
def thunder_hat(n, side, s):
    cloud = [(sq((x, y, z), r), mat("slate", 0.6)) for x, y, z, r in ((0, 0, 0.24, 0.17), (-0.17, -0.03, 0.2, 0.13), (0.17, -0.02, 0.2, 0.135),
             (0.0, -0.17, 0.19, 0.12), (0.02, 0.17, 0.2, 0.13), (-0.12, 0.13, 0.25, 0.1), (0.12, -0.12, 0.27, 0.1), (-0.1, -0.13, 0.28, 0.095))]
    bolt = [(0.03, 0.2), (0.11, 0.2), (0.045, 0.07), (0.1, 0.07), (-0.06, -0.17), (-0.01, -0.02), (-0.075, -0.02)]
    obj("thunder_cloud", cloud + [(sq((0, 0, 0.13), (0.25, 0.25, 0.06), 0.7), mat("violet"))], n)
    obj("thunder_bolt", [(prism(bolt, 0.03, (0, -0.05, 0.5), R(0, 0, 12), 0.006), mat("yellow", 0.4, 3.0)),
                         (prism([(x * 0.5, z * 0.5) for x, z in bolt], 0.02, (-0.25, -0.12, 0.13), R(0, 20, 25), 0.004), mat("yellow", 0.4, 3.0))], n)
    obj("trim_thunder", [(prism([(x * 0.5, z * 0.5) for x, z in bolt], 0.02, (0.25, -0.12, 0.13), R(0, -20, -25), 0.004), GOLD())], n)


@item("Moon Gravity", ["head"], ["headwear"])
def moon_gravity(n, side, s):
    obj("moon_cap", [dome("indigo", 0.12, 0.25), (loop((0, 0, 0.13), 0.25, 0.25, 0.016), mat("violet")),
                     (prism(star(0.045, 0.02), 0.012, (0, -0.245, 0.2), R(-14)), mat("yellow", 0.4, 1.5))], n)
    orbit = empty("fx_orbit_moon", n, (0, 0, 0.2), R(14, 8, 0))
    moon = [(sq((0.37, 0, 0), 0.075), mat("white", 0.6, 0.6))] + [(sq((0.37 + 0.07 * cos(a), 0.07 * sin(a) * 0.7, 0.03 * sin(a * 2)), 0.02), mat("slate")) for a in (0.5, 2.4, 4.4)]
    obj("moon_orbit", [(loop((0, 0, 0), 0.37, 0.37, 0.008, n=56, segs=8), mat("aqua", 0.5, 1.5))] + moon
        + [(prism(star(0.04, 0.017), 0.012, (-0.37, 0, 0), R(0, 0, 90)), mat("yellow", 0.4, 2.0))], orbit)
    obj("trim_moon", [(loop((0.37, 0, 0), 0.105, 0.105, 0.007, rot=R(70), segs=8), GOLD())], orbit)


@item("Sweatband", ["head"], ["headwear"])
def sweatband(n, side, s):
    obj("sweatband", [(rev([(0.045, 0.238), (0.05, 0.252), (0.085, 0.256), (0.12, 0.25), (0.125, 0.236)], segs=40), mat("pink", 0.8)),
                      (loop((0, 0, 0.085), 0.256, 0.256, 0.012), mat("white", 0.8))], n)
    obj("trim_sweatband", [(prism(star(0.035, 0.015), 0.012, (0, -0.262, 0.085)), GOLD())], n)


# ------------------------------------------------------------------------------------------ face
# Face slot: origin on the face at eye level; the head centre is 0.235 behind (+Y).

@item("Googly Eyes", ["face"])
def googly_eyes(n, side, s):
    parts = []
    for x, dx, dz in ((0.09, -0.02, -0.03), (-0.09, 0.025, 0.03)):
        parts += [(sq((x, -0.02, 0.01), (0.082, 0.05, 0.082)), mat("white", 0.25)), (sq((x + dx, -0.06, 0.01 + dz), (0.038, 0.016, 0.038)), mat("ink", 0.25)),
                  (loop((x, -0.012, 0.01), 0.08, 0.08, 0.012, rot=R(90)), mat("cyan"))]
    obj("googly_eyes", parts, n)
    obj("trim_googly", [(loop((x, -0.012, 0.01), 0.093, 0.093, 0.007, rot=R(90)), GOLD()) for x in (0.09, -0.09)], n)


@item("Mustache", ["face"])
def mustache(n, side, s):
    parts = [(sq((0, -0.03, -0.085), (0.03, 0.025, 0.028)), mat("brown", 0.6))]
    for x in (-1, 1):
        parts.append((tube([(0, -0.03, -0.085), (x * 0.09, -0.035, -0.11), (x * 0.17, -0.01, -0.085), (x * 0.215, 0.015, -0.02)], lambda t: 0.036 * (1 - t) ** 0.7 + 0.007, sm=6, segs=14), mat("brown", 0.6)))
    obj("mustache", parts, n)
    obj("trim_mustache", [(sq((x * 0.215, 0.015, -0.02), 0.016), GOLD()) for x in (-1, 1)], n)


@item("Opera Bow Tie", ["face"])
def opera_kick(n, side, s):
    # The singer's kit: a big bow tie under the chin, a monocle (the eyes stay in view) and two notes in the air.
    c = Vector((0, 0.07, -0.262))
    parts = [(sq(c, (0.034, 0.03, 0.04)), mat("violet"))]
    for x in (-1, 1):
        parts.append((rev([(0, 0.02), (0.03, 0.034), (0.1, 0.07), (0.135, 0.076), (0.15, 0.06), (0.15, 0)], c, R(0, x * 90, 0), sy=0.42), mat("pink")))
    parts += [(loop((0.098, -0.022, 0.012), 0.066, 0.066, 0.011, rot=R(90)), GOLD()),
              (tube([(0.066, -0.03, 0.046), (0.078, -0.03, 0.058), (0.094, -0.03, 0.062)], 0.005, sm=3), mat("white", 0.3)),
              (tube([(0.152, -0.018, -0.025), (0.175, -0.005, -0.12), (0.16, 0.035, -0.2), (0.11, 0.06, -0.25)], 0.006, sm=4), GOLD())]
    obj("opera_bow_tie", parts, n)
    orbit = empty("fx_orbit_notes", n, (-0.33, 0.02, -0.03))
    notes = []
    for x, z, col in ((0.07, 0.0, "violet"), (-0.07, 0.07, "pink")):
        notes += [(sq((x, 0, z), (0.036, 0.026, 0.027), rot=R(0, -25, 0)), mat(col, 0.4, 0.5)),
                  (cyl((x + 0.03, 0, z), (x + 0.03, 0, z + 0.115), 0.008), mat(col, 0.4, 0.5)),
                  (tube([(x + 0.03, 0, z + 0.115), (x + 0.06, 0, z + 0.095), (x + 0.07, 0, z + 0.06)], lambda t: 0.012 - 0.006 * t, sm=3), mat(col, 0.4, 0.5))]
    obj("opera_notes", notes, orbit)
    obj("trim_opera", [(prism(star(0.03, 0.013), 0.01, (0, 0.038, -0.262)), GOLD())], n)


# ----------------------------------------------------------------------------------------- hands
# Hand slot: origin at the mitten centre (radii 0.036, 0.047, 0.052). Arms hang: +Z is up the arm,
# -Y is the front, the outside of the hand is s * X.

@item("Foam Finger", ["hand_r"], ["hand_r"])
def foam_finger(n, side, s):
    # A big flat "number one" hand held up in front of the mitten: the broad face looks forward.
    foam = mat("orange", 0.7)
    parts = [(sq((s * 0.02, -0.03, 0.0), (0.105, 0.05, 0.095), 0.5, 0.6), foam), (sq((s * 0.03, -0.03, 0.2), (0.045, 0.042, 0.15), 0.6, 0.7), foam),
             (sq((s * 0.125, -0.03, 0.04), (0.034, 0.036, 0.062), 0.7, 0.7), foam), (loop((s * 0.02, -0.03, -0.055), 0.108, 0.053, 0.012, e=0.5), mat("white")),
             (sq((s * 0.02, -0.08, 0.005), (0.05, 0.008, 0.05)), mat("white")), (sq((s * 0.02, -0.088, 0.005), (0.012, 0.006, 0.034), 0.4, 0.4), mat("plum"))]
    obj("foam_finger", parts, n)
    obj("trim_foam", [(prism(star(0.03, 0.013), 0.01, (s * 0.03, -0.076, 0.25)), GOLD())], n)


@item("Rubber Chicken", ["hand_l"])
def rubber_chicken(n, side, s):
    # Held by the legs and brandished forward: white so it shows against Jeff's yellow, well clear of the ground.
    skin, beak, red = mat("white", 0.3), mat("orange", 0.35), mat("pink", 0.35)
    parts = [(sq((0, 0, 0.15), (0.066, 0.07, 0.1)), skin), (cyl((0, 0.05, 0.1), (0, 0.115, 0.075), 0.03, 0.008), skin),
             (tube([(0, 0, 0.23), (0, -0.012, 0.3), (0, -0.006, 0.36)], 0.027, sm=3), skin), (sq((0, -0.01, 0.392), 0.05), skin),
             (cyl((0, -0.045, 0.398), (0, -0.125, 0.39), 0.025, 0.004), beak), (cyl((0, -0.04, 0.376), (0, -0.1, 0.35), 0.019, 0.004), beak),
             (sq((0, -0.042, 0.342), (0.013, 0.015, 0.026)), red)]
    parts += [(sq((0, -0.03 + 0.024 * i, 0.447 - 0.007 * i * i), (0.013, 0.021, 0.026)), red) for i in range(3)]
    for x in (-1, 1):
        parts += [(sq((x * 0.042, -0.034, 0.404), 0.013), mat("ink", 0.3)), (sq((x * 0.064, 0.008, 0.15), (0.016, 0.046, 0.062), rot=R(-15)), skin),
                  (tube([(x * 0.022, 0, 0.07), (x * 0.026, 0, -0.045)], 0.011), beak), (sq((x * 0.026, -0.012, -0.05), (0.02, 0.032, 0.009)), beak)]
    obj("rubber_chicken", group(parts, (0, -0.005, 0), R(55), 0.9), n)
    obj("trim_chicken", group([(loop((0, -0.01, 0.3), 0.031, 0.031, 0.009), GOLD())], (0, -0.005, 0), R(55), 0.9), n)


def sausage(p0, p1, r, m):
    """One balloon segment: a fat round-ended sausage."""
    p0, p1 = Vector(p0), Vector(p1)
    return (tube([p0.lerp(p1, i / 10) for i in range(11)], lambda t: r * max(1 - abs(2 * t - 1) ** 4, 0.02) ** 0.5, segs=14), m)


@item("Balloon Animal", ["hand_l"])
def balloon_animal_ball(n, side, s):
    # A balloon dog floating on a short string, clear of the body.
    m = mat("pink", 0.15)
    b = lambda p0, p1, r=0.03: sausage(p0, p1, r, m)
    dog = [b((0, 0.085, 0), (0, -0.085, 0), 0.04), b((0, -0.078, 0.01), (0, -0.098, 0.125)), b((0, -0.07, 0.135), (0, -0.215, 0.11), 0.037),
           b((0, 0.08, 0.01), (0, 0.118, 0.105), 0.021), (sq((0, 0.124, 0.122), 0.026), m), (sq((0, -0.222, 0.108), 0.013), mat("plum", 0.3)),
           (sq((0.014, -0.01, 0.034), (0.008, 0.034, 0.006)), mat("white", 0.2)), (sq((0.012, -0.14, 0.142), (0.007, 0.026, 0.005)), mat("white", 0.2))]
    for x in (-1, 1):
        dog += [b((x * 0.03, -0.08, 0.0), (x * 0.046, -0.092, -0.125), 0.029), b((x * 0.03, 0.08, 0.0), (x * 0.046, 0.092, -0.125), 0.029),
                b((x * 0.02, -0.088, 0.135), (x * 0.058, -0.062, 0.235), 0.027)]
    at, rot = (s * 0.19, -0.12, 0.12), R(0, 0, s * 30)
    obj("balloon_dog", group(dog, at, rot, 1.15) + [(tube([(0, 0, 0.03), (s * 0.07, -0.04, 0.05), (s * 0.17, -0.11, 0.08)], 0.005, sm=4), mat("white"))], n)
    obj("trim_balloon", group([(loop((0, -0.09, 0.075), 0.034, 0.034, 0.01, rot=R(-10)), GOLD())], at, rot, 1.15), n)


@item("Power Gloves", HANDS, HANDS, level_up={"max": 3, "scale_step": 0.08})
def super_strength(n, side, s):
    parts = [(sq((0, -0.005, -0.015), (0.072, 0.088, 0.09), 0.8, 0.85), mat("orange")), (sq((-s * 0.03, -0.075, 0.01), (0.03, 0.035, 0.045)), mat("orange")),
             (cyl((0, 0, 0.04), (0, 0, 0.1), 0.064), mat("indigo")), (loop((0, 0, 0.1), 0.064, 0.064, 0.013), mat("yellow"))]
    parts += [(sq((s * 0.045, y, -0.085), 0.022), mat("yellow")) for y in (-0.055, -0.005, 0.045)]
    obj("power_glove_" + side, parts, n)
    obj("trim_glove_" + side, [(loop((0, 0, 0.055), 0.067, 0.067, 0.008), GOLD())], n)


# ----------------------------------------------------------------------------------------- knees
# Knee slot: origin on the leg axis (leg radius 0.049), 45% of the way down; the ankle is at z -0.125.

@item("Knee Pads", KNEES)
def knee_pads(n, side, s):
    obj("knee_pad_" + side, [(sq((0, -0.036, 0), (0.07, 0.052, 0.082), 0.7, 0.8), mat("white", 0.7)), (sq((0, -0.08, 0.0), (0.05, 0.026, 0.06), 0.75, 0.8), mat("orange", 0.3)),
                             (loop((0, 0, 0.042), 0.057, 0.057, 0.014), mat("indigo")), (loop((0, 0, -0.042), 0.057, 0.057, 0.014), mat("indigo"))], n)
    obj("trim_knee_" + side, [(prism(star(0.03, 0.013), 0.01, (0, -0.107, 0)), GOLD())], n)


def along(prof, p0, p1, **kw):
    """A lathe whose axis runs from p0 towards p1."""
    return rev(prof, p0, Vector((0, 0, 1)).rotation_difference((Vector(p1) - Vector(p0)).normalized()).to_matrix(), **kw)


@item("Cannon Leg", ["knee_r"])
def cannon_leg(n, side, s):
    # A cannon strapped across the knee: barrel forward, gold bands, a wheel on the outside, a lit fuse.
    iron, wood = mat("dark", 0.35, 0, 0.3), mat("brown", 0.6)
    p0, p1 = Vector((0, 0.1, -0.012)), Vector((0, -0.245, 0.07))
    d = (p1 - p0).normalized()
    band = lambda t, r: (along([(t - 0.014, r - 0.004), (t - 0.008, r + 0.008), (t + 0.008, r + 0.008), (t + 0.014, r - 0.004)], p0, p1), GOLD())
    parts = [(along([(0, 0), (0.0, 0.05), (0.02, 0.076), (0.06, 0.082), (0.2, 0.068), (0.29, 0.064), (0.3, 0.082), (0.345, 0.088), (0.355, 0.078), (0.355, 0)], p0, p1), iron),
             band(0.075, 0.081), band(0.2, 0.068), band(0.322, 0.086), (sq(p0 - d * 0.022, 0.032), GOLD()),
             (along([(0, 0), (0, 0.058), (0.006, 0.06), (0.008, 0)], p0 + d * 0.352, p1), mat("ink")),
             (sq((0, 0.012, -0.045), (0.074, 0.075, 0.04), 0.5, 0.6), wood),
             (tube([(0, 0.07, 0.07), (0, 0.085, 0.115), (0.015, 0.12, 0.15), (0.0, 0.15, 0.185)], 0.008, sm=4), mat("white")),
             (sq((0.0, 0.152, 0.19), 0.024), mat("orange", 0.5, 4.0)), (prism(star(0.045, 0.018, 4), 0.012, (0.0, 0.152, 0.19), None, 0.003), mat("yellow", 0.5, 4.0))]
    wx = s * 0.105   # the wheel, outside the leg
    parts += [(cyl((wx - 0.016, 0.025, -0.03), (wx + 0.016, 0.025, -0.03), 0.082, bev=0.1), wood), (loop((wx, 0.025, -0.03), 0.082, 0.082, 0.015, rot=R(0, 90, 0)), iron),
              (sq((wx + s * 0.012, 0.025, -0.03), (0.018, 0.03, 0.03)), GOLD())]
    for a in (0, 45, 90, 135):
        parts.append((tube([(wx + s * 0.014, 0.025 + 0.068 * cos(radians(a)), -0.03 + 0.068 * sin(radians(a))), (wx + s * 0.014, 0.025 - 0.068 * cos(radians(a)), -0.03 - 0.068 * sin(radians(a)))], 0.007), iron))
    obj("cannon", parts, n)
    obj("trim_cannon", [(sq(p0 + d * 0.352, 0.05), GOLD())], n)


@item("Lucky Sock", ["knee_l"])
def lucky_sock(n, side, s):
    # A fat tube sock with a folded cuff and a four-leaf clover.
    wool, green = mat("white", 0.85), mat("teal", 0.8)
    parts = [(rev([(-0.12, 0), (-0.12, 0.06), (-0.1, 0.073), (0.07, 0.077), (0.085, 0.072), (0.085, 0)]), wool), (loop((0, 0, 0.082), 0.076, 0.076, 0.024), green)]
    parts += [(rev([(z - 0.013, 0.076), (z - 0.009, 0.0795), (z + 0.009, 0.0795), (z + 0.013, 0.076)]), green) for z in (0.03, -0.012)]
    for a in (45, 135, 225, 315):
        parts.append((sq((0.027 * cos(radians(a)), -0.079, -0.066 + 0.027 * sin(radians(a))), (0.027, 0.012, 0.027)), green))
    parts.append((tube([(0, -0.08, -0.066), (0.012, -0.079, -0.1), (0.03, -0.074, -0.112)], 0.007, sm=3), green))
    obj("lucky_sock", parts, n)
    shoe_pts = [(s * 0.083, 0.005 + 0.034 * cos(radians(a)), -0.055 + 0.034 * sin(radians(a))) for a in range(150, 391, 20)]
    obj("trim_sock", [(tube(shoe_pts, 0.009), GOLD())], n)


# ----------------------------------------------------------------------------------------- waist
# Waist slot: origin on the torso axis at belt height; torso half-width 0.155, half-depth 0.127.

def belt(col, r=0.02, z=0.0):
    return (loop((0, 0, z), 0.162, 0.134, r, e=0.77, n=48), mat(col))


@item("Duck Floatie", ["waist"])
def duck_floatie(n, side, s):
    obj("duck_floatie", [(loop((0, 0, 0), 0.215, 0.19, 0.072, e=0.85, n=48, segs=16), mat("yellow", 0.3)), (sq((0, -0.285, 0.11), 0.08), mat("yellow", 0.3)),
                         (cyl((0, -0.25, 0.02), (0, -0.28, 0.08), 0.05), mat("yellow", 0.3)), (sq((0, -0.365, 0.095), (0.05, 0.045, 0.02)), mat("orange")),
                         (sq((0.04, -0.345, 0.135), 0.014), mat("ink")), (sq((-0.04, -0.345, 0.135), 0.014), mat("ink")),
                         (sq((0, 0.285, 0.05), (0.05, 0.07, 0.035), rot=R(-35)), mat("yellow", 0.3))], n)
    obj("trim_duck", [(loop((0, 0, 0.055), 0.215, 0.19, 0.012, e=0.85, n=48), mat("white"))], n)


@item("Tornado Spin", ["waist"])
def tornado_spin(n, side, s):
    # A cartoon twister around the legs: stacked off-centre whirls and a spiral stripe, so the spin shows.
    spin = empty("fx_spin_tornado", n)
    parts = []
    for k in range(5):
        r = 0.105 + 0.026 * k
        parts.append((sq((0.03 * cos(k * 2.4), 0.03 * sin(k * 2.4), -0.185 + 0.062 * k), (r, r, 0.038), 0.6), mat("aqua" if k % 2 else "white", 0.5, 0.25)))
    pts = [((0.118 + 0.125 * t) * cos(t * 5.2 * pi), (0.118 + 0.125 * t) * sin(t * 5.2 * pi), -0.2 + 0.29 * t) for t in (i / 80 for i in range(81))]
    parts.append((tube(pts, lambda t: 0.008 + 0.016 * sin(t * pi) ** 0.5, segs=10), mat("cyan", 0.5, 0.3)))
    obj("tornado", parts, spin)
    bits = [(prism(star(0.04, 0.017), 0.012, (0.3, 0, 0.09)), mat("yellow", 0.4, 1.0)), (sq((-0.19, 0.19, -0.02), (0.04, 0.02, 0.012), rot=R(20, 30, 40)), mat("teal")),
            (sq((-0.1, -0.24, 0.03), 0.024), mat("pink"))]
    obj("tornado_bits", bits, spin)
    obj("trim_tornado", [(prism(star(0.035, 0.015), 0.01, (0.29 * cos(a), 0.29 * sin(a), 0.11)), GOLD()) for a in (2.1, 4.2)], spin)


@item("Dad Belt", ["waist"])
def dad_strength(n, side, s):
    # A weightlifter's belt: wide leather, tall at the back, a big gold plate with a dumbbell.
    leather = mat("brown", 0.6)
    parts = [(rev([(-0.048, 0.9), (-0.055, 1.0), (-0.045, 1.04), (0.045, 1.04), (0.055, 1.0), (0.048, 0.9)], sx=0.166, sy=0.138, e=0.77, segs=48), leather),
             (sq((0, 0.13, 0.03), (0.115, 0.028, 0.08), 0.5, 0.6), leather),
             (sq((0, -0.15, 0), (0.088, 0.022, 0.072), 0.6, 0.6), GOLD()),
             (cyl((-0.04, -0.172, 0), (0.04, -0.172, 0), 0.01), mat("ink"))]
    parts += [(loop((0, 0, z), 0.1735, 0.1445, 0.006, e=0.77, n=48), mat("yellow")) for z in (-0.036, 0.036)]
    parts += [(sq((x * 0.046, -0.172, 0), (0.016, 0.012, 0.036), 0.6, 0.6), mat("ink")) for x in (-1, 1)]
    obj("dad_belt", parts, n)
    obj("trim_dad", [(sq((x * a, b, 0), 0.016), GOLD()) for x in (-1, 1) for a, b in ((0.116, -0.126), (0.164, -0.076))], n)


@item("Coach's Whistle", ["waist"])
def coachs_whistle(n, side, s):
    lan = [(0, 0.1, 0.31), (0.125, 0.0, 0.28), (0.1, -0.135, 0.18), (0, -0.165, 0.09), (-0.1, -0.135, 0.18), (-0.125, 0.0, 0.28)]
    obj("whistle", [(tube(lan, 0.009, cyc=True, sm=5), mat("pink")), (cyl((-0.03, -0.185, 0.045), (0.03, -0.185, 0.045), 0.045), mat("yellow", 0.3)),
                    (sq((0.0, -0.2, 0.095), (0.028, 0.03, 0.05), 0.5, 0.5, rot=R(-20)), mat("yellow", 0.3)), (sq((0, -0.228, 0.05), (0.02, 0.008, 0.016)), mat("ink")),
                    (loop((0, -0.172, 0.085), 0.014, 0.014, 0.005, rot=R(0, 90, 0)), STEEL())], n)
    obj("trim_whistle", [(loop((0, -0.185, 0.045), 0.047, 0.047, 0.006, rot=R(0, 90, 0)), GOLD())], n)


@item("Running Start", ["waist"])
def running_start(n, side, s):
    chev = [(-0.03, 0.036), (0.0, 0.036), (0.03, 0), (0, -0.036), (-0.03, -0.036), (0, 0)]
    obj("race_bib", [belt("pink", 0.016), (sq((0, -0.15, -0.005), (0.1, 0.014, 0.07), 0.4, 0.4), mat("white")),
                     (prism(chev, 0.012, (-0.028, -0.166, -0.005)), mat("orange")), (prism(chev, 0.012, (0.03, -0.166, -0.005)), mat("orange"))], n)
    obj("trim_bib", [(sq((x, -0.165, 0.05), 0.01), GOLD()) for x in (-0.08, 0.08)], n)


# ------------------------------------------------------------------------------------------ build

def export(root, path):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in [root] + list(root.children_recursive):
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_animations=False, export_extras=True, export_yup=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--outdir", default=os.path.join(HERE, "..", "..", "assets", "gear"))
    ap.add_argument("--only", default="")
    a = ap.parse_args(argv)
    os.makedirs(a.outdir, exist_ok=True)
    only = [x for x in a.only.split(",") if x]
    for gid, spec in ITEMS.items():
        if only and gid not in only:
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        _mats.clear()
        root = empty(gid)
        for slot in spec["slots"]:
            side = slot[-1] if slot[-2:] in ("_l", "_r") else ""
            spec["fn"](empty(slot, root), side, -1 if side == "r" else 1)
        export(root, os.path.join(a.outdir, gid + ".glb"))
        d = {"id": gid, "name": spec["name"], "slots": spec["slots"], "scene": gid + ".glb",
             "replaces_body_part": spec["replaces_body_part"], "fit": spec.get("fit", {}),
             "level_up": spec.get("level_up", {"max": 3, "scale_step": 0.06})}
        if "spring" in spec:
            d["spring"] = spec["spring"]
        with open(os.path.join(a.outdir, gid + ".json"), "w") as f:
            json.dump(d, f, indent=2)
            f.write("\n")
        print("GEAR_OK", gid)
