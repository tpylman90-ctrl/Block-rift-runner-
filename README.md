# Block Rift Runner

A standalone, low-poly space-flight arcade game built with Godot. Courses are assembled from rule-checked block formations in open space; the ship and scenery use simple geometry and flat materials.

## Current playable slice

- Landscape flight view with responsive expanded layout for wider Android screens.
- Expanded free-flight steering range so you can sweep across the open course instead of staying near the center.
- Runs are divided into increasingly long flight stages assembled from block gates, debris fields, salvage paths, and drone encounters.
- Drag to steer; hold **FIRE** to shoot; tap **BOOST** to surge. Desktop testing also supports mouse drag, Space, and Shift.
- Three lives per run. A rare life cache has a random 20% chance to appear in each run.
- Each stage ends at a decision pause: bank the unbanked salvage and return to the hangar, or continue with the haul at risk for a higher multiplier. The first leg is 600m; each continued stage grows by 15% up to 1,800m, while course segments pack closer and debris/walls add hazards over time. Continuing raises the multiplier by 0.25 and speed by 1.2 up to the run's speed cap. The pause displays the completed and upcoming leg lengths before the choice.
- Only cashed-out salvage becomes banked scrap. Losing all lives forfeits the unbanked haul; unlocked ship blocks and previously banked scrap persist.
- Six compressed scenic backgrounds each have five camera crops, giving 30 reusable space views without 30 full-size textures. A new view is selected for every run and continued stage.
- Build the ship from a small cockpit core and individually placed hull cubes, nose wedges, a fuselage, cockpit shells, and flat body plates. Wing sets, fins, three engine types, four cannon types, shield emitters/plates, and armor blocks add visual and flight/combat differences.
- Drag library cards onto the magnetic build grid, then drag placed blocks to move them. Rotate, change depth, and remove individual blocks. The ship carries 8 base mass and has a 50 mass limit; each library card shows its block mass, overweight additions are rejected, and heavier builds turn and boost more slowly. Builders can place up to 20 blocks and orbit the preview.
- The flight backdrop uses a full-screen scenic image layer with 30 reusable crop views, keeping it visible on Android even if the 3D backdrop plane fails to render.
- Ship blocks use editable flat-color primitive meshes; three Blender-authored asteroid models furnish the flight corridors, with the source scene and asset-generation script included.
- High-resolution deep-space photo backdrops frame each flight stage; detailed, smooth-shaded asteroid hazards contrast with the intentionally blocky low-poly ship.

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

