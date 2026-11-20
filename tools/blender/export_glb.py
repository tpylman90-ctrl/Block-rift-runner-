"""Export the current Blender scene to a Godot-friendly binary glTF file.

Usage:
  blender -b scene.blend --python tools/blender/export_glb.py -- --output art/models/scene.glb
"""

import argparse
import os
import sys

import bpy


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, help="Destination .glb path")
    options = parser.parse_args(args)

    output_path = os.path.abspath(options.output)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        use_selection=False,
    )
    print(f"Exported GLB: {output_path}")


if __name__ == "__main__":
    main()

