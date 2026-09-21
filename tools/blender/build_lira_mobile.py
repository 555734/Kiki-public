"""Build Kiki's mobile-ready Lira model and export .blend + .glb.

Run with Blender 4.5 LTS:
  blender --background --factory-startup --python tools/blender/build_lira_mobile.py

The model deliberately uses simple rounded forms, flat materials, one armature,
and no textures.  It is based on the existing painted runner sprites rather
than the retired procedural 3D pass.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "tools" / "blender"
OUT_DIR = ROOT / "assets" / "models" / "blender"
BLEND_PATH = SOURCE_DIR / "lira_mobile.blend"
GLB_PATH = OUT_DIR / "lira_mobile.glb"
PREVIEW_PATH = ROOT / "build" / "lira_mobile_preview.png"


def material(name: str, rgba: tuple[float, float, float, float], roughness: float = 0.88):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = rgba
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = rgba
    principled.inputs["Roughness"].default_value = roughness
    return mat


MATS = {}


def add_materials():
    global MATS
    MATS = {
        "skin": material("Skin warm", (0.94, 0.57, 0.34, 1.0)),
        "hair": material("Hair chestnut", (0.23, 0.075, 0.045, 1.0)),
        "hair_hi": material("Hair highlight", (0.40, 0.13, 0.075, 1.0)),
        "white": material("Shirt cream", (0.96, 0.93, 0.82, 1.0)),
        "blue": material("Overalls blue", (0.025, 0.23, 0.63, 1.0)),
        "blue_hi": material("Overalls highlight", (0.035, 0.36, 0.85, 1.0)),
        "red": material("Scarf red", (0.90, 0.045, 0.08, 1.0)),
        "boot": material("Boot leather", (0.28, 0.09, 0.035, 1.0)),
        "sole": material("Boot sole", (0.08, 0.035, 0.02, 1.0)),
        "eye": material("Eye", (0.025, 0.018, 0.012, 1.0)),
        "button": material("Button brass", (1.0, 0.63, 0.10, 1.0), 0.55),
    }


def smooth(obj):
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = True


def parent_to_bone(obj, rig, bone):
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    obj.matrix_world = world


def uv_part(name, location, scale, mat, bone, segments=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(MATS[mat])
    smooth(obj)
    parent_to_bone(obj, RIG, bone)
    return obj


def capsule(name, location, radius, depth, mat, bone, rotation=(0, 0, 0), vertices=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=vertices, ring_count=6, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (radius, radius, depth * 0.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(MATS[mat])
    smooth(obj)
    parent_to_bone(obj, RIG, bone)
    return obj


def cube_part(name, location, scale, mat, bone, bevel=0.08, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Soft edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    obj.data.materials.append(MATS[mat])
    parent_to_bone(obj, RIG, bone)
    return obj


def cone_part(name, location, radius1, radius2, depth, mat, bone, rotation=(0, 0, 0), vertices=8):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2,
                                    depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(MATS[mat])
    smooth(obj)
    parent_to_bone(obj, RIG, bone)
    return obj


def create_rig():
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    rig = bpy.context.object
    rig.name = "LiraRig"
    arm = rig.data
    arm.name = "LiraSkeleton"
    base = arm.edit_bones[0]
    base.name = "Root"
    base.head = (0, 0, 0)
    base.tail = (0, 0, 0.35)

    def bone(name, head, tail, parent="Root"):
        b = arm.edit_bones.new(name)
        b.head, b.tail = head, tail
        b.parent = arm.edit_bones[parent]
        return b

    bone("Torso", (0, 0, 0.55), (0, 0, 1.35))
    bone("Head", (0, 0, 1.30), (0, 0, 2.02), "Torso")
    bone("Scarf", (0, 0.10, 1.40), (0, 0.36, 1.28), "Torso")
    for side, x in (("L", 0.34), ("R", -0.34)):
        bone(f"UpperArm.{side}", (x, 0, 1.25), (x, 0, 0.82), "Torso")
        bone(f"LowerArm.{side}", (x, 0, 0.82), (x, 0, 0.46), f"UpperArm.{side}")
        bone(f"UpperLeg.{side}", (x * 0.52, 0, 0.64), (x * 0.58, 0, 0.08), "Torso")
        bone(f"LowerLeg.{side}", (x * 0.58, 0, 0.08), (x * 0.62, 0, -0.48), f"UpperLeg.{side}")
    bpy.ops.object.mode_set(mode="POSE")
    for pbone in rig.pose.bones:
        pbone.rotation_mode = "XYZ"
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def create_model():
    # Torso and overalls: compact proportions matching the painted sprites.
    uv_part("Torso", (0, 0, 1.02), (0.46, 0.28, 0.55), "white", "Torso")
    uv_part("Overalls", (0, -0.025, 0.88), (0.40, 0.31, 0.42), "blue", "Torso")
    cube_part("Bib", (0, -0.29, 1.05), (0.28, 0.055, 0.30), "blue_hi", "Torso", 0.06)
    for x in (-0.19, 0.19):
        cube_part("Overall strap", (x, -0.29, 1.29), (0.055, 0.035, 0.29), "blue", "Torso", 0.035,
                  rotation=(0, (-0.10 if x < 0 else 0.10), 0))
        uv_part("Brass button", (x, -0.35, 1.22), (0.07, 0.035, 0.07), "button", "Torso", 8, 5)

    # Head, face and layered hair silhouette.
    uv_part("Head", (0, -0.02, 1.76), (0.48, 0.40, 0.46), "skin", "Head", 16, 10)
    uv_part("Hair cap", (0, 0.03, 1.94), (0.51, 0.42, 0.32), "hair", "Head", 14, 8)
    for i, (x, z, angle) in enumerate(((-0.38, 2.13, -0.55), (-0.13, 2.25, -0.15),
                                       (0.14, 2.24, 0.17), (0.38, 2.12, 0.55))):
        cone_part(f"Hair lock {i}", (x, -0.01, z), 0.18, 0.015, 0.40, "hair_hi", "Head",
                  rotation=(0, angle, 0), vertices=7)
    # Eyes face camera (-Y); nose projects slightly forward.
    for x in (-0.17, 0.17):
        uv_part("Eye", (x, -0.397, 1.79), (0.075, 0.027, 0.12), "eye", "Head", 10, 6)
        uv_part("Eye glint", (x - 0.018, -0.427, 1.835), (0.018, 0.009, 0.025), "white", "Head", 8, 5)
    uv_part("Nose", (0, -0.43, 1.67), (0.095, 0.10, 0.085), "skin", "Head", 10, 6)
    cube_part("Smile", (0, -0.421, 1.57), (0.10, 0.018, 0.018), "eye", "Head", 0.018)

    # Limbs are separate rigid pieces parented to bones: cheap to animate and no skinning seams.
    for side, x in (("L", 0.46), ("R", -0.46)):
        capsule(f"Upper arm {side}", (x, 0, 1.10), 0.17, 0.54, "white", f"UpperArm.{side}")
        capsule(f"Forearm {side}", (x, 0, 0.64), 0.15, 0.44, "skin", f"LowerArm.{side}")
        uv_part(f"Glove {side}", (x, -0.015, 0.40), (0.19, 0.17, 0.18), "boot", f"LowerArm.{side}", 10, 6)
        capsule(f"Thigh {side}", (x * 0.50, 0, 0.36), 0.20, 0.58, "blue", f"UpperLeg.{side}")
        capsule(f"Shin {side}", (x * 0.54, 0, -0.20), 0.18, 0.52, "blue_hi", f"LowerLeg.{side}")
        boot = uv_part(f"Boot {side}", (x * 0.54, -0.12, -0.53), (0.25, 0.36, 0.20), "boot", f"LowerLeg.{side}", 12, 7)
        boot.rotation_euler.x = math.radians(-12)
        cube_part(f"Sole {side}", (x * 0.54, -0.16, -0.67), (0.26, 0.35, 0.055), "sole", f"LowerLeg.{side}", 0.045)

    # Scarf collar plus a tapered, animated tail.
    bpy.ops.mesh.primitive_torus_add(major_radius=0.33, minor_radius=0.075, major_segments=12,
                                    minor_segments=6, location=(0, 0, 1.39))
    collar = bpy.context.object
    collar.name = "Scarf collar"
    collar.data.materials.append(MATS["red"])
    parent_to_bone(collar, RIG, "Torso")
    cone_part("Scarf tail", (0, 0.34, 1.24), 0.22, 0.06, 0.72, "red", "Scarf",
              rotation=(math.radians(72), 0, 0), vertices=7)


def set_pose(frame, rotations=None, locations=None, scale=None):
    rotations = rotations or {}
    locations = locations or {}
    scale = scale or {}
    for name, angles in rotations.items():
        bone = RIG.pose.bones[name]
        bone.rotation_euler = tuple(math.radians(a) for a in angles)
        bone.keyframe_insert("rotation_euler", frame=frame)
    for name, value in locations.items():
        bone = RIG.pose.bones[name]
        bone.location = value
        bone.keyframe_insert("location", frame=frame)
    for name, value in scale.items():
        bone = RIG.pose.bones[name]
        bone.scale = value
        bone.keyframe_insert("scale", frame=frame)


def reset_pose():
    for bone in RIG.pose.bones:
        bone.rotation_euler = (0, 0, 0)
        bone.location = (0, 0, 0)
        bone.scale = (1, 1, 1)


def action(name, frames, loop=True):
    reset_pose()
    act = bpy.data.actions.new(name)
    # Keep every exported action in the editable .blend even when it is not the
    # armature's currently selected action at save time.
    act.use_fake_user = True
    RIG.animation_data_create()
    RIG.animation_data.action = act
    for frame, pose in frames:
        set_pose(frame, **pose)
    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
        if loop:
            fc.modifiers.new("CYCLES")
    return act


def create_animations():
    neutral = {"rotations": {"UpperArm.L": (0, 0, -8), "UpperArm.R": (0, 0, 8),
                              "Scarf": (0, 0, 6)}}
    action("Idle", [(1, neutral), (18, {"locations": {"Torso": (0, 0, 0.035)},
                                        "rotations": {"Head": (0, 0, -2), "Scarf": (0, 0, -5)}}),
                    (36, neutral)])
    run_a = {"rotations": {"UpperArm.L": (0, 0, 42), "LowerArm.L": (0, 0, -28),
                            "UpperArm.R": (0, 0, -42), "LowerArm.R": (0, 0, 28),
                            "UpperLeg.L": (0, 0, -45), "LowerLeg.L": (0, 0, 48),
                            "UpperLeg.R": (0, 0, 45), "LowerLeg.R": (0, 0, 10),
                            "Torso": (0, 0, -8), "Scarf": (18, 0, -18)}}
    run_b = {"rotations": {"UpperArm.L": (0, 0, -42), "LowerArm.L": (0, 0, -28),
                            "UpperArm.R": (0, 0, 42), "LowerArm.R": (0, 0, 28),
                            "UpperLeg.L": (0, 0, 45), "LowerLeg.L": (0, 0, 10),
                            "UpperLeg.R": (0, 0, -45), "LowerLeg.R": (0, 0, 48),
                            "Torso": (0, 0, -8), "Scarf": (-15, 0, 16)}}
    action("Run", [(1, run_a), (7, {"locations": {"Torso": (0, 0, 0.06)}}), (13, run_b),
                   (19, {"locations": {"Torso": (0, 0, 0.06)}}), (25, run_a)])
    action("Jump", [(1, {"rotations": {"UpperArm.L": (0, 0, -65), "UpperArm.R": (0, 0, 65),
                                         "UpperLeg.L": (0, 0, -28), "UpperLeg.R": (0, 0, 22),
                                         "LowerLeg.L": (0, 0, 58), "LowerLeg.R": (0, 0, 35),
                                         "Scarf": (25, 0, -12)}})], False)
    action("Fall", [(1, {"rotations": {"UpperArm.L": (0, 0, -82), "UpperArm.R": (0, 0, 82),
                                         "UpperLeg.L": (0, 0, 18), "UpperLeg.R": (0, 0, -18),
                                         "LowerLeg.L": (0, 0, 25), "LowerLeg.R": (0, 0, 25),
                                         "Scarf": (-15, 0, 12)}})], False)
    action("Land", [(1, {"scale": {"Torso": (1.08, 1.08, 0.72)},
                                  "rotations": {"UpperLeg.L": (0, 0, -32), "UpperLeg.R": (0, 0, 32),
                                                "LowerLeg.L": (0, 0, 58), "LowerLeg.R": (0, 0, 58)}}),
                    (8, neutral)], False)
    action("Dash", [(1, {"rotations": {"Torso": (0, 0, -24),
                                         "UpperArm.L": (0, 0, 70), "UpperArm.R": (0, 0, 62),
                                         "UpperLeg.L": (0, 0, -58), "UpperLeg.R": (0, 0, 48),
                                         "LowerLeg.L": (0, 0, 42), "LowerLeg.R": (0, 0, 12),
                                         "Scarf": (32, 0, -22)}})], False)
    action("Hurt", [(1, {"rotations": {"Torso": (0, 0, 18), "Head": (0, 0, 12),
                                         "UpperArm.L": (0, 0, -92), "UpperArm.R": (0, 0, 92)}})], False)
    action("Dead", [(1, {"rotations": {"Root": (0, 0, 86)}})], False)
    RIG.animation_data.action = bpy.data.actions["Idle"]


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    add_materials()
    global RIG
    RIG = create_rig()
    create_model()
    create_animations()
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"
    bpy.context.scene.render.fps = 30
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        export_yup=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_frame_range=False,
        export_def_bones=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
    )
    # Render a deterministic inspection image from the same .blend source.
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.camera_add(location=(3.7, -7.2, 2.7))
    camera = bpy.context.object
    camera.name = "PreviewCamera"
    direction = Vector((0, 0, 0.85)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.45
    bpy.context.scene.camera = camera
    bpy.ops.object.light_add(type="AREA", location=(-3.5, -4.5, 6.0))
    key = bpy.context.object
    key.name = "PreviewKey"
    key.data.energy = 650
    key.data.shape = "DISK"
    key.data.size = 5.0
    bpy.ops.object.light_add(type="AREA", location=(4.0, 1.0, 3.0))
    fill = bpy.context.object
    fill.name = "PreviewFill"
    fill.data.energy = 320
    fill.data.size = 4.0
    scene = bpy.context.scene
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.055, 0.075, 0.10)
    scene.render.filepath = str(PREVIEW_PATH)
    scene.frame_set(1)
    bpy.ops.render.render(write_still=True)
    print(f"Wrote {BLEND_PATH}")
    print(f"Wrote {GLB_PATH}")
    print(f"Wrote {PREVIEW_PATH}")


if __name__ == "__main__":
    main()
