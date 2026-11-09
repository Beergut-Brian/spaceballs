"""Crowd Jarlings for the field: generic Jarlings from the openjar-characters avatar kit (v0.0.1),
decimated for a cheap sideline crowd (about a third of the triangles, 512 px face atlas).

    blender -b --factory-startup -P art/tools/build_crowd.py -- \
        --kit <openjar-characters>/avatar/kit --seed 9 --out assets/models/crowd/jarling_09.glb
"""
import sys, os, argparse
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--kit", required=True); ap.add_argument("--seed", type=int, required=True)
ap.add_argument("--out", required=True); ap.add_argument("--ratio", type=float, default=0.35)
ap.add_argument("--face", type=int, default=512)
a = ap.parse_args(argv)
sys.path.insert(0, os.path.abspath(a.kit))
import bpy
import jarling_kit as kit

kit.reset_scene()
bpy.context.scene.render.fps = kit.FPS
j = kit.build_jarling(kit.random_params(a.seed))
kit.pose_at(j, "idle", 1)
for ob in (j.body, j.hat):
    if ob:
        m = ob.modifiers.new("lod", "DECIMATE")
        m.ratio = a.ratio
        m.use_collapse_triangulate = True
for img in bpy.data.images:
    if img.size[0] > a.face:
        img.scale(a.face, a.face)
bpy.ops.object.select_all(action="DESELECT")
for ob in (j.rig, j.body, j.hat):
    if ob:
        ob.select_set(True)
bpy.context.view_layer.objects.active = j.rig
os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=a.out, export_format="GLB", use_selection=True, export_apply=True,
    export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
    export_extras=True, export_yup=True, export_force_sampling=True, export_frame_range=False,
    export_reset_pose_bones=True, export_image_format="AUTO")
print("CROWD_OK", a.out)
