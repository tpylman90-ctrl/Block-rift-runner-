"""Build Block Rift Runner's editable, low-poly ship-block library and thumbnails."""
import math
import os
import random
import sys
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
PREVIEW_DIR = os.path.join(ROOT, "art/library/previews")
MODEL_DIR = os.path.join(ROOT, "art/library/models")
SOURCE_DIR = os.path.join(ROOT, "art/source")
os.makedirs(PREVIEW_DIR, exist_ok=True)
os.makedirs(MODEL_DIR, exist_ok=True)
os.makedirs(SOURCE_DIR, exist_ok=True)
random.seed(4082)


def mat(name, color, metallic=0.08, emission=0.0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*color, 1.0)
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = 0.48
    if emission:
        principled.inputs["Emission Color"].default_value = (*color, 1.0)
        principled.inputs["Emission Strength"].default_value = emission
    return material


RED = mat("Hull | Rift coral", (0.72, 0.12, 0.16), 0.18)
WHITE = mat("Hull | Ceramic", (0.78, 0.86, 0.92), 0.12)
GOLD = mat("Trim | Warm alloy", (0.98, 0.58, 0.14), 0.34)
BLUE = mat("Core | Deep blue", (0.06, 0.18, 0.36), 0.27)
CYAN = mat("Energy | Ion cyan", (0.12, 0.74, 1.0), 0.1, 2.4)
PURPLE = mat("Energy | Rift violet", (0.65, 0.23, 1.0), 0.1, 2.0)
ROCKS = [mat("Asteroid | Slate", (0.13, 0.21, 0.3)), mat("Asteroid | Blue basalt", (0.19, 0.29, 0.4)), mat("Asteroid | Cold face", (0.28, 0.38, 0.48))]


def cube(name, location, dimensions, material, bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel:
        modifier = obj.modifiers.new("single-cut edge glint", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.modifiers.new("weighted block normals", "WEIGHTED_NORMAL")
    return obj


def cyl(name, location, radius, depth, material, vertices=8, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def ico_rock(name, location, scale, material_index=0, seed=0):
    random.seed(seed + 4082)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    for vertex in obj.data.vertices:
        factor = random.uniform(0.72, 1.3)
        vertex.co *= factor
    obj.scale = scale
    obj.data.materials.append(ROCKS[material_index % len(ROCKS)])
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    return obj


def splitter_nose():
    return [
        cube("splitter | center keel", (0, 0, 0), (2.2, 0.42, 1.25), RED),
        cube("splitter | left blade", (-0.86, -0.12, -0.28), (0.62, 0.16, 1.85), WHITE, 0.035),
        cube("splitter | right blade", (0.86, -0.12, -0.28), (0.62, 0.16, 1.85), WHITE, 0.035),
        cube("splitter | gold leading edge", (0, 0.23, -0.56), (0.9, 0.08, 0.35), GOLD, 0.025),
    ]


def wing_pack():
    objects = []
    for side in (-1, 1):
        objects.extend([
            cube("wing | swept block", (side * 1.05, 0, 0), (2.35, 0.22, 1.2), WHITE, 0.055),
            cube("wing | coral tip", (side * 2.0, 0.08, 0.12), (0.62, 0.3, 0.72), RED, 0.045),
            cube("wing | ion strip", (side * 1.3, -0.14, 0.1), (1.3, 0.045, 0.12), CYAN, 0.015),
        ])
    return objects


def fin_set():
    return [
        cube("fin | left blade", (-0.72, 0.62, 0.1), (0.32, 1.3, 0.8), RED, 0.045),
        cube("fin | right blade", (0.72, 0.62, 0.1), (0.32, 1.3, 0.8), RED, 0.045),
        cube("fin | cross brace", (0, 0.54, 0.32), (1.5, 0.16, 0.38), GOLD, 0.035),
    ]


def boost_core():
    return [
        cube("engine | armored housing", (0, 0, 0.22), (1.45, 1.0, 1.8), BLUE, 0.11),
        cube("engine | upper spine", (0, 0.56, -0.12), (0.58, 0.16, 1.0), GOLD, 0.035),
        cyl("engine | ion nozzle", (0, -0.01, 1.18), 0.52, 0.35, CYAN, 8),
        cube("engine | side rail left", (-0.82, 0.02, 0.32), (0.18, 0.7, 1.3), WHITE, 0.035),
        cube("engine | side rail right", (0.82, 0.02, 0.32), (0.18, 0.7, 1.3), WHITE, 0.035),
    ]


def side_pods():
    objects = []
    for side in (-1, 1):
        objects.extend([
            cube("pod | shell", (side * 0.78, 0, 0), (0.82, 0.9, 1.8), BLUE, 0.12),
            cube("pod | armor cap", (side * 0.78, 0.5, -0.1), (0.56, 0.13, 1.1), GOLD, 0.04),
            cyl("pod | nozzle", (side * 0.78, 0, 1.05), 0.27, 0.3, CYAN, 8),
        ])
    return objects


def twin_cannon():
    return [
        cube("cannon | receiver", (0, 0, 0.35), (1.25, 0.7, 1.25), BLUE, 0.08),
        cube("cannon | upper bridge", (0, 0.42, 0.1), (0.8, 0.16, 0.75), GOLD, 0.035),
        cube("cannon | left barrel", (-0.37, 0, -0.65), (0.3, 0.3, 1.3), WHITE, 0.04),
        cube("cannon | right barrel", (0.37, 0, -0.65), (0.3, 0.3, 1.3), WHITE, 0.04),
        cyl("cannon | left muzzle", (-0.37, 0, -1.35), 0.19, 0.16, CYAN, 8),
        cyl("cannon | right muzzle", (0.37, 0, -1.35), 0.19, 0.16, CYAN, 8),
    ]


def armor():
    return [
        cube("armor | main plate", (0, 0, 0.2), (1.95, 0.34, 1.7), RED, 0.055),
        cube("armor | left rib", (-0.68, -0.26, 0.15), (0.22, 0.22, 1.3), GOLD, 0.03),
        cube("armor | right rib", (0.68, -0.26, 0.15), (0.22, 0.22, 1.3), GOLD, 0.03),
        cube("armor | center badge", (0, -0.22, -0.22), (0.55, 0.12, 0.48), WHITE, 0.025),
    ]


PART_BUILDERS = {
    "splitter_nose": splitter_nose,
    "wing_pack": wing_pack,
    "fin_set": fin_set,
    "boost_core": boost_core,
    "side_pods": side_pods,
    "twin_cannon": twin_cannon,
    "armor": armor,
}


def asteroid_cluster(variant=0):
    return [
        ico_rock("asteroid | main mass", (0, 0, 0), (2.0, 1.55, 1.7), variant, 31 + variant),
        ico_rock("asteroid | satellite shard", (1.5, -0.5, 0.5), (0.88, 0.7, 0.76), variant + 1, 51 + variant),
        ico_rock("asteroid | trailing fragment", (-1.28, 0.3, -0.62), (0.7, 0.82, 0.62), variant + 2, 71 + variant),
        cyl("asteroid | exposed crystal", (0.05, -1.03, -0.28), 0.34, 1.22, CYAN, 6, (math.radians(90), 0, 0)),
    ]


def look_at(obj, point):
    obj.rotation_euler = (Vector(point) - obj.location).to_track_quat("-Z", "Y").to_euler()


def setup_studio():
    bpy.ops.object.camera_add(location=(6.2, -8.0, 5.5))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 6.8
    look_at(camera, (0, 0, 0))
    bpy.context.scene.camera = camera
    for name, location, power, size in [
        ("key", (2, -5, 8), 1050, 6),
        ("fill", (-6, -1, 2), 780, 5),
        ("rim", (3, 5, 4), 1200, 4),
    ]:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = "studio " + name
        light.data.energy = power
        light.data.shape = "DISK"
        light.data.size = size
        look_at(light, (0, 0, 0))


def prepare_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 24
    scene.render.resolution_x = 512
    scene.render.resolution_y = 300
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    scene.world.color = (0.015, 0.035, 0.07)
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.012, 0.03, 0.065, 1)
    background.inputs["Strength"].default_value = 0.45
    return scene


def render_thumb(part_id, builder):
    scene = prepare_scene()
    objects = builder()
    setup_studio()
    scene.camera.data.ortho_scale = 6.4 if part_id != "asteroid" else 7.4
    scene.render.filepath = os.path.join(PREVIEW_DIR, part_id + ".png")
    bpy.ops.render.render(write_still=True)
    # Store a standalone GLB for direct Blender/Godot reuse.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=os.path.join(MODEL_DIR, part_id + ".glb"), export_format="GLB", use_selection=True, export_apply=True)


def save_library_source():
    prepare_scene()
    for index, (part_id, builder) in enumerate(PART_BUILDERS.items()):
        column = index % 4
        row = index // 4
        offset = Vector((column * 8.0, row * -7.0, 0.0))
        collection = bpy.data.collections.new("BLOCK " + part_id.upper())
        bpy.context.scene.collection.children.link(collection)
        objects = builder()
        for obj in objects:
            for old_collection in list(obj.users_collection):
                old_collection.objects.unlink(obj)
            collection.objects.link(obj)
            obj.location += offset
    asteroid_collection = bpy.data.collections.new("ENVIRONMENT LOW-POLY ASTEROIDS")
    bpy.context.scene.collection.children.link(asteroid_collection)
    for index in range(3):
        offset = Vector((index * 7.5, -14.0, 0.0))
        for obj in asteroid_cluster(index):
            for old_collection in list(obj.users_collection):
                old_collection.objects.unlink(obj)
            asteroid_collection.objects.link(obj)
            obj.location += offset
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE_DIR, "block_rift_modular_library.blend"))


force = "--force" in sys.argv
for part_id, builder in PART_BUILDERS.items():
    preview_path = os.path.join(PREVIEW_DIR, part_id + ".png")
    model_path = os.path.join(MODEL_DIR, part_id + ".glb")
    if force or not (os.path.exists(preview_path) and os.path.exists(model_path)):
        render_thumb(part_id, builder)
asteroid_preview = os.path.join(PREVIEW_DIR, "asteroid.png")
if force or not os.path.exists(asteroid_preview):
    render_thumb("asteroid", lambda: asteroid_cluster(0))
for variant in range(3):
    # Each variant is a separate low-poly, texture-free reusable environment prop.
    asteroid_path = os.path.join(MODEL_DIR, f"asteroid_{variant + 1}.glb")
    if force or not os.path.exists(asteroid_path):
        prepare_scene()
        objects = asteroid_cluster(variant)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.export_scene.gltf(filepath=asteroid_path, export_format="GLB", use_selection=True, export_apply=True)
save_library_source()
print("Generated Blender part previews, editable .blend library, modular GLBs, and three asteroid variants.")
