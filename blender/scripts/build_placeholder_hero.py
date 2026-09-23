"""Build a blocky, rigged and animated placeholder hero, then save and export it.

This is a stand in until the real hero is modeled. It exercises the whole
Blender to Godot pipeline: an armature, named actions that the Godot player
script plays automatically, and separate skinned meshes for the unarmored body,
hair styles (Hair_Short, Hair_Long) and armor pieces (Armor_Helmet, Armor_Chest,
Armor_Gauntlets, Armor_Greaves) that the game shows or hides.

Usage, from the repo root:

    blender -b -P blender/scripts/build_placeholder_hero.py

Writes blender/source/hero_placeholder.blend and game/assets/models/hero_placeholder.glb.
The hero faces -Y in Blender (the Blender "front"), which arrives in Godot facing +Z.
"""

import math
import pathlib
import sys

import bpy

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import export_glb  # noqa: E402

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
BLEND_PATH = REPO_ROOT / "blender" / "source" / "hero_placeholder.blend"
GLB_PATH = REPO_ROOT / "game" / "assets" / "models" / "hero_placeholder.glb"
FPS = 30

# name: (head, tail, parent)
BONES = {
    "hips": ((0, 0, 0.95), (0, 0, 1.1), None),
    "chest": ((0, 0, 1.1), (0, 0, 1.55), "hips"),
    "head": ((0, 0, 1.55), (0, 0, 1.9), "chest"),
    "upper_arm.L": ((0.3, 0, 1.53), (0.3, 0, 1.23), "chest"),
    "forearm.L": ((0.3, 0, 1.23), (0.3, 0, 0.93), "upper_arm.L"),
    "upper_arm.R": ((-0.3, 0, 1.53), (-0.3, 0, 1.23), "chest"),
    "forearm.R": ((-0.3, 0, 1.23), (-0.3, 0, 0.93), "upper_arm.R"),
    "thigh.L": ((0.11, 0, 0.9), (0.11, 0, 0.48), "hips"),
    "shin.L": ((0.11, 0, 0.48), (0.11, 0, 0.04), "thigh.L"),
    "thigh.R": ((-0.11, 0, 0.9), (-0.11, 0, 0.48), "hips"),
    "shin.R": ((-0.11, 0, 0.48), (-0.11, 0, 0.04), "thigh.R"),
}

# Each object is a separate skinned mesh so the game can show or hide it:
# hair styles by the player's choice, armor pieces when equipped from chests.
# (center, size, bone, material)
OBJECTS = {
    "Body": [
        ((0, 0, 0.98), (0.34, 0.2, 0.2), "hips", "Cloth"),
        ((0, 0, 1.33), (0.4, 0.22, 0.46), "chest", "Cloth"),
        ((0, 0, 1.03), (0.36, 0.23, 0.06), "hips", "Leather"),  # Belt
        ((0, 0, 1.72), (0.28, 0.28, 0.3), "head", "Skin"),
        ((-0.06, -0.141, 1.74), (0.05, 0.01, 0.05), "head", "Eyes"),
        ((0.06, -0.141, 1.74), (0.05, 0.01, 0.05), "head", "Eyes"),
        ((0.3, 0, 1.38), (0.12, 0.12, 0.3), "upper_arm.L", "Skin"),
        ((0.3, 0, 1.08), (0.11, 0.11, 0.3), "forearm.L", "Skin"),
        ((-0.3, 0, 1.38), (0.12, 0.12, 0.3), "upper_arm.R", "Skin"),
        ((-0.3, 0, 1.08), (0.11, 0.11, 0.3), "forearm.R", "Skin"),
        ((0.11, 0, 0.69), (0.14, 0.14, 0.42), "thigh.L", "Cloth"),
        ((0.11, -0.02, 0.24), (0.13, 0.17, 0.44), "shin.L", "Leather"),
        ((-0.11, 0, 0.69), (0.14, 0.14, 0.42), "thigh.R", "Cloth"),
        ((-0.11, -0.02, 0.24), (0.13, 0.17, 0.44), "shin.R", "Leather"),
    ],
    "Sword": [((-0.3, -0.5, 0.95), (0.05, 0.9, 0.05), "forearm.R", "Blade")],
    "Hair_Short": [
        ((0, 0.02, 1.88), (0.3, 0.3, 0.06), "head", "Hair"),
        ((0, 0.14, 1.76), (0.3, 0.04, 0.26), "head", "Hair"),
    ],
    "Hair_Long": [
        ((0, 0.02, 1.88), (0.3, 0.3, 0.06), "head", "Hair"),
        ((0, 0.15, 1.62), (0.32, 0.06, 0.5), "head", "Hair"),
        ((0.16, 0.03, 1.62), (0.05, 0.22, 0.5), "head", "Hair"),
        ((-0.16, 0.03, 1.62), (0.05, 0.22, 0.5), "head", "Hair"),
    ],
    "Armor_Helmet": [
        ((0, 0.01, 1.75), (0.34, 0.33, 0.38), "head", "Steel"),
        ((0, 0.01, 1.96), (0.05, 0.3, 0.06), "head", "Gold"),  # Crest
        ((0, -0.162, 1.76), (0.24, 0.01, 0.04), "head", "Eyes"),  # Visor slit
    ],
    "Armor_Chest": [
        ((0, 0, 1.34), (0.46, 0.28, 0.48), "chest", "Steel"),
        ((0.31, 0, 1.5), (0.2, 0.2, 0.12), "chest", "Steel"),  # Pauldrons
        ((-0.31, 0, 1.5), (0.2, 0.2, 0.12), "chest", "Steel"),
        ((0, 0, 1.1), (0.47, 0.29, 0.05), "chest", "Gold"),
    ],
    "Armor_Gauntlets": [
        ((0.3, 0, 1.03), (0.15, 0.15, 0.22), "forearm.L", "Steel"),
        ((-0.3, 0, 1.03), (0.15, 0.15, 0.22), "forearm.R", "Steel"),
    ],
    "Armor_Greaves": [
        ((0.11, 0, 0.71), (0.18, 0.18, 0.34), "thigh.L", "Steel"),
        ((-0.11, 0, 0.71), (0.18, 0.18, 0.34), "thigh.R", "Steel"),
        ((0.11, -0.02, 0.3), (0.17, 0.21, 0.34), "shin.L", "Steel"),
        ((-0.11, -0.02, 0.3), (0.17, 0.21, 0.34), "shin.R", "Steel"),
    ],
}

# Base colors are linear (Blender's color space). The game recolors Skin and Hair
# with the player's choices and never touches the others.
MATERIALS = {
    "Skin": ((0.72, 0.45, 0.32, 1), 0.0, 0.7),
    "Eyes": ((0.02, 0.02, 0.03, 1), 0.0, 0.4),
    "Hair": ((0.12, 0.06, 0.03, 1), 0.0, 0.8),
    "Cloth": ((0.36, 0.3, 0.2, 1), 0.0, 0.9),
    "Leather": ((0.12, 0.06, 0.03, 1), 0.0, 0.7),
    "Steel": ((0.55, 0.58, 0.62, 1), 0.8, 0.35),
    "Gold": ((0.8, 0.5, 0.12, 1), 0.9, 0.3),
    "Blade": ((0.7, 0.75, 0.8, 1), 0.9, 0.2),
}


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def make_armature() -> bpy.types.Object:
    data = bpy.data.armatures.new("HeroRig")
    rig = bpy.data.objects.new("HeroRig", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, parent) in BONES.items():
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = head, tail
        if parent:
            bone.parent = data.edit_bones[parent]
            bone.use_connect = bone.head == data.edit_bones[parent].tail
    bpy.ops.object.mode_set(mode="OBJECT")
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = "XYZ"
    return rig


def make_materials() -> dict:
    materials = {}
    for name, (color, metallic, roughness) in MATERIALS.items():
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        materials[name] = mat
    return materials


def make_mesh(rig: bpy.types.Object, name: str, parts: list, materials: dict) -> bpy.types.Object:
    verts, faces, face_mats, groups = [], [], [], {}
    used = list(dict.fromkeys(mat for *_, mat in parts))
    for center, size, bone, mat in parts:
        base = len(verts)
        for i in range(8):
            corner = [(1 if i & (1 << axis) else -1) for axis in range(3)]
            verts.append(tuple(c + s * 0.5 * k for c, s, k in zip(center, size, corner)))
        groups.setdefault(bone, []).extend(range(base, base + 8))
        for quad in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
            faces.append(tuple(base + q for q in quad))
            face_mats.append(used.index(mat))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    for mat in used:
        mesh.materials.append(materials[mat])
    for poly, mat_index in zip(mesh.polygons, face_mats):
        poly.material_index = mat_index

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for bone, indices in groups.items():
        obj.vertex_groups.new(name=bone).add(indices, 1.0, "REPLACE")
    obj.parent = rig
    obj.modifiers.new("Armature", "ARMATURE").object = rig
    return obj


def key_pose(rig, frame: int, pose: dict) -> None:
    """pose maps bone name to (rx, ry, rz) in degrees, plus an optional "hips_y" height offset."""
    for pose_bone in rig.pose.bones:
        rot = pose.get(pose_bone.name, (0, 0, 0))
        pose_bone.rotation_euler = [math.radians(a) for a in rot]
        pose_bone.keyframe_insert("rotation_euler", frame=frame)
    hips = rig.pose.bones["hips"]
    hips.location = (0, pose.get("hips_y", 0.0), 0)  # Bone local Y points up for the hips.
    hips.keyframe_insert("location", frame=frame)


def make_action(rig, name: str, keys: list) -> None:
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data_create().action = action
    for frame, pose in keys:
        key_pose(rig, frame, pose)


def build_actions(rig) -> None:
    # Bones hanging down (arms, legs): +X rotation swings them backward, -X forward.
    arms_down = {"upper_arm.L": (0, 0, 8), "upper_arm.R": (0, 0, -8)}
    make_action(rig, "Idle", [
        (1, {**arms_down}),
        (20, {**arms_down, "chest": (3, 0, 0), "head": (-3, 0, 0), "hips_y": -0.015}),
        (40, {**arms_down}),
    ])

    stride, arm_swing = 40, 35
    run_a = {"thigh.L": (-stride, 0, 0), "shin.L": (20, 0, 0), "thigh.R": (stride, 0, 0), "shin.R": (50, 0, 0),
             "upper_arm.L": (arm_swing, 0, 8), "upper_arm.R": (-arm_swing, 0, -8),
             "forearm.L": (-30, 0, 0), "forearm.R": (-30, 0, 0), "chest": (8, 0, 0)}
    run_b = {"thigh.L": (stride, 0, 0), "shin.L": (50, 0, 0), "thigh.R": (-stride, 0, 0), "shin.R": (20, 0, 0),
             "upper_arm.L": (-arm_swing, 0, 8), "upper_arm.R": (arm_swing, 0, -8),
             "forearm.L": (-30, 0, 0), "forearm.R": (-30, 0, 0), "chest": (8, 0, 0)}
    make_action(rig, "Run", [(1, run_a), (6, {**run_a, "hips_y": 0.05}), (11, run_b),
                             (16, {**run_b, "hips_y": 0.05}), (21, run_a)])

    make_action(rig, "Jump", [
        (1, {"thigh.L": (-50, 0, 0), "shin.L": (70, 0, 0), "thigh.R": (-10, 0, 0), "shin.R": (30, 0, 0),
             "upper_arm.L": (-20, 0, 30), "upper_arm.R": (-20, 0, -30)}),
    ])

    # Three sword swings: a sweep across the body, a return sweep, an overhead slam.
    ready = {"upper_arm.R": (-60, 0, -40), "forearm.R": (-30, 0, 0), "chest": (0, 25, 0)}
    make_action(rig, "Attack1", [(1, ready),
                                 (5, {"upper_arm.R": (-85, 0, 30), "forearm.R": (-10, 0, 0), "chest": (0, -30, 0)}),
                                 (13, {**arms_down})])
    make_action(rig, "Attack2", [(1, {"upper_arm.R": (-85, 0, 30), "chest": (0, -30, 0)}),
                                 (5, {"upper_arm.R": (-70, 0, -50), "forearm.R": (-20, 0, 0), "chest": (0, 30, 0)}),
                                 (13, {**arms_down})])
    make_action(rig, "Attack3", [(1, {"upper_arm.R": (-170, 0, 0), "forearm.R": (-20, 0, 0), "chest": (-10, 0, 0)}),
                                 (5, {"upper_arm.R": (-60, 0, 0), "forearm.R": (-10, 0, 0), "chest": (25, 0, 0),
                                      "thigh.L": (-30, 0, 0), "shin.L": (30, 0, 0)}),
                                 (13, {**arms_down})])

    make_action(rig, "Shoot", [(1, {"upper_arm.L": (-90, 0, 0), "chest": (0, -15, 0)}),
                               (3, {"upper_arm.L": (-80, 0, 0), "forearm.L": (-15, 0, 0), "chest": (0, -15, 0)}),
                               (9, {"upper_arm.L": (-90, 0, 0), "chest": (0, -15, 0)})])

    crouch = {"hips_y": -0.35, "chest": (40, 0, 0), "head": (-20, 0, 0),
              "thigh.L": (-80, 0, 0), "shin.L": (100, 0, 0), "thigh.R": (-80, 0, 0), "shin.R": (100, 0, 0),
              "upper_arm.L": (-40, 0, 20), "upper_arm.R": (-40, 0, -20)}
    make_action(rig, "Dodge", [(1, {}), (4, crouch), (8, crouch), (11, {})])

    make_action(rig, "Hurt", [(1, {}), (3, {"chest": (-20, 0, 0), "head": (-15, 0, 0),
                                           "upper_arm.L": (20, 0, 30), "upper_arm.R": (20, 0, -30)}), (10, {})])

    make_action(rig, "Death", [(1, {}), (8, {**crouch, "chest": (60, 0, 0)}),
                               (16, {**crouch, "chest": (80, 0, 0), "head": (20, 0, 0), "hips_y": -0.6})])

    rig.animation_data.action = bpy.data.actions["Idle"]


def main() -> None:
    reset_scene()
    rig = make_armature()
    materials = make_materials()
    for name, parts in OBJECTS.items():
        make_mesh(rig, name, parts, materials)
    build_actions(rig)
    BLEND_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    export_glb.export(GLB_PATH)


if __name__ == "__main__":
    main()
