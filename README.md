# Block Rift Runner

A standalone, low-poly space-flight arcade game built with Godot. Courses are assembled from rule-checked block formations in open space; the ship and scenery use simple geometry and flat materials.

## Current playable slice

- Landscape flight view with responsive expanded layout for wider Android screens.
- Expanded free-flight steering range so you can sweep across the open course instead of staying near the center.
- Endless runs assembled from block gates, debris fields, salvage paths, and drone encounters.
- Drag to steer; hold **FIRE** to shoot; tap **BOOST** to surge. Desktop testing also supports mouse drag, Space, and Shift.
- Three lives per run. A rare life cache has a random 20% chance to appear in each run.
- Scrap and unlocked ship blocks persist between runs. Four modular parts can be bought and equipped in the hangar; the active build resets after a run ends.
- Separate ship-builder window with category tabs, photo-style previews, scrap costs, and a rotatable live ship preview.
- Blender-authored low-poly ship modules and three asteroid models used in the generated flight corridors, with the editable source scene and generation script included.
- A high-resolution deep-space photo backdrop frames the flight path; detailed, smooth-shaded asteroid hazards contrast with the intentionally blocky low-poly ship.

This is an early playable build. Flight feel, collision spacing, and touch sizing are ready for device feedback and tuning.

## Toolchain

| Tool | Version / setting |
| --- | --- |
| Godot | 4.5.1 stable |
| Renderer | Mobile (Vulkan on Android) |
| Blender | 4.5.3 for source assets |
| Android export | Android SDK 35, NDK 28.1.13356709, CMake 3.10.2.4988404, JDK 17 |
| Android ABI | arm64-v8a |

The game project stays separate from the other vehicle and AI projects. Blender files are source assets; export runtime models as GLB before importing them into Godot.

## Open in Godot

Open this repository's `project.godot` in Godot 4.5.1. The project uses the Mobile renderer, which uses Vulkan on supported Android devices. Keep models low-poly and favor flat-color materials; textures are optional.

## Blender asset handoff

Keep editable `.blend` files in `art/source/` and exported `.glb` files in `art/models/`. From the repository root, export a scene with:

```sh
blender -b art/source/example.blend --python tools/blender/export_glb.py -- --output art/models/example.glb
```

The exporter writes a GLB with Blender's Y-up to Godot's coordinate conversion enabled. Avoid checking generated renders or Blender backup files into the repository.

## Android review APK

The `Android` Godot export preset targets landscape ARM64 and uses the repository's temporary test debug key so successive review APKs can install as updates. The key is public by design and must only be used for development builds. It is not a release or store signing key. If the key is replaced, uninstall the existing test APK before installing the newly signed build.

To export locally, install the Android SDK packages listed above, configure the Java SDK and Android SDK paths in Godot Editor Settings, and install the Godot 4.5.1 export templates. The helper decodes the tracked public test key when needed, then exports the APK:

```sh
bash tools/android/export_debug.sh
```

GitHub Actions builds the same debug APK on pushes to `main` and on manual dispatch, then publishes it as a workflow artifact. It never uses release signing credentials.

## Repository map

- `scenes/` — Godot scenes
- `art/source/` — Blender source files
- `art/models/` — GLB runtime assets
- `tools/blender/` — Blender export helper
- `tools/android/` — Android export helper
- `.github/workflows/` — project validation and Android APK build workflows

