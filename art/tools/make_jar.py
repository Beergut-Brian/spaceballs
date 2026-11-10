# Builds store/jar.glb: Spaceballs' tiny world for the Open Jar launcher's hub jar.
# Art lane. Run through art/tools/make_jar.sh (Blender 5.2.3, background), never by hand.
#
# Launcher contract (openjar-launcher docs/contracts.md, "Jar world"): Y up, origin at the centre of
# the floor, fits a cylinder r 0.8 m x h 1.9 m, reads from every side (turntable), no text,
# <= 5,000 triangles, <= 8 materials, textures <= 512 px, no external files.
#
# The diorama: a round patch of the striped lawn with the white line, Jeff mid-kick beside his empty
# orange tee, his green beach ball spiralling up on a trail to a ringed planet, Chuck's red ball
# waiting on its tee, a puff cloud and a few stars. Everything but Jeff's face is flat colours (the
# game's palette) from one 32 px palette texture, so the budget goes on shape.
import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
JEFF = os.path.join(ROOT, "assets/models/characters/jeff.glb")
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(ROOT, "store/jar.glb")

KICK_FRAME = 14          # contact frame of Jeff's `kick` (art/scripts/jarling_rig.gd)
JEFF_HEIGHT = 0.86
JEFF_TRIS = 2000
FACE_CELL = (0.5, 0.0)   # face atlas cell "happy" (jarling_rig.gd EXPR), as a UV offset
FACE_PX = 512


def hexc(h, a=1.0):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, a)


# Game palette (field.tscn, ball_look.gd, GAME.md, Jeff's own materials).
GRASS_A = hexc("4fc24a")
GRASS_B = hexc("3faa3e")
SOIL = hexc("8a5a3c")
SOIL_DARK = hexc("6b4430")
LINE = hexc("f8faf2")
TEE = hexc("ff9a2e")
P1 = hexc("3cc24a")
P1_POP = hexc("ffd84d")
P2 = hexc("e4393c")
P2_POP = hexc("38c6ff")
WHITE = hexc("ffffff")
CLOUD = hexc("eef8ff")
TRAIL = hexc("9ff4ff")
PLANET = hexc("7a6cff")
PLANET_BAND = hexc("38c6ff")
RING = hexc("ffd84d")
STAR = hexc("fff27a")


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


PALETTE = {}            # linear RGBA -> cell index in the palette texture
PAL_CELLS = 8           # 8 x 8 cells
PAL_CELL_PX = 4         # 32 x 32 px texture


def pal_uv(c):
    key = tuple(round(x, 4) for x in c[:3])
    if key not in PALETTE:
        assert len(PALETTE) < PAL_CELLS * PAL_CELLS, "palette full"
        PALETTE[key] = len(PALETTE)
    i = PALETTE[key]
    return ((i % PAL_CELLS + 0.5) / PAL_CELLS, (i // PAL_CELLS + 0.5) / PAL_CELLS)


def colour_faces(obj, fn, skip=None):
    """Points every corner of a face at its colour's cell: fn(face_index, face_centre) -> colour."""
    me = obj.data
    uv = me.uv_layers.active or me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        if skip and skip(poly):
            continue
        u = pal_uv(fn(poly.index, poly.center))
        for li in poly.loop_indices:
            uv.data[li].uv = u


def from_bmesh(name, bm, colour, smooth=False):
    for f in bm.faces:
        f.smooth = smooth
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    colour_faces(obj, colour if callable(colour) else (lambda i, p: colour))
    return obj


def place(obj, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """Blender is Z up; glTF export turns it into Y up with -Y(blender) -> +Z(front)."""
    obj.location = loc
    obj.rotation_euler = rot
    obj.scale = scale
    return obj


def cylinder(name, r1, r2, depth, segs, colour, cap=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, segments=segs, radius1=r1, radius2=r2, depth=depth)
    return from_bmesh(name, bm, colour)


def sphere(name, r, segs, rings, colour):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    return from_bmesh(name, bm, colour, smooth=True)


def ico(name, r, subdiv, colour):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    return from_bmesh(name, bm, colour, smooth=True)


# ---------------------------------------------------------------- the lawn

def lawn():
    r, depth = 0.8, 0.14
    # Top: mowed stripes and the white line, as rings x columns so the stripes are geometry.
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=40, radius=r)
    top = bm.faces[:]
    bmesh.ops.triangulate(bm, faces=top)
    # Cut stripes and the line's edges into the disc.
    cuts = [-0.6, -0.36, -0.12, 0.12, 0.36, 0.6]
    for x in cuts:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(x, 0, 0), plane_no=(1, 0, 0))
    for y in (0.17, 0.23):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, y, 0), plane_no=(0, 1, 0))
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, depth))

    def grass(_i, p):
        if 0.17 < p.y < 0.23:
            return LINE
        band = math.floor((p.x + 0.12) / 0.24)
        return GRASS_A if band % 2 == 0 else GRASS_B
    top_obj = from_bmesh("Lawn", bm, grass)
    soil = cylinder("Soil", r, r * 0.9, depth, 40, lambda i, p: SOIL if p.z > -0.02 else SOIL_DARK, cap=True)
    place(soil, (0, 0, depth / 2 - 0.001))
    # A lip of grass over the soil so the top reads as turf, not a plate.
    lip = cylinder("Lip", r + 0.012, r + 0.012, 0.035, 40, GRASS_B, cap=False)
    place(lip, (0, 0, depth - 0.016))
    return depth


# ---------------------------------------------------------------- props

def tee(name, at, ground):
    t = cylinder(name, 0.045, 0.075, 0.08, 12, TEE)
    return place(t, (at[0], at[1], ground + 0.04))


def beach_ball(name, r, main, pop, segs=12, rings=8):
    def panel(_i, p):
        a = math.atan2(p.y, p.x)
        k = int(math.floor((a + math.pi) / (2 * math.pi) * 6)) % 6
        if abs(p.z) > r * 0.88:
            return WHITE
        return (main, WHITE, pop, WHITE, main, WHITE)[k] if k % 2 == 0 else WHITE
    return sphere(name, r, segs, rings, panel)


def trail(points, r0, r1, sides=6):
    """A tapering tube through points, whiter at the ball end."""
    bm = bmesh.new()
    rings = []
    n = len(points)
    for i, p in enumerate(points):
        t = i / (n - 1)
        d = (points[min(i + 1, n - 1)] - points[max(i - 1, 0)]).normalized()
        side = d.cross(Vector((0, 0, 1)))
        if side.length < 1e-4:
            side = Vector((1, 0, 0))
        side.normalize()
        up = side.cross(d).normalized()
        rad = r0 + (r1 - r0) * t
        ring = []
        for s in range(sides):
            a = s / sides * math.tau
            ring.append(bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * rad))
        rings.append(ring)
    for i in range(n - 1):
        for s in range(sides):
            a, b = rings[i][s], rings[i][(s + 1) % sides]
            c, d = rings[i + 1][(s + 1) % sides], rings[i + 1][s]
            bm.faces.new((a, b, c, d))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    lo, hi = points[0].z, points[-1].z

    def col(_i, p):
        t = round((p.z - lo) / max(hi - lo, 1e-4) * 4) / 4
        return tuple(TRAIL[k] + (WHITE[k] - TRAIL[k]) * t for k in range(3)) + (1.0,)
    return from_bmesh("Trail", bm, col, smooth=True)


def planet(at):
    body = ico("Planet", 0.21, 2, lambda i, p: PLANET_BAND if abs(p.z) < 0.055 else PLANET)
    place(body, at)
    # Flat ring: two concentric loops bridged.
    bm = bmesh.new()
    outer_v = [bm.verts.new((math.cos(a) * 0.37, math.sin(a) * 0.37, 0)) for a in
               (i / 28 * math.tau for i in range(28))]
    inner_v = [bm.verts.new((math.cos(a) * 0.26, math.sin(a) * 0.26, 0)) for a in
               (i / 28 * math.tau for i in range(28))]
    for i in range(28):
        j = (i + 1) % 28
        bm.faces.new((outer_v[i], outer_v[j], inner_v[j], inner_v[i]))
    ring = from_bmesh("Ring", bm, RING)
    place(ring, at, (math.radians(24), math.radians(-12), 0))
    return body, ring


def cloud(at, s):
    puffs = [((0, 0, 0), 0.11), ((0.1, 0.02, -0.02), 0.085), ((-0.1, -0.01, -0.025), 0.08),
             ((0.03, -0.05, 0.05), 0.08), ((-0.04, 0.05, 0.04), 0.07)]
    out = []
    for k, (o, r) in enumerate(puffs):
        p = ico("Puff%d" % k, r * s, 1, CLOUD)
        place(p, (at[0] + o[0] * s, at[1] + o[1] * s, at[2] + o[2] * s), scale=(1, 1, 0.8))
        out.append(p)
    return out


def star(name, at, r):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=0, radius=r)
    for v in bm.verts:   # spiky: push alternating verts out
        v.co *= 1.0 if v.index % 2 else 0.45
    s = from_bmesh(name, bm, STAR)
    return place(s, at, (0.3, 0.5, 0.2))


# ---------------------------------------------------------------- Jeff

def jeff(ground, at, facing):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=JEFF)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    body = next(o for o in new if o.type == "MESH" and o.find_armature() is not None)
    kick = next(a for a in bpy.data.actions if "kick" in a.name.lower())
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = kick
    if hasattr(ad, "action_slot") and len(kick.slots):
        ad.action_slot = kick.slots[0]
    bpy.context.scene.frame_set(KICK_FRAME)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(body.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    me.transform(body.matrix_world)
    slot_mats = [s.material for s in body.material_slots]
    posed = bpy.data.objects.new("Jeff", me)
    bpy.context.scene.collection.objects.link(posed)
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)

    # Material colours -> vertex colours; keep only the face's own (textured) material.
    mats = list(me.materials)
    if not any(mats):
        mats = slot_mats
    print("make_jar: jeff materials", [m.name if m else None for m in mats])
    face_idx = next(i for i, m in enumerate(mats) if m and m.name.split(".")[0].endswith("_face"))

    def base(m):
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m and m.use_nodes else None
        return tuple(bsdf.inputs["Base Color"].default_value) if bsdf else (1, 1, 1, 1)
    cols = [base(m) for m in mats]
    colour_faces(posed, lambda i, p: cols[me.polygons[i].material_index],
                 skip=lambda p: p.material_index == face_idx)
    face_mat = mats[face_idx]
    is_face = [p.material_index == face_idx for p in me.polygons]
    me.materials.clear()   # (resets every material_index to 0)
    me.materials.append(palette_material())
    me.materials.append(face_material(face_mat))
    for p in me.polygons:
        p.material_index = 1 if is_face[p.index] else 0

    # The face shows the "happy" cell of the expression atlas.
    uv = me.uv_layers.active
    for p in me.polygons:
        if p.material_index == 1:
            for li in p.loop_indices:
                uv.data[li].uv = (uv.data[li].uv[0] + FACE_CELL[0], uv.data[li].uv[1] - FACE_CELL[1])

    # Fit, decimate, place.
    zs = [v.co.z for v in me.vertices]
    s = JEFF_HEIGHT / (max(zs) - min(zs))
    me.transform(Matrix.Translation((0, 0, -min(zs))))
    me.transform(Matrix.Scale(s, 4))
    bpy.context.view_layer.objects.active = posed
    dec = posed.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = JEFF_TRIS / max(len(me.polygons) * 1.0, 1.0)
    dec.use_collapse_triangulate = True
    posed.select_set(True)
    bpy.ops.object.modifier_apply(modifier=dec.name)
    place(posed, (at[0], at[1], ground), (0, 0, facing))
    return posed


_pal_mat = None


def palette_material():
    """The one material every flat-coloured face uses: a tiny palette texture. (Vertex colours are
    not an option: the launcher's runtime GLTFDocument leaves them off on untextured materials.)"""
    global _pal_mat
    if _pal_mat is None:
        _pal_mat = bpy.data.materials.new("spaceballs_palette")
        nt = _pal_mat.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        t = nt.nodes.new("ShaderNodeTexImage")
        t.interpolation = "Closest"
        t.name = "pal"
        nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.75
    return _pal_mat


def bake_palette():
    px = PAL_CELLS * PAL_CELL_PX
    img = bpy.data.images.new("spaceballs_palette", px, px, alpha=False)
    buf = [1.0] * (px * px * 4)
    for c, i in PALETTE.items():
        srgb = [12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055 for x in c]
        cx, cy = (i % PAL_CELLS) * PAL_CELL_PX, (i // PAL_CELLS) * PAL_CELL_PX
        for y in range(cy, cy + PAL_CELL_PX):
            for x in range(cx, cx + PAL_CELL_PX):
                buf[(y * px + x) * 4:(y * px + x) * 4 + 3] = srgb
    img.pixels = buf
    img.pack()
    palette_material().node_tree.nodes["pal"].image = img


def face_material(src):
    tex = next(n for n in src.node_tree.nodes if n.type == "TEX_IMAGE")
    img = tex.image
    small = img.copy()
    small.name = "jeff_face_jar"
    small.scale(FACE_PX, FACE_PX)
    small.pack()
    m = bpy.data.materials.new("spaceballs_face")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = small
    nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.75
    return m


# ---------------------------------------------------------------- build

def main():
    reset()
    g = lawn()
    # Blender: -Y is the glTF/launcher front (+Z). Jeff stands left-front, kicking towards his tee.
    tee1 = (0.02, -0.28)
    tee2 = (0.42, 0.34)
    jeff(g, (-0.34, -0.1), math.radians(-115))
    tee("Tee1", tee1, g)
    tee("Tee2", tee2, g)
    b2 = beach_ball("BallChuck", 0.13, P2, P2_POP)
    place(b2, (tee2[0], tee2[1], g + 0.08 + 0.125))

    # The kick: a rising spiral from Jeff's tee round the jar to the planet.
    pts = []
    n = 28
    top = 1.36
    for i in range(n):
        t = i / (n - 1)
        a = math.radians(-90) + t * math.radians(300)
        rad = 0.32 * (1 - t) ** 0.6 + 0.12 * t
        ease = t ** 0.8
        pts.append(Vector((tee1[0] + math.cos(a) * rad - math.cos(math.radians(-90)) * 0.32 * (1 - t),
                           tee1[1] + math.sin(a) * rad - math.sin(math.radians(-90)) * 0.32 * (1 - t),
                           g + 0.12 + ease * (top - g - 0.12))))
    trail(pts[:-1], 0.015, 0.075)
    b1 = beach_ball("BallJeff", 0.13, P1, P1_POP)
    place(b1, pts[-1], (0.6, 0.3, 0.9))

    planet((-0.2, 0.16, 1.62))
    cloud((0.42, 0.08, 0.92), 1.0)
    cloud((-0.5, 0.25, 0.55), 0.7)
    for k, (x, y, z, r) in enumerate([(0.45, -0.3, 1.55, 0.05), (0.25, 0.4, 1.8, 0.04),
                                       (-0.5, -0.2, 1.35, 0.045), (0.5, 0.2, 1.3, 0.035)]):
        star("Star%d" % k, (x, y, z), r)

    for o in bpy.context.scene.objects:
        if o.type == "MESH" and not o.data.materials:
            o.data.materials.append(palette_material())
    bake_palette()

    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
    mats = {m.name if m else "(none: vertex colours)" for o in bpy.context.scene.objects if o.type == "MESH"
            for m in (o.data.materials[:] or [None])}
    print("make_jar: %d triangles, %d materials %s" % (tris, len(mats), sorted(mats)))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True,
                              export_vertex_color="NONE",
                              export_animations=False, export_lights=False, export_cameras=False,
                              export_image_format="AUTO")
    print("make_jar: wrote", OUT)


main()
