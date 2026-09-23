"""Export a .blend file to a glTF binary (.glb) that Godot imports automatically.

Usage, from the repo root:

    blender -b blender/source/hero.blend -P blender/scripts/export_glb.py
    blender -b blender/source/hero.blend -P blender/scripts/export_glb.py -- --out game/assets/models/hero.glb

The default output is game/assets/models/<blend name>.glb. If the file has a
collection named "Export", only the objects in it are exported, so helper
objects (reference images, cameras, lights) can stay in the .blend.

Every action in the file is exported as a separate animation, named after the
action (Idle, Run, Attack1, ...).
"""

import argparse
import pathlib
import sys

import bpy

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
MODELS_DIR = REPO_ROOT / "game" / "assets" / "models"


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", help="output .glb path (default: game/assets/models/<blend>.glb)")
    return parser.parse_args(argv)


def export(out: pathlib.Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    options = dict(
        filepath=str(out),
        export_format="GLB",
        export_apply=True,  # Apply modifiers (mirror, subdivision, ...).
        export_yup=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
    )

    export_collection = bpy.data.collections.get("Export")
    if export_collection is not None:
        for obj in bpy.context.scene.objects:
            obj.select_set(obj.name in export_collection.all_objects)
        options["use_selection"] = True

    bpy.ops.export_scene.gltf(**options)
    print(f"Exported {out}")


def main() -> None:
    args = parse_args()
    if args.out:
        out = pathlib.Path(args.out).resolve()
    elif bpy.data.filepath:
        out = MODELS_DIR / f"{pathlib.Path(bpy.data.filepath).stem}.glb"
    else:
        sys.exit("Save the .blend file first or pass --out")
    export(out)


if __name__ == "__main__":
    main()
